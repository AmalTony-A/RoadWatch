from __future__ import annotations

import re

from app.db.repository import DataRepository


class ComplaintService:
    def __init__(self, repository: DataRepository):
        self.repository = repository

    def generate(self, road_id: str, description: str, image_ref: str | None, location: dict):
        recommendation = self._route_department(road_id=road_id, description=description)
        complaint = self.repository.add_complaint(
            road_id=road_id,
            description=description,
            image_ref=image_ref,
            location=location,
            recommended_department=recommendation["department"],
            routing_reason=recommendation["reason"],
            complaint_letter=recommendation["letter"],
        )
        return {
            **complaint,
            "routing": recommendation,
            "submission": {
                "authority": recommendation["department"],
                "submitted_at": None,
                "channel": "USER_REVIEW_PENDING",
                "acknowledged": False,
            },
        }

    def send_to_authority(self, complaint_id: str):
        return self.repository.send_complaint_to_authority(complaint_id)

    def mark_read(self, complaint_id: str):
        return self.repository.mark_complaint_read(complaint_id)

    def _route_department(self, road_id: str, description: str) -> dict[str, str]:
        road = self.repository.get_road(road_id) or {}
        road_name = str(road.get("name", "")).lower()
        ward = str(road.get("ward", "")).lower()
        text = f"{road_name} {ward} {description.lower()}"

        keyword_matches = {
            "drainage": "Greater Chennai Corporation - Storm Water Drainage Division",
            "sewer": "Greater Chennai Corporation - Storm Water Drainage Division",
            "streetlight": "Greater Chennai Corporation - Electrical Wing",
            "street light": "Greater Chennai Corporation - Electrical Wing",
            "footpath": "Greater Chennai Corporation - Road Works Division",
            "encroachment": "Greater Chennai Corporation - Zonal Office",
            "garbage": "Greater Chennai Corporation - Zonal Office",
        }
        for keyword, department in keyword_matches.items():
            if keyword in text:
                return {
                    "department": department,
                    "reason": f"Description mentions '{keyword}' so the request is best routed to {department}.",
                    "letter": self._build_letter(road, description, department),
                }

        if any(keyword in road_name for keyword in ["nh", "highway", "bypass", "expressway"]):
            department = "Tamil Nadu Highways Department"
            reason = "The selected road appears to be a highway or bypass, so the highways department should receive it."
        elif any(keyword in road_name for keyword in ["omr", "ecr", "gst", "inner ring", "main road", "link road"]):
            department = "Greater Chennai Corporation - Road Works Division"
            reason = "The road is a city corridor and should be routed to the municipal road works team."
        elif any(keyword in ward for keyword in ["adyar", "perungudi", "velachery", "guindy", "thiruvanmiyur", "kotturpuram"]):
            department = "Greater Chennai Corporation - Zonal Engineering Office"
            reason = "The ward falls under a civic zone, so the zonal engineering office should process it."
        else:
            department = "Tamil Nadu Highways Department"
            reason = "No sharper match was found, so the highways department is the safest routing target."

        return {
            "department": department,
            "reason": reason,
            "letter": self._build_letter(road, description, department),
        }

    def _build_letter(self, road: dict, description: str, department: str) -> str:
        road_name = road.get("name", "selected road")
        ward = road.get("ward", "Unknown ward")
        return (
            f"To: {department}\n"
            f"Subject: Road complaint for {road_name}\n\n"
            f"Dear Sir/Madam,\n\n"
            f"RoadWatch AI reports a complaint for {road_name} in {ward}. "
            f"User report: {description.strip()}\n\n"
            f"Please inspect the road and confirm action taken.\n\n"
            f"Regards,\nRoadWatch AI Civic Reporter"
        )
