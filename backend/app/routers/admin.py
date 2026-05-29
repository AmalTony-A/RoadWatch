"""Admin monitoring endpoints for backend activity tracking."""

import time
from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends

from app.db.repository import DataRepository
from app.schemas.models import Complaint
from app.services.container import get_repository

router = APIRouter(prefix="/admin", tags=["Admin Monitoring"])

# Global activity tracking
_activity_log = []
_max_activities = 1000


def log_activity(activity_type: str, description: str, details: dict = None):
    """Log an activity to the activity log."""
    global _activity_log
    
    activity = {
        "timestamp": datetime.now(UTC).isoformat(),
        "type": activity_type,
        "description": description,
        "details": details or {},
    }
    
    _activity_log.insert(0, activity)  # Insert at beginning for reverse chronological order
    
    # Keep only last 1000 activities
    if len(_activity_log) > _max_activities:
        _activity_log = _activity_log[:_max_activities]


@router.get("/dashboard-stats")
def get_dashboard_stats(repository: Annotated[DataRepository, Depends(get_repository)]):
    """Get overall dashboard statistics."""
    complaints = repository.get_complaints()
    
    # Calculate statistics
    total_complaints = len(complaints)
    filed = len([c for c in complaints if c.get("status") in ["Filed", "In Progress"]])
    sent = len([c for c in complaints if c.get("sentToAuthority")])
    delivered = len([c for c in complaints if c.get("deliveredToAuthority")])
    read = len([c for c in complaints if c.get("readByAuthority")])
    
    roads = repository.get_roads()
    budgets = repository.get_budgets()
    road_network = repository.get_road_network()
    
    return {
        "timestamp": datetime.now(UTC).isoformat(),
        "complaints": {
            "total": total_complaints,
            "filed": filed,
            "sent": sent,
            "delivered": delivered,
            "read": read,
        },
        "data_counts": {
            "roads": len(roads),
            "budgets": len(budgets),
            "road_network_items": len(road_network),
            "complaints": total_complaints,
        },
        "activity_log_count": len(_activity_log),
    }


@router.get("/activity-log")
def get_activity_log(skip: int = 0, limit: int = 50):
    """Get recent activity log entries."""
    return {
        "total": len(_activity_log),
        "skip": skip,
        "limit": limit,
        "activities": _activity_log[skip : skip + limit],
    }


@router.get("/activity-stats")
def get_activity_stats():
    """Get statistics about activities by type."""
    if not _activity_log:
        return {"total": 0, "by_type": {}}
    
    stats = {}
    for activity in _activity_log:
        activity_type = activity["type"]
        stats[activity_type] = stats.get(activity_type, 0) + 1
    
    return {
        "total": len(_activity_log),
        "by_type": stats,
        "recent_activity_types": [a["type"] for a in _activity_log[:10]],
    }


@router.get("/complaints-breakdown")
def get_complaints_breakdown(repository: Annotated[DataRepository, Depends(get_repository)]):
    """Get detailed complaints breakdown."""
    complaints = repository.get_complaints()
    
    breakdown = {
        "total": len(complaints),
        "by_status": {},
        "by_sent_status": {"sent": 0, "not_sent": 0},
        "by_delivery": {"delivered": 0, "not_delivered": 0},
        "by_read": {"read": 0, "not_read": 0},
        "recent_complaints": complaints[:10] if complaints else [],
    }
    
    for complaint in complaints:
        status = complaint.get("status", "Unknown")
        breakdown["by_status"][status] = breakdown["by_status"].get(status, 0) + 1
        
        if complaint.get("sentToAuthority"):
            breakdown["by_sent_status"]["sent"] += 1
        else:
            breakdown["by_sent_status"]["not_sent"] += 1
        
        if complaint.get("deliveredToAuthority"):
            breakdown["by_delivery"]["delivered"] += 1
        else:
            breakdown["by_delivery"]["not_delivered"] += 1
        
        if complaint.get("readByAuthority"):
            breakdown["by_read"]["read"] += 1
        else:
            breakdown["by_read"]["not_read"] += 1
    
    return breakdown


