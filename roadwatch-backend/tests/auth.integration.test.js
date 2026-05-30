const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');

describe('Auth integration', () => {
  let mongo;
  let app;
  let connectDB;
  let disconnectDB;
  let seedDatabase;

  beforeAll(async () => {
    process.env.NODE_ENV = 'test';
    process.env.JWT_SECRET = 'test-secret';
    process.env.JWT_EXPIRES_IN = '15m';
    mongo = await MongoMemoryServer.create();
    process.env.MONGODB_URI = mongo.getUri();

    ({ connectDB, disconnectDB, seedDatabase } = require('../src/config/db'));
    app = require('../src/app');
    await connectDB();
    await seedDatabase();
  }, 60000);

  afterAll(async () => {
    await disconnectDB();
    if (mongo) await mongo.stop();
  });

  test('login returns access token, user payload, and auth cookies', async () => {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@roadwatch.local', password: 'Admin@12345' })
      .expect(200);

    expect(response.body.token).toBeTruthy();
    expect(response.body.user.email).toBe('admin@roadwatch.local');
    expect(response.body.csrfToken).toBeTruthy();
    expect(response.headers['set-cookie'].join(';')).toContain('refresh_token=');
  });

  test('health endpoint returns ok status', async () => {
    const response = await request(app)
      .get('/health')
      .expect(200);

    expect(response.body).toEqual({
      status: 'ok',
      service: 'RoadWatch AI',
    });
  });

  test('refresh rotates the access session', async () => {
    const agent = request.agent(app);
    const login = await agent
      .post('/api/auth/login')
      .send({ email: 'admin@roadwatch.local', password: 'Admin@12345' })
      .expect(200);

    const csrf = login.body.csrfToken;
    const refresh = await agent
      .post('/api/auth/refresh')
      .set('X-CSRF-Token', csrf)
      .expect(200);

    expect(refresh.body.token).toBeTruthy();
    expect(refresh.body.user.role).toBe('admin');
  });
});
