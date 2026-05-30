const bcrypt = require('bcryptjs');

const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../utils/AppError');
const { signToken, generateRandomToken, hashToken } = require('../utils/token');
const { logger } = require('../utils/logger');
const broadcaster = require('../utils/broadcast');
const config = require('../config/config');
const { serializeCookie, cookieOptions } = require('../utils/http');
const User = require('../models/User');
const PasswordResetToken = require('../models/PasswordResetToken');
const RefreshToken = require('../models/RefreshToken');
const Activity = require('../models/Activity');

function userPayload(user) {
  return {
    id: user._id,
    name: user.name,
    email: user.email,
    role: user.role,
    banned: Boolean(user.banned),
    createdAt: user.createdAt,
  };
}

function refreshCookieOptions() {
  const secure = config.env === 'production';
  return cookieOptions({
    maxAgeDays: config.refreshTokenExpiresInDays,
    httpOnly: true,
    sameSite: secure ? 'None' : 'Lax',
    secure,
    domain: config.cookieDomain,
  });
}

function csrfCookieOptions() {
  const secure = config.env === 'production';
  return cookieOptions({
    maxAgeDays: config.refreshTokenExpiresInDays,
    httpOnly: false,
    sameSite: secure ? 'None' : 'Lax',
    secure,
    domain: config.cookieDomain,
  });
}

async function issueSession(res, user, req, statusCode = 200) {
  const refreshToken = generateRandomToken(48);
  const csrfToken = generateRandomToken(32);
  const refreshHash = hashToken(refreshToken);
  const expiresAt = new Date(Date.now() + config.refreshTokenExpiresInDays * 24 * 60 * 60 * 1000);

  await RefreshToken.deleteMany({ userId: user._id, revokedAt: null });
  await RefreshToken.create({
    userId: user._id,
    tokenHash: refreshHash,
    csrfToken,
    expiresAt,
    userAgent: req.headers['user-agent'] || '',
    ipAddress: req.ip || req.socket?.remoteAddress || '',
  });

  res.setHeader('Set-Cookie', [
    serializeCookie('refresh_token', refreshToken, refreshCookieOptions()),
    serializeCookie('csrf_token', csrfToken, csrfCookieOptions()),
  ]);

  res.status(statusCode).json({
    token: signToken({ id: user._id, role: user.role }),
    user: userPayload(user),
    csrfToken,
  });
}

const signup = asyncHandler(async (req, res) => {
  const { name, email, password } = req.body;
  const normalizedEmail = email.toLowerCase().trim();
  const existing = await User.findOne({ email: normalizedEmail });
  if (existing) {
    logger.warn({ email: normalizedEmail }, 'signup rejected: email already exists');
    throw new AppError('Email already registered', 409);
  }

  const hashed = await bcrypt.hash(password, 12);
  const user = await User.create({ name, email: normalizedEmail, password: hashed });
  await Activity.create({ userId: user._id, action: 'auth:signup', details: 'User signed up' });
  logger.info({ email: normalizedEmail, userId: user._id.toString() }, 'signup successful');
  try {
    broadcaster.emit('userRegistered', { user: userPayload(user) });
  } catch (error) {
    // ignore realtime broadcast failures
  }
  await issueSession(res, user, req, 201);
});

const login = asyncHandler(async (req, res) => {
  const { email, password } = req.body;
  logger.info(
    {
      email: email?.toLowerCase?.().trim?.() || email,
      passwordLength: typeof password === 'string' ? password.length : 0,
      origin: req.headers.origin || '',
      requestId: req.requestId || '',
    },
    'login request body'
  );
  const user = await User.findOne({ email: email.toLowerCase().trim() }).select('+password');
  if (!user) {
    logger.warn({ email }, 'login failed: user not found');
    throw new AppError('Invalid credentials', 401);
  }

  const match = await bcrypt.compare(password, user.password);
  if (!match) {
    logger.warn({ email, userId: user._id.toString() }, 'login failed: invalid password');
    throw new AppError('Invalid credentials', 401);
  }

  if (user.banned) {
    throw new AppError('Account is banned', 403);
  }

  await Activity.create({ userId: user._id, action: 'auth:login', details: 'User logged in' });
  logger.info({ email, userId: user._id.toString() }, 'login successful');
  try {
    broadcaster.emit('userLoggedIn', { user: userPayload(user) });
  } catch (error) {
    // ignore realtime broadcast failures
  }
  await issueSession(res, user, req);
});

