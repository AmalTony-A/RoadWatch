require('dotenv').config();

function parseList(value, fallback = []) {
  if (!value) return fallback;
  return value
    .split(',')
    .map((entry) => entry.trim())
    .filter(Boolean);
}

const config = {
  port: Number(process.env.PORT || 8000),
  mongodbUri: process.env.MONGODB_URI || null,
  jwtSecret: process.env.JWT_SECRET || null,
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '15m',
  refreshTokenExpiresInDays: Number(process.env.REFRESH_TOKEN_EXPIRES_IN_DAYS || 30),
  frontendUrl: process.env.FRONTEND_URL || null,
  // include Vite preview default port 4173 as well
  // when preview is used (vite preview), frontend runs on 4173
  // keep backward compatibility with 5173 dev server
  // Default development CORS origins: prefer localhost hostnames for dev servers
  corsOrigins: parseList(process.env.CORS_ORIGINS || process.env.FRONTEND_URL, [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'http://localhost:5173',
    'http://localhost:4173',
    'http://127.0.0.1:5173',
    'http://127.0.0.1:4173',
    'https://amaltony-a.github.io',
  ]),
  uploadDir: process.env.UPLOAD_DIR || 'uploads',
  monitorAllowInsecure: String(process.env.MONITOR_ALLOW_INSECURE || 'false') === 'true',
  seedSampleData: String(process.env.SEED_SAMPLE_DATA || 'true').toLowerCase() !== 'false',
  rateLimitWindowMs: Number(process.env.RATE_LIMIT_WINDOW_MS || 15 * 60 * 1000),
  rateLimitMax: Number(process.env.RATE_LIMIT_MAX || 200),
  csrfEnabled: String(process.env.CSRF_ENABLED || 'true').toLowerCase() !== 'false',
  cookieDomain: process.env.COOKIE_DOMAIN || undefined,
  env: process.env.NODE_ENV || 'development',
};

module.exports = config;
