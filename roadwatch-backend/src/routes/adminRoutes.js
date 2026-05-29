const express = require('express');

const adminController = require('../controllers/adminController');
const { protect } = require('../middleware/authMiddleware');
const permit = require('../middleware/roleMiddleware');

const router = express.Router();

const isInsecureLocalAccess = process.env.MONITOR_ALLOW_INSECURE === 'true';

function guardsFor(...roles) {
	if (isInsecureLocalAccess) {
		return [];
	}
	return [protect, permit(...roles)];
}

router.get('/dashboard-stats', ...guardsFor('admin', 'moderator'), adminController.dashboardStats);
router.get('/activity-log', ...guardsFor('admin', 'moderator'), adminController.activityLog);
router.get('/system-info', ...guardsFor('admin'), adminController.systemInfo);
router.get('/complaints-breakdown', ...guardsFor('admin', 'moderator'), adminController.complaintsBreakdown);
router.get('/analytics', ...guardsFor('admin', 'moderator'), adminController.analytics);
router.get('/users', ...guardsFor('admin'), adminController.usersList);
router.get('/user/:id', ...guardsFor('admin'), adminController.getUserById);
router.put('/user/:id/role', ...guardsFor('admin'), adminController.updateUserRole);
router.put('/user/:id/ban', ...guardsFor('admin'), adminController.updateUserBan);
router.delete('/user/:id', ...guardsFor('admin'), adminController.deleteUser);
router.get('/reports', ...guardsFor('admin', 'moderator'), adminController.reportsList);
router.put('/report/:id', ...guardsFor('admin', 'moderator'), adminController.updateReport);
router.delete('/report/:id', ...guardsFor('admin', 'moderator'), adminController.deleteReport);
router.post('/seed', ...guardsFor('admin'), adminController.seedDatabaseNow);
router.post('/clear-activity', ...guardsFor('admin'), adminController.clearActivityLogs);

module.exports = router;
