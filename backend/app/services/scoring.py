from app.schemas.models import DetectionBox, ScoreResponse


SEVERITY_WEIGHTS = {
    "low": 4,
    "medium": 9,
    "high": 15,
}


def score_to_color(score: int) -> str:
    if score < 50:
        return "red"
    if score < 75:
        return "yellow"
    return "green"


def calculate_road_health_score(detections: list[DetectionBox] | list[dict]) -> ScoreResponse:
    severity_breakdown = {"low": 0, "medium": 0, "high": 0}
    total_penalty = 0

    for item in detections:
        severity = item.severity if isinstance(item, DetectionBox) else item["severity"]
        weight = SEVERITY_WEIGHTS[severity]
        total_penalty += weight
        severity_breakdown[severity] += 1

    score = max(0, min(100, 100 - total_penalty))
    color = score_to_color(score)
    return ScoreResponse(
        road_health_score=score,
        severity_breakdown=severity_breakdown,
        color=color,
    )
