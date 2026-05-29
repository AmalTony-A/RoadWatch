const base = location.origin;

async function fetchJson(path) {
  try {
    const res = await fetch(path);
    return res.ok ? res.json() : { error: `HTTP ${res.status}` };
  } catch (e) {
    return { error: e.message };
  }
}

async function fetchText(path) {
  try {
    const res = await fetch(path);
    return res.ok ? res.text() : `HTTP ${res.status}`;
  } catch (e) {
    return e.message;
  }
}

async function refreshHealth() {
  document.getElementById('healthContent').textContent = 'Loading...';
  const data = await fetchJson(base + '/health');
  document.getElementById('healthContent').textContent = JSON.stringify(data, null, 2);
}

async function refreshSystem() {
  document.getElementById('systemContent').textContent = 'Loading...';
  const data = await fetchJson(base + '/api/admin/system-info');
  document.getElementById('systemContent').textContent = JSON.stringify(data, null, 2);
}

async function refreshDashboard() {
  document.getElementById('dashboard').textContent = 'Loading...';
  const data = await fetchJson(base + '/api/admin/dashboard-stats');
  document.getElementById('dashboard').textContent = JSON.stringify(data, null, 2);
}

async function refreshActivity() {
  document.getElementById('activity').textContent = 'Loading...';
  const data = await fetchJson(base + '/api/admin/activity-log?limit=20');
  document.getElementById('activity').textContent = JSON.stringify(data, null, 2);
}

async function refreshMetrics() {
  document.getElementById('metrics').textContent = 'Loading...';
  const text = await fetchText(base + '/metrics');
  document.getElementById('metrics').textContent = text;
}

async function seedDb() {
  const res = await fetch(base + '/api/admin/seed', { method: 'POST' });
  document.getElementById('actionResult').textContent = 'Seed: ' + (res.ok ? 'OK' : 'Failed ' + res.status);
}

async function clearLogs() {
  const res = await fetch(base + '/api/admin/clear-activity', { method: 'POST' });
  document.getElementById('actionResult').textContent = 'Clear logs: ' + (res.ok ? 'OK' : 'Failed ' + res.status);
}

// Wire buttons
window.addEventListener('load', () => {
  document.getElementById('refreshHealth').onclick = refreshHealth;
  document.getElementById('refreshSystem').onclick = refreshSystem;
  document.getElementById('refreshDashboard').onclick = refreshDashboard;
  document.getElementById('refreshActivity').onclick = refreshActivity;
  document.getElementById('refreshMetrics').onclick = refreshMetrics;
  document.getElementById('seedDb').onclick = seedDb;
  document.getElementById('clearLogs').onclick = clearLogs;

  // initial
  refreshHealth();
  refreshSystem();
  refreshDashboard();
  refreshActivity();
  refreshMetrics();
});
