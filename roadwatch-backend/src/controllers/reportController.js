const fs = require('fs');
const path = require('path');

const asyncHandler = require('../utils/asyncHandler');
const AppError = require('../utils/AppError');
const Report = require('../models/Report');
const Activity = require('../models/Activity');
const { logger } = require('../utils/logger');
const broadcaster = require('../utils/broadcast');

const CATEGORY_TO_DEPARTMENT = {
  Pothole: 'Highways Department',
  Waterlogging: 'Municipal Corporation',
  'Damaged road': 'Highways Department',
  'Traffic issue': 'Traffic Police',
  'Street light issue': 'Electricity Board',
  Other: 'Municipal Corporation',
};

function toComplaintView(report) {
  const images = Array.isArray(report.images) && report.images.length > 0
    ? report.images
    : report.image
      ? [report.image]
      : [];

  return {
    id: report._id.toString(),
    road_id: report.roadId || '',
    title: report.title || '',
    description: report.description,
    image_ref: report.image || report.imageUrl || '',
    image: report.image || report.imageUrl || '',
    images,
    location: {
      lat: report.latitude ?? report.location?.lat ?? 0,
      lng: report.longitude ?? report.location?.lng ?? 0,
      address: report.address || report.location?.address || '',
    },
    timestamp: report.createdAt.toISOString(),
    ticketId: report.authorityTicket || 'PENDING',
    status: report.status,
    authority_ticket: report.authorityTicket || 'PENDING',
    recommended_department: report.recommendedDepartment || 'Unassigned',
    routing_reason: report.routingReason || '',
    complaint_letter: report.complaintLetter || '',
    sent_to_authority: report.sentToAuthority || false,
    delivered_to_authority: report.deliveredToAuthority || false,
    read_by_authority: report.readByAuthority || false,
    sent_at: report.sentAt ? report.sentAt.toISOString() : null,
    delivered_at: report.deliveredAt ? report.deliveredAt.toISOString() : null,
    read_at: report.readAt ? report.readAt.toISOString() : null,
    timeline: (report.timeline || []).map((entry) => ({
      status: entry.status,
      at: entry.at instanceof Date ? entry.at.toISOString() : entry.at,
      note: entry.note,
    })),
  };
}

async function appendLog(action, details, meta = {}, user = null) {
  await Activity.create({ action, details, meta, userId: user ? user._id : null });
}

function removeLocalFile(filePath) {
  if (!filePath) return;
  const normalized = filePath.startsWith('http') ? '' : filePath;
  if (!normalized) return;
  const absolute = path.resolve(process.cwd(), normalized.replace(/^\//, ''));
  if (fs.existsSync(absolute)) {
    fs.unlinkSync(absolute);
  }
}

const createReport = asyncHandler(async (req, res) => {
  const { title, description, category, lat, lng, address = '' } = req.body;
  const roadId = req.body.roadId || req.body.road_id || '';
  const upload = req.file;
  const images = Array.isArray(req.body.images) ? req.body.images.filter(Boolean) : [];
  const image = upload ? `/uploads/${upload.filename}` : req.body.image || req.body.imageUrl || images[0] || '';

  const report = await Report.create({
    userId: req.user._id,
    roadId,
    title,
    description,
    category,
    latitude: Number(lat),
    longitude: Number(lng),
    address,
    image,
    images: upload ? [image] : images,
    imagePublicId: upload ? upload.filename : '',
    status: 'Pending',
    authorityTicket: 'PENDING',
    recommendedDepartment: CATEGORY_TO_DEPARTMENT[category] || 'Municipal Corporation',
    routingReason: `${category} reports are routed to ${CATEGORY_TO_DEPARTMENT[category] || 'Municipal Corporation'}.`,
    complaintLetter: `${title}\n\n${description}`,
    timeline: [{ status: 'Pending', at: new Date(), note: 'Report created' }],
  });

  await appendLog('report:create', 'Report created', { reportId: report._id, category }, req.user);
  try {
    const payload = toComplaintView(report);
    broadcaster.emit('report:created', payload);
    broadcaster.emit('reportCreated', payload);
  } catch (e) {}
  logger.info({ reportId: report._id.toString(), userId: req.user._id.toString() }, 'report created');
  const view = toComplaintView(report);
  res.status(201).json({
    ...view,
    report: {
      _id: report._id.toString(),
      ...view,
    },
  });
});

const getReports = asyncHandler(async (req, res) => {
  const filter = req.user.role === 'admin' ? {} : { userId: req.user._id };
  if (req.query.status) filter.status = req.query.status;
  if (req.query.category) filter.category = req.query.category;

  const reports = await Report.find(filter).sort({ createdAt: -1 });
  res.json({ reports: reports.map(toComplaintView) });
});

const getReportById = asyncHandler(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) {
    throw new AppError('Report not found', 404);
  }
  if (req.user.role !== 'admin' && report.userId.toString() !== req.user._id.toString()) {
    throw new AppError('Forbidden', 403);
  }
  res.json(toComplaintView(report));
});

