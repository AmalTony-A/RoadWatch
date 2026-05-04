from __future__ import annotations

import logging
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, WebSocket, WebSocketDisconnect

from app.db.repository import DataRepository
from app.schemas.models import (
    ChatRequest,
    ChatResponse,
    ComplaintCreateRequest,
    DetectionRequest,
    RiskRequest,
    ScoreRequest,
)
from app.services.complaint import ComplaintService
from app.services.container import (
    get_chatbot_service,
    get_complaint_service,
    get_detection_service,
    get_prediction_service,
    get_repository,
)
from app.services.detection import DamageDetectionService
from app.services.prediction import RiskPredictionService
from app.services.scoring import calculate_road_health_score

router = APIRouter(tags=["RoadWatch AI"])
logger = logging.getLogger(__name__)


class RealtimeUpdateHub:
    def __init__(self):
        self._connections: set[WebSocket] = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self._connections.add(websocket)

    def disconnect(self, websocket: WebSocket):
        self._connections.discard(websocket)

    async def broadcast(self, message: dict[str, str]):
        if not self._connections:
            return
        payload = message
        for websocket in list(self._connections):
            try:
                await websocket.send_json(payload)
            except Exception:
                self.disconnect(websocket)


realtime_hub = RealtimeUpdateHub()

UPLOADS_DIR = Path(__file__).resolve().parent.parent / "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)


@router.get("/health")
def health_check():
    return {"ok": True, "service": "roadwatch-ai-api", "time": datetime.now(UTC).isoformat()}


def _safe_error_message(error: Exception) -> str:
    message = f"{type(error).__name__}: {error}"
    return message[:200]


async def _publish_realtime_update(event: str, road_id: str | None = None):
    await realtime_hub.broadcast(
        {
            "type": "update",
            "event": event,
            "road_id": road_id or "",
            "timestamp": datetime.now(UTC).isoformat(),
        }
    )


async def _publish_realtime_payload(event: str, payload: dict[str, object]):
    message = {
        "type": "update",
        "event": event,
        "timestamp": datetime.now(UTC).isoformat(),
        **payload,
    }
    await realtime_hub.broadcast(message)


@router.websocket("/ws/updates")
async def websocket_updates(websocket: WebSocket):
    await realtime_hub.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        realtime_hub.disconnect(websocket)
    except Exception:
        realtime_hub.disconnect(websocket)


@router.post("/upload-image")
async def upload_image(file: UploadFile = File(...), road_id: str | None = None):
    if file.content_type not in {
        "image/jpeg",
        "image/png",
        "image/jpg",
        "image/webp",
        "image/svg+xml",
        "application/octet-stream",
    }:
        raise HTTPException(
            status_code=400,
            detail="Only JPEG, PNG, WEBP, or SVG images are supported",
        )

    extension = Path(file.filename or "upload.jpg").suffix or ".jpg"
    image_id = f"{uuid4().hex}{extension}"
    path = UPLOADS_DIR / image_id
    content = await file.read()
    path.write_bytes(content)

    return {
        "image_id": image_id,
        "road_id": road_id,
        "size_bytes": len(content),
        "stored_at": path.as_posix(),
    }


@router.post("/detect-damage")
async def detect_damage(
    payload: DetectionRequest,
    detector: Annotated[DamageDetectionService, Depends(get_detection_service)],
    repository: Annotated[DataRepository, Depends(get_repository)],
):
    uploaded_path = UPLOADS_DIR / payload.image_id
    image_path = uploaded_path.as_posix() if uploaded_path.exists() else payload.image_id

    result = detector.detect(image_path=image_path, image_id=payload.image_id, road_id=payload.road_id)
    score = calculate_road_health_score(result["detections"])
    result["score"] = score.model_dump()

    if payload.road_id:
        repository.update_road_score(payload.road_id, score.road_health_score)

    road = repository.get_road(payload.road_id) if payload.road_id else None
    await _publish_realtime_payload(
        "detect-damage",
        {
            "road_id": payload.road_id or "",
            "road": road or {},
            "score": score.model_dump(),
        },
    )

    return result


@router.post("/calculate-score")
def calculate_score(payload: ScoreRequest):
    return calculate_road_health_score(payload.detections)


