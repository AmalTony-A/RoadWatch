from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.core.config import get_settings
from app.routers.api import router as api_router
from app.routers.admin import router as admin_router

settings = get_settings()

app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description=(
        "RoadWatch AI backend for road damage detection, civic transparency, "
        "complaint automation, and risk prediction"
    ),
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_origin] if settings.frontend_origin != "*" else ["*"],
    allow_credentials=settings.frontend_origin != "*",
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)

# Serve uploaded images so the frontend can display them
uploads_dir = Path(__file__).resolve().parent / "uploads"
app.mount("/uploads", StaticFiles(directory=uploads_dir), name="uploads")

app.include_router(api_router)
app.include_router(admin_router)


@app.get("/dashboard")
async def get_dashboard():
    """Serve the backend dashboard."""
    dashboard_path = Path(__file__).resolve().parent / "dashboard.html"
    return FileResponse(dashboard_path)
