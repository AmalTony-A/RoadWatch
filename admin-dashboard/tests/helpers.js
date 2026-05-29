const { expect } = require('@playwright/test');

const ADMIN_EMAIL = process.env.TEST_ADMIN_EMAIL || 'admin@roadwatch.local';
const ADMIN_PASS = process.env.TEST_ADMIN_PASS || 'Admin@12345';

async function safeGoto(page, url) {
  const responses = [];
  page.on('response', r => responses.push(r));
  await page.goto(url, { waitUntil: 'networkidle' });
  return responses;
}

async function failOnConsoleErrors(page) {
  page.on('console', msg => {
    if (msg.type() !== 'error') return;
    const text = msg.text();
    // ignore expected dev / auth noise
    if (/401|Unauthorized|Failed to load resource|ERR_ABORTED/.test(text)) return;
    if (/React DevTools|Warning:/.test(text)) return;
    // ignore cookie rejections caused by SameSite/Secure differences in CI/dev
    if (/Cookie .*rejected|has been rejected|rejected because/.test(text)) return;
    throw new Error('Console error: ' + text);
  });
}

async function callTestHook(page, hookPath, payload = {}) {
  const frontendBaseUrl = process.env.PW_BASE_URL || 'http://localhost:5173';
  const apiBaseUrl = process.env.PW_API_BASE_URL || 'http://localhost:8001';
  const url = new URL(hookPath, apiBaseUrl).toString();
  if (page.url() === 'about:blank') {
    await page.goto(frontendBaseUrl);
  }
  const responsePromise = page.waitForResponse(
    (response) => response.url().includes(hookPath) && response.request().method() === 'POST',
    { timeout: 10000 },
  );
  await page.evaluate(async ({ path, body }) => {
    const res = await fetch(path, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });
    return res.json();
  }, { path: url, body: payload });
  const response = await responsePromise;
  return response.json();
}

async function loginViaUI(page) {
  await failOnConsoleErrors(page);
  await page.goto('/');
  // wait for login UI heading if present
  try { await page.getByRole('heading', { name: /RoadWatch Admin Login/i }).first().waitFor({ timeout: 7000 }); } catch (e) {}
  // Prefer test ids for stable selectors
  const email = page.getByTestId('login-email');
  const pass = page.getByTestId('login-password');
  const submit = page.getByTestId('login-submit');
  await expect(email).toBeVisible({ timeout: 7000 });
  await email.fill(ADMIN_EMAIL);
  await pass.fill(ADMIN_PASS);
  await Promise.all([
    page.waitForResponse((response) => response.url().includes('/api/auth/login') && response.ok(), { timeout: 10000 }).catch(() => {}),
    submit.click(),
  ]);
  await page.waitForLoadState('networkidle').catch(() => {});
  const token = await page.evaluate(() => sessionStorage.getItem('rw_token'));
  expect(token, 'rw_token should be present after login').toBeTruthy();
  return token;
}

async function apiCreateReport(request, token, payload) {
  return request.post('/api/admin/report', {
    data: payload,
    headers: { authorization: `Bearer ${token}` },
  });
}

async function apiUpdateReport(request, token, id, data) {
  return request.put(`/api/admin/report/${id}`, { data, headers: { authorization: `Bearer ${token}` } });
}

async function apiDeleteReport(request, token, id) {
  return request.delete(`/api/admin/report/${id}`, { headers: { authorization: `Bearer ${token}` } });
}

module.exports = {
  ADMIN_EMAIL,
  ADMIN_PASS,
  callTestHook,
  loginViaUI,
  safeGoto,
  failOnConsoleErrors,
  apiCreateReport,
  apiUpdateReport,
  apiDeleteReport,
};
