from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from app.schemas import (
    InternalProtectedEventFeed,
    InternalProtectedOverview,
    InternalProtectedPolicyCounters,
    InternalProtectedQuotaCounters,
    InternalProtectedSessionsOverview,
    InternalProtectedStreamCounters,
    InternalProtectedTerminationCounters,
    InternalProtectedWorkersOverview,
    ProtectedSessionMetadataView,
)
from app.security_internal import require_internal_admin
from app.services.protected_session_control_plane import get_protected_session_control_plane
from app.services.protected_sessions import ProtectedSessionError

router = APIRouter(prefix='/internal/protected-sessions', tags=['internal_protected_sessions'])


@router.get('/overview', response_model=InternalProtectedOverview)
async def protected_overview(_: None = Depends(require_internal_admin)) -> InternalProtectedOverview:
    control_plane = get_protected_session_control_plane()
    return control_plane.overview()


@router.get('/sessions', response_model=InternalProtectedSessionsOverview)
async def protected_sessions_overview(_: None = Depends(require_internal_admin)) -> InternalProtectedSessionsOverview:
    control_plane = get_protected_session_control_plane()
    return control_plane.sessions_overview()


@router.get('/sessions/active', response_model=InternalProtectedSessionsOverview)
async def protected_active_sessions(_: None = Depends(require_internal_admin)) -> InternalProtectedSessionsOverview:
    control_plane = get_protected_session_control_plane()
    return control_plane.active_sessions_overview()


@router.get('/sessions/{session_id}', response_model=ProtectedSessionMetadataView)
async def protected_session_detail(session_id: str, _: None = Depends(require_internal_admin)) -> ProtectedSessionMetadataView:
    control_plane = get_protected_session_control_plane()
    try:
        return control_plane.session_detail(session_id)
    except ProtectedSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.get('/workers', response_model=InternalProtectedWorkersOverview)
async def protected_workers_overview(_: None = Depends(require_internal_admin)) -> InternalProtectedWorkersOverview:
    control_plane = get_protected_session_control_plane()
    return control_plane.workers_overview()


@router.get('/counters/policy', response_model=InternalProtectedPolicyCounters)
async def protected_policy_counters(_: None = Depends(require_internal_admin)) -> InternalProtectedPolicyCounters:
    control_plane = get_protected_session_control_plane()
    return control_plane.policy_counters()


@router.get('/counters/quota', response_model=InternalProtectedQuotaCounters)
async def protected_quota_counters(_: None = Depends(require_internal_admin)) -> InternalProtectedQuotaCounters:
    control_plane = get_protected_session_control_plane()
    return control_plane.quota_counters()


@router.get('/counters/stream', response_model=InternalProtectedStreamCounters)
async def protected_stream_counters(_: None = Depends(require_internal_admin)) -> InternalProtectedStreamCounters:
    control_plane = get_protected_session_control_plane()
    return control_plane.stream_counters()


@router.get('/counters/terminations', response_model=InternalProtectedTerminationCounters)
async def protected_termination_counters(_: None = Depends(require_internal_admin)) -> InternalProtectedTerminationCounters:
    control_plane = get_protected_session_control_plane()
    return control_plane.termination_counters()


@router.get('/events', response_model=InternalProtectedEventFeed)
async def protected_recent_events(
    limit: int = Query(default=50, ge=1, le=200),
    _: None = Depends(require_internal_admin),
) -> InternalProtectedEventFeed:
    control_plane = get_protected_session_control_plane()
    return control_plane.events_feed(limit=limit)
