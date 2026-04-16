from __future__ import annotations

from dataclasses import dataclass
from datetime import timedelta

from fastapi import Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.models import OpsOperatorSession
from app.schemas import OpsEnvironmentView
from app.security import create_session_token, utcnow
from app.security_internal import expected_internal_admin_token

OPS_PROXY_SECRET_HEADER = 'X-Amon-Ops-Proxy-Secret'
OPS_OPERATOR_ID_HEADER = 'X-Amon-Operator-Id'


@dataclass
class OpsOperatorContext:
    operator_id: str
    auth_method: str
    session: OpsOperatorSession


def ops_environment_view() -> OpsEnvironmentView:
    settings = get_settings()
    return OpsEnvironmentView(
        key=settings.ops_environment_key,
        label=settings.ops_environment_label,
        app_env=settings.app_env,
    )


def ops_dev_token_login_enabled() -> bool:
    settings = get_settings()
    return bool(settings.ops_allow_dev_token_login or settings.app_env == 'development')


def _validate_operator_id(operator_id: str) -> str:
    normalized = operator_id.strip()
    if len(normalized) < 3:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail='Operator identifier is too short.')
    settings = get_settings()
    if settings.ops_allowed_operator_ids and normalized not in settings.ops_allowed_operator_ids:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail='Operator is not allowed for ops access.')
    return normalized


def create_ops_session(
    *,
    db: Session,
    response: Response,
    operator_id: str,
    auth_method: str,
) -> OpsOperatorSession:
    settings = get_settings()
    now = utcnow()
    session = OpsOperatorSession(
        id=create_session_token(),
        operator_id=_validate_operator_id(operator_id),
        environment=settings.ops_environment_key,
        auth_method=auth_method,
        issued_at=now,
        expires_at=now + timedelta(hours=settings.ops_session_ttl_hours),
        last_seen_at=now,
    )
    db.add(session)
    db.commit()
    response.set_cookie(
        key=settings.ops_session_cookie_name,
        value=session.id,
        httponly=True,
        samesite=settings.ops_session_cookie_same_site,
        secure=settings.resolved_ops_session_cookie_secure(),
        domain=settings.ops_session_cookie_domain,
        path='/ops',
        expires=int(session.expires_at.timestamp()),
    )
    return session


def clear_ops_session(response: Response, session: OpsOperatorSession | None = None, db: Session | None = None) -> None:
    settings = get_settings()
    if session is not None and db is not None and session.revoked_at is None:
        session.revoked_at = utcnow()
        db.add(session)
        db.commit()
    response.delete_cookie(
        key=settings.ops_session_cookie_name,
        path='/ops',
    )


def _resolve_proxy_operator(
    *,
    request: Request,
) -> tuple[str, str] | None:
    settings = get_settings()
    expected_secret = settings.ops_trusted_proxy_secret
    if not expected_secret:
        return None
    provided_secret = request.headers.get(OPS_PROXY_SECRET_HEADER)
    operator_id = request.headers.get(OPS_OPERATOR_ID_HEADER)
    if provided_secret != expected_secret or not operator_id:
        return None
    return _validate_operator_id(operator_id), 'trusted_proxy'


def resolve_ops_operator_from_cookie(
    *,
    db: Session,
    session_token: str | None,
) -> OpsOperatorContext | None:
    if not session_token:
        return None
    session = db.get(OpsOperatorSession, session_token)
    now = utcnow()
    if session is None or session.revoked_at is not None or session.expires_at < now:
        return None
    session.last_seen_at = now
    db.add(session)
    db.commit()
    return OpsOperatorContext(
        operator_id=session.operator_id,
        auth_method=session.auth_method,
        session=session,
    )


def maybe_bootstrap_ops_operator(
    *,
    request: Request,
    response: Response,
    db: Session,
) -> OpsOperatorContext | None:
    settings = get_settings()
    ops_session = request.cookies.get(settings.ops_session_cookie_name)
    from_cookie = resolve_ops_operator_from_cookie(db=db, session_token=ops_session)
    if from_cookie is not None:
        return from_cookie

    proxied = _resolve_proxy_operator(request=request)
    if proxied is None:
        return None

    operator_id, auth_method = proxied
    session = create_ops_session(db=db, response=response, operator_id=operator_id, auth_method=auth_method)
    return OpsOperatorContext(operator_id=operator_id, auth_method=auth_method, session=session)


async def get_optional_ops_operator(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
) -> OpsOperatorContext | None:
    return maybe_bootstrap_ops_operator(request=request, response=response, db=db)


async def require_ops_operator(
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
) -> OpsOperatorContext:
    operator = maybe_bootstrap_ops_operator(request=request, response=response, db=db)
    if operator is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Operator session required.',
        )
    return operator


def validate_dev_ops_token(admin_token: str) -> None:
    settings = get_settings()
    if not ops_dev_token_login_enabled():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Dev token ops login is disabled in this environment.',
        )
    expected = expected_internal_admin_token(settings)
    if expected is None or admin_token != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid ops development token.',
        )
