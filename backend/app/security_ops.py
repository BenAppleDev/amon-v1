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
from app.security_ops_identity import resolve_trusted_upstream_identity


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


def ops_trusted_upstream_enabled() -> bool:
    settings = get_settings()
    return settings.resolved_ops_trusted_upstream_mode() != 'disabled'


def ops_trusted_upstream_mode() -> str:
    settings = get_settings()
    return settings.resolved_ops_trusted_upstream_mode()


def ops_dev_token_login_enabled() -> bool:
    settings = get_settings()
    return bool(expected_internal_admin_token(settings)) and bool(
        settings.ops_allow_dev_token_login or settings.app_env == 'development'
    )


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
        path=settings.resolved_ops_session_cookie_path(),
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
        path=settings.resolved_ops_session_cookie_path(),
    )


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

    upstream_result = resolve_trusted_upstream_identity(request=request, settings=settings)
    if upstream_result.rejected:
        raise HTTPException(
            status_code=upstream_result.failure_status_code or status.HTTP_401_UNAUTHORIZED,
            detail={
                'code': upstream_result.failure_code or 'trusted_upstream_identity_rejected',
                'message': upstream_result.failure_message or 'Trusted upstream identity assertion was rejected.',
            },
        )
    if upstream_result.identity is None:
        return None

    session = create_ops_session(
        db=db,
        response=response,
        operator_id=_validate_operator_id(upstream_result.identity.operator_id),
        auth_method=upstream_result.identity.auth_method,
    )
    return OpsOperatorContext(
        operator_id=session.operator_id,
        auth_method=upstream_result.identity.auth_method,
        session=session,
    )


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