const refresh = asyncHandler(async (req, res) => {
  const refreshToken = req.cookies?.refresh_token || req.body?.refreshToken;
  if (!refreshToken) {
    throw new AppError('Refresh token missing', 401);
  }

  const tokenHash = hashToken(refreshToken);
  const record = await RefreshToken.findOne({ tokenHash, revokedAt: null }).populate('userId');
  if (!record || record.expiresAt < new Date()) {
    throw new AppError('Refresh token invalid or expired', 401);
  }

  const user = record.userId;
  if (!user || user.banned) {
    throw new AppError('Account is banned', 403);
  }

  record.revokedAt = new Date();
  await record.save();

  await issueSession(res, user, req);
});

const logout = asyncHandler(async (req, res) => {
  const refreshToken = req.cookies?.refresh_token || req.body?.refreshToken;
  if (refreshToken) {
    await RefreshToken.updateOne({ tokenHash: hashToken(refreshToken) }, { $set: { revokedAt: new Date() } });
  }

  const secure = config.env === 'production';
  const expiredOptions = cookieOptions({
    maxAgeDays: 0,
    httpOnly: true,
    sameSite: secure ? 'None' : 'Lax',
    secure,
    domain: config.cookieDomain,
  });

  res.setHeader('Set-Cookie', [
    serializeCookie('refresh_token', '', { ...expiredOptions, expires: new Date(0) }),
    serializeCookie('csrf_token', '', { ...cookieOptions({ maxAgeDays: 0, httpOnly: false, sameSite: secure ? 'None' : 'Lax', secure, domain: config.cookieDomain }), expires: new Date(0) }),
  ]);

  res.json({ message: 'Logged out' });
});

const csrfToken = asyncHandler(async (req, res) => {
  res.json({ csrfToken: req.cookies?.csrf_token || null });
});

const profile = asyncHandler(async (req, res) => {
  res.json({ user: userPayload(req.user) });
});

const updateProfile = asyncHandler(async (req, res) => {
  const { name } = req.body;
  if (name !== undefined) req.user.name = name;
  await req.user.save();
  res.json({ user: userPayload(req.user) });
});

const forgotPassword = asyncHandler(async (req, res) => {
  const { email } = req.body;
  const user = await User.findOne({ email: email.toLowerCase().trim() });
  if (!user) {
    throw new AppError('No account found for that email', 404);
  }

  await PasswordResetToken.deleteMany({ user: user._id });
  const resetToken = generateRandomToken(24);
  const tokenHash = hashToken(resetToken);
  const ttlMinutes = Number(process.env.RESET_TOKEN_TTL_MINUTES || 30);

  await PasswordResetToken.create({
    user: user._id,
    tokenHash,
    expiresAt: new Date(Date.now() + ttlMinutes * 60 * 1000),
  });

  res.json({
    message: 'Password reset token generated',
    resetToken,
  });
});

const resetPassword = asyncHandler(async (req, res) => {
  const { token, newPassword } = req.body;
  const tokenHash = hashToken(token);
  const record = await PasswordResetToken.findOne({ tokenHash, usedAt: { $exists: false } }).populate('user');
  if (!record || record.expiresAt < new Date()) {
    throw new AppError('Reset token is invalid or expired', 400);
  }

  const user = await User.findById(record.user._id).select('+password');
  if (!user) {
    throw new AppError('User not found', 404);
  }

  user.password = await bcrypt.hash(newPassword, 12);
  await user.save();
  record.usedAt = new Date();
  await record.save();

  res.json({ message: 'Password reset successful' });
});

module.exports = {
  signup,
  login,
  refresh,
  logout,
  csrfToken,
  profile,
  updateProfile,
  forgotPassword,
  resetPassword,
};
