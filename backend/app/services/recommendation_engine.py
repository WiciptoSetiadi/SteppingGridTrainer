"""
Modul M-10: Recommendation Engine (Saran AI Adaptif)
Rujukan Ilmiah:
1. Hollands et al. (2013), PMC3846668:
   Protokol VCT: Pacing ritme langkah (cadence = 60000 / tempo_ms),
   dan eskalasi kemampuan adaptabilitas (variasi langkah, zigzag, lateral).
2. Lee et al. (2026), Ann Rehabil Med 50(5):363-375:
   Kriteria progresivitas latihan langkah:
   - Evaluasi keberhasilan langkah (ambang batas 70% dan 90%).
   - Peningkatan tantangan koordinasi bila stabilitas motorik tercapai.
Desain UI: Sesuai Figma 'Saran AI · Sesi berikutnya'.
"""

from typing import List, Dict, Any, Optional
from app.models.schemas import SessionFeatures, RecommendationResult
from app.core.config import settings

class RecommendationEngine:
    AVAILABLE_MODES_FLOW = ["Sekuensial", "Acak Reaksi", "Tempo Dinamis"]

    @classmethod
    def recommend(
        cls,
        session_id: int,
        features: SessionFeatures,
        current_mode: str = "Sekuensial",
        current_tempo_ms: int = 1500,
        history_results: Optional[List[Dict[str, Any]]] = None
    ) -> RecommendationResult:
        acc = features.accuracy_percent
        avg_reaction = features.average_reaction_ms
        current_tempo = max(settings.MIN_TEMPO_MS, min(settings.MAX_TEMPO_MS, current_tempo_ms))

        # Hitung cadence langkah per menit: 60000 / tempo_ms (Hollands et al., 2013)
        cadence_steps_per_min = int(round(60000.0 / current_tempo))

        # Cek konsistensi performa pada riwayat sesi
        high_accuracy_streak = 0
        if history_results:
            recent_accs = [
                float(r.get("accuracy_percent", 0.0))
                for r in history_results[-2:]
            ]
            recent_accs.append(acc)
            high_accuracy_streak = sum(1 for a in recent_accs if a >= settings.TARGET_ACCURACY)
        else:
            if acc >= settings.TARGET_ACCURACY:
                high_accuracy_streak = 1

        # KONDISI 1: Akurasi >= 90% (Performa Sangat Baik)
        if acc >= settings.TARGET_ACCURACY:
            new_tempo = int(round(current_tempo * 0.90))
            new_tempo = max(settings.MIN_TEMPO_MS, new_tempo)
            new_cadence = int(round(60000.0 / new_tempo))

            new_mode = current_mode
            mode_note = ""
            if high_accuracy_streak >= 3:
                try:
                    curr_idx = cls.AVAILABLE_MODES_FLOW.index(current_mode)
                    if curr_idx < len(cls.AVAILABLE_MODES_FLOW) - 1:
                        new_mode = cls.AVAILABLE_MODES_FLOW[curr_idx + 1]
                        mode_note = f" Anda telah konsisten di atas 90% selama 3 sesi, siap beralih ke Mode '{new_mode}'!"
                except ValueError:
                    new_mode = "Acak Reaksi"

            text = (
                f"Luar biasa! Akurasi Anda mencapai {acc:.1f}% dengan rata-rata reaksi {avg_reaction:.0f} ms. "
                f"Tempo dipercepat 10% (menjadi {new_tempo} ms / {new_cadence} langkah/menit) untuk memicu refleks gerak baru.{mode_note}"
            )
            return RecommendationResult(
                session_id=session_id,
                recommended_mode=new_mode,
                recommended_tempo_ms=new_tempo,
                recommendation_text=text
            )

        # KONDISI 2: Akurasi 70% hingga < 90% (Stabil & Membaik)
        # Sesuai template teks Figma & protokol VCT Hollands et al. (2013):
        elif acc >= 70.0:
            text = (
                "Langkah latihan stabil. Pertahankan ritme yang nyaman. "
                "Coba Zigzag setelah berdiskusi dengan fisioterapis."
            )
            return RecommendationResult(
                session_id=session_id,
                recommended_mode=current_mode,
                recommended_tempo_ms=current_tempo,
                recommendation_text=text
            )

        # KONDISI 3: Akurasi < 70% (Butuh Relaksasi & Penyesuaian Tempo)
        else:
            new_tempo = int(round(current_tempo * 1.15))
            new_tempo = min(settings.MAX_TEMPO_MS, new_tempo)
            new_cadence = int(round(60000.0 / new_tempo))

            text = (
                f"Akurasi tercatat {acc:.1f}%. Jangan memaksakan diri; "
                f"tempo diperlambat 15% (menjadi {new_tempo} ms / {new_cadence} langkah/menit) "
                f"agar tumpuan beban (weight shifting) dapat dilakukan dengan aman dan stabil."
            )
            return RecommendationResult(
                session_id=session_id,
                recommended_mode=current_mode,
                recommended_tempo_ms=new_tempo,
                recommendation_text=text
            )
