import logging
from typing import Optional
from app.repositories.supabase_repo import SupabaseRepository
from app.services.feature_extractor import FeatureExtractor
from app.services.prediction_engine import PredictionEngine
from app.services.recommendation_engine import RecommendationEngine
from app.models.schemas import FullAnalysisResult, SessionFeatures, PredictionResult, RecommendationResult

logger = logging.getLogger(__name__)

class AIPipeline:
    """
    Orkestrator pemrosesan sistem cerdas Stepping Grid Trainer (SDD Gambar 2. Arsitektur AI & Gambar 24).
    Mengkombinasikan ekstraksi fitur, estimasi target regresi, dan rekomendasi adaptif.
    """

    def __init__(self, repo: Optional[SupabaseRepository] = None):
        self.repo = repo or SupabaseRepository()

    async def run(self, session_id: int, force: bool = False) -> FullAnalysisResult:
        logger.info(f"Memulai pipeline AI untuk session_id={session_id}")

        # 1. Cek idempotensi jika tidak dipaksa re-analisis
        if not force:
            already_done = await self.repo.check_session_result_exists(session_id)
            if already_done:
                logger.info(f"Session {session_id} sudah diproses sebelumnya (idempotent).")

        # 2. Ambil data sesi dari Supabase
        session_data = await self.repo.get_session(session_id)
        if not session_data:
            raise ValueError(f"Sesi dengan ID {session_id} tidak ditemukan di database.")

        user_id = session_data.get("user_id")
        config = session_data.get("session_config") or {}
        layout_info = config.get("layout") or {}
        layout_code = layout_info.get("layout_code", "SQUARE_2X2")
        layout_id = config.get("layout_id")
        current_tempo = config.get("target_tempo_ms", 1500)

        # 3. Ambil log seluruh langkah sesi
        steps = await self.repo.get_session_steps(session_id)
        started_at = session_data.get("started_at")
        ended_at = session_data.get("ended_at")

        # 4. Ekstraksi Fitur (M-08)
        features: SessionFeatures = FeatureExtractor.extract(
            session_id=session_id,
            steps=steps,
            started_at=started_at,
            ended_at=ended_at,
            layout_code=layout_code
        )
        # Simpan metrik sesi ke session_result
        await self.repo.upsert_session_result(features)

        # 5. Ambil riwayat sesi pasien untuk layout ini
        history_results = await self.repo.get_user_session_history(user_id=user_id, layout_id=layout_id)

        # 6. Prediksi Estimasi Capai Target (M-09)
        prediction: PredictionResult = PredictionEngine.predict(
            session_id=session_id,
            history_results=history_results,
            target_accuracy=90.0,
            model_version="linreg-v1"
        )
        # Simpan ke ai_prediction
        await self.repo.insert_ai_prediction(prediction)

        # 7. Rekomendasi Adaptif (M-10)
        recommendation: RecommendationResult = RecommendationEngine.recommend(
            session_id=session_id,
            features=features,
            current_mode="Sekuensial",
            current_tempo_ms=current_tempo,
            history_results=history_results
        )
        # Simpan ke ai_recommendation
        await self.repo.insert_ai_recommendation(recommendation)

        logger.info(
            f"Pipeline AI selesai untuk session_id={session_id}: "
            f"acc={features.accuracy_percent}%, pred={prediction.predicted_value} hari, "
            f"tempo={recommendation.recommended_tempo_ms} ms"
        )

        return FullAnalysisResult(
            session_id=session_id,
            features=features,
            prediction=prediction,
            recommendation=recommendation
        )
