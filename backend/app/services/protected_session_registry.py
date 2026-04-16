from __future__ import annotations

from dataclasses import dataclass, field
from datetime import timedelta

from app.security import utcnow
from app.services.protected_session_policy import ServeDecision


@dataclass
class ProtectedSessionMetadata:
    session_id: str
    user_id: str
    domain: str
    state: str
    created_at: object
    last_activity_at: object
    action_count: int
    termination_reason: str | None
    policy_decision: ServeDecision
    quota_metadata: dict[str, int | str]
    worker_id: str | None = None
    worker_type: str | None = None
    runtime_kind: str | None = None
    worker_state: str | None = None
    worker_health: str | None = None
    frame_revision: int | None = None
    frames_emitted: int = 0
    last_frame_at: object | None = None
    active_streams: int = 0
    total_stream_attaches: int = 0
    total_stream_detaches: int = 0
    reconnect_attempts: int = 0
    successful_resumes: int = 0
    heartbeat_timeout_count: int = 0
    dropped_events_total: int = 0
    protocol_error_count: int = 0
    last_protocol_error_code: str | None = None
    state_update_count: int = 0
    frame_update_count: int = 0
    action_ack_accepted_count: int = 0
    action_ack_failed_count: int = 0
    action_ack_rejected_count: int = 0
    action_completed_count: int = 0
    action_failed_count: int = 0
    total_action_duration_ms: int = 0
    last_action_duration_ms: int | None = None
    last_stream_attached_at: object | None = None
    last_stream_detached_at: object | None = None


