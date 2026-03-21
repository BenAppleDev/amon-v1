from __future__ import annotations

from datetime import UTC, datetime, timedelta
from secrets import token_urlsafe
from uuid import uuid4

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import Entitlement, SessionRecord, User


def utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def create_user_id() -> str:
    return f'user_{uuid4().hex}'


def create_record_id(prefix: str) -> str:
    return f'{prefix}_{uuid4().hex}'


def create_session_token() -> str:
    return token_urlsafe(32)


class CurrentUser:
    def __init__(self, user: User, entitlement: Entitlement, session: SessionRecord) -> None:
        self.user = user
        self.entitlement = entitlement
        self.session = session


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> CurrentUser:
    if not authorization or not authorization.lower().startswith('bearer '):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Missing bearer token')

    token = authorization.split(' ', 1)[1].strip()
    session_record = db.get(SessionRecord, token)
    now = utcnow()

    if not session_record or session_record.revoked_at is not None or session_record.expires_at < now:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid or expired session')

    user = db.get(User, session_record.user_id)
    entitlement = (
        db.query(Entitlement)
        .filter(Entitlement.user_id == session_record.user_id)
        .order_by(Entitlement.created_at.desc())
        .first()
    )
    if not user or not entitlement:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session state')

    return CurrentUser(user=user, entitlement=entitlement, session=session_record)


def build_session_record(user_id: str) -> SessionRecord:
    settings = get_settings()
    now = utcnow()
    return SessionRecord(
        id=create_session_token(),
        user_id=user_id,
        issued_at=now,
        expires_at=now + timedelta(hours=settings.session_ttl_hours),
    )
