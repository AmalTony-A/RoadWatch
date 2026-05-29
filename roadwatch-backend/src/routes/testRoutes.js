const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const config = require('../config/config');
const AppError = require('../utils/AppError');
const { emit } = require('../utils/broadcast');
const { logger } = require('../utils/logger');
const User = require('../models/User');
const Report = require('../models/Report');
const Activity = require('../models/Activity');
const PasswordResetToken = require('../models/PasswordResetToken');
const RefreshToken = require('../models/RefreshToken');
const RoadSegment = require('../models/RoadSegment');
const RoadNetworkItem = require('../models/RoadNetworkItem');
const Budget = require('../models/Budget');
const Contractor = require('../models/Contractor');

const router = express.Router();

router.use(express.json({ limit: '10mb' }));
router.use(express.urlencoded({ extended: true }));

const TEST_ADMIN = {
  name: 'RoadWatch Admin',
  email: 'admin@roadwatch.local',
  password: 'Admin@12345',
  role: 'admin',
};

const TEST_USER = {
  name: 'RoadWatch Test User',
  email: 'test@roadwatch.local',
  password: 'Test@12345',
  role: 'user',
};

const TEST_REPORT = {
  title: 'Test Report',
  description: 'Deterministic test report',
  category: 'Pothole',
  status: 'Pending',
  lat: 12.9716,
  lng: 80.238,
  address: 'Test Route, Chennai',
};

function isEnabled() {
  return config.env !== 'production';
}

function respondDisabled(res) {
  return res.status(404).json({ ok: false, message: 'Not found' });
}

function logTestEvent(eventName, payload = {}) {
  const message = `[TestEvent] ${eventName}`;
  if (logger && logger.info) {
    logger.info({ event: eventName, payload }, message);
  } else {
    console.log(message, payload);
  }
}

function toReportEvent(report) {
  if (!report) return null;
  return {
    id: report._id?.toString?.() || report.id,
    _id: report._id?.toString?.() || report.id,
    title: report.title,
    description: report.description,
    category: report.category,
    status: report.status,
    recommendedDepartment: report.recommendedDepartment,
    latitude: report.latitude,
    longitude: report.longitude,
    location: {
      lat: report.latitude,
      lng: report.longitude,
      address: report.address || '',
    },
    address: report.address || '',
    createdAt: report.createdAt,
    updatedAt: report.updatedAt,
  };
}

function toUserPayload(user) {
  return {
    id: user._id?.toString?.() || user.id,
    _id: user._id?.toString?.() || user.id,
    name: user.name,
    email: user.email,
    role: user.role,
    banned: Boolean(user.banned),
    createdAt: user.createdAt,
  };
}

async function clearTestDatabase() {
  const collections = [
    User,
    Report,
    Activity,
    PasswordResetToken,
    RefreshToken,
    RoadSegment,
    RoadNetworkItem,
    Budget,
    Contractor,
  ];

  await Promise.all(collections.map((Model) => Model.deleteMany({})));
}

