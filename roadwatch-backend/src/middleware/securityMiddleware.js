const crypto = require('crypto');

const config = require('../config/config');
const { parseCookies } = require('../utils/http');

function attachRequestMeta(req, _res, next) {
  req.requestId = req.headers['x-request-id'] || crypto.randomUUID();
  next();
}

function parseCookieMiddleware(req, _res, next) {
  req.cookies = parseCookies(req.headers.cookie || '');
  next();
}

function sanitizeInput(value) {
  if (Array.isArray(value)) return value.map(sanitizeInput);
  if (value && typeof value === 'object') {
    return Object.entries(value).reduce((acc, [key, nestedValue]) => {
      if (key.startsWith('$') || key.includes('.')) return acc;
      acc[key] = sanitizeInput(nestedValue);
      return acc;
    }, {});
  }
  return value;
}

function sanitizeRequest(req, _res, next) {
  req.body = sanitizeInput(req.body);
  req.query = sanitizeInput(req.query);
  req.params = sanitizeInput(req.params);
  next();
}

function csrfProtection(req, res, next) {
  if (!config.csrfEnabled) {
    next();
    return;
  }

  const safeMethods = new Set(['GET', 'HEAD', 'OPTIONS']);
  if (safeMethods.has(req.method)) {
    next();
    return;
  }

  const csrfExemptPaths = new Set([
    '/api/auth/login',
    '/api/auth/signup',
    '/api/auth/refresh',
    '/api/auth/logout',
  ]);
  if (csrfExemptPaths.has(req.path)) {
    next();
    return;
  }

  const hasCookieAuth = Boolean(req.cookies?.refresh_token || req.cookies?.csrf_token);
  if (!hasCookieAuth) {
    next();
    return;
  }

  const token = req.headers['x-csrf-token'];
  const csrfCookie = req.cookies?.csrf_token;
  if (!token || !csrfCookie || token !== csrfCookie) {
    res.status(403).json({ message: 'CSRF token missing or invalid' });
    return;
  }

  next();
}

module.exports = {
  attachRequestMeta,
  parseCookieMiddleware,
  sanitizeRequest,
  csrfProtection,
};