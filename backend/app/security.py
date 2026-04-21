from __future__ import annotations

from datetime import UTC, datetime, timedelta
from secrets import token_urlsafe
from uuid import uuid4

from fastapi import Depends, Header, HTTPException, status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import Entitlement, ProductSessionRecord, SessionRecord, User


def utcnow() -> datetime:
    return datetime.now(UTC).replace(tzinfo=None)


def create_user_id() -> str:
    return f'user_{uuid4().hex}'


def create_record_id(prefix: str) -> str:
    return f'{prefix}_{uuid4().hex}'


def create_session_token() -> str:
    return token_urlsafe(32)


class CurrentAccessContext:
    def __init__(
        self,
        *,
        account: User | None = None,
        entitlement: Entitlement,
        auth_session: SessionRecord | None = None,
        product_session: ProductSessionRecord | None = None,
        user: User | None = None,
        session: SessionRecord | None = None,
    ) -> None:
        resolved_account = account or user
        resolved_auth_session = auth_session or session
        if resolved_account is None or resolved_auth_session is None:
            raise ValueError('CurrentAccessContext requires account/auth_session or legacy user/session values.')

        self.account = resolved_account
        self.entitlement = entitlement
        self.auth_session = resolved_auth_session
        self.product_session = product_session

    @property
    def access_grant(self) -> Entitlement:
        return self.entitlement

    @property
    def user(self) -> User:
        return self.account

    @property
    def session(self) -> SessionRecord:
        return self.auth_session


# Compatibility alias while callers migrate from the old name.
CurrentUser = CurrentAccessContext


def extract_bearer_token(authorization: str | None) -> str:
    if not authorization or not authorization.lower().startswith('bearer '):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Missing bearer token')
    return authorization.split(' ', 1)[1].strip()


def resolve_current_access_context_from_token(token: str, db: Session) -> CurrentAccessContext:
    product_session = db.get(ProductSessionRecord, token)
    now = utcnow()

    if (
        product_session is None
        or product_session.revoked_at is not None
        or product_session.expires_at < now
    ):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid or expired session')

    auth_session = db.get(SessionRecord, product_session.auth_session_id)
    if (
        auth_session is None
        or auth_session.user_id != product_session.account_id
        or auth_session.revoked_at is not None
        or auth_session.expires_at < now
    ):
        _revoke_product_session(product_session, db)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid or expired session')

    account = db.get(User, product_session.account_id)
    entitlement = db.get(Entitlement, product_session.entitlement_id)
    if (
        account is None
        or entitlement is None
        or entitlement.user_id != product_session.account_id
    ):
        _revoke_product_session(product_session, db)
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail='Invalid session state')

    product_session.last_seen_at = now
    db.add(product_session)
    db.commit()

    return CurrentAccessContext(
        account=account,
        entitlement=entitlement,
        auth_session=auth_session,
        product_session=product_session,
    )


def resolve_current_user_from_token(token: str, db: Session) -> CurrentAccessContext:
    return resolve_current_access_context_from_token(token, db)


async def get_current_access_context(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> CurrentAccessContext:
    token = extract_bearer_token(authorization)
    return resolve_current_access_context_from_token(token, db)


async def get_current_user(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
) -> CurrentAccessContext:
    return await get_current_access_context(authorization=authorization, db=db)


def build_auth_session_record(user_id: str) -> SessionRecord:
    settings = get_settings()
    now = utcnow()
    return SessionRecord(
        id=create_session_token(),
        user_id=user_id,
        issued_at=now,
        expires_at=now + timedelta(hours=settings.session_ttl_hours),
    )


def build_product_session_record(
    *,
    account_id: str,
    entitlement_id: str,
    auth_session_id: str,
    expires_at: datetime,
) -> ProductSessionRecord:
    now = utcnow()
    return ProductSessionRecord(
        id=create_session_token(),
        account_id=account_id,
        auth_session_id=auth_session_id,
        entitlement_id=entitlement_id,
        issued_at=now,
        expires_at=expires_at,
        last_seen_at=now,
    )


def build_session_record(user_id: str) -> SessionRecord:
    return build_auth_session_record(user_id)


def _revoke_product_session(product_session: ProductSessionRecord, db: Session) -> None:
    if product_session.revoked_at is None:
        product_session.revoked_at = utcnow()
        db.add(product_session)
        db.commit()