async function ensureSeedUsers() {
  const adminPassword = await bcrypt.hash(TEST_ADMIN.password, 12);
  const testPassword = await bcrypt.hash(TEST_USER.password, 12);

  const admin = await User.findOneAndUpdate(
    { email: TEST_ADMIN.email },
    {
      $set: {
        name: TEST_ADMIN.name,
        email: TEST_ADMIN.email,
        password: adminPassword,
        role: TEST_ADMIN.role,
        banned: false,
        bannedAt: null,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  const testUser = await User.findOneAndUpdate(
    { email: TEST_USER.email },
    {
      $set: {
        name: TEST_USER.name,
        email: TEST_USER.email,
        password: testPassword,
        role: TEST_USER.role,
        banned: false,
        bannedAt: null,
      },
    },
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  return { admin, testUser };
}

async function ensureSeedReport(ownerId) {
  await Report.deleteMany({ title: TEST_REPORT.title, category: TEST_REPORT.category });
  const report = await Report.create({
    userId: ownerId,
    title: TEST_REPORT.title,
    description: TEST_REPORT.description,
    category: TEST_REPORT.category,
    latitude: TEST_REPORT.lat,
    longitude: TEST_REPORT.lng,
    address: TEST_REPORT.address,
    status: TEST_REPORT.status,
    roadId: 'TEST-ROAD-001',
    image: '',
    images: [],
    authorityTicket: 'PENDING',
    recommendedDepartment: 'Municipal Corporation',
    routingReason: 'Deterministic test seed',
    complaintLetter: 'Deterministic test seed',
    timeline: [{ status: TEST_REPORT.status, at: new Date(), note: 'Seeded test report' }],
  });

  return report;
}

async function resetDatabase(res) {
  await clearTestDatabase();
  const { admin, testUser } = await ensureSeedUsers();
  const report = await ensureSeedReport(testUser._id);
  await Activity.create({ action: 'seed', details: 'Test database reset', meta: { source: 'api/test/reset-db' } });
  logTestEvent('resetDb', { admin: admin.email, testUser: testUser.email, report: report.title });
  return res.json({ ok: true, admin: toUserPayload(admin), testUser: toUserPayload(testUser), report: toReportEvent(report) });
}

function requireTestMode(req, res, next) {
  if (!isEnabled()) {
    return respondDisabled(res);
  }
  return next();
}

router.use(requireTestMode);

router.post('/reset-db', async (req, res, next) => {
  try {
    return await resetDatabase(res);
  } catch (error) {
    return next(error);
  }
});

router.post('/create-user', async (req, res, next) => {
  try {
    const name = req.body.name || TEST_USER.name;
    const email = String(req.body.email || TEST_USER.email).toLowerCase().trim();
    const password = req.body.password || TEST_USER.password;
    const role = ['user', 'moderator', 'admin'].includes(req.body.role) ? req.body.role : TEST_USER.role;
    const banned = Boolean(req.body.banned || false);
    const hashed = await bcrypt.hash(password, 12);

    const user = await User.findOneAndUpdate(
      { email },
      {
        $set: {
          name,
          email,
          password: hashed,
          role,
          banned,
          bannedAt: banned ? new Date() : null,
        },
      },
      { new: true, upsert: true, setDefaultsOnInsert: true },
    );

    if (req.body.emitLogin) {
      emit('userLoggedIn', { user: toUserPayload(user) });
      logTestEvent('userLoggedIn', { email: user.email });
    }

    return res.json({ ok: true, user: toUserPayload(user) });
  } catch (error) {
    return next(error);
  }
});

router.post('/create-report', async (req, res, next) => {
  try {
    const { testUser } = await ensureSeedUsers();
    const title = req.body.title || TEST_REPORT.title;
    const category = req.body.category || TEST_REPORT.category;
    const description = req.body.description || TEST_REPORT.description;
    const latitude = Number(req.body.lat ?? req.body.latitude ?? TEST_REPORT.lat);
    const longitude = Number(req.body.lng ?? req.body.longitude ?? TEST_REPORT.lng);
    const address = req.body.address || TEST_REPORT.address;
    const status = req.body.status || TEST_REPORT.status;

    await Report.deleteMany({ title, category });

    const report = await Report.create({
      userId: testUser._id,
      title,
      description,
      category,
      latitude,
      longitude,
      address,
      status,
      roadId: req.body.roadId || 'TEST-ROAD-001',
      image: req.body.image || '',
      images: Array.isArray(req.body.images) ? req.body.images.filter(Boolean) : [],
      authorityTicket: 'PENDING',
      recommendedDepartment: req.body.recommendedDepartment || 'Municipal Corporation',
      routingReason: req.body.routingReason || 'Deterministic test report',
      complaintLetter: req.body.complaintLetter || `${title}\n\n${description}`,
      timeline: [{ status, at: new Date(), note: 'Created by test hook' }],
    });

    const payload = toReportEvent(report);
    emit('report:created', payload);
    emit('reportCreated', payload);
    logTestEvent('reportCreated', { reportId: report._id.toString(), title: report.title });

    return res.json({ ok: true, report: payload });
  } catch (error) {
    return next(error);
  }
});

router.post('/emit-report-created', async (req, res, next) => {
  try {
    const report = req.body.reportId ? await Report.findById(req.body.reportId) : await Report.findOne({ title: req.body.title || TEST_REPORT.title });
    if (!report) throw new AppError('Report not found', 404);
    const payload = toReportEvent(report);
    emit('report:created', payload);
    emit('reportCreated', payload);
    logTestEvent('reportCreated', { reportId: report._id.toString() });
    return res.json({ ok: true, report: payload });
  } catch (error) {
    return next(error);
  }
});

router.post('/emit-report-updated', async (req, res, next) => {
  try {
    const id = req.body.reportId || req.body.id;
    if (!id) throw new AppError('reportId is required', 400);

    const updates = {};
    ['title', 'description', 'category', 'status', 'address', 'recommendedDepartment', 'roadId'].forEach((field) => {
      if (req.body[field] !== undefined) updates[field] = req.body[field];
    });
    if (req.body.lat !== undefined || req.body.latitude !== undefined) {
      updates.latitude = Number(req.body.lat ?? req.body.latitude);
    }
    if (req.body.lng !== undefined || req.body.longitude !== undefined) {
      updates.longitude = Number(req.body.lng ?? req.body.longitude);
    }

    const report = await Report.findByIdAndUpdate(id, { $set: updates }, { new: true });
    if (!report) throw new AppError('Report not found', 404);

    const payload = toReportEvent(report);
    emit('report:updated', payload);
    emit('reportUpdated', payload);
    logTestEvent('reportUpdated', { reportId: report._id.toString(), updates: Object.keys(updates) });
    return res.json({ ok: true, report: payload });
  } catch (error) {
    return next(error);
  }
});

router.post('/emit-report-deleted', async (req, res, next) => {
  try {
    const id = req.body.reportId || req.body.id;
    if (!id) throw new AppError('reportId is required', 400);

    const report = await Report.findById(id);
    if (!report) throw new AppError('Report not found', 404);
    await report.deleteOne();

    emit('report:deleted', { id });
    emit('reportDeleted', { id });
    logTestEvent('reportDeleted', { reportId: id });
    return res.json({ ok: true, id });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
