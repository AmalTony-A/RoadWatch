const jwt = require('jsonwebtoken');

const AppError = require('../utils/AppError');
const asyncHandler = require('../utils/asyncHandler');
const User = require('../models/User');
const config = require('../config/config');

const protect = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    throw new AppError('Not authorized, token missing', 401);
  }

  if (!config.jwtSecret) {
    throw new AppError('JWT secret is not configured', 500);
  }

  const decoded = jwt.verify(token, config.jwtSecret);
  const user = await User.findById(decoded.id).select('-password');
  if (!user) {
    throw new AppError('User not found', 401);
  }

  if (user.banned) {
    throw new AppError('Account is banned', 403);
  }

  req.user = user;
  next();
});

const requireRole = (...roles) => (req, _res, next) => {
  if (!req.user || !roles.includes(req.user.role)) {
    next(new AppError('Forbidden', 403));
    return;
  }
  next();
};

const authOptional = asyncHandler(async (req, _res, next) => {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    next();
    return;
  }

  try {
    if (!config.jwtSecret) {
      next();
      return;
    }

    const decoded = jwt.verify(token, config.jwtSecret);
    const user = await User.findById(decoded.id).select('-password');
    if (user) {
      req.user = user;
    }
  } catch (error) {
    // optional auth must never block public compatibility endpoints
  }

  next();
});

module.exports = {
  protect,
  requireRole,
  authOptional,
};
