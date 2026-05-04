# Backend (FastAPI)

## Run locally

```bash
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

## Run tests

```bash
pytest -q
```

## Core endpoints

- `POST /upload-image`
- `POST /detect-damage`
- `POST /calculate-score`
- `POST /generate-complaint`
- `GET /get-road-data`
- `GET /get-budget-data`
- `POST /predict-risk`

## Demo behavior

- deterministic detection for demo image ids
- mock governance datasets
- rule-based chatbot fallback

## Optional MongoDB

Set `MONGO_URI` in `.env` to persist complaint records in MongoDB.
