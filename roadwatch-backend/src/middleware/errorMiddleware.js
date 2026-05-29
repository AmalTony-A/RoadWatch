const AppError = require('../utils/AppError');
const { captureException } = require('../utils/observability');

function notFound(_req, _res, next) {
  next(new AppError('Route not found', 404));
}

function errorHandler(err, _req, res, _next) {
  const statusCode = err.statusCode || 500;
  if (statusCode >= 500) {
    captureException(err, { statusCode });
  }

  if (err.temporary) {
    res.status(statusCode).json({
      success: false,
      temporary: true,
      message: 'AI service temporarily busy',
    });
    return;
  }

  const response = {
    message: err.message || 'Internal server error',
  };

  if (err.validationErrors) {
    response.message = 'Validation failed';
    response.errors = err.validationErrors;
  }

  if (err.name === 'ValidationError') {
    response.message = Object.values(err.errors)
      .map((entry) => entry.message)
      .join(', ');
  }

  if (err.code === 11000) {
    response.message = 'Duplicate field value';
  }

  if (err.name === 'JsonWebTokenError') {
    response.message = 'Invalid token';
  }

  if (err.name === 'TokenExpiredError') {
    response.message = 'Token expired';
  }

  if (process.env.NODE_ENV !== 'production') {
    response.stack = err.stack;
  }

  res.status(statusCode).json(response);
}

module.exports = {
  notFound,
  errorHandler,
};
