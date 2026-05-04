# AI Model Integration Steps

## 1) Computer vision (YOLOv8)

Current state:

- Backend service `backend/app/services/detection.py` is YOLOv8-ready.
- In demo mode, deterministic results are returned for predefined image ids.
- If custom model is unavailable, synthetic fallback ensures stable UX.

To wire real model:

1. Train/fine-tune a pothole-crack model using Ultralytics YOLOv8.
2. Export weights (`best.pt`) and place in backend model path.
3. Set `.env`:

```env
YOLO_MODEL_PATH=./models/best.pt
DEMO_MODE=false
```

4. Restart backend.

Expected output from `/detect-damage`:

- bounding boxes
- class labels (`pothole`, `crack`)
- confidence and severity

## 2) Road health scoring

Implemented in `backend/app/services/scoring.py`.

- Formula: `Score = 100 - sum(severity_weight)`
- Weights: `low=4`, `medium=9`, `high=15`
- Color bands: red (`<50`), yellow (`50-74`), green (`>=75`)

## 3) Prediction engine

Implemented in `backend/app/services/prediction.py`.

- Uses Random Forest if scikit-learn is available
- Training data comes from `mock_risk_features.json`
- Inputs: complaints, weather index, traffic index
- Outputs: risk level + probability + days-to-decline

To upgrade:

- Replace mock features with real historical data
- Retrain weekly and persist model artifact
- Add confidence interval + drift metrics

## 4) Civic chatbot (LLM)

Implemented in `backend/app/services/chatbot.py`.

- Prompt strategy instead of fine-tuning
- System instruction tone: concise, transparent, actionable
- Context injection: road score, budget, contractor, complaints
- Fallback: rule-based civic assistant when API key missing

To enable OpenAI:

```env
OPENAI_API_KEY=your_key
OPENAI_MODEL=gpt-4o-mini
```

Then restart backend and call `/chat`.
