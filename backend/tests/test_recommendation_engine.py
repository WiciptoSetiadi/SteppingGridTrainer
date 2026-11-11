import pytest
from app.models.schemas import SessionFeatures
from app.services.recommendation_engine import RecommendationEngine

def test_recommendation_high_accuracy_tempo_speedup():
    features = SessionFeatures(
        session_id=1,
        total_steps=20,
        correct_steps=19,
        incorrect_steps=1,
        accuracy_percent=95.0,
        total_duration_ms=25000,
        average_reaction_ms=1100.0,
        left_right_ratio=1.0
    )
    rec = RecommendationEngine.recommend(
        session_id=1,
        features=features,
        current_mode="Sekuensial",
        current_tempo_ms=1500
    )
    # 1500 * 0.90 = 1350 ms
    assert rec.recommended_tempo_ms == 1350
    assert rec.recommended_mode == "Sekuensial"
    assert "dipercepat 10%" in rec.recommendation_text

def test_recommendation_advances_mode_after_streak():
    features = SessionFeatures(
        session_id=3,
        total_steps=20,
        correct_steps=19,
        incorrect_steps=1,
        accuracy_percent=95.0,
        total_duration_ms=25000,
        average_reaction_ms=1000.0
    )
    history = [
        {"accuracy_percent": 92.0},
        {"accuracy_percent": 94.0},
    ]
    rec = RecommendationEngine.recommend(
        session_id=3,
        features=features,
        current_mode="Sekuensial",
        current_tempo_ms=1350,
        history_results=history
    )
    # 3 consecutive sessions >= 90% -> advances to "Acak Reaksi"
    assert rec.recommended_mode == "Acak Reaksi"
    assert "Acak Reaksi" in rec.recommendation_text

def test_recommendation_moderate_accuracy_maintain():
    features = SessionFeatures(
        session_id=1,
        total_steps=20,
        correct_steps=16,
        incorrect_steps=4,
        accuracy_percent=80.0,
        total_duration_ms=30000,
        average_reaction_ms=1250.0
    )
    rec = RecommendationEngine.recommend(
        session_id=1,
        features=features,
        current_mode="Sekuensial",
        current_tempo_ms=1500
    )
    assert rec.recommended_tempo_ms == 1500
    assert rec.recommended_mode == "Sekuensial"
    assert "stabil" in rec.recommendation_text.lower()

def test_recommendation_low_accuracy_slowdown():
    features = SessionFeatures(
        session_id=1,
        total_steps=20,
        correct_steps=10,
        incorrect_steps=10,
        accuracy_percent=50.0,
        total_duration_ms=35000,
        average_reaction_ms=1800.0
    )
    rec = RecommendationEngine.recommend(
        session_id=1,
        features=features,
        current_mode="Sekuensial",
        current_tempo_ms=1500
    )
    # 1500 * 1.15 = 1725 ms
    assert rec.recommended_tempo_ms == 1725
    assert rec.recommended_mode == "Sekuensial"
    assert "diperlambat 15%" in rec.recommendation_text