const updateReport = asyncHandler(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) {
    throw new AppError('Report not found', 404);
  }
  if (req.user.role !== 'admin' && report.userId.toString() !== req.user._id.toString()) {
    throw new AppError('Forbidden', 403);
  }

  const upload = req.file;
  const updates = {};

  // Basic fields
  ['title', 'description', 'category', 'roadId', 'address', 'recommendedDepartment'].forEach((field) => {
    if (req.body[field] !== undefined) updates[field] = req.body[field];
  });

  // Location
  if (req.body.lat !== undefined && req.body.lng !== undefined) {
    updates.latitude = Number(req.body.lat);
    updates.longitude = Number(req.body.lng);
  }

  // Image handling
  if (upload) {
    if (report.image) removeLocalFile(report.image);
    updates.image = `/uploads/${upload.filename}`;
    updates.imagePublicId = upload.filename;
    updates.images = [`/uploads/${upload.filename}`];
  } else if (req.body.image || req.body.imageUrl) {
    updates.image = req.body.image || req.body.imageUrl;
  } else if (Array.isArray(req.body.images)) {
    updates.images = req.body.images.filter(Boolean);
  }

  // Recommended department when category changes
  if (updates.category) {
    updates.recommendedDepartment = CATEGORY_TO_DEPARTMENT[updates.category] || report.recommendedDepartment;
  }

  const push = {};
  if (req.body.status !== undefined) {
    updates.status = req.body.status;
    push.timeline = { status: req.body.status, at: new Date(), note: `Status set to ${req.body.status}` };
  }

  const updatePayload = { $set: updates };
  if (Object.keys(push).length > 0) {
    updatePayload.$push = push;
  }

  const updated = await Report.findByIdAndUpdate(req.params.id, updatePayload, { new: true });

  await appendLog('report:update', 'Report updated', { reportId: updated._id }, req.user);
  try {
    const payload = toComplaintView(updated);
    broadcaster.emit('report:updated', payload);
    broadcaster.emit('reportUpdated', payload);
  } catch (e) {}
  logger.info({ reportId: updated._id.toString(), userId: req.user._id.toString() }, 'report updated');
  res.json(toComplaintView(updated));
});

const deleteReport = asyncHandler(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) {
    throw new AppError('Report not found', 404);
  }
  if (req.user.role !== 'admin' && report.userId.toString() !== req.user._id.toString()) {
    throw new AppError('Forbidden', 403);
  }

  if (report.image) {
    removeLocalFile(report.image);
  }

  await report.deleteOne();
  await appendLog('report:delete', 'Report deleted', { reportId: req.params.id }, req.user);
  try {
    broadcaster.emit('report:deleted', { id: req.params.id });
    broadcaster.emit('reportDeleted', { id: req.params.id });
  } catch (e) {}
  logger.info({ reportId: req.params.id, userId: req.user._id.toString() }, 'report deleted');
  res.json({ message: 'Report deleted successfully' });
});

