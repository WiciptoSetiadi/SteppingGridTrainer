import httpx
from typing import Optional, List, Dict, Any
from app.core.config import settings
from app.models.schemas import StepLogItem, SessionFeatures, PredictionResult, RecommendationResult

class SupabaseRepository:
    def __init__(self):
        self.base_url = f"{settings.SUPABASE_URL.rstrip('/')}/rest/v1"
        self.headers = {
            "apikey": settings.SUPABASE_SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {settings.SUPABASE_SERVICE_ROLE_KEY}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }

    async def get_session(self, session_id: int) -> Optional[Dict[str, Any]]:
        """Mengambil data sesi beserta session_config dan layout."""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/training_session",
                params={
                    "session_id": f"eq.{session_id}",
                    "select": "*,session_config(*,layout(*))"
                },
                headers=self.headers,
                timeout=10.0
            )
            if resp.status_code == 200:
                data = resp.json()
                return data[0] if data else None
            return None

    async def check_session_result_exists(self, session_id: int) -> bool:
        """Memeriksa apakah hasil sesi sudah pernah dihitung (idempotensi SDD 3.2.8)."""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/session_result",
                params={"session_id": f"eq.{session_id}", "select": "session_id"},
                headers=self.headers,
                timeout=5.0
            )
            if resp.status_code == 200:
                return len(resp.json()) > 0
            return False

    async def get_session_steps(self, session_id: int) -> List[StepLogItem]:
        """Mengambil log seluruh langkah sesi terurut step_number dengan detail tile_position."""
        async with httpx.AsyncClient() as client:
            resp = await client.get(
                f"{self.base_url}/step_log",
                params={
                    "session_id": f"eq.{session_id}",
                    "select": "*,tile_position(side,position_code)",
                    "order": "step_number.asc"
                },
                headers=self.headers,
                timeout=10.0
            )
            if resp.status_code == 200:
                rows = resp.json()
                items = []
                for r in rows:
                    tile_info = r.get("tile_position") or {}
                    items.append(StepLogItem(
                        step_log_id=r.get("step_log_id"),
                        session_id=r["session_id"],
                        position_id=r["position_id"],
                        step_number=r["step_number"],
                        event_type=r["event_type"],
                        is_correct=r["is_correct"],
                        reaction_time_ms=r.get("reaction_time_ms"),
                        event_at=r["event_at"],
                        side=tile_info.get("side"),
                        position_code=tile_info.get("position_code")
                    ))
                return items
            return []

    async def get_user_session_history(self, user_id: int, layout_id: Optional[int] = None) -> List[Dict[str, Any]]:
        """
        Mengambil riwayat session_result sebelumnya untuk pasien tertentu.
        Jika layout_id diberikan, memfilter sesi dengan layout yang sama (SDD 3.2.10).
        """
        async with httpx.AsyncClient() as client:
            params = {
                "training_session.user_id": f"eq.{user_id}",
                "select": "*,training_session!inner(user_id,started_at,session_config(layout_id))",
                "order": "calculated_at.asc"
            }
            if layout_id:
                params["training_session.session_config.layout_id"] = f"eq.{layout_id}"

            resp = await client.get(
                f"{self.base_url}/session_result",
                params=params,
                headers=self.headers,
                timeout=10.0
            )
            if resp.status_code == 200:
                return resp.json()
            return []

    async def upsert_session_result(self, features: SessionFeatures) -> Dict[str, Any]:
        """Menyimpan atau memperbarui session_result."""
        payload = {
            "session_id": features.session_id,
            "total_steps": features.total_steps,
            "correct_steps": features.correct_steps,
            "incorrect_steps": features.incorrect_steps,
            "accuracy_percent": round(features.accuracy_percent, 2),
            "total_duration_ms": features.total_duration_ms,
            "average_reaction_ms": round(features.average_reaction_ms, 2),
            "left_right_ratio": round(features.left_right_ratio, 2) if features.left_right_ratio is not None else None,
            "calculated_at": "now()"
        }
        headers = dict(self.headers)
        headers["Prefer"] = "resolution=merge-duplicates,return=representation"
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/session_result",
                json=payload,
                headers=headers,
                timeout=10.0
            )
            resp.raise_for_status()
            data = resp.json()
            return data[0] if data else payload

    async def insert_ai_prediction(self, prediction: PredictionResult) -> Dict[str, Any]:
        """Menyimpan hasil estimasi target pemulihan ke ai_prediction."""
        payload = {
            "session_id": prediction.session_id,
            "model_version": prediction.model_version,
            "predicted_value": round(prediction.predicted_value, 2) if prediction.predicted_value is not None else None,
            "prediction_unit": prediction.prediction_unit,
            "confidence_score": round(prediction.confidence_score, 3),
            "notes": prediction.notes,
            "predicted_at": "now()"
        }
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/ai_prediction",
                json=payload,
                headers=self.headers,
                timeout=10.0
            )
            resp.raise_for_status()
            data = resp.json()
            return data[0] if data else payload

    async def insert_ai_recommendation(self, recommendation: RecommendationResult) -> Dict[str, Any]:
        """Menyimpan saran mode dan tempo adaptif ke ai_recommendation."""
        payload = {
            "session_id": recommendation.session_id,
            "recommended_mode": recommendation.recommended_mode,
            "recommended_tempo_ms": recommendation.recommended_tempo_ms,
            "recommendation_text": recommendation.recommendation_text,
            "created_at": "now()"
        }
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{self.base_url}/ai_recommendation",
                json=payload,
                headers=self.headers,
                timeout=10.0
            )
            resp.raise_for_status()
            data = resp.json()
            return data[0] if data else payload
