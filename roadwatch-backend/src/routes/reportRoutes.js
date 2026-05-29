const express = require('express');
const { body, param } = require('express-validator');

const reportController = require('../controllers/reportController');
const { protect } = require('../middleware/authMiddleware');
const requireAdmin = require('../middleware/adminMiddleware');
const upload = require('../config/multer');
const validateRequest = require('../middleware/validateRequest');

const router = express.Router();

const reportValidators = [
  body('title').trim().isLength({ min: 3 }).withMessage('Title is required'),
  body('description').trim().isLength({ min: 10 }).withMessage('Description is required'),
  body('category').isIn(['Pothole', 'Waterlogging', 'Damaged road', 'Traffic issue', 'Street light issue', 'Other']).withMessage('Invalid category'),
  body('lat').isFloat({ min: -90, max: 90 }).withMessage('Latitude is required'),
  body('lng').isFloat({ min: -180, max: 180 }).withMessage('Longitude is required'),
];

router.post('/', protect, upload.single('image'), reportValidators, validateRequest, reportController.createReport);
router.get('/', protect, reportController.getReports);
router.get('/:id', protect, [param('id').isMongoId().withMessage('Invalid report id')], validateRequest, reportController.getReportById);
router.put('/:id', protect, upload.single('image'), [param('id').isMongoId().withMessage('Invalid report id')], validateRequest, reportController.updateReport);
router.delete('/:id', protect, [param('id').isMongoId().withMessage('Invalid report id')], validateRequest, reportController.deleteReport);
router.patch('/:id/status', protect, requireAdmin, [param('id').isMongoId().withMessage('Invalid report id'), body('status').isIn(['Pending', 'In Progress', 'Resolved'])], validateRequest, reportController.updateStatus);

module.exports = router;
