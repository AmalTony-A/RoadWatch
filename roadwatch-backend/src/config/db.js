const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const config = require('./config');
const { logger } = require('../utils/logger');
const AppError = require('../utils/AppError');
const seedData = require('../utils/seedData');
const User = require('../models/User');
const Report = require('../models/Report');
const PasswordResetToken = require('../models/PasswordResetToken');
const Activity = require('../models/Activity');
const RoadSegment = require('../models/RoadSegment');
const RoadNetworkItem = require('../models/RoadNetworkItem');
const Budget = require('../models/Budget');
const Contractor = require('../models/Contractor');

let memoryServer = null;

function logInfo(message, meta = {}) {
  if (logger && logger.info) {
    logger.info(meta, message);
  } else {
    console.log(message, meta);
  }
}

function logError(message, meta = {}) {
  if (logger && logger.error) {
    logger.error(meta, message);
  } else {
    console.error(message, meta);
  }
}

async function connectDB() {
  mongoose.connection.on('connected', () => {
    logInfo('MongoDB connection ready');
  });
  mongoose.connection.on('error', (err) => {
    logError('MongoDB connection error', { err: err.message });
  });
  mongoose.connection.on('disconnected', () => {
    if (logger && logger.warn) {
      logger.warn('MongoDB disconnected');
    } else {
      console.warn('MongoDB disconnected');
    }
  });

  let uri = config.mongodbUri;

  logInfo(`[Mongo] env=${config.env} mongodbUri=${uri ? 'present' : 'missing'}`);

  if (!uri) {
    if (config.env === 'production') {
      throw new AppError('MONGODB_URI is required', 500);
    }

    let MongoMemoryServer;
    try {
      ({ MongoMemoryServer } = require('mongodb-memory-server'));
    } catch (error) {
      throw new AppError('MONGODB_URI is missing and mongodb-memory-server is not available', 500);
    }

    memoryServer = await MongoMemoryServer.create();
    uri = memoryServer.getUri();
    logInfo('[Mongo] Using in-memory DB');
  } else {
    logInfo('[Mongo] Using Atlas/local DB');
  }

  const redactedUri = uri.replace(/:\/\/([^:]+):([^@]+)@/, '://***:***@');
  const maxAttempts = 8;
  let attempt = 0;
  while (attempt < maxAttempts) {
    try {
      await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
      logInfo('[Mongo] Connected', { uri: redactedUri });
      return;
    } catch (err) {
      attempt += 1;
      const waitMs = Math.min(30000, 1000 * Math.pow(2, attempt));
      logError('MongoDB connection failed, retrying', { err: err.message, attempt });
      if (attempt >= maxAttempts) {
        throw new AppError(`Could not connect to MongoDB after ${maxAttempts} attempts: ${err.message}`, 500);
      }
      await new Promise((r) => setTimeout(r, waitMs));
    }
  }
}

async function disconnectDB() {
  await mongoose.connection.close();
  if (memoryServer) {
    await memoryServer.stop();
    memoryServer = null;
  }
}

async function seedDatabase() {
  const sampleEnabled = config.seedSampleData;
  if (!sampleEnabled) {
    return;
  }

  const [userCount, reportCount, roadCount, networkCount, budgetCount, contractorCount] = await Promise.all([
    User.countDocuments(),
    Report.countDocuments(),
    RoadSegment.countDocuments(),
    RoadNetworkItem.countDocuments(),
    Budget.countDocuments(),
    Contractor.countDocuments(),
  ]);

  if (userCount === 0) {
    const adminPassword = await bcrypt.hash(process.env.ADMIN_PASSWORD || 'Admin@12345', 12);
    const demoPassword = await bcrypt.hash('User@12345', 12);
    await User.insertMany([
      {
        name: 'RoadWatch Admin',
        email: process.env.ADMIN_EMAIL || 'admin@roadwatch.local',
        password: adminPassword,
        role: 'admin',
      },
      {
        name: 'RoadWatch Demo User',
        email: 'demo@roadwatch.local',
        password: demoPassword,
        role: 'user',
      },
    ]);
  }

  if (reportCount === 0) {
    const demoUser = await User.findOne({ email: 'demo@roadwatch.local' });
    if (demoUser) {
      await Report.insertMany(
        seedData.complaintReports.map((report) => ({
          userId: demoUser._id,
          title: report.title,
          description: report.description,
          category: report.category,
          latitude: report.location?.lat ?? 0,
          longitude: report.location?.lng ?? 0,
          address: report.location?.address || '',
          image: report.image_ref,
          imagePublicId: '',
          status: report.status,
          roadId: report.road_id,
          authorityTicket: report.authority_ticket,
          recommendedDepartment: report.recommended_department,
          routingReason: report.routing_reason,
          complaintLetter: report.complaint_letter,
          sentToAuthority: report.sent_to_authority,
          deliveredToAuthority: report.delivered_to_authority,
          readByAuthority: report.read_by_authority,
          sentAt: report.sent_at,
          deliveredAt: report.delivered_at,
          readAt: report.read_at,
          timeline: report.timeline,
          createdAt: new Date(report.timestamp),
          updatedAt: new Date(report.timestamp),
        })),
      );
    }
  }

  if (roadCount === 0) {
    await RoadSegment.insertMany(seedData.roadSegments);
  }

  if (networkCount === 0) {
    await RoadNetworkItem.insertMany(
      seedData.roadNetworkItems.map((item) => ({
        id: item.id,
        name: item.name,
        type: item.type,
        route: item.route,
        districts: item.districts,
        lengthKm: item.length_km,
        year: item.year,
        contractor: item.contractor,
        budgetCrore: item.budget_crore,
        condition: item.condition,
        issues: item.issues,
        summary: item.summary,
      })),
    );
  }

  if (budgetCount === 0) {
    await Budget.insertMany(
      seedData.budgets.map((item) => ({
        roadId: item.road_id,
        projectId: item.project_id,
        allocatedInr: item.allocated_inr,
        spentInr: item.spent_inr,
        contractor: item.contractor,
        lastRepairDate: item.last_repair_date,
        expectedScore: item.expected_score,
        actualScore: item.actual_score,
        transparencyNote: item.transparency_note,
      })),
    );
  }

  if (contractorCount === 0) {
    await Contractor.insertMany(
      seedData.contractors.map((item) => ({
        id: item.id,
        name: item.name,
        company: item.company,
        projectStatus: item.project_status,
        overallRating: item.overall_rating,
        totalReviews: item.total_reviews,
        reviews: item.reviews.map((review) => ({
          id: review.id,
          userId: review.user_id,
          userName: review.user_name,
          rating: review.rating,
          sentiment: review.sentiment,
          reviewText: review.review_text,
          emotionEmoji: review.emotion_emoji,
          timestamp: review.timestamp,
          isSpamDetected: review.is_spam_detected,
          helpfulCount: review.helpful_count,
          imageUrl: review.image_url,
        })),
        trustedBadge: item.trusted_badge,
        publicTransparencyScore: item.public_transparency_score,
        complaintCount: item.complaint_count,
        roadsManaged: item.roads_managed,
        profileImageUrl: item.profile_image_url,
      })),
    );
  }

  if ((await Activity.countDocuments()) === 0) {
    await Activity.create({
      action: 'seed',
      details: 'Seed data loaded for RoadWatch backend',
      meta: { source: 'seedDatabase' },
    });
  }

  await PasswordResetToken.deleteMany({});
}

module.exports = {
  connectDB,
  disconnectDB,
  seedDatabase,
};
