from __future__ import annotations

import json
import random
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from app.core.config import Settings
from app.schemas.models import Complaint, ComplaintTimelineEvent

try:
    from pymongo import MongoClient
except Exception:  # pragma: no cover
    MongoClient = None


class DataRepository:
    def __init__(self, settings: Settings):
        self.settings = settings
        self._mongo_client = None
        self._mongo_db = None
        self._roads_collection = None
        self._budgets_collection = None
        self._road_network_collection = None
        self._complaints_collection = None

        data_root = Path(__file__).resolve().parent.parent / "data"
        self._roads: list[dict[str, Any]] = self._load_json(data_root / "mock_roads.json")
        self._budgets: list[dict[str, Any]] = self._load_json(data_root / "mock_budget.json")
        self._road_network: list[dict[str, Any]] = self._load_json(data_root / "road_network_data.json")
        self._complaints: list[dict[str, Any]] = self._load_json(data_root / "mock_complaints.json")
        self._risk_features: list[dict[str, Any]] = self._load_json(
            data_root / "mock_risk_features.json"
        )
        self._demo_detections: dict[str, Any] = self._load_json(
            data_root / "demo_detections.json"
        )
        self._init_mongo()

    @staticmethod
    def _load_json(path: Path):
        with path.open("r", encoding="utf-8") as file:
            return json.load(file)

    def _init_mongo(self):
        if not self.settings.mongo_uri or MongoClient is None:
            return
        try:
            client = MongoClient(self.settings.mongo_uri, serverSelectionTimeoutMS=2000)
            client.admin.command("ping")
            db = client[self.settings.mongo_db]
            roads = db["roads"]
            budgets = db["budgets"]
            road_network = db["road_network"]
            complaints = db["complaints"]

            if roads.count_documents({}) == 0 and self._roads:
                roads.insert_many(self._roads)
            if budgets.count_documents({}) == 0 and self._budgets:
                budgets.insert_many(self._budgets)
            if road_network.count_documents({}) == 0 and self._road_network:
                road_network.insert_many(self._road_network)
            if complaints.count_documents({}) == 0 and self._complaints:
                complaints.insert_many(self._complaints)

            self._mongo_client = client
            self._mongo_db = db
            self._roads_collection = roads
            self._budgets_collection = budgets
            self._road_network_collection = road_network
            self._complaints_collection = complaints
        except Exception:
            self._mongo_client = None
            self._mongo_db = None
            self._roads_collection = None
            self._budgets_collection = None
            self._road_network_collection = None
            self._complaints_collection = None

    @staticmethod
    def _strip_mongo_id(payload: dict[str, Any]) -> dict[str, Any]:
        if "_id" not in payload:
            return payload
        clone = dict(payload)
        clone.pop("_id", None)
        return clone

    def get_roads(self) -> list[dict[str, Any]]:
        if self._roads_collection is not None:
            return [self._strip_mongo_id(doc) for doc in self._roads_collection.find().sort("id", 1)]
        return self._roads

    def get_road(self, road_id: str) -> dict[str, Any] | None:
        if self._roads_collection is not None:
            item = self._roads_collection.find_one({"id": road_id})
            return self._strip_mongo_id(item) if item else None
        return next((r for r in self._roads if r["id"] == road_id), None)

    def update_road_score(self, road_id: str, score: int):
        road = self.get_road(road_id)
        if not road:
            return
        blended = int((road["road_health_score"] * 0.65) + (score * 0.35))
        if blended < 50:
            color = "red"
        elif blended < 75:
            color = "yellow"
        else:
            color = "green"

        if self._roads_collection is not None:
            self._roads_collection.update_one(
                {"id": road_id},
                {"$set": {"road_health_score": blended, "color": color}},
            )
            return

        road["road_health_score"] = blended
        road["color"] = color

    def get_budgets(self) -> list[dict[str, Any]]:
        budgets = []
        score_lookup = {road["id"]: road["road_health_score"] for road in self.get_roads()}
        source = self._budgets_collection.find() if self._budgets_collection is not None else self._budgets
        for item in source:
            item = self._strip_mongo_id(item)
            actual_score = score_lookup.get(item["road_id"], 0)
            gap = item["expected_score"] - actual_score
            if gap > 25:
                note = (
                    f"Transparency alert: INR {item['allocated_inr']:,} allocated but score is "
                    f"{actual_score}/100"
                )
            elif gap > 10:
                note = "Moderate mismatch between expected and AI-observed condition"
            else:
                note = "Budget utilization appears aligned with current condition"

            budgets.append(
                {
                    **item,
                    "actual_score": actual_score,
                    "transparency_note": note,
                }
            )
        return budgets

    def get_budget_by_road(self, road_id: str) -> dict[str, Any] | None:
        return next((item for item in self.get_budgets() if item["road_id"] == road_id), None)

    def get_road_network(self) -> list[dict[str, Any]]:
        order = {"NH": 0, "SH": 1, "MDR": 2}
        if self._road_network_collection is not None:
            docs = [self._strip_mongo_id(doc) for doc in self._road_network_collection.find()]
        else:
            docs = self._road_network
        return sorted(docs, key=lambda row: (order.get(row.get("type", "MDR"), 99), row.get("name", "")))

    def get_road_network_item(self, item_id: str) -> dict[str, Any] | None:
        if self._road_network_collection is not None:
            item = self._road_network_collection.find_one({"id": item_id})
            return self._strip_mongo_id(item) if item else None
        return next((item for item in self._road_network if item["id"] == item_id), None)

    def get_complaints(self) -> list[dict[str, Any]]:
        if self._complaints_collection is not None:
            docs = list(self._complaints_collection.find().sort("timestamp", -1))
            return [self._strip_mongo_id(doc) for doc in docs]
        return sorted(self._complaints, key=lambda x: x["timestamp"], reverse=True)

    def get_complaint(self, complaint_id: str) -> dict[str, Any] | None:
        if self._complaints_collection is not None:
            item = self._complaints_collection.find_one({"id": complaint_id})
            return self._strip_mongo_id(item) if item else None
        return next((c for c in self._complaints if c["id"] == complaint_id), None)

    def add_complaint(
        self,
        road_id: str,
        description: str,
        image_ref: str | None,
        location: dict[str, float],
        recommended_department: str,
        routing_reason: str,
        complaint_letter: str,
    ) -> dict[str, Any]:
        now = datetime.now(UTC)
        suffix = len(self._complaints) + 1
        complaint_id = f"cmp-2026-{suffix:04d}"
        authority_ticket = f"CCMC-{random.randint(12000, 12999)}"

        complaint = Complaint(
            id=complaint_id,
            road_id=road_id,
            description=description,
            image_ref=image_ref,
            location=location,
            timestamp=now.isoformat(),
            status="Filed",
            authority_ticket=authority_ticket,
            recommended_department=recommended_department,
            routing_reason=routing_reason,
            complaint_letter=complaint_letter,
            sent_to_authority=False,
            delivered_to_authority=False,
            read_by_authority=False,
            timeline=[
                ComplaintTimelineEvent(
                    status="Filed",
                    at=now.isoformat(),
                    note="Complaint auto-filed from RoadWatch AI",
                )
            ],
        )

        payload = complaint.model_dump()
        self._complaints.append(payload)
        if self._complaints_collection is not None:
            self._complaints_collection.insert_one(payload)
        road = self.get_road(road_id)
        if road:
            road["recent_complaints"] += 1
        return payload

    def _update_complaint_record(self, complaint_id: str, updates: dict[str, Any]) -> dict[str, Any] | None:
        complaint = self.get_complaint(complaint_id)
        if not complaint:
            return None

        complaint.update(updates)
        if self._complaints_collection is not None:
            self._complaints_collection.update_one({"id": complaint_id}, {"$set": updates})
        else:
            index = next((i for i, item in enumerate(self._complaints) if item["id"] == complaint_id), -1)
            if index >= 0:
                self._complaints[index] = complaint
        return complaint

    def send_complaint_to_authority(self, complaint_id: str) -> dict[str, Any] | None:
        complaint = self.get_complaint(complaint_id)
        if not complaint:
            return None

        now = datetime.now(UTC).isoformat()
        timeline = list(complaint.get("timeline", []))
        if not complaint.get("sent_to_authority"):
            timeline.append(
                ComplaintTimelineEvent(
                    status="Sent",
                    at=now,
                    note=f"Complaint sent to {complaint.get('recommended_department', 'authority')}",
                ).model_dump()
            )
            timeline.append(
                ComplaintTimelineEvent(
                    status="Delivered",
                    at=now,
                    note="Complaint letter delivered to the department inbox",
                ).model_dump()
            )

        return self._update_complaint_record(
            complaint_id,
            {
                "sent_to_authority": True,
                "delivered_to_authority": True,
                "status": "Sent",
                "sent_at": complaint.get("sent_at") or now,
                "delivered_at": complaint.get("delivered_at") or now,
                "timeline": timeline,
            },
        )

    def mark_complaint_read(self, complaint_id: str) -> dict[str, Any] | None:
        complaint = self.get_complaint(complaint_id)
        if not complaint:
            return None

        now = datetime.now(UTC).isoformat()
        timeline = list(complaint.get("timeline", []))
        if not complaint.get("read_by_authority"):
            timeline.append(
                ComplaintTimelineEvent(
                    status="Read",
                    at=now,
                    note=f"Authority opened the complaint letter for {complaint.get('recommended_department', 'review')}",
                ).model_dump()
            )

        return self._update_complaint_record(
            complaint_id,
            {
                "read_by_authority": True,
                "status": "Read",
                "read_at": complaint.get("read_at") or now,
                "timeline": timeline,
            },
        )

    def get_demo_detections(self, image_name: str) -> list[dict[str, Any]] | None:
        return self._demo_detections.get(image_name)

    def get_risk_training_data(self) -> list[dict[str, Any]]:
        return self._risk_features

    def get_health_overview(self) -> dict[str, Any]:
        scores = [item["road_health_score"] for item in self.get_roads()]
        total = len(scores)
        red = len([s for s in scores if s < 50])
        yellow = len([s for s in scores if 50 <= s < 75])
        green = len([s for s in scores if s >= 75])
        return {
            "overall_score": int(sum(scores) / max(total, 1)),
            "total_roads": total,
            "red_roads": red,
            "yellow_roads": yellow,
            "green_roads": green,
            "generated_at": datetime.now(UTC),
        }

    def get_intelligence_snapshot(self) -> dict[str, Any]:
        monthly_damage_trend = [
            {"month": "Jan", "issues": 42},
            {"month": "Feb", "issues": 57},
            {"month": "Mar", "issues": 61},
            {"month": "Apr", "issues": 74},
            {"month": "May", "issues": 69},
        ]
        budget_vs_condition = [
            {
                "road_id": row["road_id"],
                "allocated_inr": row["allocated_inr"],
                "score": row["actual_score"],
            }
            for row in self.get_budgets()
        ]
        repair_frequency = [
            {"road_id": "road-001", "repairs_last_12m": 2},
            {"road_id": "road-002", "repairs_last_12m": 1},
            {"road_id": "road-003", "repairs_last_12m": 2},
            {"road_id": "road-004", "repairs_last_12m": 3},
            {"road_id": "road-005", "repairs_last_12m": 1},
            {"road_id": "road-006", "repairs_last_12m": 1},
        ]

        prediction_text = (
            "Sardar Patel Road may deteriorate further in 19 days if monsoon traffic "
            "remains high."
        )

        return {
            "damage_trends": monthly_damage_trend,
            "budget_vs_condition": budget_vs_condition,
            "repair_frequency": repair_frequency,
            "prediction_text": prediction_text,
        }
