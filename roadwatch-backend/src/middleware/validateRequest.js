const { validationResult } = require('express-validator');

module.exports = function validateRequest(req, _res, next) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    const err = new Error('Validation failed');
    err.statusCode = 400;
    err.validationErrors = errors.array().map((error) => ({
      field: error.path,
      message: error.msg,
      value: error.value,
    }));
    next(err);
    return;
  }
  next();
};
