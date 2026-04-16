from __future__ import annotations

from fastapi import APIRouter, Depends, Response
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas import OpsAuthStatusResponse, OpsDevLoginRequest
from app.security_ops import (
    OpsOperatorContext,
    clear_ops_session,
    create_ops_session,
    get_optional_ops_operator,
    ops_dev_token_login_enabled,
    ops_environment_view,
    require_ops_operator,
    validate_dev_ops_token,
)

router = APIRouter(prefix='/ops/auth', tags=['ops_auth'])


def _status_payload(operator: OpsOperatorContext | None) -> OpsAuthStatusResponse:
    return OpsAuthStatusResponse(
        authenticated=operator is not None,
        environment=ops_environment_view(),
        operator_id=operator.operator_id if operator is not None else None,
        auth_method=operator.auth_method if operator is not None else None,
        session_expires_at=operator.session.expires_at if operator is not None else None,
        dev_token_login_enabled=ops_dev_token_login_enabled(),
    )


@router.get('/status', response_model=OpsAuthStatusResponse)
async def ops_auth_status(operator: OpsOperatorContext | None = Depends(get_optional_ops_operator)) -> OpsAuthStatusResponse:
    return _status_payload(operator)


@router.post('/session', response_model=OpsAuthStatusResponse)
async def ops_dev_login(
    payload: OpsDevLoginRequest,
    response: Response,
    db: Session = Depends(get_db),
) -> OpsAuthStatusResponse:
    validate_dev_ops_token(payload.admin_token)
    operator_id = payload.operator_id or 'dev-operator'
    session = create_ops_session(
        db=db,
        response=response,
        operator_id=operator_id,
        auth_method='dev_token',
    )
    operator = OpsOperatorContext(
        operator_id=session.operator_id,
        auth_method=session.auth_method,
        session=session,
    )
    return _status_payload(operator)


@router.post('/logout', response_model=OpsAuthStatusResponse)
async def ops_logout(
    response: Response,
    operator: OpsOperatorContext = Depends(require_ops_operator),
    db: Session = Depends(get_db),
) -> OpsAuthStatusResponse:
    clear_ops_session(response=response, session=operator.session, db=db)
    return _status_payload(None)
