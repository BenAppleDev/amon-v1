from __future__ import annotations

import asyncio
from collections import deque
from dataclasses import dataclass, field
from html import escape
from typing import Any

from app.config import Settings, get_settings
from app.schemas import ProtectedSessionFrame, ProtectedSessionStreamServerMessage
from app.security import create_record_id, utcnow


@dataclass
class ProtectedSessionWorker:
    worker_id: str
    worker_type: str
    capacity: int
    stream_capacity: int
    state: str
    health: str = 'healthy'
    capabilities: tuple[str, ...] = ('snapshot_stream', 'dom_actions', 'lightweight_forms')
    assigned_sessions: set[str] = field(default_factory=set)
    active_streams: int = 0
    assignment_count: int = 0
    release_count: int = 0
    attach_count: int = 0
    detach_count: int = 0
    heartbeat_timeout_count: int = 0
    protocol_error_count: int = 0
    degraded_reason: str | None = None

    @property
    def assigned_count(self) -> int:
        return len(self.assigned_sessions)


class ProtectedSessionStreamSubscriber:
    def __init__(self, *, max_pending: int) -> None:
        self.id = create_record_id('pssub')
        self._messages: deque[dict[str, object | None]] = deque()
        self._max_pending = max_pending
        self._event = asyncio.Event()
        self._closed = False
        self._dropped_events = 0

    @property
    def dropped_events(self) -> int:
        return self._dropped_events

    def consume_dropped_events(self) -> int:
        dropped = self._dropped_events
        self._dropped_events = 0
        return dropped

    async def get(self, *, timeout: float | None = None) -> dict[str, object | None]:
        while True:
            if self._messages:
                return self._messages.popleft()
            if self._closed:
                raise RuntimeError('subscriber closed')
            self._event.clear()
            if timeout is None:
                await self._event.wait()
            else:
                await asyncio.wait_for(self._event.wait(), timeout=timeout)

    def put(self, message: dict[str, object | None]) -> None:
        if self._closed:
            raise RuntimeError('subscriber closed')

        message_type = str(message.get('type') or '')
        if message_type in {'state', 'heartbeat'}:
            retained = deque(
                item for item in self._messages
                if str(item.get('type') or '') not in {'state', 'heartbeat'}
            )
            dropped = len(self._messages) - len(retained)
            if dropped > 0:
                self._dropped_events += dropped
            self._messages = retained

        while len(self._messages) >= self._max_pending:
            self._messages.popleft()
            self._dropped_events += 1

        self._messages.append(message)
        self._event.set()

    def close(self) -> None:
        self._closed = True
        self._event.set()


