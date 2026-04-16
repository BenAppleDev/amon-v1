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
    ProtectedSessionOpsHistoricalSummary,
    ProtectedSessionOpsSnapshotSeries,
)
from app.security_ops import OpsOperatorContext, require_ops_operator
from app.services.protected_session_control_plane import get_protected_session_control_plane
from app.services.protected_sessions import ProtectedSessionError

router = APIRouter(prefix='/ops/api/protected-sessions', tags=['ops_protected_sessions'])


@router.get('/overview', response_model=InternalProtectedOverview)
async def ops_protected_overview(_: OpsOperatorContext = Depends(require_ops_operator)) -> InternalProtectedOverview:
    return get_protected_session_control_plane().overview()


@router.get('/sessions', response_model=InternalProtectedSessionsOverview)
async def ops_protected_sessions(_: OpsOperatorContext = Depends(require_ops_operator)) -> InternalProtectedSessionsOverview:
    return get_protected_session_control_plane().sessions_overview()


@router.get('/sessions/active', response_model=InternalProtectedSessionsOverview)
async def ops_protected_active_sessions(
    _: OpsOperatorContext = Depends(require_ops_operator),
) -> InternalProtectedSessionsOverview:
    return get_protected_session_control_plane().active_sessions_overview()


@router.get('/sessions/{session_id}', response_model=ProtectedSessionMetadataView)
async def ops_protected_session_detail(
    session_id: str,
    _: OpsOperatorContext = Depends(require_ops_operator),
) -> ProtectedSessionMetadataView:
    try:
        return get_protected_session_control_plane().session_detail(session_id)
    except ProtectedSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.get('/workers', response_model=InternalProtectedWorkersOverview)
async def ops_protected_workers(_: OpsOperatorContext = Depends(require_ops_operator)) -> InternalProtectedWorkersOverview:
    return get_protected_session_control_plane().workers_overview()


@router.get('/counters/policy', response_model=InternalProtectedPolicyCounters)
async def ops_protected_policy(_: OpsOperatorContext = Depends(require_ops_operator)) -> InternalProtectedPolicyCounters:
    return get_protected_session_control_plane().policy_counters()


@router.get('/counters/quota', response_model=InternalProtectedQuotaCounters)
async def ops_protected_quota(_: OpsOperatorContext = Depends(require_ops_operator)) -> InternalProtectedQuotaCounters:
    return get_protected_session_control_plane().quota_counters()


@router.get('/counters/stream', response_model=InternalProtectedStreamCounters)
async def ops_protected_stream(_: OpsOperatorContext = Depends(require_ops_operator)) -> InternalProtectedStreamCounters:
    return get_protected_session_control_plane().stream_counters()


@router.get('/counters/terminations', response_model=InternalProtectedTerminationCounters)
async def ops_protected_terminations(
    _: OpsOperatorContext = Depends(require_ops_operator),
) -> InternalProtectedTerminationCounters:
    return get_protected_session_control_plane().termination_counters()


@router.get('/events', response_model=InternalProtectedEventFeed)
async def ops_protected_events(
    limit: int = Query(default=50, ge=1, le=200),
    _: OpsOperatorContext = Depends(require_ops_operator),
) -> InternalProtectedEventFeed:
    return get_protected_session_control_plane().historical_events_feed(limit=limit)


@router.get('/history/summary', response_model=ProtectedSessionOpsHistoricalSummary)
async def ops_protected_history_summary(
    hours: int = Query(default=24, ge=1, le=168),
    _: OpsOperatorContext = Depends(require_ops_operator),
) -> ProtectedSessionOpsHistoricalSummary:
    return get_protected_session_control_plane().historical_summary(window_hours=hours)


@router.get('/history/snapshots', response_model=ProtectedSessionOpsSnapshotSeries)
async def ops_protected_history_snapshots(
    limit: int = Query(default=72, ge=1, le=240),
    _: OpsOperatorContext = Depends(require_ops_operator),
) -> ProtectedSessionOpsSnapshotSeries:
    return get_protected_session_control_plane().historical_snapshot_series(limit=limit)