@router.get("/system-info")
def get_system_info(repository: Annotated[DataRepository, Depends(get_repository)]):
    """Get system information."""
    return {
        "timestamp": datetime.now(UTC).isoformat(),
        "demo_mode": repository.settings.demo_mode,
        "database_connected": repository._mongo_db is not None,
        "database_type": "MongoDB" if repository._mongo_db else "JSON files",
        "data_sources": {
            "roads": "MongoDB" if repository._roads_collection else "JSON",
            "budgets": "MongoDB" if repository._budgets_collection else "JSON",
            "road_network": "MongoDB" if repository._road_network_collection else "JSON",
            "complaints": "MongoDB" if repository._complaints_collection else "JSON",
        },
    }


@router.get("/road-network-stats")
def get_road_network_stats(repository: Annotated[DataRepository, Depends(get_repository)]):
    """Get road network statistics."""
    road_network = repository.get_road_network()
    
    if not road_network:
        return {
            "total_roads": 0,
            "total_budget_crore": 0,
            "districts": [],
            "average_length_km": 0,
        }
    
    districts = set()
    total_budget = 0
    total_length = 0
    
    for road in road_network:
        for district in road.get("districts", []):
            districts.add(district)
        total_budget += road.get("budget_crore", 0)
        total_length += road.get("length_km", 0)
    
    return {
        "total_roads": len(road_network),
        "districts": sorted(list(districts)),
        "total_budget_crore": total_budget,
        "average_length_km": total_length / len(road_network) if road_network else 0,
        "total_length_km": total_length,
        "average_budget_per_road_crore": total_budget / len(road_network) if road_network else 0,
    }


@router.post("/clear-activity-log")
def clear_activity_log():
    """Clear the activity log (admin only)."""
    global _activity_log
    _activity_log = []
    return {"status": "cleared", "timestamp": datetime.now(UTC).isoformat()}


# Chat log management endpoints
from pathlib import Path
import json


def _chat_log_path() -> Path:
    return Path(__file__).resolve().parents[2] / "logs" / "chat_history.jsonl"


def _read_chat_logs() -> list[dict]:
    path = _chat_log_path()
    if not path.exists():
        return []
    entries = []
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                entries.append(json.loads(line))
            except Exception:
                # skip malformed lines
                continue
    return entries


def _write_chat_logs(entries: list[dict]):
    path = _chat_log_path()
    with path.open("w", encoding="utf-8") as fh:
        for e in entries:
            fh.write(json.dumps(e, ensure_ascii=False) + "\n")


@router.get("/chat-logs")
def list_chat_logs(skip: int = 0, limit: int = 100):
    logs = _read_chat_logs()
    total = len(logs)
    slice_ = logs[skip : skip + limit]
    return {"total": total, "skip": skip, "limit": limit, "items": slice_}


@router.get("/chat-logs/{index}")
def get_chat_log(index: int):
    logs = _read_chat_logs()
    if index < 0 or index >= len(logs):
        return {"error": "not found"}
    return logs[index]


@router.post("/chat-logs/{index}/redact")
def redact_chat_log(index: int, payload: dict):
    """Redact fields in a chat log entry. Payload: {"fields": ["history","origin"]} """
    fields = payload.get("fields") if isinstance(payload, dict) else None
    if not fields:
        fields = ["history", "origin"]
    logs = _read_chat_logs()
    if index < 0 or index >= len(logs):
        return {"error": "not found"}
    entry = logs[index]
    for f in fields:
        if f in entry:
            entry[f] = "<redacted>"
    # also redact nested response history
    if "response" in entry and isinstance(entry["response"], dict):
        resp = entry["response"]
        for f in fields:
            if f in resp:
                resp[f] = "<redacted>"
    logs[index] = entry
    _write_chat_logs(logs)
    return {"status": "redacted", "index": index}


@router.delete("/chat-logs/{index}")
def delete_chat_log(index: int):
    logs = _read_chat_logs()
    if index < 0 or index >= len(logs):
        return {"error": "not found"}
    entry = logs.pop(index)
    _write_chat_logs(logs)
    return {"status": "deleted", "index": index, "entry": entry}
