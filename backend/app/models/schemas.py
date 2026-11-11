from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime

class WebhookRecord(BaseModel):
    session_id: int
    user_id: Optional[int] = None
    device_id: Optional[int] = None
    mode_id: Optional[int] = None
    session_status: str
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    created_at: Optional[datetime] = None

class SessionCompletedWebhook(BaseModel):
    type: Optional[str] = "UPDATE"
    table: Optional[str] = "training_session"
    record: Optional[WebhookRecord] = None
    session_id: Optional[int] = None
    user_id: Optional[int] = None
    session_status: Optional[str] = None

class StepLogItem(BaseModel):
    step_log_id: Optional[int] = None
    session_id: int
    position_id: int
    step_number: int
    event_type: str  # target_hit, wrong_step, timeout
    is_correct: bool
    reaction_time_ms: Optional[int] = None
    event_at: datetime
    # Joined from tile_position
    side: Optional[str] = None  # L, C, R
    position_code: Optional[str] = None

class SessionFeatures(BaseModel):
    session_id: int
    total_steps: int
    correct_steps: int
    incorrect_steps: int
    accuracy_percent: float
    total_duration_ms: int
    average_reaction_ms: float
    left_right_ratio: Optional[float] = None
    layout_code: Optional[str] = None

class PredictionResult(BaseModel):
    session_id: int
    model_version: str = "linreg-v1"
    predicted_value: Optional[float] = None  # days to target
    prediction_unit: str = "days"
    confidence_score: float = 0.0
    notes: Optional[str] = None

class RecommendationResult(BaseModel):
    session_id: int
    recommended_mode: str
    recommended_tempo_ms: int
    recommendation_text: str

class FullAnalysisResult(BaseModel):
    session_id: int
    features: SessionFeatures
    prediction: PredictionResult
    recommendation: RecommendationResult
    processed_at: datetime = Field(default_factory=datetime.utcnow)

class HealthResponse(BaseModel):
    status: str
    version: str
    timestamp: datetime = Field(default_factory=datetime.utcnow)
