"""
Modul M-08: Feature Extractor
Rujukan Klinis:
1. Hollands et al. (2013), PMC3846668: Visual cue training and gait adaptability in stroke.
2. Lee et al. (2026), Ann Rehabil Med 50(5):363-375 (e-arm.org/journal/view.php?number=4464):
   Targeted stepping error distance, bilateral symmetry ratio, and visual cue progression.
"""

from typing import List, Optional, Dict, Any
from datetime import datetime
from app.models.schemas import StepLogItem, SessionFeatures

class FeatureExtractor:
    @staticmethod
    def extract(
        session_id: int,
        steps: List[StepLogItem],
        started_at: Optional[datetime] = None,
        ended_at: Optional[datetime] = None,
        layout_code: Optional[str] = "SQUARE_2X2"
    ) -> SessionFeatures:
        if not steps:
            return SessionFeatures(
                session_id=session_id,
                total_steps=0,
                correct_steps=0,
                incorrect_steps=0,
                accuracy_percent=0.0,
                total_duration_ms=0,
                average_reaction_ms=0.0,
                left_right_ratio=None,
                layout_code=layout_code
            )

        total_steps = len(steps)
        correct_steps = sum(1 for s in steps if s.is_correct)
        incorrect_steps = total_steps - correct_steps

        # 1. Akurasi langkah (%): Benar / Total * 100
        # (Hollands et al., 2013 & Lee et al., 2026)
        accuracy = (correct_steps / total_steps * 100.0) if total_steps > 0 else 0.0

        # 2. Rata-rata waktu reaksi (ms & detik): waktu inisiasi langkah benar sejak cue visual menyala
        valid_reactions = [
            s.reaction_time_ms for s in steps 
            if s.is_correct and s.reaction_time_ms is not None and s.reaction_time_ms > 0
        ]
        avg_reaction = (sum(valid_reactions) / len(valid_reactions)) if valid_reactions else 0.0

        # 3. Durasi total sesi (ms)
        total_duration_ms = 0
        if started_at and ended_at:
            delta = ended_at - started_at
            total_duration_ms = max(0, int(delta.total_seconds() * 1000))
        elif len(steps) >= 2:
            first_time = steps[0].event_at
            last_time = steps[-1].event_at
            if first_time and last_time:
                delta = last_time - first_time
                total_duration_ms = max(0, int(delta.total_seconds() * 1000))

        # 4. Bilateral Gait Symmetry Ratio (Weight Shifting)
        # Sesuai formula Lee et al. (2026) Tabel 2 & Hollands et al. (2013):
        # Mengukur simetri penempatan kaki kiri vs kanan. Target ideal = 50% / 50% (rasio 1.0).
        left_correct = 0
        right_correct = 0

        for s in steps:
            if not s.is_correct:
                continue
            side = (s.side or "").upper()
            if side == "L":
                left_correct += 1
            elif side == "R":
                right_correct += 1

        left_right_ratio: Optional[float] = None
        if right_correct > 0:
            left_right_ratio = round(left_correct / right_correct, 2)
        elif left_correct > 0 and right_correct == 0:
            left_right_ratio = None

        return SessionFeatures(
            session_id=session_id,
            total_steps=total_steps,
            correct_steps=correct_steps,
            incorrect_steps=incorrect_steps,
            accuracy_percent=round(accuracy, 2),
            total_duration_ms=total_duration_ms,
            average_reaction_ms=round(avg_reaction, 2),
            left_right_ratio=left_right_ratio,
            layout_code=layout_code
        )
