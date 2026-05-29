const AppError = require('../utils/AppError');

function requireAdmin(req, _res, next) {
  if (!req.user || req.user.role !== 'admin') {
    next(new AppError('Admin access required', 403));
    return;
  }
  next();
}

module.exports = requireAdmin;