class ProtectedSessionVisualWorkerSession:
    def __init__(
        self,
        *,
        session_id: str,
        allowed_host: str,
        worker: ProtectedSessionWorker,
        settings: Settings,
        width: int = 390,
        height: int = 844,
    ) -> None:
        self.session_id = session_id
        self.allowed_host = allowed_host
        self.worker = worker
        self.settings = settings
        self.width = width
        self.height = height
        self.worker_state = 'starting'
        self.health = worker.health
        self.frames_emitted = 0
        self.last_frame_at = None
        self.current_frame: ProtectedSessionFrame | None = None
        self.last_stream_at = None
        self.last_attach_at = None
        self.last_detach_at = None
        self.last_heartbeat_at = None
        self._content_revision = 0
        self._stream_sequence = 0
        self._subscribers: dict[str, ProtectedSessionStreamSubscriber] = {}

    @property
    def content_revision(self) -> int:
        return self._content_revision

    @property
    def stream_sequence(self) -> int:
        return self._stream_sequence

    @property
    def subscriber_count(self) -> int:
        return len(self._subscribers)

    def mark_state(self, worker_state: str, *, health: str | None = None) -> None:
        self.worker_state = worker_state
        if health is not None:
            self.health = health

    def capture(
        self,
        *,
        page: Any | None,
        status: str,
        detail_message: str | None,
        can_go_back: bool,
        can_go_forward: bool,
    ) -> ProtectedSessionFrame:
        self._content_revision += 1
        generated_at = utcnow()
        self.frames_emitted += 1
        self.last_frame_at = generated_at
        self.current_frame = ProtectedSessionFrame(
            revision=self._content_revision,
            mime_type='image/svg+xml',
            document=self._build_svg(
                page=page,
                status=status,
                detail_message=detail_message,
                can_go_back=can_go_back,
                can_go_forward=can_go_forward,
            ),
            width=self.width,
            height=self.height,
            generated_at=generated_at,
        )
        return self.current_frame

    def attach(
        self,
        *,
        initial_state: Any,
        last_stream_sequence: int | None,
    ) -> tuple[ProtectedSessionStreamSubscriber, dict[str, object | None]]:
        subscriber = ProtectedSessionStreamSubscriber(
            max_pending=max(2, self.settings.protected_session_stream_subscriber_queue_size),
        )
        self._subscribers[subscriber.id] = subscriber
        self.last_attach_at = utcnow()
        self.mark_state('attached', health='healthy')
        resumed = last_stream_sequence is not None and last_stream_sequence == self._stream_sequence
        return subscriber, self._make_message(
            message_type='subscribed',
            state=initial_state,
            resumed=resumed,
        )

    def detach(self, subscriber: ProtectedSessionStreamSubscriber) -> None:
        self._subscribers.pop(subscriber.id, None)
        subscriber.close()
        self.last_detach_at = utcnow()
        if not self._subscribers:
            if self.worker_state not in {'closed', 'expired', 'failed'}:
                self.mark_state('detached', health=self.health)

    async def publish_state(
        self,
        *,
        event: str,
        state: Any | None = None,
        source_action_id: str | None = None,
    ) -> None:
        payload = self._make_message(
            message_type='terminal' if event == 'terminal' else 'state',
            state=state,
            source_action_id=source_action_id,
        )
        self.last_stream_at = utcnow()
        stale_subscribers: list[ProtectedSessionStreamSubscriber] = []
        for subscriber in list(self._subscribers.values()):
            try:
                subscriber.put(payload)
            except RuntimeError:
                stale_subscribers.append(subscriber)
        for subscriber in stale_subscribers:
            self.detach(subscriber)

    def heartbeat_message(self) -> dict[str, object | None]:
        self.last_heartbeat_at = utcnow()
        return self._make_message(message_type='heartbeat')

    def action_ack_message(
        self,
        *,
        client_action_id: str,
        action_status: str,
        code: str | None = None,
        message: str | None = None,
    ) -> dict[str, object | None]:
        return self._make_message(
            message_type='action_ack',
            client_action_id=client_action_id,
            action_status=action_status,
            code=code,
            message=message,
        )

    def error_message(
        self,
        *,
        code: str,
        message: str,
    ) -> dict[str, object | None]:
        return self._make_message(
            message_type='error',
            code=code,
            message=message,
        )

    def _make_message(
        self,
        *,
        message_type: str,
        state: Any | None = None,
        resumed: bool | None = None,
        source_action_id: str | None = None,
        client_action_id: str | None = None,
        action_status: str | None = None,
        code: str | None = None,
        message: str | None = None,
    ) -> dict[str, object | None]:
        self._stream_sequence += 1
        payload = ProtectedSessionStreamServerMessage(
            type=message_type,
            session_id=self.session_id,
            stream_sequence=self._stream_sequence,
            content_revision=(
                getattr(state, 'content_revision', None)
                if state is not None
                else (self.current_frame.revision if self.current_frame is not None else self.content_revision)
            ),
            state=state,
            resumed=resumed,
            source_action_id=source_action_id,
            client_action_id=client_action_id,
            action_status=action_status,
            code=code,
            message=message,
            worker_state=self.worker_state,
            worker_health=self.health,
        ).model_dump(mode='json')
        return payload

    def _build_svg(
        self,
        *,
        page: Any | None,
        status: str,
        detail_message: str | None,
        can_go_back: bool,
        can_go_forward: bool,
    ) -> str:
        blocks: list[str] = []
        cursor_y = 170
        page_title = self._coalesce(getattr(page, 'title', None), 'Protected Session')
        page_url = self._coalesce(getattr(page, 'url', None), f'https://{self.allowed_host}/')
        excerpt = self._coalesce(getattr(page, 'excerpt', None), detail_message)
        status_label = status.replace('_', ' ').title()

        blocks.append(self._card(20, 20, self.width - 40, 94))
        blocks.append(self._text(36, 54, 'Protected Session', size=20, weight=700, color='#0F172A'))
        blocks.append(self._text(36, 82, f'Remote visual snapshot · {escape(status_label)}', size=12, color='#475569'))
        blocks.append(
            self._pill(
                self.width - 176,
                42,
                140,
                32,
                fill='#E2E8F0',
                text=self._truncate(detail_message or 'Remote worker live', 28),
            )
        )

        blocks.append(self._card(20, 128, self.width - 40, 160))
        blocks.append(self._text(36, 158, self._truncate(page_title, 40), size=22, weight=700, color='#0F172A'))
        blocks.append(self._text(36, 184, self._truncate(page_url, 58), size=12, color='#2563EB'))
        blocks.append(
            self._text(
                36,
                212,
                f'Back: {"Yes" if can_go_back else "No"} · Forward: {"Yes" if can_go_forward else "No"} · Revision: {self.content_revision}',
                size=12,
                color='#475569',
            )
        )
        if excerpt:
            cursor_y = self._append_wrapped_text(blocks, excerpt, x=36, y=238, width=42, size=14, color='#334155')
        else:
            cursor_y = 238

        links = list(getattr(page, 'links', []) or [])[:5]
        if links:
            section_height = 52 + (len(links) * 42)
            blocks.append(self._card(20, cursor_y + 18, self.width - 40, section_height))
            blocks.append(self._text(36, cursor_y + 48, 'Visible remote actions', size=16, weight=700, color='#0F172A'))
            item_y = cursor_y + 76
            for link in links:
                label = self._truncate(self._coalesce(getattr(link, 'label', None), getattr(link, 'url', None), 'Link'), 44)
                blocks.append(self._pill(36, item_y - 18, self.width - 72, 30, fill='#EFF6FF', text=f'{getattr(link, "id", "link")} · {label}', text_color='#1D4ED8'))
                item_y += 42
            cursor_y += 18 + section_height

        forms = list(getattr(page, 'forms', []) or [])[:2]
        if forms:
            form_lines: list[str] = []
            for form in forms:
                field_names = ', '.join(self._truncate(getattr(field, 'label', ''), 18) for field in getattr(form, 'fields', [])[:3])
                summary = self._truncate(f'{getattr(form, "id", "form")} · {getattr(form, "submit_label", "Submit")} · {field_names}', 56)
                form_lines.append(summary)
            section_height = 64 + (len(form_lines) * 32)
            blocks.append(self._card(20, cursor_y + 18, self.width - 40, section_height))
            blocks.append(self._text(36, cursor_y + 48, 'Remote form controls', size=16, weight=700, color='#0F172A'))
            item_y = cursor_y + 78
            for line in form_lines:
                blocks.append(self._text(36, item_y, line, size=13, color='#334155'))
                item_y += 32
            cursor_y += 18 + section_height

        footer_y = min(self.height - 44, cursor_y + 34)
        blocks.append(self._text(28, footer_y, 'Real-time stream protocol pass: coalesced snapshots over a bounded remote session.', size=11, color='#64748B'))

        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.width}" height="{self.height}" viewBox="0 0 {self.width} {self.height}" '
            'fill="none">'
            f'<rect width="{self.width}" height="{self.height}" rx="28" fill="#F8FAFC"/>'
            f'<rect x="10" y="10" width="{self.width - 20}" height="{self.height - 20}" rx="24" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="1"/>'
            + ''.join(blocks)
            + '</svg>'
        )

    @staticmethod
    def _coalesce(*values: str | None) -> str | None:
        for value in values:
            if value is not None and str(value).strip():
                return str(value).strip()
        return None

    @staticmethod
    def _truncate(value: str, limit: int) -> str:
        if len(value) <= limit:
            return escape(value)
        return escape(value[: max(0, limit - 1)].rstrip() + '…')

    def _append_wrapped_text(
        self,
        blocks: list[str],
        text: str,
        *,
        x: int,
        y: int,
        width: int,
        size: int,
        color: str,
    ) -> int:
        lines = self._wrap_text(text, width)
        current_y = y
        for line in lines[:4]:
            blocks.append(self._text(x, current_y, line, size=size, color=color))
            current_y += size + 7
        return current_y

    @staticmethod
    def _wrap_text(text: str, width: int) -> list[str]:
        words = text.split()
        if not words:
            return []
        lines: list[str] = []
        current = words[0]
        for word in words[1:]:
            candidate = f'{current} {word}'
            if len(candidate) <= width:
                current = candidate
            else:
                lines.append(escape(current))
                current = word
        lines.append(escape(current))
        return lines

    @staticmethod
    def _card(x: int, y: int, width: int, height: int) -> str:
        return (
            f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="22" fill="#FFFFFF" stroke="#E2E8F0" stroke-width="1"/>'
        )

    @staticmethod
    def _pill(x: int, y: int, width: int, height: int, *, fill: str, text: str, text_color: str = '#0F172A') -> str:
        return (
            f'<rect x="{x}" y="{y}" width="{width}" height="{height}" rx="{height / 2}" fill="{fill}"/>'
            f'<text x="{x + 14}" y="{y + (height / 2) + 5}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" '
            f'font-size="12" font-weight="600" fill="{text_color}">{text}</text>'
        )

    @staticmethod
    def _text(x: int, y: int, text: str, *, size: int, color: str, weight: int = 500) -> str:
        return (
            f'<text x="{x}" y="{y}" font-family="-apple-system,BlinkMacSystemFont,Segoe UI,sans-serif" '
            f'font-size="{size}" font-weight="{weight}" fill="{color}">{text}</text>'
        )


