const { test, expect } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, failOnConsoleErrors, callTestHook } = require('./helpers');

test.describe('Maps / Leaflet', () => {
  test.beforeEach(async ({ page }) => {
    await failOnConsoleErrors(page);
    await callTestHook(page, '/api/test/reset-db');
    await loginViaUI(page);
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('leaflet container, markers, popup and realtime marker updates', async ({ page }) => {
    // Ensure leaflet loaded
    const container = page.getByTestId('leaflet-map');
    await expect(container).toBeVisible({ timeout: 10000 });

    // Markers exist
    const markers = page.locator('[data-testid="map-marker"]');
    await expect(markers.first()).toBeVisible({ timeout: 10000 });

    // Click first marker and check popup
    await markers.first().click({ force: true });
    const popup = page.locator('.leaflet-popup-content, .leaflet-popup');
    await expect(popup.first()).toBeVisible({ timeout: 10000 });

    // Realtime marker updates: create a new report, wait for the dashboard to refresh, and verify the new marker
    const initialCount = await markers.count();
    const created = await callTestHook(page, '/api/test/create-report', {
      title: 'Test Report Map',
      description: 'Map update test',
      category: 'Pothole',
      lat: 12.93,
      lng: 80.25,
    });
    expect(created.ok).toBeTruthy();

    await page.reload({ waitUntil: 'networkidle' });

    const updatedMarkers = page.locator('[data-testid="map-marker"]');
    await expect(await updatedMarkers.count()).toBeGreaterThan(initialCount);

    await updatedMarkers.first().click({ force: true });
    await expect(page.locator('.leaflet-popup-content')).toContainText(/Test Report Map|Pending|In Progress|Resolved/);
  });
});
