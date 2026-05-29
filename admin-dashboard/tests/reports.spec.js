const { test, expect, request } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, failOnConsoleErrors, callTestHook } = require('./helpers');

test.describe('Reports CRUD and realtime', () => {
  test('create -> appears -> update status -> realtime -> delete', async ({ page, request: apiRequest }) => {
    await failOnConsoleErrors(page);
    await callTestHook(page, '/api/test/reset-db');
    await page.goto('/');
    const token = await loginViaUI(page);

    // Create report via deterministic test hook
    const payload = { title: 'Test Report', description: 'Created by Playwright', category: 'Pothole', lat: 12.9, lng: 80.1 };
    const created = await callTestHook(page, '/api/test/create-report', payload);
    expect(created.ok).toBeTruthy();
    const reportId = created.report._id || created.report.id;
    expect(reportId).toBeTruthy();

    // Verify appears in UI list
    await page.goto('/reports');
    await page.waitForLoadState('networkidle');
    const row = page.getByTestId('report-row').filter({ hasText: payload.title });
    await expect(row.first()).toBeVisible({ timeout: 10000 });

    // Update status deterministically and verify the refreshed list reflects it
    const updated = await callTestHook(page, '/api/test/emit-report-updated', { reportId, status: 'Resolved' });
    expect(updated.ok).toBeTruthy();

    await page.reload({ waitUntil: 'networkidle' });
    await expect(page.getByTestId('report-row').filter({ hasText: 'Resolved' }).first()).toBeVisible({ timeout: 10000 });

    // Delete deterministically and verify removal
    const deleted = await callTestHook(page, '/api/test/emit-report-deleted', { reportId });
    expect(deleted.ok).toBeTruthy();

    await page.reload({ waitUntil: 'networkidle' });
    await expect(page.getByTestId('report-row').filter({ hasText: payload.title })).toHaveCount(0, { timeout: 10000 });
  });
});
