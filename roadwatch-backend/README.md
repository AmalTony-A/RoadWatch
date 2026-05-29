# RoadWatch Backend

Node.js + Express.js backend for RoadWatch with MongoDB, JWT authentication, bcrypt password hashing, Multer uploads, admin analytics, and compatibility endpoints for the Flutter frontend.

## Features

- User signup, login, profile, forgot password, and reset password
- JWT authentication with role-based access control
- Report/complaint CRUD with image uploads
- Status tracking and authority handoff flow
- Admin dashboard metrics and activity log
- Root compatibility routes for the existing Flutter app
- MongoDB schemas via Mongoose
- Postman collection included

## Folder Structure

```
src/
  config/
  controllers/
  middleware/
  models/
  routes/
  utils/
uploads/
postman/
```

## Prerequisites

- Node.js 18+ recommended
- MongoDB running locally or a MongoDB Atlas connection string

## Setup

1. Install dependencies:

```bash
npm install
```

2. Create your environment file:

```bash
copy .env.example .env
```

3. Update `.env` with your MongoDB URI and JWT secret.

4. Start MongoDB if you are using a local database.

5. Add `GEMINI_API_KEY` for chatbot and image damage analysis. The runtime model is fixed to `gemini-2.5-flash` because the older Flash model requested earlier is no longer returned by the current Gemini model-list endpoint for this key.

## Run Locally

```bash
npm run dev
```

Default port:

```bash
http://127.0.0.1:8000
```

Monitor UI:

```bash
http://127.0.0.1:8000/monitor/
```

## Seeded Demo Accounts

The backend seeds sample data by default.

- Admin: `admin@roadwatch.local`
- Demo user: `demo@roadwatch.local`
- Demo password: `User@12345`
- Admin password: `Admin@12345` or the value in `.env`

## Key API Routes

### Auth

- `POST /api/auth/signup`
- `POST /api/auth/login`
- `GET /api/auth/profile`
- `PUT /api/auth/profile`
- `POST /api/auth/forgot-password`
- `POST /api/auth/reset-password`

### Reports

- `POST /api/reports`
- `GET /api/reports`
- `GET /api/reports/:id`
- `PUT /api/reports/:id`
- `DELETE /api/reports/:id`
- `PATCH /api/reports/:id/status`

### Admin

- `GET /api/admin/dashboard-stats`
- `GET /api/admin/activity-log`
- `GET /api/admin/system-info`
- `GET /api/admin/complaints-breakdown`

### Monitoring

- `GET /health`
- `GET /metrics`
- `GET /monitor`
- `ws://127.0.0.1:8000/ws/updates`

### Flutter Compatibility Endpoints

- `GET /health`
- `GET /get-road-data`
- `GET /get-budget-data`
- `GET /get-road-network-data`
- `GET /get-road-network-data/:itemId`
- `GET /complaints`
- `POST /generate-complaint`
- `POST /upload-image`
- `POST /detect-damage`
- `POST /predict-risk`
- `POST /chat`
- `POST /sync-offline`
- `GET /contractors`
- `GET /api/location/reverse?lat=&lng=`

AI busy response:

```json
{
  "success": false,
  "temporary": true,
  "message": "AI service temporarily busy"
}
```

## Notes

- The frontend currently points to `http://127.0.0.1:8000` by default.
- If you run another backend on that port, stop it first.
- `POST /api/auth/forgot-password` returns a reset token directly for local testing.

## Professional organization & runbook

- Configuration: centralized in `src/config/config.js` (loads `.env`).
- Logging: `src/utils/logger.js` provides a pino logger used by the app.
- Metrics: optional Prometheus metrics at `/metrics` when `prom-client` is installed.
- Monitoring UI: static UI served at `/monitor` (dev-only insecure access via `MONITOR_ALLOW_INSECURE=true`).
- Docker: a `Dockerfile` is included for containerized deployment.
- MongoDB: the backend uses retrying connections for Atlas or local MongoDB and shuts the connection down gracefully on exit.

Run commands

```bash
# development
npm install
npm run dev

# seed only
npm run seed

# production (example)
docker build -t roadwatch-backend .
docker run -p 8000:8000 --env-file .env roadwatch-backend
```

Smoke tests:

```bash
curl http://127.0.0.1:8000/health
curl http://127.0.0.1:8000/get-road-data
curl http://127.0.0.1:8000/get-budget-data
```

If you want, I can add ESLint/Prettier, a PM2 ecosystem file, CI workflow, and secure the monitor UI behind JWT auth.
