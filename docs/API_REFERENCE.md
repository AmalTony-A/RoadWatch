# RoadWatch AI API Reference

Base URL: `http://localhost:8000`

## 1) Upload image

`POST /upload-image`

Form-data:

- `file`: image (`jpeg/png/webp`)
- optional query `road_id`

Response:

```json
{
  "image_id": "3ca6f2....jpg",
  "road_id": "road-001",
  "size_bytes": 184221,
  "stored_at": ".../uploads/3ca6f2....jpg"
}
```

## 2) Detect damage

`POST /detect-damage`

Body:

```json
{
  "image_id": "3ca6f2....jpg",
  "road_id": "road-001"
}
```

Response:

```json
{
  "image_id": "3ca6f2....jpg",
  "road_id": "road-001",
  "detections": [
    {
      "label": "pothole",
      "confidence": 0.92,
      "severity": "high",
      "bbox": [102, 188, 254, 318]
    }
  ],
  "model": "demo-mock-detector",
  "inference_ms": 510,
  "score": {
    "road_health_score": 85,
    "severity_breakdown": {"low": 0, "medium": 0, "high": 1},
    "color": "green"
  }
}
```

## 3) Calculate score

`POST /calculate-score`

Body:

```json
{
  "detections": [
    {"label": "pothole", "confidence": 0.9, "severity": "high", "bbox": [1, 2, 3, 4]},
    {"label": "crack", "confidence": 0.8, "severity": "medium", "bbox": [5, 6, 7, 8]}
  ]
}
```

Rule:

- `score = 100 - sum(severity_weight)`
- weights: `low=4`, `medium=9`, `high=15`

## 4) Generate complaint

`POST /generate-complaint`

Body:

```json
{
  "road_id": "road-001",
  "description": "Deep pothole near bus stop",
  "image_ref": "3ca6f2....jpg",
  "location": {"lat": 12.9946, "lng": 80.2371}
}
```

Response includes ID, timeline, and simulated authority submission ack.

## 5) Get road data

`GET /get-road-data`

- without query: overview, roads, complaints, intelligence snapshot
- with query `road_id`: single road + budget + complaints

## 6) Get budget data

`GET /get-budget-data`

- returns budget/contractor/repair/transparency info
- use `?road_id=road-001` for specific record

## 7) Predict risk

`POST /predict-risk`

Body:

```json
{
  "road_id": "road-001",
  "weather_index": 0.71,
  "traffic_index": 0.84,
  "complaint_count_30d": 9
}
```

Response:

```json
{
  "road_id": "road-001",
  "risk_level": "High",
  "probability_of_deterioration": 0.82,
  "predicted_days_to_decline": 19
}
```

## Extra endpoints

- `POST /chat` : civic assistant Q&A
- `GET /complaints` : list complaint timeline
- `POST /sync-offline` : batch sync offline-created complaints
- `GET /health` : uptime check
