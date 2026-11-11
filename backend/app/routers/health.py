from fastapi import APIRouter
from app.models.schemas import HealthResponse
from app.core.config import settings

router = APIRouter(tags=["Health"])

@router.get("/health", response_model=HealthResponse)
async def health_check():
    """Endpoint pemeriksaan kesehatan layanan AI & Analytics."""
    return HealthResponse(
        status="healthy",
        version=settings.APP_VERSION
    )
