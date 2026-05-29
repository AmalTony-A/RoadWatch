const AppError = require('../utils/AppError');

function permit(...roles) {
  return (req, _res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      next(new AppError('Forbidden', 403));
      return;
    }
    next();
  };
}

module.exports = permit;