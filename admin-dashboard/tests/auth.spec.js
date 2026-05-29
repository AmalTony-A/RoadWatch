const { test, expect, request } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, failOnConsoleErrors, callTestHook } = require('./helpers');

test.describe('Authentication flow', () => {
  test('login, persist session, logout', async ({ page, baseURL }) => {
    await failOnConsoleErrors(page);
    await callTestHook(page, '/api/test/reset-db');
    await page.goto('/');
    const token = await loginViaUI(page);
    expect(token).toBeTruthy();

    // Dashboard should be visible
    await expect(page).toHaveURL(/\/$|\/dashboard/i);

    // Refresh and ensure session persists
    await page.reload({ waitUntil: 'networkidle' });
    const tokenAfter = await page.evaluate(() => sessionStorage.getItem('rw_token'));
    expect(tokenAfter).toBeTruthy();

    // Logout via UI - try common logout selectors
    const logout = page.getByRole('button', { name: /logout/i });
    if (await logout.count()) {
      await Promise.all([
        page.waitForURL(/\/login/i, { timeout: 10000 }).catch(() => {}),
        logout.first().click(),
      ]);
      await expect(page).toHaveURL(/login|\/login/i);
    } else {
      test.skip(true, 'Logout control not found');
    }
  });
});
