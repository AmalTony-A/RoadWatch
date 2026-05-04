from functools import lru_cache

from app.core.config import get_settings
from app.db.repository import DataRepository
from app.services.chatbot import CivicChatbotService
from app.services.complaint import ComplaintService
from app.services.detection import DamageDetectionService
from app.services.prediction import RiskPredictionService


@lru_cache
def get_repository() -> DataRepository:
    settings = get_settings()
    return DataRepository(settings)


@lru_cache
def get_detection_service() -> DamageDetectionService:
    settings = get_settings()
    return DamageDetectionService(settings=settings, repository=get_repository())


@lru_cache
def get_prediction_service() -> RiskPredictionService:
    return RiskPredictionService(repository=get_repository())


@lru_cache
def get_complaint_service() -> ComplaintService:
    return ComplaintService(repository=get_repository())


@lru_cache
def get_chatbot_service() -> CivicChatbotService:
    settings = get_settings()
    return CivicChatbotService(settings=settings, repository=get_repository())
