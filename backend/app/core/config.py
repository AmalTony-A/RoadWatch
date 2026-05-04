from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


ENV_PATH = Path(__file__).resolve().parents[2] / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=ENV_PATH, env_file_encoding="utf-8")

    app_name: str = "RoadWatch AI API"
    app_env: str = "development"
    demo_mode: bool = False

    api_host: str = "0.0.0.0"
    api_port: int = 8000

    mongo_uri: str | None = None
    mongo_db: str = "roadwatch_ai"

    yolo_model_path: str = "./models/yolov8n.pt"

    openai_api_key: str | None = None
    openai_model: str = "gpt-4o-mini"

    groq_api_key: str | None = None
    groq_model: str = "llama-3.1-8b-instant"

    google_api_key: str | None = None
    google_model: str = "gemini-flash-latest"

    frontend_origin: str = "*"


@lru_cache
def get_settings() -> Settings:
    return Settings()
