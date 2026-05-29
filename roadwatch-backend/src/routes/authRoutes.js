const express = require('express');
const { body } = require('express-validator');

const authController = require('../controllers/authController');
const { protect } = require('../middleware/authMiddleware');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

router.post(
  '/signup',
  [
    body('name').trim().isLength({ min: 2 }).withMessage('Name is required'),
    body('email').isEmail().withMessage('Valid email is required'),
    body('password').isLength({ min: 8 }).withMessage('Password must be at least 8 characters'),
  ],
  validateRequest,
  authController.signup,
);

router.post(
  '/login',
  [
    body('email').isEmail().withMessage('Valid email is required'),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  validateRequest,
  authController.login,
);

router.post('/refresh', authController.refresh);
router.post('/logout', authController.logout);
router.get('/csrf-token', authController.csrfToken);

router.get('/profile', protect, authController.profile);
router.put('/profile', protect, authController.updateProfile);

router.post(
  '/forgot-password',
  [body('email').isEmail().withMessage('Valid email is required')],
  validateRequest,
  authController.forgotPassword,
);

router.post(
  '/reset-password',
  [
    body('token').notEmpty().withMessage('Reset token is required'),
    body('newPassword').isLength({ min: 8 }).withMessage('New password must be at least 8 characters'),
  ],
  validateRequest,
  authController.resetPassword,
);

module.exports = router;