const updateStatus = asyncHandler(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) {
    throw new AppError('Report not found', 404);
  }

  if (req.user.role !== 'admin') {
    throw new AppError('Only admins can change report status', 403);
  }

  const { status, note = '' } = req.body;
  report.status = status;
  report.timeline.push({ status, at: new Date(), note: note || `Status changed to ${status}` });
  if (status === 'Resolved') {
    report.readByAuthority = true;
    report.readAt = new Date();
  }
  await report.save();
  await appendLog('report:status', 'Report status updated', { reportId: report._id, status }, req.user);
  try {
    const payload = toComplaintView(report);
    broadcaster.emit('report:updated', payload);
    broadcaster.emit('reportUpdated', payload);
  } catch (e) {}
  res.json(toComplaintView(report));
});

const sendToAuthority = asyncHandler(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) {
    throw new AppError('Report not found', 404);
  }

  report.sentToAuthority = true;
  report.sentAt = new Date();
  report.deliveredToAuthority = true;
  report.deliveredAt = new Date();
  report.status = report.status === 'Pending' ? 'In Progress' : report.status;
  report.authorityTicket = report.authorityTicket === 'PENDING' ? `RW-${String(Date.now()).slice(-6)}` : report.authorityTicket;
  report.timeline.push({ status: 'Sent', at: new Date(), note: 'Sent to authority' });
  report.timeline.push({ status: 'Delivered', at: new Date(), note: 'Delivered to authority inbox' });
  await report.save();
  try {
    const payload = toComplaintView(report);
    broadcaster.emit('report:updated', payload);
    broadcaster.emit('reportUpdated', payload);
  } catch (e) {}
  res.json(toComplaintView(report));
});

const markAsRead = asyncHandler(async (req, res) => {
  const report = await Report.findById(req.params.id);
  if (!report) {
    throw new AppError('Report not found', 404);
  }

  report.readByAuthority = true;
  report.readAt = new Date();
  if (report.status === 'Pending') {
    report.status = 'In Progress';
  }
  report.timeline.push({ status: 'Read', at: new Date(), note: 'Marked as read by authority' });
  await report.save();
  try {
    const payload = toComplaintView(report);
    broadcaster.emit('report:updated', payload);
    broadcaster.emit('reportUpdated', payload);
  } catch (e) {}
  res.json(toComplaintView(report));
});

const syncOffline = asyncHandler(async (req, res) => {
  const payload = req.body.reports || req.body.complaints || [];
  const created = [];

  for (const item of payload) {
    const report = await Report.create({
      userId: req.user._id,
      roadId: item.road_id || item.roadId || '',
      title: item.title || item.description?.slice(0, 48) || 'Offline report',
      description: item.description || 'Offline synced complaint',
      category: item.category || 'Other',
      latitude: item.location?.lat || item.lat || 0,
      longitude: item.location?.lng || item.lng || 0,
      address: item.location?.address || item.address || '',
      image: item.image_ref || item.imageUrl || '',
      status: item.status || 'Pending',
      authorityTicket: item.authority_ticket || 'PENDING',
      recommendedDepartment: item.recommended_department || 'Municipal Corporation',
      routingReason: item.routing_reason || '',
      complaintLetter: item.complaint_letter || '',
      sentToAuthority: item.sent_to_authority || false,
      deliveredToAuthority: item.delivered_to_authority || false,
      readByAuthority: item.read_by_authority || false,
      sentAt: item.sent_at || null,
      deliveredAt: item.delivered_at || null,
      readAt: item.read_at || null,
      timeline: item.timeline || [{ status: 'Pending', at: new Date(), note: 'Synced from offline cache' }],
    });
    created.push(toComplaintView(report));
  }

  res.json({ synced: created.length, complaints: created });
});

module.exports = {
  createReport,
  getReports,
  getReportById,
  updateReport,
  deleteReport,
  updateStatus,
  sendToAuthority,
  markAsRead,
  syncOffline,
  toComplaintView,
};
