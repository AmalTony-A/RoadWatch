const { test, expect } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, failOnConsoleErrors, callTestHook } = require('./helpers');

test.describe('Dashboard', () => {
  test.beforeEach(async ({ page }) => {
    await failOnConsoleErrors(page);
    await callTestHook(page, '/api/test/reset-db');
    await loginViaUI(page);
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('stats and activity feed', async ({ page }) => {
    // Check stats
    const stats = page.getByTestId('dashboard-stats');
    await expect(stats.first()).toBeVisible({ timeout: 10000 });

    // Activity feed
    const feed = page.getByTestId('activity-feed');
    await expect(feed.first()).toBeVisible({ timeout: 7000 });

  });
});
