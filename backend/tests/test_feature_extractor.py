import pytest
from datetime import datetime, timedelta
from app.models.schemas import StepLogItem
from app.services.feature_extractor import FeatureExtractor

def test_feature_extractor_empty_steps():
    features = FeatureExtractor.extract(session_id=1, steps=[])
    assert features.total_steps == 0
    assert features.accuracy_percent == 0.0
    assert features.average_reaction_ms == 0.0
    assert features.left_right_ratio is None

def test_feature_extractor_accuracy_and_reaction():
    now = datetime.utcnow()
    steps = [
        StepLogItem(session_id=1, position_id=1, step_number=1, event_type="target_hit", is_correct=True, reaction_time_ms=800, event_at=now, side="L"),
        StepLogItem(session_id=1, position_id=2, step_number=2, event_type="target_hit", is_correct=True, reaction_time_ms=1000, event_at=now + timedelta(seconds=1), side="R"),
        StepLogItem(session_id=1, position_id=3, step_number=3, event_type="wrong_step", is_correct=False, reaction_time_ms=None, event_at=now + timedelta(seconds=2), side="L"),
        StepLogItem(session_id=1, position_id=4, step_number=4, event_type="target_hit", is_correct=True, reaction_time_ms=1200, event_at=now + timedelta(seconds=3), side="R"),
    ]

    features = FeatureExtractor.extract(
        session_id=1,
        steps=steps,
        started_at=now,
        ended_at=now + timedelta(seconds=4)
    )

    assert features.total_steps == 4
    assert features.correct_steps == 3
    assert features.incorrect_steps == 1
    # 3/4 = 75.0%
    assert features.accuracy_percent == 75.0
    # Average reaction of 800, 1000, 1200 = 1000.0 ms
    assert features.average_reaction_ms == 1000.0
    # Total duration = 4000 ms
    assert features.total_duration_ms == 4000
    # Left correct = 1, Right correct = 2 -> ratio = 1/2 = 0.5
    assert features.left_right_ratio == 0.5

def test_feature_extractor_no_right_steps():
    now = datetime.utcnow()
    steps = [
        StepLogItem(session_id=1, position_id=1, step_number=1, event_type="target_hit", is_correct=True, reaction_time_ms=900, event_at=now, side="L"),
        StepLogItem(session_id=1, position_id=3, step_number=2, event_type="target_hit", is_correct=True, reaction_time_ms=950, event_at=now + timedelta(seconds=1), side="L"),
    ]

    features = FeatureExtractor.extract(session_id=1, steps=steps)
    # Zero right steps should return None without error (SDD 3.2.8)
    assert features.left_right_ratio is None
