# RoadWatch
RoadWatch AI is a smart platform that monitors road infrastructure using AI and public data. It provides details like construction year, contractor, budget, and current condition, while enabling users to report issues such as potholes. The system improves transparency, accountability, and road safety.

# RoadWatch AI

RoadWatch AI is an AI-powered civic intelligence and transparency platform for road safety governance.
It combines computer vision, spending transparency, complaint automation, and a civic chatbot in one app.

## What this repo includes

- `frontend/` Flutter app source (mobile + web support) with map dashboard, AI capture flow, chatbot, transparency module, complaints timeline, intelligence panel, and offline queue.
- `backend/` FastAPI service with all required hackathon endpoints, YOLO-ready integration, risk prediction engine, complaint simulation, and demo data.
- `docs/` setup, architecture, API reference, model integration, and demo walkthrough.

## Full project structure

```text
roadwatch_ai/
├── README.md
├── docker-compose.yml
├── backend/
│   ├── .env.example
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── scripts/
│   │   └── smoke_test.py
│   ├── tests/
│   │   └── test_api_smoke.py
│   └── app/
│       ├── main.py
│       ├── core/
│       │   └── config.py
│       ├── db/
│       │   └── repository.py
│       ├── data/
│       │   ├── demo_detections.json
│       │   ├── mock_budget.json
│       │   ├── mock_complaints.json
│       │   ├── mock_risk_features.json
│       │   └── mock_roads.json
│       ├── routers/
│       │   └── api.py
│       ├── schemas/
│       │   └── models.py
│       └── services/
│           ├── chatbot.py
│           ├── complaint.py
│           ├── container.py
│           ├── detection.py
│           ├── prediction.py
│           └── scoring.py
├── frontend/
│   ├── pubspec.yaml
│   ├── analysis_options.yaml
│   ├── assets/
│   │   └── demo/
│   │       ├── README.md
│   │       ├── demo_manifest.json
│   │       ├── demo_crack_2.svg
│   │       ├── demo_good_road.svg
│   │       └── demo_pothole_1.svg
│   └── lib/
│       ├── main.dart
│       ├── config/
│       │   └── app_config.dart
│       ├── models/
│       │   ├── budget_record.dart
│       │   ├── chat.dart
│       │   ├── complaint.dart
│       │   ├── detection.dart
│       │   ├── risk_prediction.dart
│       │   └── road_segment.dart
│       ├── providers/
│       │   └── app_state.dart
│       ├── screens/
│       │   ├── capture_screen.dart
│       │   ├── chatbot_screen.dart
│       │   ├── complaints_screen.dart
│       │   ├── home_screen.dart
│       │   ├── intelligence_screen.dart
│       │   ├── shell_screen.dart
│       │   └── transparency_screen.dart
│       ├── services/
│       │   ├── api_service.dart
│       │   ├── connectivity_service.dart
│       │   ├── demo_data_service.dart
│       │   ├── local_storage_service.dart
│       │   └── location_service.dart
│       └── widgets/
│           ├── complaint_timeline.dart
│           ├── risk_badge.dart
│           ├── road_health_legend.dart
│           ├── road_score_gauge.dart
│           └── trend_chart.dart
└── docs/
    ├── API_REFERENCE.md
    ├── ARCHITECTURE.md
    ├── DEMO_WALKTHROUGH.md
    ├── IMPLEMENTATION_PLAN_2_TO_4_WEEKS.md
    ├── MODEL_INTEGRATION.md
    └── SETUP.md
```

## Required endpoints implemented

- `POST /upload-image`
- `POST /detect-damage`
- `POST /calculate-score`
- `POST /generate-complaint`
- `GET /get-road-data`
- `GET /get-budget-data`
- `POST /predict-risk`

Additional helper endpoints:

- `POST /chat`
- `GET /complaints`
- `POST /sync-offline`
- `GET /health`

## Quick start

See detailed steps in `docs/SETUP.md`.

Backend + Mongo with Docker:

```bash
docker compose up --build
```

Backend tests:

```bash
cd backend
pytest -q
```

## Demo-first behavior

- If backend services are unavailable, the frontend uses deterministic demo payloads so the app still demos cleanly.
- If YOLO weights are not present, backend falls back to mock/synthetic detections.
- Chatbot works with fallback rule-based civic assistant even without API keys.

## Notes

- For Flutter platform folders (`android/`, `ios/`, `web/`, etc.), run `flutter create .` inside `frontend/` once Flutter is installed, then keep this `lib/` and `pubspec.yaml`.
- For production deployment and API key wiring, follow `docs/MODEL_INTEGRATION.md`.
