let sentry = null;

function initErrorTracking() {
  if (!process.env.SENTRY_DSN) return null;
  try {
    // Optional dependency, safe when not installed.
    // eslint-disable-next-line global-require
    sentry = require('@sentry/node');
    sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.NODE_ENV || 'development',
      tracesSampleRate: Number(process.env.SENTRY_TRACES_SAMPLE_RATE || 0.1),
    });
    return sentry;
  } catch (error) {
    return null;
  }
}

function captureException(error, context = {}) {
  if (sentry) {
    sentry.captureException(error, { extra: context });
  }
}

module.exports = {
  initErrorTracking,
  captureException,
};