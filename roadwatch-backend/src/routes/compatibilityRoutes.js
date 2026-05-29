const express = require('express');

const upload = require('../config/multer');
const compatibilityController = require('../controllers/compatibilityController');
const reportController = require('../controllers/reportController');
const { protect } = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/health', compatibilityController.health);
router.get('/api/location/reverse', compatibilityController.reverseGeocode);
router.get('/get-road-data', compatibilityController.getRoadData);
router.get('/get-budget-data', compatibilityController.getBudgetData);
router.get('/get-road-network-data', compatibilityController.getRoadNetworkData);
router.get('/get-road-network-data/:itemId', compatibilityController.getRoadNetworkData);
router.get('/api/roads', compatibilityController.getRoads);
router.get('/complaints', compatibilityController.getComplaints);
router.get('/api/complaints', protect, reportController.getReports);
router.get('/contractors', compatibilityController.getContractors);
router.post('/generate-complaint', express.json(), compatibilityController.generateComplaint);
router.post('/api/complaints', protect, express.json(), upload.single('image'), reportController.createReport);
router.post('/upload-image', upload.single('file'), compatibilityController.uploadImage);
router.post('/detect-damage', express.json(), compatibilityController.detectDamage);
router.post('/api/detect-road-damage', upload.single('image'), compatibilityController.detectDamage);
router.post('/predict-risk', express.json(), compatibilityController.predictRisk);
router.post('/chat', express.json(), compatibilityController.chat);
router.post('/api/chat', express.json(), compatibilityController.chat);
router.post('/sync-offline', protect, express.json(), compatibilityController.syncOffline);

router.post('/complaints/:id/send', express.json(), reportController.sendToAuthority);
router.post('/complaints/:id/read', express.json(), reportController.markAsRead);
router.post('/api/complaints/:id/send', protect, reportController.sendToAuthority);
router.post('/api/complaints/:id/read', protect, reportController.markAsRead);
router.put('/api/complaints/:id', protect, express.json(), upload.single('image'), reportController.updateReport);

module.exports = router;
