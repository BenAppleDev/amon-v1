from __future__ import annotations

from datetime import timedelta
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.models import RateLimitWindow
from app.security import utcnow


class RateLimiter:
    def __init__(self, db: Session) -> None:
        self.db = db
        self.settings = get_settings()

    def check_and_increment(self, user_id: str) -> None:
        now = utcnow().replace(second=0, microsecond=0)
        window_start = now
        window_end = now + timedelta(minutes=1)

        record = (
            self.db.query(RateLimitWindow)
            .filter(
                RateLimitWindow.user_id == user_id,
                RateLimitWindow.window_start == window_start,
            )
            .first()
        )

        if record is None:
            record = RateLimitWindow(
                id=f'rl_{uuid4().hex}',
                user_id=user_id,
                window_start=window_start,
                window_end=window_end,
                request_count=0,
            )
            self.db.add(record)

        if record.request_count >= self.settings.requests_per_minute:
            self.db.commit()
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail='Rate limit exceeded for current window',
            )

        record.request_count += 1
        self.db.commit()
