import hmac
import hashlib
from typing import Optional
from fastapi import HTTPException, Header, status
from app.core.config import settings

def verify_webhook_signature(
    x_webhook_secret: Optional[str] = Header(None, alias="X-Webhook-Secret")
) -> bool:
    """
    Memverifikasi secret webhook dari Supabase Database Webhook atau Edge Function.
    Jika WEBHOOK_SECRET tidak diset, validasi diabaikan (mode pengembangan).
    """
    if not settings.WEBHOOK_SECRET:
        return True

    if not x_webhook_secret:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Header X-Webhook-Secret wajib disertakan."
        )

    # Constant-time comparison untuk mencegah timing attack
    if not hmac.compare_digest(x_webhook_secret, settings.WEBHOOK_SECRET):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="X-Webhook-Secret tidak valid."
        )
    return True