class ProtectedSessionMetadataRegistry:
    def __init__(self) -> None:
        self._sessions: dict[str, ProtectedSessionMetadata] = {}
        self._user_session_starts: dict[str, list[object]] = {}

    def register_session(
        self,
        *,
        session_id: str,
        user_id: str,
        domain: str,
        state: str,
        policy_decision: ServeDecision,
        quota_metadata: dict[str, int | str],
        worker_id: str | None = None,
        worker_type: str | None = None,
    ) -> ProtectedSessionMetadata:
        now = utcnow()
        metadata = ProtectedSessionMetadata(
            session_id=session_id,
            user_id=user_id,
            domain=domain,
            state=state,
            created_at=now,
            last_activity_at=now,
            action_count=0,
            termination_reason=None,
            policy_decision=policy_decision,
            quota_metadata=dict(quota_metadata),
            worker_id=worker_id,
            worker_type=worker_type,
            runtime_kind=worker_type,
        )
        self._sessions[session_id] = metadata
        self._user_session_starts.setdefault(user_id, []).append(now)
        return metadata

    def mark_state(
        self,
        session_id: str,
        *,
        state: str,
        termination_reason: str | None = None,
    ) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        metadata.state = state
        metadata.last_activity_at = utcnow()
        if termination_reason is not None:
            metadata.termination_reason = termination_reason
        if state in {'closed', 'expired', 'failed'}:
            metadata.active_streams = 0

    def increment_action_count(self, session_id: str) -> int:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return 0
        metadata.action_count += 1
        metadata.last_activity_at = utcnow()
        return metadata.action_count

    def touch_activity(self, session_id: str) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        metadata.last_activity_at = utcnow()

    def mark_runtime(
        self,
        session_id: str,
        *,
        runtime_kind: str | None = None,
        worker_state: str | None = None,
        worker_health: str | None = None,
        frame_revision: int | None = None,
        frames_emitted: int | None = None,
        last_frame_at: object | None = None,
    ) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        metadata.last_activity_at = utcnow()
        if runtime_kind is not None:
            metadata.runtime_kind = runtime_kind
        if worker_state is not None:
            metadata.worker_state = worker_state
        if worker_health is not None:
            metadata.worker_health = worker_health
        if frame_revision is not None:
            metadata.frame_revision = frame_revision
        if frames_emitted is not None:
            metadata.frames_emitted = frames_emitted
        if last_frame_at is not None:
            metadata.last_frame_at = last_frame_at

    def attach_stream(
        self,
        session_id: str,
        *,
        attempted_resume: bool = False,
        resumed: bool = False,
    ) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        now = utcnow()
        metadata.active_streams += 1
        metadata.total_stream_attaches += 1
        metadata.last_stream_attached_at = now
        metadata.last_activity_at = now
        if attempted_resume:
            metadata.reconnect_attempts += 1
        if resumed:
            metadata.successful_resumes += 1

    def detach_stream(
        self,
        session_id: str,
        *,
        heartbeat_timeout: bool = False,
    ) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        now = utcnow()
        if metadata.active_streams > 0:
            metadata.active_streams -= 1
        metadata.total_stream_detaches += 1
        metadata.last_stream_detached_at = now
        metadata.last_activity_at = now
        if heartbeat_timeout:
            metadata.heartbeat_timeout_count += 1

    def note_dropped_events(self, session_id: str, count: int) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None or count <= 0:
            return
        metadata.dropped_events_total += count
        metadata.last_activity_at = utcnow()

    def note_protocol_error(self, session_id: str, code: str) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        metadata.protocol_error_count += 1
        metadata.last_protocol_error_code = code
        metadata.last_activity_at = utcnow()

    def note_state_update(self, session_id: str, *, frame_updated: bool) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        metadata.state_update_count += 1
        if frame_updated:
            metadata.frame_update_count += 1
        metadata.last_activity_at = utcnow()

    def note_action_ack(self, session_id: str, *, status: str) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        if status == 'accepted':
            metadata.action_ack_accepted_count += 1
        elif status == 'failed':
            metadata.action_ack_failed_count += 1
        elif status == 'rejected':
            metadata.action_ack_rejected_count += 1
        metadata.last_activity_at = utcnow()

    def note_action_result(self, session_id: str, *, status: str, duration_ms: int) -> None:
        metadata = self._sessions.get(session_id)
        if metadata is None:
            return
        if status == 'completed':
            metadata.action_completed_count += 1
        elif status == 'failed':
            metadata.action_failed_count += 1
        if duration_ms >= 0:
            metadata.total_action_duration_ms += duration_ms
            metadata.last_action_duration_ms = duration_ms
        metadata.last_activity_at = utcnow()

    def get(self, session_id: str) -> ProtectedSessionMetadata | None:
        return self._sessions.get(session_id)

    def list_sessions(self) -> list[ProtectedSessionMetadata]:
        return sorted(self._sessions.values(), key=lambda item: item.created_at, reverse=True)

    def active_sessions_for_user(self, user_id: str) -> list[ProtectedSessionMetadata]:
        return [
            metadata
            for metadata in self._sessions.values()
            if metadata.user_id == user_id and metadata.state in {'creating', 'active', 'terminating'}
        ]

    def recent_session_starts_for_user(self, user_id: str, *, window_seconds: int) -> list[object]:
        now = utcnow()
        cutoff = now - timedelta(seconds=window_seconds)
        starts = [timestamp for timestamp in self._user_session_starts.get(user_id, []) if timestamp >= cutoff]
        self._user_session_starts[user_id] = starts
        return starts

    def active_user_count(self) -> int:
        return len({metadata.user_id for metadata in self._sessions.values() if metadata.state in {'creating', 'active', 'terminating'}})

    def active_streams_total(self) -> int:
        return sum(metadata.active_streams for metadata in self._sessions.values())

    def active_streams_for_user(self, user_id: str) -> int:
        return sum(metadata.active_streams for metadata in self._sessions.values() if metadata.user_id == user_id)

    def users_with_live_streams_count(self) -> int:
        return len({metadata.user_id for metadata in self._sessions.values() if metadata.active_streams > 0})

    def state_counts(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for metadata in self._sessions.values():
            counts[metadata.state] = counts.get(metadata.state, 0) + 1
        return counts

    def stream_counters(self) -> dict[str, object]:
        ack_counts = {
            'accepted': 0,
            'failed': 0,
            'rejected': 0,
        }
        action_result_counts = {
            'completed': 0,
            'failed': 0,
        }
        total_duration = 0
        total_duration_count = 0
        total_attaches = 0
        total_detaches = 0
        total_reconnect_attempts = 0
        total_successful_resumes = 0
        heartbeat_timeouts = 0
        dropped_events_total = 0
        protocol_error_count = 0
        state_update_count = 0
        frame_update_count = 0
        for metadata in self._sessions.values():
            total_attaches += metadata.total_stream_attaches
            total_detaches += metadata.total_stream_detaches
            total_reconnect_attempts += metadata.reconnect_attempts
            total_successful_resumes += metadata.successful_resumes
            heartbeat_timeouts += metadata.heartbeat_timeout_count
            dropped_events_total += metadata.dropped_events_total
            protocol_error_count += metadata.protocol_error_count
            state_update_count += metadata.state_update_count
            frame_update_count += metadata.frame_update_count
            ack_counts['accepted'] += metadata.action_ack_accepted_count
            ack_counts['failed'] += metadata.action_ack_failed_count
            ack_counts['rejected'] += metadata.action_ack_rejected_count
            action_result_counts['completed'] += metadata.action_completed_count
            action_result_counts['failed'] += metadata.action_failed_count
            completed_actions = metadata.action_completed_count + metadata.action_failed_count
            if completed_actions > 0:
                total_duration += metadata.total_action_duration_ms
                total_duration_count += completed_actions
        average_action_duration_ms = (
            float(total_duration) / float(total_duration_count)
            if total_duration_count > 0
            else None
        )
        return {
            'active_streams_total': self.active_streams_total(),
            'users_with_live_streams': self.users_with_live_streams_count(),
            'attach_count': total_attaches,
            'detach_count': total_detaches,
            'reconnect_attempts': total_reconnect_attempts,
            'successful_resumes': total_successful_resumes,
            'heartbeat_timeout_count': heartbeat_timeouts,
            'dropped_events_total': dropped_events_total,
            'protocol_error_count': protocol_error_count,
            'state_update_count': state_update_count,
            'frame_update_count': frame_update_count,
            'action_ack_counts': ack_counts,
            'action_result_counts': action_result_counts,
            'average_action_duration_ms': average_action_duration_ms,
        }

    def termination_reason_counts(self) -> dict[str, int]:
        counts: dict[str, int] = {}
        for metadata in self._sessions.values():
            if not metadata.termination_reason:
                continue
            counts[metadata.termination_reason] = counts.get(metadata.termination_reason, 0) + 1
        return counts

    @staticmethod
    def to_view_dict(metadata: ProtectedSessionMetadata) -> dict[str, object]:
        return {
            'session_id': metadata.session_id,
            'user_id': metadata.user_id,
            'domain': metadata.domain,
            'state': metadata.state,
            'created_at': metadata.created_at,
            'last_activity_at': metadata.last_activity_at,
            'action_count': metadata.action_count,
            'termination_reason': metadata.termination_reason,
            'policy': {
                'disposition': metadata.policy_decision.disposition,
                'reason_code': metadata.policy_decision.reason_code,
                'confidence': metadata.policy_decision.confidence,
                'policy_version': metadata.policy_decision.policy_version,
                'site_class': metadata.policy_decision.site_class,
                'budget_tier': metadata.policy_decision.budget_tier,
            },
            'quota': dict(metadata.quota_metadata),
            'worker_id': metadata.worker_id,
            'worker_type': metadata.worker_type,
            'runtime_kind': metadata.runtime_kind,
            'worker_state': metadata.worker_state,
            'worker_health': metadata.worker_health,
            'frame_revision': metadata.frame_revision,
            'frames_emitted': metadata.frames_emitted,
            'last_frame_at': metadata.last_frame_at,
            'active_streams': metadata.active_streams,
            'total_stream_attaches': metadata.total_stream_attaches,
            'total_stream_detaches': metadata.total_stream_detaches,
            'reconnect_attempts': metadata.reconnect_attempts,
            'successful_resumes': metadata.successful_resumes,
            'heartbeat_timeout_count': metadata.heartbeat_timeout_count,
            'dropped_events_total': metadata.dropped_events_total,
            'protocol_error_count': metadata.protocol_error_count,
            'last_protocol_error_code': metadata.last_protocol_error_code,
            'state_update_count': metadata.state_update_count,
            'frame_update_count': metadata.frame_update_count,
            'action_ack_accepted_count': metadata.action_ack_accepted_count,
            'action_ack_failed_count': metadata.action_ack_failed_count,
            'action_ack_rejected_count': metadata.action_ack_rejected_count,
            'action_completed_count': metadata.action_completed_count,
            'action_failed_count': metadata.action_failed_count,
            'average_action_duration_ms': (
                float(metadata.total_action_duration_ms) / float(metadata.action_completed_count + metadata.action_failed_count)
                if (metadata.action_completed_count + metadata.action_failed_count) > 0
                else None
            ),
            'last_action_duration_ms': metadata.last_action_duration_ms,
            'last_stream_attached_at': metadata.last_stream_attached_at,
            'last_stream_detached_at': metadata.last_stream_detached_at,
        }
