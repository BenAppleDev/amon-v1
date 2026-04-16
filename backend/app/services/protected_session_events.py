from __future__ import annotations

from collections import Counter, deque
from dataclasses import dataclass
from typing import Iterable

from app.config import Settings, get_settings
from app.security import create_record_id, utcnow


@dataclass(frozen=True)
class ProtectedSessionEvent:
    event_id: str
    event_type: str
    occurred_at: object
    session_id: str | None = None
    user_id: str | None = None
    domain: str | None = None
    worker_id: str | None = None
    reason_code: str | None = None
    state: str | None = None
    disposition: str | None = None
    budget_tier: str | None = None
    metric_value: int | None = None
    duration_ms: int | None = None


class ProtectedSessionEventSink:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self._events: deque[ProtectedSessionEvent] = deque(maxlen=self.settings.protected_session_event_buffer_size)
        self._event_counts: Counter[str] = Counter()
        self._reason_counts: Counter[str] = Counter()
        self._decision_counts: Counter[str] = Counter()
        self._quota_rejections: Counter[str] = Counter()
        self._terminal_reason_counts: Counter[str] = Counter()
        self._stream_error_counts: Counter[str] = Counter()
        self._duration_totals: Counter[str] = Counter()
        self._duration_counts: Counter[str] = Counter()

    def record(
        self,
        event_type: str,
        *,
        session_id: str | None = None,
        user_id: str | None = None,
        domain: str | None = None,
        worker_id: str | None = None,
        reason_code: str | None = None,
        state: str | None = None,
        disposition: str | None = None,
        budget_tier: str | None = None,
        metric_value: int | None = None,
        duration_ms: int | None = None,
    ) -> ProtectedSessionEvent:
        event = ProtectedSessionEvent(
            event_id=create_record_id('psevt'),
            event_type=event_type,
            occurred_at=utcnow(),
            session_id=session_id,
            user_id=user_id,
            domain=domain,
            worker_id=worker_id,
            reason_code=reason_code,
            state=state,
            disposition=disposition,
            budget_tier=budget_tier,
            metric_value=metric_value,
            duration_ms=duration_ms,
        )
        self._events.appendleft(event)
        self._event_counts[event_type] += 1
        if reason_code:
            self._reason_counts[reason_code] += 1
            if event_type in {'session_ended', 'session_expired', 'session_failed'}:
                self._terminal_reason_counts[reason_code] += 1
            if event_type in {'stream_protocol_error', 'stream_heartbeat_timeout', 'stream_worker_degraded', 'stream_capacity_rejected'}:
                self._stream_error_counts[reason_code] += 1
        if disposition and event_type.startswith('decision_'):
            self._decision_counts[disposition] += 1
        if event_type == 'quota_rejected':
            self._quota_rejections[reason_code or 'unknown'] += 1
        if duration_ms is not None and duration_ms >= 0:
            self._duration_totals[event_type] += duration_ms
            self._duration_counts[event_type] += 1
        return event

    def recent_events(self, *, limit: int = 50) -> list[ProtectedSessionEvent]:
        return list(self._events)[:limit]

    def event_counts(self) -> dict[str, int]:
        return dict(self._event_counts)

    def reason_counts(self) -> dict[str, int]:
        return dict(self._reason_counts)

    def decision_counts(self) -> dict[str, int]:
        return dict(self._decision_counts)

    def quota_rejections(self) -> dict[str, int]:
        return dict(self._quota_rejections)

    def terminal_reason_counts(self) -> dict[str, int]:
        return dict(self._terminal_reason_counts)

    def stream_error_counts(self) -> dict[str, int]:
        return dict(self._stream_error_counts)

    def average_duration_ms(self, event_type: str) -> float | None:
        count = self._duration_counts.get(event_type, 0)
        if count <= 0:
            return None
        return float(self._duration_totals[event_type]) / float(count)

    @staticmethod
    def to_views(events: Iterable[ProtectedSessionEvent]) -> list[dict[str, object | None]]:
        return [
            {
                'event_id': event.event_id,
                'event_type': event.event_type,
                'occurred_at': event.occurred_at,
                'session_id': event.session_id,
                'user_id': event.user_id,
                'domain': event.domain,
                'worker_id': event.worker_id,
                'reason_code': event.reason_code,
                'state': event.state,
                'disposition': event.disposition,
                'budget_tier': event.budget_tier,
                'metric_value': event.metric_value,
                'duration_ms': event.duration_ms,
            }
            for event in events
        ]
