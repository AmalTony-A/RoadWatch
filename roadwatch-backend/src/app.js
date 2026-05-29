const path = require('path');

const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');

const config = require('./config/config');
const { logger, pinoHttp } = require('./utils/logger');

let promClient;
try {
  promClient = require('prom-client');
} catch (e) {
  promClient = null;
}

const authRoutes = require('./routes/authRoutes');
const reportRoutes = require('./routes/reportRoutes');
const adminRoutes = require('./routes/adminRoutes');
const testRoutes = require('./routes/testRoutes');
const compatibilityRoutes = require('./routes/compatibilityRoutes');
const {
  attachRequestMeta,
  parseCookieMiddleware,
  sanitizeRequest,
  csrfProtection,
} = require('./middleware/securityMiddleware');

const {
  notFound,
  errorHandler
} = require('./middleware/errorMiddleware');

const app = express();

app.set('trust proxy', 1);

const allowedOrigins = new Set([
  // prefer localhost hostname in defaults to avoid cross-site cookie issues in tests
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  ...(config.corsOrigins || []),
]);

// Logger
if (pinoHttp) {
  app.use(pinoHttp);
} else if (logger && logger.info) {
  app.use((req, _res, next) => {
    logger.info(
      {
        method: req.method,
        url: req.url
      },
      'request'
    );
    next();
  });
}

const uploadDir = path.resolve(
  process.cwd(),
  process.env.UPLOAD_DIR || 'uploads'
);

// Security
app.use(helmet());

// CORS must run before routes so browser preflight receives the headers.
app.use(cors({
  origin(origin, callback) {
    if (!origin) {
      callback(null, true);
      return;
    }

    // Allow common local development origins (localhost, 127.0.0.1, IPv6 ::1)
    if (config.env !== 'production') {
      try {
        const lowered = origin.toLowerCase();
        if (lowered.includes('localhost') || lowered.includes('127.0.0.1') || lowered.includes('::1')) {
          callback(null, true);
          return;
        }
      } catch (e) {
        // fallthrough to allowedOrigins check
      }
    }

    if (allowedOrigins.has(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  credentials: true,
  optionsSuccessStatus: 200,
}));

app.options('*', cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.has(origin)) {
      callback(null, true);
      return;
    }

    callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  credentials: true,
  optionsSuccessStatus: 200,
}));

// Rate limiting
app.use(rateLimit({
  windowMs: config.rateLimitWindowMs,
  max: config.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
  skip: () => config.env !== 'production',
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(attachRequestMeta);
app.use(parseCookieMiddleware);
app.use(sanitizeRequest);
if (config.env !== 'production') {
  app.use('/api/test', testRoutes);
}
app.use(csrfProtection);

if (!pinoHttp) {
  app.use(morgan('dev'));
}

// Static files
app.use('/uploads', express.static(uploadDir));

// Monitor UI
const monitorDir = path.resolve(
  process.cwd(),
  'public',
  'monitor'
);

app.use('/monitor', express.static(monitorDir));

// Metrics
if (promClient) {
  promClient.collectDefaultMetrics();

  app.get('/metrics', async (_req, res) => {
    try {
      res.set(
        'Content-Type',
        promClient.register.contentType
      );

      res.end(
        await promClient.register.metrics()
      );

    } catch (err) {
      res.status(500).send(
        err.message || 'metrics error'
      );
    }
  });
}

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/admin', adminRoutes);
app.use('/', compatibilityRoutes);

// Error handlers
app.use(notFound);
app.use(errorHandler);

module.exports = app;