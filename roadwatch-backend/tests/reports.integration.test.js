const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');

describe('Reports and admin API integration', () => {
  let mongo;
  let app;
  let connectDB;
  let disconnectDB;
  let seedDatabase;
  let adminToken;

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

    const login = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@roadwatch.local', password: 'Admin@12345' })
      .expect(200);

    adminToken = login.body.token;
  }, 60000);

  afterAll(async () => {
    await disconnectDB();
    if (mongo) await mongo.stop();
  });

  test('can create, read, update and delete report', async () => {
    const created = await request(app)
      .post('/api/reports')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        title: 'Large pothole at junction',
        description: 'Deep pothole causing dangerous swerves at peak traffic hours.',
        category: 'Pothole',
        lat: 12.9716,
        lng: 77.5946,
      })
      .expect(201);

    const id = created.body.report?._id;
    expect(id).toBeTruthy();

    await request(app)
      .get('/api/reports')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    await request(app)
      .put(`/api/reports/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ title: 'Updated pothole report', status: 'In Progress' })
      .expect(200);

    await request(app)
      .delete(`/api/reports/${id}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);
  });

  test('admin can set user role to moderator', async () => {
    const usersRes = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .expect(200);

    const demoUser = (usersRes.body.users || []).find((user) => user.email === 'demo@roadwatch.local');
    expect(demoUser?._id).toBeTruthy();

    const roleRes = await request(app)
      .put(`/api/admin/user/${demoUser._id}/role`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ role: 'moderator' })
      .expect(200);

    expect(roleRes.body.user.role).toBe('moderator');
  });
});
