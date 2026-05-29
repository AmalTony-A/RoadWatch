from __future__ import annotations

import logging
from typing import Any

from app.core.config import Settings
from app.db.repository import DataRepository

try:
    from openai import OpenAI
except Exception:  # pragma: no cover
    OpenAI = None

try:
    from groq import Groq
except Exception:  # pragma: no cover
    Groq = None

try:
    import google.generativeai as genai
except Exception:  # pragma: no cover
    genai = None


SYSTEM_PROMPT = (
    "You are a civic assistant for RoadWatch AI. Be concise, transparent, and actionable. "
    "Prioritize road safety, public spending visibility, and complaint guidance."
)

logger = logging.getLogger(__name__)


class CivicChatbotService:
    def __init__(self, settings: Settings, repository: DataRepository):
        self.settings = settings
        self.repository = repository
        self.openai_client = None
        self.groq_client = None
        self.google_model = None
        if settings.google_api_key and genai is not None:
            genai.configure(api_key=settings.google_api_key)
            self.google_model = genai.GenerativeModel(settings.google_model)
        elif settings.google_api_key and genai is None:
            logger.warning("Google AI SDK not installed; chatbot will use fallback.")
        if settings.groq_api_key and Groq is not None:
            self.groq_client = Groq(api_key=settings.groq_api_key)
        elif settings.groq_api_key and Groq is None:
            logger.warning("Groq SDK not installed; chatbot will use fallback.")
        if settings.openai_api_key and OpenAI is not None:
            self.openai_client = OpenAI(api_key=settings.openai_api_key)

    def ask(self, query: str, road_id: str | None, history: list[dict[str, str]] | None = None):
        history = history or []
        road = None
        budget = None
        complaints: list[dict[str, Any]] = []

        try:
            road = self.repository.get_road(road_id) if road_id else None
            budget = self.repository.get_budget_by_road(road_id) if road_id else None
            complaints = [
                c
                for c in self.repository.get_complaints()
                if not road_id or c["road_id"] == road_id
            ]

            cited_data: dict[str, Any] = {
                "road_id": road_id,
                "road_name": road["name"] if road else None,
                "road_score": road["road_health_score"] if road else None,
                "contractor": budget["contractor"] if budget else None,
                "allocated_budget": budget["allocated_inr"] if budget else None,
                "complaints_count": len(complaints),
            }

            google_error = None
            groq_error = None
            openai_error = None

            if self.google_model is not None:
                try:
                    context = {
                        "road": road,
                        "budget": budget,
                        "recent_complaints": complaints[:3],
                    }
                    history_text = "\n".join(
                        f"{item['role']}: {item['content']}" for item in history[-6:]
                    )
                    if not history_text:
                        history_text = "None"
                    prompt = (
                        f"{SYSTEM_PROMPT}\n\nContext: {context}\n\n"
                        f"Conversation:\n{history_text}\n\nuser: {query}"
                    )
                    response = self.google_model.generate_content(prompt)
                    answer = getattr(response, "text", None) or "No response generated."
                    cited_data["llm"] = "google"
                    return {
                        "answer": answer,
                        "cited_data": cited_data,
                        "source": "llm",
                        "llm": "google",
                        "confidence": None,
                    }
                except Exception as exc:
                    google_error = self._safe_error(exc)
                    logger.exception("Google chat failed; falling back.")

            if self.groq_client is not None:
                try:
                    context = {
                        "road": road,
                        "budget": budget,
                        "recent_complaints": complaints[:3],
                    }
                    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
                    for item in history[-6:]:
                        messages.append({"role": item["role"], "content": item["content"]})
                    messages.append(
                        {
                            "role": "user",
                            "content": f"Context: {context}\n\nUser question: {query}",
                        }
                    )
                    response = self.groq_client.chat.completions.create(
                        model=self.settings.groq_model,
                        temperature=0.2,
                        messages=messages,
                    )
                    answer = response.choices[0].message.content or "No response generated."
                    cited_data["llm"] = "groq"
                    return {
                        "answer": answer,
                        "cited_data": cited_data,
                        "source": "llm",
                        "llm": "groq",
                        "confidence": None,
                    }
                except Exception as exc:
                    groq_error = self._safe_error(exc)
                    logger.exception("Groq chat failed; falling back.")

            if self.openai_client is not None:
                try:
                    context = {
                        "road": road,
                        "budget": budget,
                        "recent_complaints": complaints[:3],
                    }
                    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
                    for item in history[-6:]:
                        messages.append({"role": item["role"], "content": item["content"]})
                    messages.append(
                        {
                            "role": "user",
                            "content": f"Context: {context}\n\nUser question: {query}",
                        }
                    )
                    response = self.openai_client.chat.completions.create(
                        model=self.settings.openai_model,
                        temperature=0.2,
                        messages=messages,
                    )
                    answer = response.choices[0].message.content or "No response generated."
                    cited_data["llm"] = "openai"
                    return {
                        "answer": answer,
                        "cited_data": cited_data,
                        "source": "llm",
                        "llm": "openai",
                        "confidence": None,
                    }
                except Exception as exc:
                    openai_error = self._safe_error(exc)
                    logger.exception("OpenAI chat failed; falling back.")

            answer = self._fallback_answer(query, road, budget, complaints)
            if self.settings.app_env != "production":
                if google_error:
                    cited_data["google_error"] = google_error
                if groq_error:
                    cited_data["groq_error"] = groq_error
                if openai_error:
                    cited_data["openai_error"] = openai_error
            return {
                "answer": answer,
                "cited_data": cited_data,
                "source": "rule-based",
                "llm": None,
                "confidence": None,
            }
        except Exception as exc:
            logger.exception("Chat assistant failed; returning fallback.")
            answer = self._fallback_answer(query, road, budget, complaints)
            return {
                "answer": answer,
                "cited_data": {"llm_error": self._safe_error(exc)},
                "source": "error",
                "llm": None,
                "confidence": None,
            }

    @staticmethod
    def _format_inr(value: int | None) -> str:
        if value is None:
            return "unknown"
        return f"INR {value:,}"

    @staticmethod
    def _safe_error(error: Exception) -> str:
        message = f"{type(error).__name__}: {error}"
        return message[:200]

    def _fallback_answer(self, query: str, road: dict | None, budget: dict | None, complaints: list):
        q = query.lower()

        if any(g in q for g in ("hello", "hi", "hey", "greetings")):
            return (
                "Hello! I'm the RoadWatch AI civic assistant. I can help you with road conditions, "
                "budget transparency, contractor details, complaint filing, and tracking. "
                "Select a road or ask me anything."
            )

        if any(g in q for g in ("help", "what can you do", "capabilities", "features")):
            return (
                "I can:\n"
                "- Show road health scores and damage detections\n"
                "- Reveal budget and contractor transparency data\n"
                "- File and track civic complaints\n"
                "- Predict road deterioration risk\n"
                "- Answer questions about specific roads"
            )

        if any(g in q for g in ("score", "health", "rating", "condition")):
            if not road:
                return "Select a road to see its health score and condition breakdown."
            return (
                f"{road['name']} has a health score of {road['road_health_score']}/100 "
                f"({road['color'].upper()}). Nearby issues: {road['nearby_issues']}, "
                f"recent complaints: {road['recent_complaints']}."
            )

        if "why" in q and "poor" in q:
            if not road:
                return "This area has unresolved issues and rising complaint volume. Select a road to get exact causes."
            return (
                f"{road['name']} is rated {road['road_health_score']}/100 due to repeated pothole and crack detections, "
                f"with {road['recent_complaints']} recent complaints. Recommended action: immediate patching and drainage check."
            )

        if "budget" in q or "allocated" in q or "spent" in q:
            if not budget:
                return "Budget data is unavailable for this road."
            return (
                f"Allocated budget: {self._format_inr(budget['allocated_inr'])}. "
                f"Spent: {self._format_inr(budget['spent_inr'])}. "
                f"Contractor: {budget['contractor']}. "
                f"Last repair: {budget['last_repair_date']}. Condition score is {budget['actual_score']}/100."
            )

        if "contractor" in q:
            if not budget:
                return "Contractor data is unavailable for this road."
            return f"Responsible contractor: {budget['contractor']} (Project {budget['project_id']})."

        if "complaint" in q and "status" in q:
            if not complaints:
                return "No complaints are registered yet for this road."
            latest = complaints[0]
            return (
                f"Latest complaint {latest['id']} is {latest['status']} with authority ticket "
                f"{latest['authority_ticket']}."
            )

        if "file" in q and "complaint" in q:
            return (
                "I can file it now. Please provide road ID, issue description, and an image. "
                "RoadWatch AI will auto-attach GPS and timestamp."
            )

        if "issue" in q or "detect" in q or "damage" in q or "pothole" in q or "crack" in q:
            if not road:
                return "Detected issues are primarily potholes and cracks. Select a road for severity-level breakdown."
            return (
                f"Primary issues on {road['name']}: potholes/cracks with {road['nearby_issues']} nearby incidents. "
                "Use image capture to generate severity-tagged evidence."
            )

        if "risk" in q or "predict" in q or "deteriorat" in q:
            if not road:
                return "Select a road to see its deterioration risk prediction."
            return (
                f"{road['name']} has {road['recent_complaints']} recent complaints and "
                f"a health score of {road['road_health_score']}/100. Use the Risk Predictor for a detailed forecast."
            )

        if "ward" in q or "area" in q or "location" in q:
            if not road:
                return "Select a road to see its ward and location details."
            return f"{road['name']} is located in {road['ward']} ward."

        return (
            "I can help with road condition, budget transparency, contractor details, complaint filing, "
            "and complaint tracking. Ask using a road name or road ID for precise answers."
        )
