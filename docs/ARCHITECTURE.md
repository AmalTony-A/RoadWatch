# Architecture

## Product architecture

RoadWatch AI has four major layers:

1. **Citizen Interface (Flutter)**
   - Map-based dashboard
   - Image capture/upload and detection output
   - Chatbot-first civic workflow
   - Complaint filing and tracking
   - Transparency and intelligence panels
   - Offline queue + later sync

2. **Governance API (FastAPI)**
   - Core REST API for roads, budget, complaints, risk
   - Bridges CV + scoring + complaint generation
   - Serves deterministic demo data for hackathon reliability

3. **AI/ML Services**
   - YOLOv8-compatible damage detection service
   - Road health scoring engine
   - Random Forest risk prediction engine
   - LLM-backed civic chatbot with fallback policy

4. **Data Layer**
   - Mock datasets (roads, budgets, complaints, risk features)
   - Designed to swap to MongoDB/Firebase and real civic feeds

## Request flow examples

### A) Detection + scoring

1. App uploads image (`/upload-image`)
2. App calls detection (`/detect-damage`)
3. Backend returns bounding boxes + severity + score
4. Selected road score is blended to update dashboard state

### B) Complaint generation

1. User taps file complaint (manual or auto from detection)
2. App captures GPS and timestamp
3. App sends payload to `/generate-complaint`
4. Backend creates structured complaint + simulated authority ticket

### C) Transparency query

1. App requests `/get-budget-data`
2. Backend compares expected score vs actual AI score
3. App highlights mismatch (allocation vs condition)

### D) Offline mode

1. If offline, detection/complaint intents are stored locally
2. On reconnect, app calls `/sync-offline`
3. Pending image detections are uploaded and processed in batch

## Security and production hardening checklist

- Add JWT auth for citizen + admin roles
- Add API rate limiting and abuse controls
- Move mock data to MongoDB/Firebase collections
- Secure secret handling via environment vault
- Add signed evidence storage (S3/GCS)
- Add observability (OpenTelemetry + logs + dashboards)
