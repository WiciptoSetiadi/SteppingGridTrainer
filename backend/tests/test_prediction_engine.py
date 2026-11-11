import pytest
from app.services.prediction_engine import PredictionEngine

def test_prediction_engine_insufficient_sessions():
    history = [
        {"accuracy_percent": 60.0},
        {"accuracy_percent": 65.0},
        {"accuracy_percent": 70.0},
        {"accuracy_percent": 72.0},
    ]  # 4 sessions < 5
    result = PredictionEngine.predict(session_id=5, history_results=history)
    assert result.predicted_value is None
    assert result.confidence_score == 0.0
    assert "minimal 5 sesi" in result.notes.lower()

def test_prediction_engine_target_already_reached():
    history = [
        {"accuracy_percent": 65.0},
        {"accuracy_percent": 70.0},
        {"accuracy_percent": 75.0},
        {"accuracy_percent": 85.0},
        {"accuracy_percent": 92.0},
    ]
    result = PredictionEngine.predict(session_id=5, history_results=history, target_accuracy=90.0)
    assert result.predicted_value == 0.0
    assert "telah tercapai" in result.notes.lower()
    assert result.confidence_score > 0.0

def test_prediction_engine_positive_trend():
    history = [
        {"accuracy_percent": 50.0},
        {"accuracy_percent": 58.0},
        {"accuracy_percent": 66.0},
        {"accuracy_percent": 74.0},
        {"accuracy_percent": 82.0},
    ]
    result = PredictionEngine.predict(session_id=5, history_results=history, target_accuracy=90.0)
    assert result.predicted_value is not None
    assert result.predicted_value > 0.0
    assert result.confidence_score > 0.0
    assert result.model_version == "linreg-v1"

def test_prediction_engine_declining_or_flat_trend():
    history = [
        {"accuracy_percent": 70.0},
        {"accuracy_percent": 65.0},
        {"accuracy_percent": 60.0},
        {"accuracy_percent": 58.0},
        {"accuracy_percent": 55.0},
    ]
    result = PredictionEngine.predict(session_id=5, history_results=history)
    assert result.predicted_value is None
    assert "belum terdeteksi" in result.notes.lower()
