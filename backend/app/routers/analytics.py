from fastapi import APIRouter, HTTPException, Query, status
from typing import Optional, Dict, Any
from app.services.ai_pipeline import AIPipeline
from app.repositories.supabase_repo import SupabaseRepository
from app.models.schemas import FullAnalysisResult

router = APIRouter(prefix="/api", tags=["Analytics"])

@router.post("/sessions/{session_id}/analyze", response_model=FullAnalysisResult)
async def analyze_session(
    session_id: int,
    force: bool = Query(default=False, description="Paksa perhitungan ulang meskipun sudah ada session_result")
):
    """
    Memicu analisis AI secara sinkron untuk keperluan pengujian / on-demand.
    Mengekstrak fitur, menjalankan prediksi regresi, dan menghasilkan rekomendasi.
    """
    try:
        pipeline = AIPipeline()
        result = await pipeline.run(session_id=session_id, force=force)
        return result
    except ValueError as ve:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Terjadi kesalahan saat memproses analisis: {str(e)}"
        )

@router.get("/users/{user_id}/insights")
async def get_user_insights(user_id: int):
    """Mengambil prediksi dan rekomendasi terbaru untuk pasien tertentu."""
    repo = SupabaseRepository()
    history = await repo.get_user_session_history(user_id)
    if not history:
        return {
            "user_id": user_id,
            "has_data": False,
            "message": "Belum ada sesi latihan yang diselesaikan."
        }

    latest = history[-1]
    return {
        "user_id": user_id,
        "has_data": True,
        "total_sessions": len(history),
        "latest_session": latest
    }