class ProtectedSessionWorkerRegistry:
    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()
        self._workers: dict[str, ProtectedSessionWorker] = {
            'worker_local_visual_stream_1': ProtectedSessionWorker(
                worker_id='worker_local_visual_stream_1',
                worker_type='visual_stream_session',
                capacity=self.settings.protected_session_worker_capacity,
                stream_capacity=self.settings.protected_session_worker_stream_capacity,
                state='healthy',
            )
        }

    def assign_session(self, session_id: str) -> ProtectedSessionWorker | None:
        available = [
            worker
            for worker in self._workers.values()
            if worker.state == 'healthy' and worker.assigned_count < worker.capacity
        ]
        if not available:
            return None
        worker = min(available, key=lambda item: item.assigned_count)
        worker.assigned_sessions.add(session_id)
        worker.assignment_count += 1
        return worker

    def release_session(self, session_id: str) -> None:
        for worker in self._workers.values():
            if session_id in worker.assigned_sessions:
                worker.assigned_sessions.discard(session_id)
                worker.release_count += 1

    def stream_attach_state(self, worker_id: str) -> tuple[bool, str | None]:
        worker = self._workers.get(worker_id)
        if worker is None:
            return False, 'worker_missing'
        if worker.state != 'healthy' or worker.health != 'healthy':
            return False, worker.degraded_reason or 'worker_degraded'
        if worker.active_streams >= worker.stream_capacity:
            return False, 'worker_stream_capacity_exhausted'
        return True, None

    def attach_stream(self, worker_id: str) -> bool:
        worker = self._workers.get(worker_id)
        if worker is None:
            return False
        ok, _ = self.stream_attach_state(worker_id)
        if not ok:
            return False
        worker.active_streams += 1
        worker.attach_count += 1
        return True

    def detach_stream(self, worker_id: str, *, heartbeat_timeout: bool = False) -> None:
        worker = self._workers.get(worker_id)
        if worker is None:
            return
        if worker.active_streams > 0:
            worker.active_streams -= 1
        worker.detach_count += 1
        if heartbeat_timeout:
            worker.heartbeat_timeout_count += 1

    def note_protocol_error(self, worker_id: str) -> None:
        worker = self._workers.get(worker_id)
        if worker is None:
            return
        worker.protocol_error_count += 1

    def mark_degraded(self, worker_id: str, reason: str) -> None:
        worker = self._workers.get(worker_id)
        if worker is None:
            return
        worker.state = 'degraded'
        worker.health = 'degraded'
        worker.degraded_reason = reason

    def clear_degraded(self, worker_id: str) -> None:
        worker = self._workers.get(worker_id)
        if worker is None:
            return
        worker.state = 'healthy'
        worker.health = 'healthy'
        worker.degraded_reason = None

    def overview(self) -> list[ProtectedSessionWorker]:
        return sorted(self._workers.values(), key=lambda item: item.worker_id)

    def total_capacity(self) -> int:
        return sum(worker.capacity for worker in self._workers.values())

    def total_stream_capacity(self) -> int:
        return sum(worker.stream_capacity for worker in self._workers.values())

    def total_assigned_sessions(self) -> int:
        return sum(worker.assigned_count for worker in self._workers.values())

    def total_active_streams(self) -> int:
        return sum(worker.active_streams for worker in self._workers.values())

    def healthy_count(self) -> int:
        return sum(1 for worker in self._workers.values() if worker.state == 'healthy' and worker.health == 'healthy')

    def degraded_count(self) -> int:
        return sum(1 for worker in self._workers.values() if worker.state != 'healthy' or worker.health != 'healthy')

    def assignment_count(self) -> int:
        return sum(worker.assignment_count for worker in self._workers.values())

    def release_count(self) -> int:
        return sum(worker.release_count for worker in self._workers.values())

    @staticmethod
    def to_view_dict(worker: ProtectedSessionWorker) -> dict[str, object]:
        return {
            'worker_id': worker.worker_id,
            'worker_type': worker.worker_type,
            'capacity': worker.capacity,
            'stream_capacity': worker.stream_capacity,
            'state': worker.state,
            'health': worker.health,
            'capabilities': list(worker.capabilities),
            'assigned_sessions': sorted(worker.assigned_sessions),
            'assigned_count': worker.assigned_count,
            'active_streams': worker.active_streams,
            'assignment_count': worker.assignment_count,
            'release_count': worker.release_count,
            'attach_count': worker.attach_count,
            'detach_count': worker.detach_count,
            'heartbeat_timeout_count': worker.heartbeat_timeout_count,
            'protocol_error_count': worker.protocol_error_count,
            'degraded_reason': worker.degraded_reason,
        }
