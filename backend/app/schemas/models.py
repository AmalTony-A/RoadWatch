from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


Severity = Literal["low", "medium", "high"]
ComplaintStatus = Literal["Filed", "Sent", "Delivered", "Read", "In Progress", "Resolved"]
RiskLevel = Literal["Low", "Medium", "High"]


class Coordinate(BaseModel):
    lat: float
    lng: float


class DetectionBox(BaseModel):
    label: Literal["pothole", "crack"]
    confidence: float = Field(ge=0, le=1)
    severity: Severity
    bbox: list[float] = Field(
        description="[x_min, y_min, x_max, y_max] pixels", min_length=4, max_length=4
    )


class DetectionResult(BaseModel):
    image_id: str
    road_id: str | None = None
    detections: list[DetectionBox]
    model: str
    inference_ms: int


class DetectionRequest(BaseModel):
    image_id: str = Field(
        description="Uploaded filename or demo image id (e.g., demo_pothole_1.jpg)"
    )
    road_id: str | None = None


class ScoreRequest(BaseModel):
    detections: list[DetectionBox] = Field(default_factory=list)


class ScoreResponse(BaseModel):
    road_health_score: int
    severity_breakdown: dict[str, int]
    color: Literal["red", "yellow", "green"]


class RoadSegment(BaseModel):
    id: str
    name: str
    ward: str
    polyline: list[Coordinate]
    road_health_score: int
    color: Literal["red", "yellow", "green"]
    nearby_issues: int
    recent_complaints: int


class RoadNetworkItem(BaseModel):
    id: str
    name: str
    type: Literal["NH", "SH", "MDR"]
    route: str
    districts: list[str]
    length_km: int
    year: int
    contractor: str
    budget_crore: int
    condition: Literal["Good", "Moderate", "Poor"]
    issues: list[str]
    summary: str


class BudgetRecord(BaseModel):
    road_id: str
    project_id: str
    allocated_inr: int
    spent_inr: int
    contractor: str
    last_repair_date: str
    expected_score: int
    actual_score: int
    transparency_note: str


class ComplaintTimelineEvent(BaseModel):
    status: ComplaintStatus
    at: str
    note: str


class Complaint(BaseModel):
    id: str
    road_id: str
    description: str
    image_ref: str | None = None
    location: Coordinate
    timestamp: str
    status: ComplaintStatus
    authority_ticket: str
    recommended_department: str
    routing_reason: str
    complaint_letter: str
    sent_to_authority: bool = False
    delivered_to_authority: bool = False
    read_by_authority: bool = False
    sent_at: str | None = None
    delivered_at: str | None = None
    read_at: str | None = None
    timeline: list[ComplaintTimelineEvent]


class ComplaintCreateRequest(BaseModel):
    road_id: str
    description: str
    image_ref: str | None = None
    location: Coordinate


class RiskRequest(BaseModel):
    road_id: str
    weather_index: float = Field(ge=0, le=1, description="0 clear, 1 extreme rain")
    traffic_index: float = Field(ge=0, le=1, description="0 low, 1 heavy")
    complaint_count_30d: int = Field(ge=0)


class RiskResponse(BaseModel):
    road_id: str
    risk_level: RiskLevel
    probability_of_deterioration: float
    predicted_days_to_decline: int


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class ChatRequest(BaseModel):
    query: str
    road_id: str | None = None
    history: list[ChatMessage] = Field(default_factory=list)


class ChatResponse(BaseModel):
    answer: str
    cited_data: dict[str, str | int | float | None]


class HealthOverview(BaseModel):
    overall_score: int
    total_roads: int
    red_roads: int
    yellow_roads: int
    green_roads: int
    generated_at: datetime


class RoadDetailResponse(BaseModel):
    road: dict[str, object]
    budget: dict[str, object] | None
    complaints: list[dict[str, object]]
    nearby_network: list[dict[str, object]]


class ApiInfoResponse(BaseModel):
    version: str
    demo_mode: bool
    dataset_counts: dict[str, int]
    model_info: dict[str, str | None]
    uptime_seconds: float | None = None
