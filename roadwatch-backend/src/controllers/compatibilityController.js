const fs = require('fs');
const path = require('path');

const asyncHandler = require('../utils/asyncHandler');
const seedData = require('../utils/seedData');
const Report = require('../models/Report');
const RoadSegment = require('../models/RoadSegment');
const Budget = require('../models/Budget');
const RoadNetworkItem = require('../models/RoadNetworkItem');
const Contractor = require('../models/Contractor');
const { toComplaintView } = require('./reportController');
const AppError = require('../utils/AppError');
const { analyzeRoadImage, generateRoadChat } = require('../services/geminiService');

function resolveGeminiApiKey() {
  return process.env.GOOGLE_API_KEY || process.env.GEMINI_API_KEY || '';
}

const BUNDLED_ROAD_DATA_PATH = path.resolve(process.cwd(), '..', 'frontend', 'assets', 'complete_road_data.json');
let bundledDistrictCache = null;

function normalizeDistrictToken(value) {
  var normalized = `${value || ''}`.trim().toLowerCase();
  normalized = normalized.replaceAll('&', 'and');
  normalized = normalized.replaceAll(/[^a-z0-9]/g, '');
  normalized = normalized.replaceAll('thiru', 'tiru');
  const alias = {
    kancheepuram: 'kanchipuram',
    kanceepuram: 'kanchipuram',
    thiruvallur: 'tiruvallur',
    thiruvannamalai: 'tiruvannamalai',
  };
  return alias[normalized] ?? normalized;
}

async function loadBundledDistricts() {
  if (bundledDistrictCache) {
    return bundledDistrictCache;
  }

  try {
    const jsonText = await fs.promises.readFile(BUNDLED_ROAD_DATA_PATH, 'utf8');
    const data = JSON.parse(jsonText);
    const map = new Map();
    for (const item of data) {
      for (const district of item.districts || []) {
        const canonical = `${district || ''}`.trim();
        const token = normalizeDistrictToken(canonical);
        if (token && !map.has(token)) {
          map.set(token, canonical);
        }
      }
    }
    bundledDistrictCache = map;
  } catch (error) {
    bundledDistrictCache = new Map();
  }

  return bundledDistrictCache;
}

function resolveDistrictFromCandidates(candidates, bundledDistricts) {
  for (const candidate of candidates) {
    const text = `${candidate || ''}`.trim();
    if (!text) continue;
    const token = normalizeDistrictToken(text);
    if (bundledDistricts.has(token)) {
      return bundledDistricts.get(token);
    }
  }

  for (const candidate of candidates) {
    const text = `${candidate || ''}`.trim();
    if (text) return text;
  }

  return null;
}

function toRoadResponse(road) {
  return {
    id: road.id,
    name: road.name,
    ward: road.ward,
    polyline: road.polyline,
    road_health_score: road.roadHealthScore,
    color: road.color,
    nearby_issues: road.nearbyIssues,
    recent_complaints: road.recentComplaints,
  };
}

function toBudgetResponse(budget) {
  return {
    road_id: budget.roadId,
    project_id: budget.projectId,
    allocated_inr: budget.allocatedInr,
    spent_inr: budget.spentInr,
    contractor: budget.contractor,
    last_repair_date: budget.lastRepairDate,
    expected_score: budget.expectedScore,
    actual_score: budget.actualScore,
    transparency_note: budget.transparencyNote,
  };
}

function toRoadNetworkResponse(item) {
  return {
    id: item.id,
    name: item.name,
    type: item.type,
    route: item.route,
    districts: item.districts,
    length_km: item.lengthKm,
    year: item.year,
    contractor: item.contractor,
    budget_crore: item.budgetCrore,
    condition: item.condition,
    issues: item.issues,
    summary: item.summary,
  };
}

function toComplaintResponse(report) {
  const complaint = toComplaintView(report);
  return {
    ...complaint,
    image: complaint.image_ref,
    ticketId: complaint.authority_ticket,
  };
}

