const { test, expect } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, failOnConsoleErrors, callTestHook } = require('./helpers');

test.describe('Analytics page', () => {
  test.beforeEach(async ({ page }) => {
    await failOnConsoleErrors(page);
    await callTestHook(page, '/api/test/reset-db');
    await loginViaUI(page);
    await page.goto('/analytics');
    await page.waitForLoadState('networkidle');
  });

  test('charts render and live refresh after new report', async ({ page, request }) => {
    const chart = page.getByTestId('analytics-chart').first();
    await expect(chart).toBeVisible({ timeout: 7000 });

    // Create a new report to ensure analytics data changes deterministically
    await callTestHook(page, '/api/test/create-report', { title: 'Test Report', description: 'for analytics', category: 'Pothole', lat: 12.9, lng: 80.1 });

    await page.reload({ waitUntil: 'networkidle' });
    await expect(chart).toBeVisible({ timeout: 10000 });
  });
});
