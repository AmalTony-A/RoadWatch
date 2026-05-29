const asyncHandler = require('../utils/asyncHandler');
const Report = require('../models/Report');
const User = require('../models/User');
const Activity = require('../models/Activity');
const mongoose = require('mongoose');
const AppError = require('../utils/AppError');

const dashboardStats = asyncHandler(async (_req, res) => {
  const [reports, users] = await Promise.all([
    Report.find({}).lean(),
    User.find({}).lean(),
  ]);

  const total = reports.length;
  const pending = reports.filter((report) => report.status === 'Pending').length;
  const inProgress = reports.filter((report) => report.status === 'In Progress').length;
  const resolved = reports.filter((report) => report.status === 'Resolved').length;

  const byCategory = reports.reduce((acc, report) => {
    acc[report.category] = (acc[report.category] || 0) + 1;
    return acc;
  }, {});

  const activeUsers = users.filter((user) => {
    const reference = user.updatedAt || user.createdAt;
    return reference && (Date.now() - new Date(reference).getTime()) < 30 * 24 * 60 * 60 * 1000;
  }).length;

  res.json({
    totalReports: total,
    pendingReports: pending,
    resolvedReports: resolved,
    reportsByCategory: byCategory,
    activeUsers,
    users: {
      total: users.length,
      admins: users.filter((user) => user.role === 'admin').length,
      regularUsers: users.filter((user) => user.role === 'user').length,
      active: activeUsers,
    },
    statuses: { pending, inProgress, resolved },
  });
});

const activityLog = asyncHandler(async (req, res) => {
  const limit = Math.min(Number(req.query.limit || 50), 200);
  const activities = await Activity.find({}).sort({ createdAt: -1 }).limit(limit).lean();

  res.json({
    activities: activities.map((item) => ({
      type: item.action,
      action: item.details || item.action,
      description: item.details || item.action,
      timestamp: item.createdAt,
      meta: item.meta || {},
    })),
  });
});

const analytics = asyncHandler(async (_req, res) => {
  const [reports, users] = await Promise.all([
    Report.find({}).lean(),
    User.find({}).lean(),
  ]);

  const reportsByCategory = reports.reduce((acc, report) => {
    acc[report.category] = (acc[report.category] || 0) + 1;
    return acc;
  }, {});

  const monthlyReports = reports.reduce((acc, report) => {
    const key = new Date(report.createdAt).toISOString().slice(0, 7);
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});

  const userGrowth = users.reduce((acc, user) => {
    const key = new Date(user.createdAt).toISOString().slice(0, 7);
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});

  const heatmap = reports
    .filter((report) => typeof report.latitude === 'number' && typeof report.longitude === 'number')
    .map((report) => ({
      lat: report.latitude,
      lng: report.longitude,
      weight: 1,
      title: report.title,
      status: report.status,
      department: report.recommendedDepartment,
      category: report.category,
      createdAt: report.createdAt,
    }));

  const resolved = reports.filter((report) => report.status === 'Resolved').length;
  const resolutionRate = reports.length ? Math.round((resolved / reports.length) * 100) : 0;

  res.json({
    reportsByCategory,
    monthlyReports,
    resolutionRate,
    userGrowth,
    heatmap,
    totalReports: reports.length,
    totalUsers: users.length,
    generatedAt: new Date().toISOString(),
  });
});

const seedDatabaseNow = asyncHandler(async (_req, res) => {
  const { seedDatabase } = require('../config/db');
  await seedDatabase();
  res.json({ ok: true, seeded: true });
});

const clearActivityLogs = asyncHandler(async (_req, res) => {
  const count = await Activity.deleteMany({});
  res.json({ ok: true, deleted: count.deletedCount || 0 });
});

const systemInfo = asyncHandler(async (_req, res) => {
  const [reportCount, userCount, activityCount] = await Promise.all([
    Report.countDocuments(),
    User.countDocuments(),
    Activity.countDocuments(),
  ]);

  const memoryUsage = process.memoryUsage();
  const cpuUsage = process.cpuUsage();

  res.json({
    demo_mode: `${process.env.SEED_SAMPLE_DATA || 'true'}`.toLowerCase() !== 'false',
    database_type: 'MongoDB',
    database_connected: mongoose.connection.readyState === 1,
    node_version: process.version,
    uptime_seconds: Math.floor(process.uptime()),
    cpu_usage_ms: Math.round((cpuUsage.user + cpuUsage.system) / 1000),
    memory_usage_mb: Math.round(memoryUsage.rss / 1024 / 1024),
    heap_used_mb: Math.round(memoryUsage.heapUsed / 1024 / 1024),
    data_sources: {
      users: userCount,
      reports: reportCount,
      activity_logs: activityCount,
    },
  });
});

