const path = require('path');

require('dotenv').config({ path: path.resolve(process.cwd(), '..', 'backend', '.env') });
require('dotenv').config({ path: path.resolve(process.cwd(), '..', '.env') });
require('dotenv').config();
const http = require('http');
let WebSocketServer;
try {
  ({ WebSocketServer } = require('ws'));
} catch (error) {
  WebSocketServer = null;
}

const app = require('./app');
const { connectDB, disconnectDB, seedDatabase } = require('./config/db');
const { logger } = require('./utils/logger');
const { initErrorTracking } = require('./utils/observability');
const config = require('./config/config');

const allowedOrigins = new Set([
  'http://localhost:3000',
  'http://127.0.0.1:3000',
  'http://localhost:5173',
  'http://localhost:5174',
  'http://localhost:4173',
  'http://127.0.0.1:5173',
  'http://127.0.0.1:5174',
  'http://127.0.0.1:4173',
  // prefer localhost hostname for dev to avoid cross-site cookie issues in browsers
  ...(config.corsOrigins || []),
]);

async function start() {
  initErrorTracking();
  if (config.env === 'production' && (!config.mongodbUri || !config.jwtSecret)) {
    throw new Error('MONGODB_URI and JWT_SECRET are required in production');
  }

  await connectDB();
  await seedDatabase();

  const port = Number(process.env.PORT || config.port || 8000);
  if (process.argv.includes('--seed-only')) {
    (logger && logger.info) ? logger.info('Seed completed') : console.log('Seed completed');
    process.exit(0);
  }

  const server = http.createServer(app);

  // Attach Socket.IO for real-time admin dashboard updates
  let io = null;
  try {
    const { Server } = require('socket.io');
    io = new Server(server, {
      cors: {
        origin(origin, callback) {
          if (!origin || allowedOrigins.has(origin)) {
            callback(null, true);
            return;
          }

          callback(new Error(`Socket.IO blocked for origin: ${origin}`));
        },
        methods: ['GET', 'POST', 'PUT', 'DELETE'],
        credentials: true,
      },
    });

    const { setIo } = require('./utils/broadcast');
    setIo(io);

    io.on('connection', (socket) => {
      console.log('Socket connected:', socket.id);
      socket.emit('connected', { service: 'roadwatch-backend', at: new Date().toISOString() });

      socket.on('disconnect', () => {
        console.log('Socket disconnected');
      });
    });
  } catch (e) {
    if (logger && logger.error) {
      logger.error({ err: e.message }, 'Socket.IO initialization failed');
    } else {
      console.error('Socket.IO initialization failed:', e.message);
    }
  }

  if (WebSocketServer) {
    const wsServer = new WebSocketServer({ noServer: true });

    wsServer.on('connection', (socket) => {
      socket.isAlive = true;
      socket.send(JSON.stringify({ type: 'connected', service: 'roadwatch-backend', at: new Date().toISOString() }));

      socket.on('pong', () => {
        socket.isAlive = true;
      });
    });

    server.on('upgrade', (request, socket, head) => {
      const { url } = request;
      if (url !== '/ws/updates') {
        socket.destroy();
        return;
      }

      wsServer.handleUpgrade(request, socket, head, (ws) => {
        wsServer.emit('connection', ws, request);
      });
    });

    const heartbeat = setInterval(() => {
      wsServer.clients.forEach((socket) => {
        if (socket.isAlive === false) {
          socket.terminate();
          return;
        }
        socket.isAlive = false;
        socket.ping();
      });
    }, 30000);

    server.on('close', () => clearInterval(heartbeat));
  }

  server.listen(port, () => {
    (logger && logger.info)
      ? logger.info({ url: `http://localhost:${port}` }, 'RoadWatch backend listening')
      : console.log(`RoadWatch backend listening on http://localhost:${port}`);
  });

  const graceful = async () => {
    (logger && logger.info) ? logger.info('Shutting down gracefully') : console.log('Shutting down');
    server.close(() => {
      disconnectDB().finally(() => {
        (logger && logger.info) ? logger.info('Mongo connection closed') : console.log('Mongo closed');
        process.exit(0);
      });
    });
  };

  process.on('SIGTERM', graceful);
  process.on('SIGINT', graceful);
}

start().catch((error) => {
  (logger && logger.error) ? logger.error(error) : console.error(error);
  process.exit(1);
});
