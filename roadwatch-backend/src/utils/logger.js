let pino;
let pinoHttp;
try {
  pino = require('pino');
  pinoHttp = require('pino-http');
} catch (e) {
  // optional dependencies may not be installed in some environments
}

const logger = pino
  ? pino({ level: process.env.LOG_LEVEL || 'info' })
  : console;

module.exports = {
  logger,
  pinoHttp: pinoHttp ? pinoHttp({ logger }) : null,
};