function defaultUserName(user) {
  return user ? user.name : 'RoadWatch AI';
}

const health = asyncHandler(async (_req, res) => {
  res.json({ ok: true, service: 'roadwatch-backend', time: new Date().toISOString() });
});

const uploadImage = asyncHandler(async (req, res) => {
  if (!req.file) {
    throw new AppError('File upload required', 400);
  }

  res.json({
    image_id: req.file.filename,
    road_id: req.query.road_id || '',
    size_bytes: req.file.size,
    stored_at: path.join(process.env.UPLOAD_DIR || 'uploads', req.file.filename).replace(/\\/g, '/'),
    public_url: `/uploads/${req.file.filename}`,
  });
});

const reverseGeocode = asyncHandler(async (req, res) => {
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    throw new AppError('lat and lng are required', 400);
  }

  const bundledDistricts = await loadBundledDistricts();
  let resolvedDistrict = null;
  let address = '';

  for (let attempt = 0; attempt < 2 && !resolvedDistrict; attempt += 1) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 6000);
      const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lng)}&addressdetails=1`;
      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'User-Agent': 'RoadWatchAI/1.0 contact=roadwatch-ai-demo',
          Accept: 'application/json',
          'Accept-Language': 'en',
        },
      });
      clearTimeout(timeout);

      if (response.ok) {
        const payload = await response.json();
        const districtCandidates = [
          payload.address?.state_district,
          payload.address?.county,
          payload.address?.city_district,
          payload.address?.city,
          payload.address?.town,
          payload.address?.village,
          payload.address?.municipality,
          payload.address?.suburb,
        ];
        resolvedDistrict = resolveDistrictFromCandidates(districtCandidates, bundledDistricts);
        address = payload.display_name || '';
      }
    } catch (_) {
      // fall back to bundled district names below
    }

    if (!resolvedDistrict && attempt === 0) {
      await new Promise((resolve) => setTimeout(resolve, 1200));
    }
  }

  if (!resolvedDistrict) {
    const coarse = resolveDistrictFromCandidates([
      req.query.district,
      req.query.city,
      req.query.area,
    ], bundledDistricts);
    if (coarse) {
      resolvedDistrict = coarse;
    }
  }

  res.json({
    district: resolvedDistrict || 'Unknown',
    address,
    source: resolvedDistrict ? 'nominatim' : 'fallback',
  });
});

const getRoadData = asyncHandler(async (_req, res) => {
  const roads = await RoadSegment.find({}).lean();
  const reports = await Report.find({}).sort({ createdAt: -1 }).limit(10).lean();
  const total = roads.length;
  const overallScore = total
    ? Math.round(roads.reduce((sum, road) => sum + Number(road.roadHealthScore || 0), 0) / total)
    : 0;

  res.json({
    overview: {
      overall_score: overallScore,
      total_roads: roads.length,
      red_roads: roads.filter((road) => road.color === 'red').length,
      yellow_roads: roads.filter((road) => road.color === 'yellow').length,
      green_roads: roads.filter((road) => road.color === 'green').length,
    },
    roads: roads.map(toRoadResponse),
    recent_complaints: reports.map(toComplaintResponse),
    intelligence: {
      damage_trends: [
        { month: 'Jan', issues: 42 },
        { month: 'Feb', issues: 57 },
        { month: 'Mar', issues: 61 },
        { month: 'Apr', issues: 74 },
        { month: 'May', issues: 69 },
      ],
      budget_vs_condition: [
        { road_id: 'road-001', allocated_inr: 5000000, score: 38 },
        { road_id: 'road-004', allocated_inr: 6300000, score: 46 },
      ],
      repair_frequency: [
        { road_id: 'road-001', repairs_last_12m: 2 },
        { road_id: 'road-004', repairs_last_12m: 3 },
      ],
      prediction_text: 'RoadWatch AI predicts increased deterioration during the next monsoon cycle.',
    },
  });
});

const getBudgetData = asyncHandler(async (_req, res) => {
  const budgets = await Budget.find({}).lean();
  res.json(budgets.map(toBudgetResponse));
});

const getRoadNetworkData = asyncHandler(async (req, res) => {
  const district = `${req.query.district || ''}`.trim();
  if (req.params.itemId) {
    const item = await RoadNetworkItem.findOne({ id: req.params.itemId }).lean();
    if (!item) {
      throw new AppError('Road network item not found', 404);
    }
    res.json(toRoadNetworkResponse(item));
    return;
  }

  const query = district
    ? {
        $or: [
          { districts: new RegExp(`^${district.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
          { districts: new RegExp(district, 'i') },
          { route: new RegExp(district, 'i') },
          { name: new RegExp(district, 'i') },
          { contractor: new RegExp(district, 'i') },
        ],
      }
    : {};
  const items = await RoadNetworkItem.find(query).lean();
  res.json(items.map(toRoadNetworkResponse));
});

