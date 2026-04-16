from __future__ import annotations

from collections import Counter
from datetime import timedelta
from threading import Lock
from typing import Callable

from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.db import SessionLocal
from app.models import ProtectedSessionOpsEventRecord, ProtectedSessionOpsSnapshotRecord
from app.schemas import (
    InternalProtectedOverview,
    OpsEnvironmentView,
    ProtectedSessionEventView,
    ProtectedSessionOpsHistoricalSummary,
    ProtectedSessionOpsSnapshotSeries,
    ProtectedSessionOpsSnapshotView,
)
from app.security import create_record_id, utcnow
from app.services.protected_session_events import ProtectedSessionEvent


SessionFactory = Callable[[], Session]


class ProtectedSessionOpsHistoryStore:
    def __init__(
        self,
        *,
        settings: Settings | None = None,
        session_factory: SessionFactory | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.session_factory = session_factory or SessionLocal
        self._snapshot_lock = Lock()
        self._last_snapshot_at = None

    def persist_event(self, event: ProtectedSessionEvent) -> None:
        with self.session_factory() as db:
            existing = db.get(ProtectedSessionOpsEventRecord, event.event_id)
            if existing is not None:
                return
            db.add(
                ProtectedSessionOpsEventRecord(
                    event_id=event.event_id,
                    environment=self.settings.ops_environment_key,
                    occurred_at=event.occurred_at,
                    event_type=event.event_type,
                    session_id=event.session_id,
                    user_id=event.user_id,
                    domain=event.domain,
                    worker_id=event.worker_id,
                    reason_code=event.reason_code,
                    state=event.state,
                    disposition=event.disposition,
                    budget_tier=event.budget_tier,
                    metric_value=event.metric_value,
                    duration_ms=event.duration_ms,
                )
            )
            db.commit()

    def maybe_capture_snapshot(self, overview: InternalProtectedOverview, *, force: bool = False) -> None:
        now = utcnow()
        with self._snapshot_lock:
            if not force and self._last_snapshot_at is not None:
                elapsed = (now - self._last_snapshot_at).total_seconds()
                if elapsed < max(1, self.settings.ops_history_snapshot_interval_seconds):
                    return
            self._last_snapshot_at = now

        with self.session_factory() as db:
            db.add(
                ProtectedSessionOpsSnapshotRecord(
                    id=create_record_id('opssnap'),
                    environment=self.settings.ops_environment_key,
                    recorded_at=now,
                    total_sessions=overview.total_sessions,
                    active_sessions=overview.active_sessions,
                    active_streams=overview.active_streams,
                    users_with_active_sessions=overview.users_with_active_sessions,
                    users_with_live_streams=overview.users_with_live_streams,
                    total_workers=overview.total_workers,
                    healthy_workers=overview.healthy_workers,
                    degraded_workers=overview.degraded_workers,
                    total_worker_capacity=overview.total_worker_capacity,
                    total_worker_stream_capacity=overview.total_worker_stream_capacity,
                    total_assigned_sessions=overview.total_assigned_sessions,
                    quota_rejections_total=overview.quota_rejections_total,
                    protocol_errors_total=overview.protocol_errors_total,
                    heartbeat_timeouts_total=overview.heartbeat_timeouts_total,
                    dropped_events_total=overview.dropped_events_total,
                )
            )
            db.commit()

    def recent_events(self, *, limit: int = 50) -> list[ProtectedSessionEventView]:
        with self.session_factory() as db:
            rows = (
                db.query(ProtectedSessionOpsEventRecord)
                .filter(ProtectedSessionOpsEventRecord.environment == self.settings.ops_environment_key)
                .order_by(ProtectedSessionOpsEventRecord.occurred_at.desc())
                .limit(limit)
                .all()
            )
        return [self._event_view(row) for row in rows]

    def snapshot_series(self, *, limit: int = 72) -> ProtectedSessionOpsSnapshotSeries:
        with self.session_factory() as db:
            rows = (
                db.query(ProtectedSessionOpsSnapshotRecord)
                .filter(ProtectedSessionOpsSnapshotRecord.environment == self.settings.ops_environment_key)
                .order_by(ProtectedSessionOpsSnapshotRecord.recorded_at.desc())
                .limit(limit)
                .all()
            )
        snapshots = [self._snapshot_view(row) for row in reversed(rows)]
        return ProtectedSessionOpsSnapshotSeries(
            environment=self.environment_view(),
            snapshots=snapshots,
        )

    def historical_summary(self, *, window_hours: int = 24) -> ProtectedSessionOpsHistoricalSummary:
        window_hours = max(1, window_hours)
        cutoff = utcnow() - timedelta(hours=window_hours)

        with self.session_factory() as db:
            event_rows = (
                db.query(ProtectedSessionOpsEventRecord)
                .filter(
                    ProtectedSessionOpsEventRecord.environment == self.settings.ops_environment_key,
                    ProtectedSessionOpsEventRecord.occurred_at >= cutoff,
                )
                .order_by(ProtectedSessionOpsEventRecord.occurred_at.desc())
                .all()
            )
            latest_snapshot_row = (
                db.query(ProtectedSessionOpsSnapshotRecord)
                .filter(ProtectedSessionOpsSnapshotRecord.environment == self.settings.ops_environment_key)
                .order_by(ProtectedSessionOpsSnapshotRecord.recorded_at.desc())
                .first()
            )

        event_counts: Counter[str] = Counter()
        reason_counts: Counter[str] = Counter()
        terminal_reason_counts: Counter[str] = Counter()
        stream_error_counts: Counter[str] = Counter()

        for row in event_rows:
            event_counts[row.event_type] += 1
            if row.reason_code:
                reason_counts[row.reason_code] += 1
                if row.event_type in {'session_ended', 'session_expired', 'session_failed'}:
                    terminal_reason_counts[row.reason_code] += 1
                if row.event_type in {
                    'stream_protocol_error',
                    'stream_heartbeat_timeout',
                    'stream_worker_degraded',
                    'stream_capacity_rejected',
                }:
                    stream_error_counts[row.reason_code] += 1

        return ProtectedSessionOpsHistoricalSummary(
            environment=self.environment_view(),
            window_hours=window_hours,
            total_events=len(event_rows),
            event_counts=dict(event_counts),
            reason_counts=dict(reason_counts),
            terminal_reason_counts=dict(terminal_reason_counts),
            stream_error_counts=dict(stream_error_counts),
            latest_snapshot=self._snapshot_view(latest_snapshot_row) if latest_snapshot_row is not None else None,
        )

    def environment_view(self) -> OpsEnvironmentView:
        return OpsEnvironmentView(
            key=self.settings.ops_environment_key,
            label=self.settings.ops_environment_label,
            app_env=self.settings.app_env,
        )

    @staticmethod
    def _event_view(row: ProtectedSessionOpsEventRecord) -> ProtectedSessionEventView:
        return ProtectedSessionEventView(
            event_id=row.event_id,
            event_type=row.event_type,
            occurred_at=row.occurred_at,
            session_id=row.session_id,
            user_id=row.user_id,
            domain=row.domain,
            worker_id=row.worker_id,
            reason_code=row.reason_code,
            state=row.state,
            disposition=row.disposition,
            budget_tier=row.budget_tier,
            metric_value=row.metric_value,
            duration_ms=row.duration_ms,
        )

    @staticmethod
    def _snapshot_view(row: ProtectedSessionOpsSnapshotRecord) -> ProtectedSessionOpsSnapshotView:
        return ProtectedSessionOpsSnapshotView(
            recorded_at=row.recorded_at,
            environment=row.environment,
            total_sessions=row.total_sessions,
            active_sessions=row.active_sessions,
            active_streams=row.active_streams,
            users_with_active_sessions=row.users_with_active_sessions,
            users_with_live_streams=row.users_with_live_streams,
            total_workers=row.total_workers,
            healthy_workers=row.healthy_workers,
            degraded_workers=row.degraded_workers,
            total_worker_capacity=row.total_worker_capacity,
            total_worker_stream_capacity=row.total_worker_stream_capacity,
            total_assigned_sessions=row.total_assigned_sessions,
            quota_rejections_total=row.quota_rejections_total,
            protocol_errors_total=row.protocol_errors_total,
            heartbeat_timeouts_total=row.heartbeat_timeouts_total,
            dropped_events_total=row.dropped_events_total,
        )
