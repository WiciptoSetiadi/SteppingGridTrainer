import logging
from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from typing import Dict, Any
from app.core.security import verify_webhook_signature
from app.services.ai_pipeline import AIPipeline
from app.models.schemas import SessionCompletedWebhook

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Webhooks"])

async def run_pipeline_task(session_id: int):
    try:
        pipeline = AIPipeline()
        await pipeline.run(session_id=session_id)
    except Exception as e:
        logger.error(f"Gagal menjalankan AI pipeline untuk session {session_id}: {str(e)}", exc_info=True)

@router.post(
    "/webhook/session-completed",
    status_code=status.HTTP_202_ACCEPTED,
    dependencies=[Depends(verify_webhook_signature)]
)
async def handle_session_completed(
    payload: Dict[str, Any],
    background_tasks: BackgroundTasks
):
    """
    Webhook receiver dari Supabase Database Webhook (SDD 3.2.8).
    Dipanggil otomatis saat training_session berstatus 'completed'.
    Mereturn status 202 Accepted dan memproses ekstraksi metrik serta AI di background.
    """
    # Ekstraksi session_id dari format payload Supabase atau direct JSON
    session_id = None
    record = payload.get("record")
    if record and isinstance(record, dict):
        status_val = record.get("session_status")
        if status_val == "completed":
            session_id = record.get("session_id")
    else:
        # Fallback jika dikirim langsung { "session_id": 123, "session_status": "completed" }
        if payload.get("session_status") == "completed" or "session_id" in payload:
            session_id = payload.get("session_id")

    if not session_id:
        return {
            "status": "ignored",
            "message": "Payload tidak memuat session_id atau status sesi bukan 'completed'."
        }

    # Jadwalkan pengerjaan AI pipeline secara asinkron
    background_tasks.add_task(run_pipeline_task, session_id)

    return {
        "status": "accepted",
        "message": f"Analitik AI untuk session_id={session_id} telah dijadwalkan.",
        "session_id": session_id
    }
