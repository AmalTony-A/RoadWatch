const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');

describe('Admin integration', () => {
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

  async function loginAdmin() {
    const response = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@roadwatch.local', password: 'Admin@12345' })
      .expect(200);

    return { token: response.body.token, csrfToken: response.body.csrfToken };
  }

  test('dashboard stats and analytics are available to admin', async () => {
    const { token } = await loginAdmin();

    const stats = await request(app)
      .get('/api/admin/dashboard-stats')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    const analytics = await request(app)
      .get('/api/admin/analytics')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(stats.body.totalReports).toBeGreaterThanOrEqual(0);
    expect(analytics.body.reportsByCategory).toBeDefined();
  });
});
