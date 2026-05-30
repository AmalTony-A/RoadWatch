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

app.use((req, _res, next) => {
  if (logger && logger.info) {
    logger.info(
      {
        method: req.method,
        path: req.path,
        origin: req.headers.origin || '',
      },
      'incoming request'
    );
  }
  next();
});

const allowedOrigins = new Set([
  // prefer localhost hostname in defaults to avoid cross-site cookie issues in tests
  'http://localhost:5173',
  'http://127.0.0.1:5173',
  'http://localhost:3000',
  'http://127.0.0.1:3000',
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
const corsOptions = {
  origin(origin, callback) {
    if (logger && logger.info) {
      logger.info({ origin: origin || '' }, 'cors origin check');
    }
    if (!origin) {
      callback(null, true);
      return;
    }

    if (allowedOrigins.has(origin)) {
      callback(null, true);
      return;
    }

    // Allow local dev hostnames even if a port or alias was not listed.
    try {
      const lowered = origin.toLowerCase();
      if (lowered.includes('localhost') || lowered.includes('127.0.0.1') || lowered.includes('::1')) {
        callback(null, true);
        return;
      }
    } catch (e) {
      // fall through to rejection below
    }

    callback(new Error(`CORS blocked for origin: ${origin}`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
  optionsSuccessStatus: 200,
};

app.use(cors(corsOptions));
app.options('*', cors(corsOptions));

// Rate limiting
// Keep production throttling intact, but make local/dev testing and repeated
// complaints retries less likely to trip the limiter while debugging.
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: config.env === 'production' ? config.rateLimitMax : 1000,
  standardHeaders: true,
  legacyHeaders: false,
  skip: (req) => config.env !== 'production' || req.path.startsWith('/api/complaints'),
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

app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'RoadWatch AI',
  });
});

app.get('/', (_req, res) => {
  res.json({
    message: 'RoadWatch AI Backend Running',
  });
});

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/reports', reportRoutes);
app.use('/api/admin', adminRoutes);
app.use('/', compatibilityRoutes);

// Error handlers
app.use(notFound);
app.use(errorHandler);

module.exports = app;