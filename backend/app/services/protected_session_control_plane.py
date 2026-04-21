from __future__ import annotations

import asyncio
from urllib.parse import urlparse

import httpx

from app.config import Settings, get_settings
from app.schemas import (
    InternalProtectedEventFeed,
    InternalProtectedOverview,
    InternalProtectedPolicyCounters,
    InternalProtectedQuotaCounters,
    InternalProtectedSessionsOverview,
    InternalProtectedStreamCounters,
    InternalProtectedTerminationCounters,
    InternalProtectedWorkersOverview,
    OpsEnvironmentView,
    ProtectedSessionActionRequest,
    ProtectedSessionEventView,
    ProtectedSessionMetadataView,
    ProtectedSessionOpsHistoricalSummary,
    ProtectedSessionOpsSnapshotSeries,
    ProtectedSessionState,
    ProtectedSessionWorkerView,
    ServeDecisionResponse,
)
from app.security import CurrentAccessContext, create_record_id, utcnow
from app.services.protected_session_events import ProtectedSessionEventSink
from app.services.protected_session_ops_history import ProtectedSessionOpsHistoryStore
from app.services.protected_session_policy import ProtectedSessionPolicyEngine, ServeDecision, normalize_host
from app.services.protected_session_registry import ProtectedSessionMetadataRegistry
from app.services.protected_session_workers import ProtectedSessionWorkerRegistry
from app.services.protected_sessions import (
    ProtectedSessionEndResponse,
    ProtectedSessionError,
    ProtectedSessionManager,
    ProtectedSessionRuntime,
)