const getRoads = asyncHandler(async (req, res) => {
  const district = `${req.query.district || ''}`.trim();
  const page = Math.max(1, Number.parseInt(req.query.page || '1', 10) || 1);
  const limit = Math.max(1, Math.min(50, Number.parseInt(req.query.limit || '10', 10) || 10));
  const query = district
    ? {
        $or: [
          { districts: new RegExp(`^${district.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') },
          { districts: new RegExp(district, 'i') },
          { route: new RegExp(district, 'i') },
          { name: new RegExp(district, 'i') },
          { contractor: new RegExp(district, 'i') },
        ],
      }
    : {};
  const [items, total] = await Promise.all([
    RoadNetworkItem.find(query).skip((page - 1) * limit).limit(limit).lean(),
    RoadNetworkItem.countDocuments(query),
  ]);

  res.json({
    roads: items.map(toRoadNetworkResponse),
    hasMore: page * limit < total,
    page,
    limit,
    total,
  });
});

const getComplaints = asyncHandler(async (req, res) => {
  const filter = {};
  if (req.query.road_id) {
    filter.roadId = req.query.road_id;
  }
  const reports = await Report.find(filter).sort({ createdAt: -1 }).lean();
  res.json(reports.map(toComplaintResponse));
});

const generateComplaint = asyncHandler(async (req, res) => {
  const user = req.user;
  if (!user) {
    throw new AppError('Authentication required to create complaints', 401);
  }

  const title = req.body.title || req.body.description?.slice(0, 48) || 'Road issue report';
  const report = await Report.create({
    userId: user._id,
    roadId: req.body.road_id || req.body.roadId || '',
    title,
    description: req.body.description || '',
    category: req.body.category || 'Other',
    latitude: req.body.location?.lat || req.body.lat || 0,
    longitude: req.body.location?.lng || req.body.lng || 0,
    address: req.body.location?.address || req.body.address || '',
    image: req.body.image_ref || req.body.imageUrl || '',
    status: 'Pending',
    authorityTicket: 'PENDING',
    recommendedDepartment: 'Municipal Corporation',
    routingReason: 'Complaint auto-generated from RoadWatch AI',
    complaintLetter: req.body.description || '',
    timeline: [{ status: 'Filed', at: new Date(), note: 'Complaint auto-filed from RoadWatch AI' }],
  });

  res.status(201).json(toComplaintResponse(report));
});

const detectDamage = asyncHandler(async (req, res) => {
  const apiKey = resolveGeminiApiKey();
  const roadId = req.body.road_id || req.body.roadId || null;

  if (req.file) {
    const result = await analyzeRoadImage({ req, file: req.file, roadId, apiKey });
    res.json(result);
    return;
  }

  const imageId = req.body.image_id || req.body.imageId;
  if (!imageId) {
    throw new AppError('Image file is required', 400);
  }

  const uploadPath = path.resolve(process.cwd(), process.env.UPLOAD_DIR || 'uploads', imageId);
  if (!fs.existsSync(uploadPath)) {
    throw new AppError('Uploaded image not found', 404);
  }

  const result = await analyzeRoadImage({
    req,
    file: { path: uploadPath, filename: imageId, originalname: imageId, mimetype: 'image/jpeg' },
    roadId,
    apiKey,
  });
  res.json(result);
});

const predictRisk = asyncHandler(async (req, res) => {
  const complaintCount = Number(req.body.complaint_count_30d || 0);
  const weather = Number(req.body.weather_index || 0);
  const traffic = Number(req.body.traffic_index || 0);
  const probability = Math.min(0.95, 0.25 + complaintCount * 0.08 + weather * 0.18 + traffic * 0.15);
  const days = Math.max(7, Math.round(45 - complaintCount * 2 - weather * 10 - traffic * 6));

  res.json({
    road_id: req.body.road_id || '',
    risk_level: probability >= 0.7 ? 'High' : probability >= 0.4 ? 'Moderate' : 'Low',
    probability_of_deterioration: Number(probability.toFixed(2)),
    predicted_days_to_decline: days,
  });
});

const chat = asyncHandler(async (req, res) => {
  const apiKey = resolveGeminiApiKey();
  const query = `${req.body.query || ''}`;
  const history = Array.isArray(req.body.history) ? req.body.history.slice(-10) : [];
  const roadContext = req.body.road_context || req.body.roadId || req.body.road_id || '';
  console.log('[RoadWatch] incoming /api/chat', {
    query: query.slice(0, 120),
    roadContext,
    historyCount: history.length,
    hasGeminiKey: Boolean(apiKey),
  });

  const response = await generateRoadChat({
    req,
    query,
    history,
    roadContext,
    apiKey,
  });

  console.log('[RoadWatch] /api/chat response', {
    allowed: response.allowed,
    topic: response.topic,
    answer: `${response.answer || ''}`.slice(0, 200),
  });

  res.json({
    ...response,
    safe: Boolean(response.allowed),
    cited_data: {
      query,
      road_id: req.body.road_id || req.body.roadId || '',
      user: defaultUserName(req.user),
    },
  });
});

const syncOffline = asyncHandler(async (req, res) => {
  const payload = req.body.complaints || req.body.reports || [];
  const user = req.user;
  if (!user) {
    throw new AppError('Authentication required to sync offline complaints', 401);
  }

  const created = [];
  for (const item of payload) {
    const report = await Report.create({
      userId: user._id,
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
      routingReason: item.routing_reason || 'Synced from offline cache',
      complaintLetter: item.complaint_letter || item.description || '',
      sentToAuthority: item.sent_to_authority || false,
      deliveredToAuthority: item.delivered_to_authority || false,
      readByAuthority: item.read_by_authority || false,
      sentAt: item.sent_at || null,
      deliveredAt: item.delivered_at || null,
      readAt: item.read_at || null,
      timeline: item.timeline || [{ status: 'Pending', at: new Date(), note: 'Synced from offline cache' }],
    });
    created.push(report._id.toString());
  }

  res.json({ synced: created.length, report_ids: created });
});

const getContractors = asyncHandler(async (_req, res) => {
  const contractors = await Contractor.find({}).lean();
  res.json(contractors.map((contractor) => ({
    id: contractor.id,
    name: contractor.name,
    company: contractor.company,
    project_status: contractor.projectStatus,
    overall_rating: contractor.overallRating,
    total_reviews: contractor.totalReviews,
    reviews: contractor.reviews,
    trusted_badge: contractor.trustedBadge,
    public_transparency_score: contractor.publicTransparencyScore,
    complaint_count: contractor.complaintCount,
    roads_managed: contractor.roadsManaged,
    profile_image_url: contractor.profileImageUrl,
  })));
});

module.exports = {
  health,
  uploadImage,
  reverseGeocode,
  getRoadData,
  getBudgetData,
  getRoadNetworkData,
  getRoads,
  getComplaints,
  generateComplaint,
  detectDamage,
  predictRisk,
  chat,
  syncOffline,
  getContractors,
};