const complaintsBreakdown = asyncHandler(async (_req, res) => {
  const reports = await Report.find({}).lean();
  const byCategory = reports.reduce((acc, report) => {
    acc[report.category] = (acc[report.category] || 0) + 1;
    return acc;
  }, {});
  const byStatus = reports.reduce((acc, report) => {
    acc[report.status] = (acc[report.status] || 0) + 1;
    return acc;
  }, {});

  res.json({
    category_counts: byCategory,
    status_counts: byStatus,
    total_reports: reports.length,
  });
});

const usersList = asyncHandler(async (req, res) => {
  const q = req.query.q ? String(req.query.q) : '';
  const page = Math.max(0, Number(req.query.page || 0));
  const limit = Math.min(100, Number(req.query.limit || 50));
  const role = req.query.role ? String(req.query.role) : '';

  const filter = {};
  if (q) {
    filter.$or = [
      { name: { $regex: q, $options: 'i' } },
      { email: { $regex: q, $options: 'i' } },
    ];
  }
  if (role) {
    filter.role = role;
  }

  const [users, total] = await Promise.all([
    User.find(filter).skip(page * limit).limit(limit).lean(),
    User.countDocuments(filter),
  ]);

  res.json({ users, total, page, limit });
});

const getUserById = asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id).lean();
  if (!user) {
    throw new AppError('User not found', 404);
  }
  res.json({ user });
});

const updateUserRole = asyncHandler(async (req, res) => {
  const { role } = req.body;
  if (!['user', 'moderator', 'admin'].includes(role)) {
    throw new AppError('Invalid role', 400);
  }
  const user = await User.findByIdAndUpdate(req.params.id, { $set: { role } }, { new: true }).lean();
  if (!user) throw new AppError('User not found', 404);
  res.json({ user });
});

const updateUserBan = asyncHandler(async (req, res) => {
  const { banned } = req.body;
  const user = await User.findByIdAndUpdate(
    req.params.id,
    { $set: { banned: Boolean(banned), bannedAt: Boolean(banned) ? new Date() : null } },
    { new: true },
  ).lean();
  if (!user) throw new AppError('User not found', 404);
  res.json({ user });
});

const deleteUser = asyncHandler(async (req, res) => {
  const user = await User.findByIdAndDelete(req.params.id).lean();
  if (!user) throw new AppError('User not found', 404);
  res.json({ ok: true });
});

const reportsList = asyncHandler(async (req, res) => {
  const q = req.query.q ? String(req.query.q) : '';
  const status = req.query.status;
  const category = req.query.category ? String(req.query.category) : '';
  const from = req.query.from ? new Date(String(req.query.from)) : null;
  const to = req.query.to ? new Date(String(req.query.to)) : null;
  const sort = req.query.sort === 'oldest' ? 1 : -1;
  const page = Math.max(0, Number(req.query.page || 0));
  const limit = Math.min(100, Number(req.query.limit || 50));

  const filter = {};
  if (q) {
    filter.$or = [
      { title: { $regex: q, $options: 'i' } },
      { description: { $regex: q, $options: 'i' } },
    ];
  }
  if (status) filter.status = status;
  if (category) filter.category = category;
  if (from || to) {
    filter.createdAt = {};
    if (from) filter.createdAt.$gte = from;
    if (to) filter.createdAt.$lte = to;
  }

  const [reports, total] = await Promise.all([
    Report.find(filter).sort({ createdAt: sort }).skip(page * limit).limit(limit).lean(),
    Report.countDocuments(filter),
  ]);

  res.json({ reports, total, page, limit });
});

const updateReport = asyncHandler(async (req, res) => {
  const id = req.params.id;
  const updates = {};
  ['title', 'description', 'category', 'status', 'address', 'roadId'].forEach((k) => {
    if (req.body[k] !== undefined) updates[k] = req.body[k];
  });
  if (req.body.lat !== undefined && req.body.lng !== undefined) {
    updates.latitude = Number(req.body.lat);
    updates.longitude = Number(req.body.lng);
  }

  const updated = await Report.findByIdAndUpdate(id, { $set: updates }, { new: true });
  if (!updated) throw new AppError('Report not found', 404);

  res.json({ report: updated });
});

const deleteReport = asyncHandler(async (req, res) => {
  const id = req.params.id;
  const report = await Report.findById(id);
  if (!report) throw new AppError('Report not found', 404);
  await report.deleteOne();
  res.json({ ok: true });
});

module.exports = {
  dashboardStats,
  activityLog,
  systemInfo,
  complaintsBreakdown,
  seedDatabaseNow,
  clearActivityLogs,
  analytics,
  usersList,
  getUserById,
  updateUserRole,
  updateUserBan,
  deleteUser,
  reportsList,
  updateReport,
  deleteReport,
};

