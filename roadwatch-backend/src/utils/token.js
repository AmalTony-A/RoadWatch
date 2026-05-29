const crypto = require('crypto');
const jwt = require('jsonwebtoken');

const config = require('../config/config');

function signToken(payload) {
  if (!config.jwtSecret) {
    throw new Error('JWT_SECRET is required');
  }

  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: config.jwtExpiresIn,
  });
}

function signRefreshToken(payload) {
  if (!config.jwtSecret) {
    throw new Error('JWT_SECRET is required');
  }

  return jwt.sign(payload, config.jwtSecret, {
    expiresIn: `${config.refreshTokenExpiresInDays}d`,
  });
}

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

function generateRandomToken(bytes = 32) {
  return crypto.randomBytes(bytes).toString('hex');
}

module.exports = {
  signToken,
  signRefreshToken,
  hashToken,
  generateRandomToken,
};
