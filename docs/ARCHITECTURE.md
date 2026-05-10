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

## Frontend incremental refactor plan (overview)

Goal: make the Flutter frontend easier to read, modify, and extend without changing runtime behavior.

High-level approach:
- Non-destructive, incremental refactors only — add new modules and providers, keep old code paths until replacement is fully tested.
- Start by documenting and extracting map-related logic and UI into a `features/map` area, then move other screens into `features/<feature>`.
- Split `AppState` into focused providers (e.g. `MapProvider`, `NetworkProvider`, `ComplaintProvider`) and use `Provider`/`Consumer` to reduce rebuild scope.
- Move heavy JSON parsing to background isolates (`compute`) and add caching layers for large datasets.

Minimal safe first steps:
1. Add `docs/FRONTEND_REFACTOR_PLAN.md` and `docs/CONTRIBUTING.md` to capture structure and conventions.
2. Introduce a `features/map` folder and a `MapProvider` wrapper that mirrors current behavior; wire it in alongside existing `AppState` without removing anything.
3. Replace map caching logic in place with the new provider, then flip usage when tests pass.
4. Continue iteratively for `road_network_browser`, `complaints`, and `transparency` screens.

Testing and validation:
- Run `flutter analyze` and `flutter test` after each incremental change.
- Manually verify Live Location behaviors (auto/manual) and map rendering performance on a representative dataset.

This plan reduces risk and keeps the app runnable throughout the refactor.
