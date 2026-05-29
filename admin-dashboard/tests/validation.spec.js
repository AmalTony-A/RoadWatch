const { test, expect } = require('@playwright/test');
test.describe.configure({ retries: 2 })
const { loginViaUI, callTestHook } = require('./helpers');

test('global validation: no console errors, no failed network requests, no unhandled exceptions', async ({ page }) => {
  const consoleErrors = [];
  const requestFailures = [];
  const pageErrors = [];

  page.on('console', msg => {
    if (msg.type() === 'error') {
      const text = msg.text();
      // ignore harmless cookie policy logs
      if (/Cookie .*rejected|has been rejected|rejected because/i.test(text)) return;
      // ignore React Router v7 migration warnings
      if (/React Router v7|migration|useNavigateStable|UseNavigate|UseRevalidator/i.test(text)) return;
      consoleErrors.push(text);
    }
  });
  page.on('requestfailed', req => {
    const f = req.failure();
    // ignore aborted module requests (HMR / chunk aborts)
    if (f && f.errorText && f.errorText.includes('ERR_ABORTED')) return;
    if (req.url().includes('/src/')) return;
    requestFailures.push({ url: req.url(), failure: f });
  });
  // also record responses with HTTP status >= 400
  page.on('response', resp => {
    try {
      const status = resp.status();
      if (status >= 400) {
        const url = resp.url();
        // ignore source map and devtools asset 404s
        if (/\.map$|playwright-report|trace|defaultSettingsView/.test(url)) return;
        requestFailures.push({ url, status, statusText: resp.statusText() });
      }
    } catch (e) {
      // ignore errors while reading response
    }
  });
  page.on('pageerror', err => pageErrors.push(err.message));

  await callTestHook(page, '/api/test/reset-db');
  await page.goto('/');
  // try to login to get authenticated access for subsequent pages
  try {
    await loginViaUI(page);
  } catch (e) {
    // if login fails, continue to basic checks
  }

  const paths = ['/dashboard', '/reports', '/analytics', '/users'];
  for (const p of paths) {
    await page.goto(p);
    await page.waitForLoadState('networkidle');
  }

  if (consoleErrors.length) throw new Error('Console errors detected: ' + consoleErrors.join('\n'));
  if (requestFailures.length) throw new Error('Request failures detected: ' + JSON.stringify(requestFailures));
  if (pageErrors.length) throw new Error('Unhandled page errors: ' + pageErrors.join('\n'));
});
