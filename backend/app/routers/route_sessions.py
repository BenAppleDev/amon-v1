from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import RouteSessionRevokeResponse, RouteSessionState
from app.security import CurrentAccessContext, get_current_access_context
from app.services.route_session_control_plane import RouteSessionError, get_route_session_control_plane

router = APIRouter(prefix='/v1/route-sessions', tags=['route_sessions'])


@router.post('', response_model=RouteSessionState)
async def mint_route_session(
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> RouteSessionState:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_route_session_control_plane()
        return control_plane.mint_session(current=current, db=db)
    except RouteSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.post('/{session_id}/refresh', response_model=RouteSessionState)
async def refresh_route_session(
    session_id: str,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> RouteSessionState:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_route_session_control_plane()
        return control_plane.refresh_session(current=current, session_id=session_id, db=db)
    except RouteSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.delete('/{session_id}', response_model=RouteSessionRevokeResponse)
async def revoke_route_session(
    session_id: str,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> RouteSessionRevokeResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_route_session_control_plane()
        return control_plane.revoke_session(current=current, session_id=session_id, db=db)
    except RouteSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc
