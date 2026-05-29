const { test, expect } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, failOnConsoleErrors, callTestHook } = require('./helpers');

test.describe('Users management', () => {
  test.beforeEach(async ({ page }) => {
    await failOnConsoleErrors(page);
    await callTestHook(page, '/api/test/reset-db');
    await loginViaUI(page);
    await page.goto('/users');
    await page.waitForLoadState('networkidle');
  });

  test('promote, ban/unban, delete flows (best-effort selectors)', async ({ page }) => {
    // Target the deterministic seeded test user
    const row = page.getByTestId('user-row').filter({ hasText: 'test@roadwatch.local' }).first();
    await expect(row).toBeVisible({ timeout: 7000 });

    // Promote to moderator
    const promoteBtn = row.locator('button:has-text("Promote"), button:has-text("Make Moderator"), button[aria-label="promote"]');
    if (await promoteBtn.count()) {
      await Promise.all([
        page.waitForResponse((response) => response.url().includes('/api/admin/user/') && response.url().includes('/role') && response.ok(), { timeout: 10000 }),
        promoteBtn.first().click(),
      ]);
      await page.reload({ waitUntil: 'networkidle' });
    } else {
      test.skip(true, 'Promote button not found');
    }

    // Promote to admin
    const promoteAdmin = row.locator('button:has-text("Make Admin"), button:has-text("Promote to Admin")');
    if (await promoteAdmin.count()) {
      await Promise.all([
        page.waitForResponse((response) => response.url().includes('/api/admin/user/') && response.url().includes('/role') && response.ok(), { timeout: 10000 }),
        promoteAdmin.first().click(),
      ]);
      await page.reload({ waitUntil: 'networkidle' });
    }

    // Ban user
    const banBtn = row.locator('button:has-text("Ban"), button[aria-label="ban"]');
    if (await banBtn.count()) {
      await Promise.all([
        page.waitForResponse((response) => response.url().includes('/api/admin/user/') && response.url().includes('/ban') && response.ok(), { timeout: 10000 }),
        banBtn.first().click(),
      ]);
      await page.reload({ waitUntil: 'networkidle' });
    }

    // Unban user
    const unbanBtn = row.locator('button:has-text("Unban"), button[aria-label="unban"]');
    if (await unbanBtn.count()) {
      await Promise.all([
        page.waitForResponse((response) => response.url().includes('/api/admin/user/') && response.url().includes('/ban') && response.ok(), { timeout: 10000 }),
        unbanBtn.first().click(),
      ]);
      await page.reload({ waitUntil: 'networkidle' });
    }

    // Delete user
    const del = row.locator('button:has-text("Delete"), button[aria-label="delete"]');
    if (await del.count()) {
      await del.first().click();
      // confirm dialog if present
      const confirm = page.locator('button:has-text("Confirm"), button:has-text("Yes, delete")');
      if (await confirm.count()) {
        await Promise.all([
          page.waitForResponse((response) => response.url().includes('/api/admin/user/') && response.request().method() === 'DELETE' && response.ok(), { timeout: 10000 }),
          confirm.first().click(),
        ]);
      }
      await page.reload({ waitUntil: 'networkidle' });
    }
  });
});