class ProtectedSessionControlPlane:
    def __init__(
        self,
        *,
        settings: Settings | None = None,
        transport: httpx.AsyncBaseTransport | None = None,
        policy_engine: ProtectedSessionPolicyEngine | None = None,
        registry: ProtectedSessionMetadataRegistry | None = None,
        workers: ProtectedSessionWorkerRegistry | None = None,
        events: ProtectedSessionEventSink | None = None,
        history_store: ProtectedSessionOpsHistoryStore | None = None,
        manager: ProtectedSessionManager | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.policy_engine = policy_engine or ProtectedSessionPolicyEngine(self.settings)
        self.registry = registry or ProtectedSessionMetadataRegistry()
        self.workers = workers or ProtectedSessionWorkerRegistry(self.settings)
        self.history_store = history_store or ProtectedSessionOpsHistoryStore(settings=self.settings)
        self.events = events or ProtectedSessionEventSink(self.settings, history_store=self.history_store)
        self.manager = manager or ProtectedSessionManager(
            settings=self.settings,
            transport=transport,
            policy_engine=self.policy_engine,
            event_sink=self.events,
            on_session_started=self._on_runtime_started,
            on_session_terminal=self._on_runtime_terminal,
            on_state_updated=self._on_runtime_updated,
        )
        self._stream_lock = asyncio.Lock()

    async def shutdown(self) -> None:
        await self.manager.shutdown()

    def environment_view(self) -> OpsEnvironmentView:
        return self.history_store.environment_view()

    async def decide_url_open(
        self,
        *,
        current: CurrentAccessContext,
        url: str,
        intent: str = 'open',
    ) -> ServeDecisionResponse:
        decision = self.policy_engine.decide_url_open(url, intent=intent, current_user=current)
        self._record_decision_event(current=current, decision=decision, domain=self._domain_for(url))
        return self._decision_response(decision)

    async def create_session(self, *, current: CurrentAccessContext, url: str) -> ProtectedSessionState:
        decision = self.policy_engine.decide_url_open(url, intent='protected_session', current_user=current)
        domain = self._domain_for(url)
        self._record_decision_event(current=current, decision=decision, domain=domain)
        if decision.disposition != 'ALLOW_PROTECTED':
            if decision.disposition == 'DENY':
                raise self._serve_decision_error(decision)
            raise ProtectedSessionError(
                409,
                'protected_session_local_only',
                'Protected Session is not available for that destination in this build. Open it locally instead.',
            )

        quota = self.policy_engine.quota_profile_for(current)
        self._enforce_session_start_quotas(current=current, domain=domain, decision=decision, quota=quota)

        planned_session_id = create_record_id('protected')
        worker = self.workers.assign_session(planned_session_id)
        if worker is None:
            self.events.record(
                'quota_rejected',
                session_id=planned_session_id,
                user_id=current.user.id,
                domain=domain,
                reason_code='worker_capacity_exhausted',
                disposition=decision.disposition,
                budget_tier=decision.budget_tier,
            )
            raise ProtectedSessionError(
                503,
                'protected_session_worker_capacity_exhausted',
                'Protected Session is at capacity right now. Open that site locally for now.',
            )

        self.registry.register_session(
            session_id=planned_session_id,
            user_id=current.user.id,
            domain=domain,
            state='creating',
            policy_decision=decision,
            quota_metadata=quota,
            worker_id=worker.worker_id,
            worker_type=worker.worker_type,
        )
        self.events.record(
            'session_created',
            session_id=planned_session_id,
            user_id=current.user.id,
            domain=domain,
            worker_id=worker.worker_id,
            state='creating',
            disposition=decision.disposition,
            budget_tier=decision.budget_tier,
        )
        self.events.record(
            'worker_assigned',
            session_id=planned_session_id,
            user_id=current.user.id,
            domain=domain,
            worker_id=worker.worker_id,
            state='creating',
            disposition=decision.disposition,
            budget_tier=decision.budget_tier,
        )

        try:
            created = await self.manager.create_session(
                user_id=current.user.id,
                url=url,
                session_id=planned_session_id,
                worker=worker,
            )
            self._capture_history_snapshot_if_due(force=True)
            return created
        except ProtectedSessionError as exc:
            self.workers.release_session(planned_session_id)
            metadata = self.registry.get(planned_session_id)
            if metadata is not None and metadata.state not in {'failed', 'closed', 'expired'}:
                self.registry.mark_state(planned_session_id, state='failed', termination_reason=exc.code)
                self.events.record(
                    'session_failed',
                    session_id=planned_session_id,
                    user_id=current.user.id,
                    domain=domain,
                    reason_code=exc.code,
                    state='failed',
                    worker_id=worker.worker_id,
                    disposition=decision.disposition,
                    budget_tier=decision.budget_tier,
                )
            self._capture_history_snapshot_if_due(force=True)
            raise

    async def get_state(self, *, current: CurrentAccessContext, session_id: str) -> ProtectedSessionState:
        self._assert_session_owned_by_user(session_id=session_id, user_id=current.user.id)
        state = await self.manager.get_state(user_id=current.user.id, session_id=session_id)
        self.registry.mark_state(session_id, state=state.status)
        self.registry.touch_activity(session_id)
        return state

    async def apply_action(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        action: ProtectedSessionActionRequest,
        expected_content_revision: int | None = None,
        source_action_id: str | None = None,
    ) -> ProtectedSessionState:
        metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
        max_actions = int(metadata.quota_metadata['max_actions_per_session'])
        if metadata.action_count >= max_actions:
            self.events.record(
                'quota_rejected',
                session_id=session_id,
                user_id=current.user.id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                reason_code='session_action_limit',
                state=metadata.state,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            raise ProtectedSessionError(
                429,
                'protected_session_action_limit_reached',
                'That protected session reached its action limit for this build.',
            )

        state = await self.manager.apply_action(
            user_id=current.user.id,
            session_id=session_id,
            action=action,
            expected_content_revision=expected_content_revision,
            source_action_id=source_action_id,
        )
        self.registry.increment_action_count(session_id)
        self.registry.mark_state(session_id, state=state.status)
        self._capture_history_snapshot_if_due()
        return state

    async def end_session(self, *, current: CurrentAccessContext, session_id: str) -> ProtectedSessionEndResponse:
        self._assert_session_owned_by_user(session_id=session_id, user_id=current.user.id)
        self.registry.mark_state(session_id, state='terminating')
        result = await self.manager.end_session(user_id=current.user.id, session_id=session_id)
        self._capture_history_snapshot_if_due(force=True)
        return result

    async def subscribe_stream(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        last_stream_sequence: int | None = None,
    ):
        async with self._stream_lock:
            metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
            self._enforce_live_stream_limits(current=current, metadata=metadata)
            worker_ok, worker_reason = self.workers.stream_attach_state(metadata.worker_id or '')
            if not worker_ok:
                event_type = 'stream_worker_degraded' if worker_reason == 'worker_degraded' else 'stream_capacity_rejected'
                self.events.record(
                    event_type,
                    session_id=session_id,
                    user_id=current.user.id,
                    domain=metadata.domain,
                    worker_id=metadata.worker_id,
                    reason_code=worker_reason,
                    state=metadata.state,
                    disposition=metadata.policy_decision.disposition,
                    budget_tier=metadata.policy_decision.budget_tier,
                )
                if worker_reason == 'worker_degraded':
                    raise ProtectedSessionError(
                        503,
                        'protected_session_stream_worker_degraded',
                        'The protected-session stream worker is degraded right now. Try again shortly or open locally.',
                    )
                raise ProtectedSessionError(
                    503,
                    'protected_session_stream_capacity_exhausted',
                    'Protected Session has no live stream capacity right now. Try again shortly or open locally.',
                )

            runtime, subscriber, subscribed = await self.manager.subscribe_stream(
                user_id=current.user.id,
                session_id=session_id,
                last_stream_sequence=last_stream_sequence,
            )

            attached = self.workers.attach_stream(metadata.worker_id or '')
            if not attached:
                runtime.unsubscribe_stream(subscriber)
                self.events.record(
                    'stream_capacity_rejected',
                    session_id=session_id,
                    user_id=current.user.id,
                    domain=metadata.domain,
                    worker_id=metadata.worker_id,
                    reason_code='worker_stream_capacity_exhausted',
                    state=metadata.state,
                    disposition=metadata.policy_decision.disposition,
                    budget_tier=metadata.policy_decision.budget_tier,
                )
                raise ProtectedSessionError(
                    503,
                    'protected_session_stream_capacity_exhausted',
                    'Protected Session has no live stream capacity right now. Try again shortly or open locally.',
                )

            attempted_resume = last_stream_sequence is not None
            resumed = bool(subscribed.get('resumed'))
            self.registry.attach_stream(
                session_id,
                attempted_resume=attempted_resume,
                resumed=resumed,
            )
            self.registry.mark_runtime(
                session_id,
                worker_state='attached',
                worker_health='healthy',
            )
            self.events.record(
                'stream_resumed' if resumed else ('stream_reconnect_missed' if attempted_resume else 'stream_attached'),
                session_id=session_id,
                user_id=current.user.id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                state=metadata.state,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            self._capture_history_snapshot_if_due()
            return runtime, subscriber, subscribed

    async def note_stream_detached(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        reason_code: str = 'stream_detached',
        heartbeat_timeout: bool = False,
    ) -> None:
        async with self._stream_lock:
            metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
            self.registry.detach_stream(session_id, heartbeat_timeout=heartbeat_timeout)
            self.registry.mark_runtime(
                session_id,
                worker_state='detached',
                worker_health=metadata.worker_health or 'healthy',
            )
            if metadata.worker_id is not None:
                self.workers.detach_stream(metadata.worker_id, heartbeat_timeout=heartbeat_timeout)
            self.events.record(
                'stream_detached',
                session_id=session_id,
                user_id=current.user.id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                reason_code=reason_code,
                state=metadata.state,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            if heartbeat_timeout:
                self.events.record(
                    'stream_heartbeat_timeout',
                    session_id=session_id,
                    user_id=current.user.id,
                    domain=metadata.domain,
                    worker_id=metadata.worker_id,
                    reason_code=reason_code,
                    state=metadata.state,
                    disposition=metadata.policy_decision.disposition,
                    budget_tier=metadata.policy_decision.budget_tier,
                )
            self._capture_history_snapshot_if_due()

    async def note_stream_dropped_events(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        count: int,
    ) -> None:
        if count <= 0:
            return
        metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
        self.registry.note_dropped_events(session_id, count)
        self.events.record(
            'stream_dropped_events',
            session_id=session_id,
            user_id=current.user.id,
            domain=metadata.domain,
            worker_id=metadata.worker_id,
            state=metadata.state,
            disposition=metadata.policy_decision.disposition,
            budget_tier=metadata.policy_decision.budget_tier,
            metric_value=count,
        )
        self._capture_history_snapshot_if_due()

    async def note_stream_protocol_error(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        code: str,
    ) -> None:
        metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
        self.registry.note_protocol_error(session_id, code)
        if metadata.worker_id is not None:
            self.workers.note_protocol_error(metadata.worker_id)
        self.events.record(
            'stream_protocol_error',
            session_id=session_id,
            user_id=current.user.id,
            domain=metadata.domain,
            worker_id=metadata.worker_id,
            reason_code=code,
            state=metadata.state,
            disposition=metadata.policy_decision.disposition,
            budget_tier=metadata.policy_decision.budget_tier,
        )
        self._capture_history_snapshot_if_due()

    async def note_stream_action_ack(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        status: str,
        reason_code: str | None = None,
    ) -> None:
        metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
        self.registry.note_action_ack(session_id, status=status)
        self.events.record(
            f'stream_action_ack_{status}',
            session_id=session_id,
            user_id=current.user.id,
            domain=metadata.domain,
            worker_id=metadata.worker_id,
            reason_code=reason_code,
            state=metadata.state,
            disposition=metadata.policy_decision.disposition,
            budget_tier=metadata.policy_decision.budget_tier,
        )
        self._capture_history_snapshot_if_due()

    async def note_stream_action_result(
        self,
        *,
        current: CurrentAccessContext,
        session_id: str,
        status: str,
        duration_ms: int,
        reason_code: str | None = None,
    ) -> None:
        metadata = self._session_metadata_for_user(session_id=session_id, user_id=current.user.id)
        self.registry.note_action_result(session_id, status=status, duration_ms=duration_ms)
        self.events.record(
            f'stream_action_{status}',
            session_id=session_id,
            user_id=current.user.id,
            domain=metadata.domain,
            worker_id=metadata.worker_id,
            reason_code=reason_code,
            state=metadata.state,
            disposition=metadata.policy_decision.disposition,
            budget_tier=metadata.policy_decision.budget_tier,
            duration_ms=duration_ms,
        )
        self._capture_history_snapshot_if_due()

    def sessions_overview(self) -> InternalProtectedSessionsOverview:
        sessions = [ProtectedSessionMetadataView(**self.registry.to_view_dict(item)) for item in self.registry.list_sessions()]
        state_counts = self.registry.state_counts()
        active_sessions = sum(count for state, count in state_counts.items() if state in {'creating', 'active', 'terminating'})
        return InternalProtectedSessionsOverview(
            total_sessions=len(sessions),
            active_sessions=active_sessions,
            state_counts=state_counts,
            sessions=sessions,
        )

    def active_sessions_overview(self) -> InternalProtectedSessionsOverview:
        sessions = [
            ProtectedSessionMetadataView(**self.registry.to_view_dict(item))
            for item in self.registry.list_sessions()
            if item.state in {'creating', 'active', 'terminating'}
        ]
        state_counts: dict[str, int] = {}
        for item in sessions:
            state_counts[item.state] = state_counts.get(item.state, 0) + 1
        return InternalProtectedSessionsOverview(
            total_sessions=len(sessions),
            active_sessions=len(sessions),
            state_counts=state_counts,
            sessions=sessions,
        )

    def overview(self) -> InternalProtectedOverview:
        quota = self.quota_counters()
        stream = self.stream_counters()
        workers = self.workers_overview()
        sessions = self.sessions_overview()
        return InternalProtectedOverview(
            generated_at=utcnow(),
            total_sessions=sessions.total_sessions,
            active_sessions=sessions.active_sessions,
            active_streams=stream.active_streams_total,
            users_with_active_sessions=quota.users_with_active_sessions,
            users_with_live_streams=stream.users_with_live_streams,
            total_workers=workers.total_workers,
            healthy_workers=self.workers.healthy_count(),
            degraded_workers=self.workers.degraded_count(),
            total_worker_capacity=workers.total_capacity,
            total_worker_stream_capacity=workers.total_stream_capacity,
            total_assigned_sessions=workers.total_assigned_sessions,
            quota_rejections_total=quota.total_rejections,
            protocol_errors_total=stream.protocol_error_count,
            heartbeat_timeouts_total=stream.heartbeat_timeout_count,
            dropped_events_total=stream.dropped_events_total,
        )

    def session_detail(self, session_id: str) -> ProtectedSessionMetadataView:
        metadata = self.registry.get(session_id)
        if metadata is None:
            raise ProtectedSessionError(404, 'protected_session_missing', 'That protected session is no longer available.')
        return ProtectedSessionMetadataView(**self.registry.to_view_dict(metadata))

    def workers_overview(self) -> InternalProtectedWorkersOverview:
        workers = [ProtectedSessionWorkerView(**self.workers.to_view_dict(worker)) for worker in self.workers.overview()]
        return InternalProtectedWorkersOverview(
            total_workers=len(workers),
            total_capacity=self.workers.total_capacity(),
            total_stream_capacity=self.workers.total_stream_capacity(),
            total_assigned_sessions=self.workers.total_assigned_sessions(),
            total_active_streams=self.workers.total_active_streams(),
            workers=workers,
        )

    def policy_counters(self) -> InternalProtectedPolicyCounters:
        recent_events = [
            ProtectedSessionEventView(**event)
            for event in self.events.to_views(self.events.recent_events(limit=25))
        ]
        return InternalProtectedPolicyCounters(
            policy_decisions=self.events.decision_counts(),
            event_counts=self.events.event_counts(),
            reason_counts=self.events.reason_counts(),
            recent_events=recent_events,
        )

    def quota_counters(self) -> InternalProtectedQuotaCounters:
        quota_rejections = self.events.quota_rejections()
        active_sessions = self.registry.active_user_count()
        total_active_sessions = len(
            [
                metadata
                for metadata in self.registry.list_sessions()
                if metadata.state in {'creating', 'active', 'terminating'}
            ]
        )
        return InternalProtectedQuotaCounters(
            quota_rejections=quota_rejections,
            total_rejections=sum(quota_rejections.values()),
            active_sessions_total=total_active_sessions,
            users_with_active_sessions=active_sessions,
        )

    def stream_counters(self) -> InternalProtectedStreamCounters:
        counters = self.registry.stream_counters()
        return InternalProtectedStreamCounters(
            **counters,
            protocol_error_codes=self.events.stream_error_counts(),
            worker_assignments=self.workers.assignment_count(),
            worker_releases=self.workers.release_count(),
            total_live_stream_capacity=self.workers.total_stream_capacity(),
        )

    def termination_counters(self) -> InternalProtectedTerminationCounters:
        event_counts = self.events.event_counts()
        terminal_event_counts = {
            event_type: event_counts.get(event_type, 0)
            for event_type in ('session_ended', 'session_expired', 'session_failed')
            if event_counts.get(event_type, 0) > 0
        }
        terminal_reason_counts = self.events.terminal_reason_counts()
        failure_reason_counts = {
            reason: count
            for reason, count in terminal_reason_counts.items()
            if reason in {'protected_session_failed', 'session_failed'}
        }
        return InternalProtectedTerminationCounters(
            terminal_event_counts=terminal_event_counts,
            terminal_reason_counts=terminal_reason_counts,
            failure_reason_counts=failure_reason_counts,
        )

    def events_feed(self, *, limit: int = 50) -> InternalProtectedEventFeed:
        recent_events = [
            ProtectedSessionEventView(**event)
            for event in self.events.to_views(self.events.recent_events(limit=limit))
        ]
        return InternalProtectedEventFeed(
            total_events=len(recent_events),
            events=recent_events,
        )

    def historical_events_feed(self, *, limit: int = 50) -> InternalProtectedEventFeed:
        events = self.history_store.recent_events(limit=limit)
        return InternalProtectedEventFeed(
            total_events=len(events),
            events=events,
        )

    def historical_snapshot_series(self, *, limit: int = 72) -> ProtectedSessionOpsSnapshotSeries:
        return self.history_store.snapshot_series(limit=limit)

    def historical_summary(self, *, window_hours: int = 24) -> ProtectedSessionOpsHistoricalSummary:
        return self.history_store.historical_summary(window_hours=window_hours)

    async def _on_runtime_started(self, runtime: ProtectedSessionRuntime) -> None:
        metadata = self.registry.get(runtime.id)
        if metadata is None:
            return
        self.registry.mark_state(runtime.id, state=runtime.status.value)
        self.registry.mark_runtime(
            runtime.id,
            runtime_kind=runtime.worker.worker_type,
            worker_state=runtime.stream_session.worker_state,
            worker_health=runtime.stream_session.health,
            frame_revision=runtime.stream_session.current_frame.revision if runtime.stream_session.current_frame else None,
            frames_emitted=runtime.stream_session.frames_emitted,
            last_frame_at=runtime.stream_session.last_frame_at,
        )
        self.events.record(
            'session_started',
            session_id=runtime.id,
            user_id=runtime.user_id,
            domain=metadata.domain,
            worker_id=metadata.worker_id,
            state=runtime.status.value,
            disposition=metadata.policy_decision.disposition,
            budget_tier=metadata.policy_decision.budget_tier,
        )
        self._capture_history_snapshot_if_due()

    async def _on_runtime_terminal(self, runtime: ProtectedSessionRuntime, detail_message: str) -> None:
        metadata = self.registry.get(runtime.id)
        if metadata is not None:
            terminal_reason_code = {
                'closed': 'session_closed',
                'expired': 'session_expired',
                'failed': 'protected_session_failed',
            }.get(runtime.status.value, 'session_closed')
            self.registry.mark_state(runtime.id, state=runtime.status.value, termination_reason=terminal_reason_code)
            self.registry.mark_runtime(
                runtime.id,
                runtime_kind=runtime.worker.worker_type,
                worker_state=runtime.stream_session.worker_state,
                worker_health=runtime.stream_session.health,
                frame_revision=runtime.stream_session.current_frame.revision if runtime.stream_session.current_frame else metadata.frame_revision,
                frames_emitted=runtime.stream_session.frames_emitted,
                last_frame_at=runtime.stream_session.last_frame_at,
            )
            self.workers.release_session(runtime.id)
            event_type = {
                'closed': 'session_ended',
                'expired': 'session_expired',
                'failed': 'session_failed',
            }.get(runtime.status.value, 'session_failed')
            self.events.record(
                event_type,
                session_id=runtime.id,
                user_id=runtime.user_id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                reason_code=terminal_reason_code,
                state=runtime.status.value,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            self.events.record(
                'worker_released',
                session_id=runtime.id,
                user_id=runtime.user_id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                reason_code=terminal_reason_code,
                state=runtime.status.value,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
        self._capture_history_snapshot_if_due(force=True)

    async def _on_runtime_updated(
        self,
        runtime: ProtectedSessionRuntime,
        state: ProtectedSessionState,
        event: str,
    ) -> None:
        metadata = self.registry.get(runtime.id)
        if metadata is None:
            return
        prior_revision = metadata.frame_revision
        self.registry.mark_state(runtime.id, state=state.status)
        self.registry.mark_runtime(
            runtime.id,
            runtime_kind=state.runtime_kind,
            worker_state=state.worker_state,
            worker_health=state.worker_health,
            frame_revision=state.current_frame.revision if state.current_frame is not None else metadata.frame_revision,
            frames_emitted=runtime.stream_session.frames_emitted,
            last_frame_at=runtime.stream_session.last_frame_at,
        )
        if (
            event == 'state'
            and state.current_frame is not None
            and state.current_frame.revision != prior_revision
        ):
            self.registry.note_state_update(runtime.id, frame_updated=True)
            self.events.record(
                'frame_emitted',
                session_id=runtime.id,
                user_id=runtime.user_id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                state=state.status,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            self._capture_history_snapshot_if_due()
            return
        self.registry.note_state_update(runtime.id, frame_updated=False)
        self._capture_history_snapshot_if_due()

    def _enforce_session_start_quotas(
        self,
        *,
        current: CurrentAccessContext,
        domain: str,
        decision: ServeDecision,
        quota: dict[str, int | str],
    ) -> None:
        user_id = current.user.id
        active_sessions = self.registry.active_sessions_for_user(user_id)
        if len(active_sessions) >= int(quota['max_concurrent_sessions_per_user']):
            self.events.record(
                'quota_rejected',
                user_id=user_id,
                domain=domain,
                reason_code='concurrent_session_limit',
                disposition=decision.disposition,
                budget_tier=decision.budget_tier,
            )
            raise ProtectedSessionError(
                429,
                'protected_session_concurrent_limit',
                'Too many protected sessions are already active for this account.',
            )

        recent_starts = self.registry.recent_session_starts_for_user(
            user_id,
            window_seconds=int(quota['session_start_window_seconds']),
        )
        if len(recent_starts) >= int(quota['max_session_starts_per_window']):
            self.events.record(
                'quota_rejected',
                user_id=user_id,
                domain=domain,
                reason_code='session_start_rate_limit',
                disposition=decision.disposition,
                budget_tier=decision.budget_tier,
            )
            raise ProtectedSessionError(
                429,
                'protected_session_start_rate_limited',
                'Too many protected session starts were requested recently for this account.',
            )

    def _enforce_live_stream_limits(self, *, current: CurrentAccessContext, metadata) -> None:
        user_live_streams = self.registry.active_streams_for_user(current.user.id)
        if user_live_streams >= self.settings.protected_session_max_live_streams_per_user:
            self.events.record(
                'quota_rejected',
                session_id=metadata.session_id,
                user_id=current.user.id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                reason_code='live_stream_user_limit',
                state=metadata.state,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            raise ProtectedSessionError(
                429,
                'protected_session_live_stream_limit',
                'Too many live protected-session streams are already open for this account.',
            )

        if self.registry.active_streams_total() >= self.settings.protected_session_max_live_streams:
            self.events.record(
                'quota_rejected',
                session_id=metadata.session_id,
                user_id=current.user.id,
                domain=metadata.domain,
                worker_id=metadata.worker_id,
                reason_code='live_stream_global_limit',
                state=metadata.state,
                disposition=metadata.policy_decision.disposition,
                budget_tier=metadata.policy_decision.budget_tier,
            )
            raise ProtectedSessionError(
                503,
                'protected_session_live_stream_capacity_exhausted',
                'Protected Session has reached its live stream capacity right now. Try again shortly or open locally.',
            )

    def _assert_session_owned_by_user(self, *, session_id: str, user_id: str) -> None:
        metadata = self.registry.get(session_id)
        if metadata is None:
            return
        if metadata.user_id != user_id:
            raise ProtectedSessionError(404, 'protected_session_missing', 'That protected session is no longer available.')

    def _session_metadata_for_user(self, *, session_id: str, user_id: str):
        metadata = self.registry.get(session_id)
        if metadata is None or metadata.user_id != user_id:
            raise ProtectedSessionError(404, 'protected_session_missing', 'That protected session is no longer available.')
        return metadata

    def _record_decision_event(
        self,
        *,
        current: CurrentAccessContext,
        decision: ServeDecision,
        domain: str | None,
    ) -> None:
        if decision.disposition == 'DENY':
            event_type = 'decision_deny'
        elif decision.disposition == 'RECOMMEND_PROTECTED':
            event_type = 'decision_recommend_protected'
        elif decision.disposition in {'ALLOW_LOCAL', 'ALLOW_CLEAN_VIEW'}:
            event_type = 'decision_local_only'
        else:
            return
        self.events.record(
            event_type,
            user_id=current.user.id,
            domain=domain,
            reason_code=decision.reason_code,
            disposition=decision.disposition,
            budget_tier=decision.budget_tier,
        )

    def _capture_history_snapshot_if_due(self, *, force: bool = False) -> None:
        self.history_store.maybe_capture_snapshot(self.overview(), force=force)

    @staticmethod
    def _decision_response(decision: ServeDecision) -> ServeDecisionResponse:
        return ServeDecisionResponse(
            disposition=decision.disposition,
            reason_code=decision.reason_code,
            confidence=decision.confidence,
            policy_version=decision.policy_version,
            site_class=decision.site_class,
            budget_tier=decision.budget_tier,
        )

    @staticmethod
    def _domain_for(url: str) -> str:
        return normalize_host(urlparse(url).hostname or '')

    @staticmethod
    def _serve_decision_error(decision: ServeDecision) -> ProtectedSessionError:
        if decision.reason_code == 'blocked_address':
            return ProtectedSessionError(
                403,
                'protected_session_blocked_address',
                'That destination is blocked in a protected session.',
            )
        if decision.reason_code in {'invalid_url', 'credentialed_url_blocked'}:
            return ProtectedSessionError(
                400,
                'protected_session_invalid_url',
                'That URL cannot be opened in a protected session.',
            )
        if decision.reason_code == 'invalid_port':
            return ProtectedSessionError(
                400,
                'protected_session_invalid_port',
                'That destination is not allowed in a protected session.',
            )
        return ProtectedSessionError(
            403,
            'protected_session_denied',
            'Protected Session is not allowed for that destination in this build.',
        )


_protected_session_control_plane: ProtectedSessionControlPlane | None = None


def get_protected_session_control_plane() -> ProtectedSessionControlPlane:
    global _protected_session_control_plane
    if _protected_session_control_plane is None or getattr(_protected_session_control_plane.manager, '_is_shutdown', False):
        _protected_session_control_plane = ProtectedSessionControlPlane()
    return _protected_session_control_plane
