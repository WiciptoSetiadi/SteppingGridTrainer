from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import Optional

class Settings(BaseSettings):
    SUPABASE_URL: str = "http://localhost:54321"
    SUPABASE_SERVICE_ROLE_KEY: str = "placeholder-service-key"
    SUPABASE_ANON_KEY: Optional[str] = "placeholder-anon-key"
    WEBHOOK_SECRET: Optional[str] = None

    # AI & Prediction Configuration (SDD 3.2.9 & 3.2.10)
    MIN_SESSIONS_FOR_PREDICTION: int = 5
    TARGET_ACCURACY: float = 90.0
    MIN_TEMPO_MS: int = 600
    MAX_TEMPO_MS: int = 5000

    # Service Configuration
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = False
    APP_NAME: str = "Stepping Grid Trainer AI & Analytics Service"
    APP_VERSION: str = "1.0.0"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
