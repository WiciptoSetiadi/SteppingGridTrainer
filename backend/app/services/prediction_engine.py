"""
Modul M-09: Prediction Engine (Estimasi Capai Target Pemulihan)
Rujukan Ilmiah:
1. Hollands et al. (2013), PMC3846668: Visual cue training to improve walking and balance after stroke.
2. Lee et al. (2026), Ann Rehabil Med 50(5):363-375:
   Model pembelajaran motorik feedforward dan estimasi waktu adaptasi motorik langkah.
Desain UI: Sesuai Figma 'Langkah makin tepat' & 'Estimasi AI - Target akurasi 90%'.
"""

import numpy as np
import math
from typing import List, Dict, Any, Optional
from sklearn.linear_model import Ridge
from app.models.schemas import PredictionResult
from app.core.config import settings

class PredictionEngine:
    @staticmethod
    def predict(
        session_id: int,
        history_results: List[Dict[str, Any]],
        target_accuracy: float = 90.0,
        model_version: str = "linreg-v1"
    ) -> PredictionResult:
        session_count = len(history_results)
        # Jika belum mencapai ambang minimal sesi
        if session_count < settings.MIN_SESSIONS_FOR_PREDICTION:
            return PredictionResult(
                session_id=session_id,
                model_version=model_version,
                predicted_value=None,
                prediction_unit="days",
                confidence_score=0.0,
                notes=f"Prediksi membutuhkan minimal {settings.MIN_SESSIONS_FOR_PREDICTION} sesi latihan. Saat ini baru terdapat {session_count} sesi."
            )

        # Ekstrak urutan sesi dan nilai akurasi (%)
        x_vals = np.arange(1, session_count + 1).reshape(-1, 1)
        y_vals = np.array([
            min(100.0, max(0.0, float(r.get("accuracy_percent", 0.0))))
            for r in history_results
        ])

        latest_acc = y_vals[-1]

        # 1. Kasus Target Sudah Tercapai
        if latest_acc >= target_accuracy:
            return PredictionResult(
                session_id=session_id,
                model_version=model_version,
                predicted_value=0.0,
                prediction_unit="days",
                confidence_score=round(min(1.0, session_count / 10.0), 3),
                notes=f"Target akurasi {target_accuracy:.0f}% telah tercapai ({latest_acc:.1f}%). Pertahankan konsistensi latihan Anda!"
            )

        # 2. Model Regresi Linier (Ridge Regression untuk mencegah overfitting)
        model = Ridge(alpha=1.0)
        model.fit(x_vals, y_vals)

        slope = float(model.coef_[0])  # Kenaikan rata-rata poin per sesi
        intercept = float(model.intercept_)

        # Hitung R^2
        y_pred = model.predict(x_vals)
        ss_res = np.sum((y_vals - y_pred) ** 2)
        ss_tot = np.sum((y_vals - np.mean(y_vals)) ** 2)
        r2 = float(1 - (ss_res / ss_tot)) if ss_tot > 1e-6 else 0.0
        r2 = max(0.0, min(1.0, r2))

        # Confidence Score: R^2 * bobot jumlah data sampel
        confidence = r2 * min(1.0, session_count / 10.0)

        # 3. Jika Slope Tidak Positif (Belum Ada Tren Peningkatan Signifikan)
        if slope <= 0.05:
            return PredictionResult(
                session_id=session_id,
                model_version=model_version,
                predicted_value=None,
                prediction_unit="days",
                confidence_score=round(confidence, 3),
                notes="Tren peningkatan akurasi belum terdeteksi secara konsisten. Teruslah berlatih."
            )

        # 4. Hitung Estimasi Jumlah Sesi Menuju Target 90%
        # Formula: (target - akurasi_terakhir) / slope
        remaining_points = target_accuracy - latest_acc
        estimated_sessions = remaining_points / slope
        rounded_sessions = max(1, int(math.ceil(estimated_sessions)))

        # Format pesan catatan klinis (persis sesuai Figma)
        points_per_session = int(round(slope)) if round(slope) >= 1 else round(slope, 1)
        notes = (
            f"Sekitar {rounded_sessions} sesi lagi. "
            f"Jika kenaikan {points_per_session} poin per sesi berlanjut. "
            "Perkiraan dapat berubah, bukan janji pemulihan klinis."
        )

        return PredictionResult(
            session_id=session_id,
            model_version=model_version,
            predicted_value=float(rounded_sessions),
            prediction_unit="days",
            confidence_score=round(confidence, 3),
            notes=notes
        )