@router.post("/generate-complaint")
async def generate_complaint(
    payload: ComplaintCreateRequest,
    complaints: Annotated[ComplaintService, Depends(get_complaint_service)],
    repository: Annotated[DataRepository, Depends(get_repository)],
):
    preview_id = f"preview-{uuid4().hex}"
    preview_payload = {
        "id": preview_id,
        "road_id": payload.road_id,
        "description": payload.description,
        "image_ref": payload.image_ref,
        "location": payload.location.model_dump(),
        "timestamp": datetime.now(UTC).isoformat(),
        "status": "Submitting",
        "authority_ticket": "PENDING",
        "timeline": [
            {
                "status": "Submitting",
                "at": datetime.now(UTC).isoformat(),
                "note": "Complaint preview broadcast from RoadWatch AI",
            }
        ],
    }

    await _publish_realtime_payload(
        "generate-complaint-preview",
        {
            "preview_id": preview_id,
            "complaint": preview_payload,
        },
    )

    complaint = complaints.generate(
        road_id=payload.road_id,
        description=payload.description,
        image_ref=payload.image_ref,
        location=payload.location.model_dump(),
    )
    road = repository.get_road(payload.road_id)
    await _publish_realtime_payload(
        "generate-complaint",
        {
            "preview_id": preview_id,
            "road_id": payload.road_id,
            "complaint": complaint,
            "road": road or {},
        },
    )
    return complaint


@router.get("/get-road-data")
def get_road_data(
    repository: Annotated[DataRepository, Depends(get_repository)],
    road_id: str | None = None,
):
    if road_id:
        road = repository.get_road(road_id)
        if not road:
            raise HTTPException(status_code=404, detail="Road not found")
        return {
            "road": road,
            "budget": repository.get_budget_by_road(road_id),
            "complaints": [c for c in repository.get_complaints() if c["road_id"] == road_id],
        }

    return {
        "overview": repository.get_health_overview(),
        "roads": repository.get_roads(),
        "recent_complaints": repository.get_complaints()[:8],
        "intelligence": repository.get_intelligence_snapshot(),
    }


@router.get("/get-budget-data")
def get_budget_data(
    repository: Annotated[DataRepository, Depends(get_repository)],
    road_id: str | None = None,
):
    if road_id:
        record = repository.get_budget_by_road(road_id)
        if not record:
            raise HTTPException(status_code=404, detail="Budget record not found")
        return record
    return repository.get_budgets()


@router.get("/get-road-network-data")
def get_road_network_data(
    repository: Annotated[DataRepository, Depends(get_repository)],
):
    return repository.get_road_network()


@router.get("/get-road-network-data/{item_id}")
def get_road_network_item(
    item_id: str,
    repository: Annotated[DataRepository, Depends(get_repository)],
):
    item = repository.get_road_network_item(item_id)
    if not item:
        raise HTTPException(status_code=404, detail=f"Road network item not found: {item_id}")
    return item


@router.post("/predict-risk")
def predict_risk(
    payload: RiskRequest,
    predictor: Annotated[RiskPredictionService, Depends(get_prediction_service)],
):
    return predictor.predict(
        road_id=payload.road_id,
        weather_index=payload.weather_index,
        traffic_index=payload.traffic_index,
        complaint_count_30d=payload.complaint_count_30d,
    )


@router.post("/chat", response_model=ChatResponse)
def chat(
    payload: ChatRequest,
):
    try:
        chatbot = get_chatbot_service()
        answer = chatbot.ask(
            query=payload.query,
            road_id=payload.road_id,
            history=[item.model_dump() for item in payload.history],
        )
        return ChatResponse(**answer)
    except Exception as exc:
        logger.exception("Chat endpoint failed.")
        return ChatResponse(
            answer="Assistant is unavailable right now. Please try again.",
            cited_data={"llm_error": _safe_error_message(exc)},
        )


@router.get("/complaints")
def list_complaints(
    repository: Annotated[DataRepository, Depends(get_repository)],
    road_id: str | None = None,
):
    items = repository.get_complaints()
    if road_id:
        items = [row for row in items if row["road_id"] == road_id]
    return items


@router.post("/complaints/{complaint_id}/send")
def send_complaint(
    complaint_id: str,
    complaints: Annotated[ComplaintService, Depends(get_complaint_service)],
):
    complaint = complaints.send_to_authority(complaint_id)
    if not complaint:
        raise HTTPException(status_code=404, detail=f"Complaint not found: {complaint_id}")
    return complaint


@router.post("/complaints/{complaint_id}/read")
def mark_complaint_read(
    complaint_id: str,
    complaints: Annotated[ComplaintService, Depends(get_complaint_service)],
):
    complaint = complaints.mark_read(complaint_id)
    if not complaint:
        raise HTTPException(status_code=404, detail=f"Complaint not found: {complaint_id}")
    return complaint


@router.post("/sync-offline")
async def sync_offline(
    payload: list[ComplaintCreateRequest],
    complaints: Annotated[ComplaintService, Depends(get_complaint_service)],
    repository: Annotated[DataRepository, Depends(get_repository)],
):
    synced = []
    for item in payload:
        synced.append(
            complaints.generate(
                road_id=item.road_id,
                description=item.description,
                image_ref=item.image_ref,
                location=item.location.model_dump(),
            )
        )
    await _publish_realtime_payload(
        "sync-offline",
        {
            "items": synced,
            "roads": repository.get_roads(),
        },
    )
    return {"synced": len(synced), "items": synced}
