from __future__ import annotations

import asyncio
import socket
from contextlib import suppress
from dataclasses import dataclass, field
from datetime import timedelta
from enum import Enum
from typing import Any, Awaitable, Callable
from urllib.parse import parse_qsl, urlencode, urljoin, urlparse, urlunparse

import httpx
from bs4 import BeautifulSoup

from app.config import Settings, get_settings
from app.services.protected_session_events import ProtectedSessionEventSink
from app.services.protected_session_policy import (
    BLOCKED_HOSTNAMES,
    ProtectedSessionPolicyEngine,
    normalize_host,
    parsed_ip_address,
    is_blocked_ip_address,
)
from app.services.protected_session_workers import (
    ProtectedSessionStreamSubscriber,
    ProtectedSessionVisualWorkerSession,
    ProtectedSessionWorker,
)
from app.schemas import (
    ProtectedSessionActionRequest,
    ProtectedSessionEndResponse,
    ProtectedSessionField,
    ProtectedSessionForm,
    ProtectedSessionLink,
    ProtectedSessionPage,
    ProtectedSessionState,
)
from app.security import create_record_id, utcnow


class ProtectedSessionError(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


class ProtectedSessionLifecycle(str, Enum):
    CREATING = 'creating'
    ACTIVE = 'active'
    TERMINATING = 'terminating'
    CLOSED = 'closed'
    EXPIRED = 'expired'
    FAILED = 'failed'


@dataclass
class RuntimeField:
    name: str
    label: str
    field_type: str
    value: str | None = None
    placeholder: str | None = None
    is_hidden: bool = False


@dataclass
class RuntimeForm:
    id: str
    action_url: str
    method: str
    submit_label: str
    fields: list[RuntimeField] = field(default_factory=list)


@dataclass
class RuntimeLink:
    id: str
    label: str
    url: str


@dataclass
class RuntimePage:
    url: str
    title: str
    domain: str
    excerpt: str | None
    text_blocks: list[str]
    links: list[RuntimeLink]
    forms: list[RuntimeForm]
    fetched_at: Any


class ProtectedSessionRuntime:
    BLOCKED_HOSTNAMES = BLOCKED_HOSTNAMES
    DEFAULT_HEADERS = {
        'User-Agent': (
            'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
            'Mobile/15E148 Safari/604.1 AmonProtectedSession/0.1'
        ),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
    }
    TERMINATING_MESSAGE = 'That protected session is ending and will not accept new actions.'
    CLOSED_MESSAGE = 'That protected session was closed and its remote state was destroyed.'
    EXPIRED_MESSAGE = 'That protected session expired and its remote state was destroyed.'
    FAILED_MESSAGE = 'That protected session failed and its remote state was destroyed.'

    def __init__(
        self,
        *,
        session_id: str | None = None,
        user_id: str,
        start_url: str,
        allowed_host: str,
        settings: Settings,
        transport: httpx.AsyncBaseTransport | None = None,
        policy_engine: ProtectedSessionPolicyEngine | None = None,
        event_sink: ProtectedSessionEventSink | None = None,
        on_session_started: Callable[['ProtectedSessionRuntime'], Awaitable[None]] | None = None,
        on_session_terminal: Callable[['ProtectedSessionRuntime', str], Awaitable[None]] | None = None,
        on_state_updated: Callable[['ProtectedSessionRuntime', ProtectedSessionState, str], Awaitable[None]] | None = None,
        worker: ProtectedSessionWorker | None = None,
    ) -> None:
        self.id = session_id or create_record_id('protected')
        self.user_id = user_id
        self.allowed_host = allowed_host
        self.start_url = start_url
        self.settings = settings
        self.transport = transport
        self.policy_engine = policy_engine or ProtectedSessionPolicyEngine(settings)
        self.event_sink = event_sink
        self.on_session_started = on_session_started
        self.on_session_terminal = on_session_terminal
        self.on_state_updated = on_state_updated
        self.worker = worker or ProtectedSessionWorker(
            worker_id='worker_local_visual_stream_direct',
            worker_type='visual_stream_session',
            capacity=1,
            stream_capacity=1,
            state='healthy',
        )
        self.stream_session = ProtectedSessionVisualWorkerSession(
            session_id=self.id,
            allowed_host=self.allowed_host,
            worker=self.worker,
            settings=self.settings,
        )
        self.started_at = utcnow()
        self.last_activity_at = self.started_at
        self.expires_at = self.started_at + timedelta(minutes=settings.protected_session_ttl_minutes)
        self._status = ProtectedSessionLifecycle.CREATING
        self._detail_message = 'Preparing remote session.'
        self._terminal_at = None
        self._history: list[RuntimePage] = []
        self._history_index = -1
        self._active_task: asyncio.Task[Any] | None = None
        self._operation_lock = asyncio.Lock()
        self._state_lock = asyncio.Lock()
        self._terminal_event = asyncio.Event()
        self._client = httpx.AsyncClient(
            timeout=20.0,
            headers=self.DEFAULT_HEADERS,
            transport=transport,
        )

    @property
    def content_revision(self) -> int:
        return self.stream_session.content_revision

    @property
    def is_expired(self) -> bool:
        return utcnow() >= self.expires_at

    @property
    def can_go_back(self) -> bool:
        return self._history_index > 0

    @property
    def can_go_forward(self) -> bool:
        return 0 <= self._history_index < (len(self._history) - 1)

    @property
    def current_page(self) -> RuntimePage | None:
        if 0 <= self._history_index < len(self._history):
            return self._history[self._history_index]
        return None

    @property
    def status(self) -> ProtectedSessionLifecycle:
        return self._status

    @property
    def is_terminal(self) -> bool:
        return self._status in {
            ProtectedSessionLifecycle.CLOSED,
            ProtectedSessionLifecycle.EXPIRED,
            ProtectedSessionLifecycle.FAILED,
        }

    def is_purgeable(self, now: Any) -> bool:
        if self._terminal_at is None:
            return False
        age = (now - self._terminal_at).total_seconds()
        return age >= self.settings.protected_session_terminal_retention_seconds

    async def start(self) -> ProtectedSessionState:
        async with self._operation_lock:
            current_task = asyncio.current_task()
            await self._set_active_task(current_task)
            try:
                return await self._navigate_and_commit(
                    self.start_url,
                    replace_current=False,
                    detail_message='Remote session started.',
                    activate_session=True,
                )
            finally:
                await self._clear_active_task(current_task)

    async def get_state(self) -> ProtectedSessionState:
        if await self._expire_if_needed():
            raise ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)

        async with self._state_lock:
            if self._status == ProtectedSessionLifecycle.TERMINATING:
                return self._build_state_locked()
            if self._status == ProtectedSessionLifecycle.CLOSED:
                raise ProtectedSessionError(410, 'protected_session_closed', self.CLOSED_MESSAGE)
            if self._status == ProtectedSessionLifecycle.EXPIRED:
                raise ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)
            if self._status == ProtectedSessionLifecycle.FAILED:
                raise ProtectedSessionError(502, 'protected_session_failed', self.FAILED_MESSAGE)
            return self._build_state_locked()

    async def apply_action(
        self,
        action: ProtectedSessionActionRequest,
        *,
        expected_content_revision: int | None = None,
        source_action_id: str | None = None,
    ) -> ProtectedSessionState:
        async with self._state_lock:
            self._ensure_action_allowed_locked()
            self._ensure_expected_revision_locked(expected_content_revision)

        async with self._operation_lock:
            if await self._expire_if_needed():
                raise ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)

            current_task = asyncio.current_task()
            await self._set_active_task(current_task)
            try:
                immediate_state: ProtectedSessionState | None = None
                async with self._state_lock:
                    self._ensure_action_allowed_locked()
                    self._ensure_expected_revision_locked(expected_content_revision)

                    if action.action == 'reload':
                        current_page = self.current_page
                        if current_page is None:
                            raise ProtectedSessionError(409, 'protected_session_empty', 'There is no page loaded to reload.')
                        reload_url = current_page.url
                    else:
                        reload_url = None

                    if action.action == 'back':
                        if not self.can_go_back:
                            raise ProtectedSessionError(
                                409,
                                'protected_session_back_unavailable',
                                'There is no earlier page to return to.',
                            )
                        self._history_index -= 1
                        self._touch_locked()
                        self._detail_message = 'Moved back in remote session history.'
                        immediate_state = self._build_state_locked(force_frame=True)

                    if action.action == 'forward':
                        if not self.can_go_forward:
                            raise ProtectedSessionError(
                                409,
                                'protected_session_forward_unavailable',
                                'There is no later page to open.',
                            )
                        self._history_index += 1
                        self._touch_locked()
                        self._detail_message = 'Moved forward in remote session history.'
                        immediate_state = self._build_state_locked(force_frame=True)

                    if action.action == 'navigate_to_url':
                        if action.url is None:
                            raise ProtectedSessionError(
                                422,
                                'protected_session_missing_url',
                                'A URL is required to navigate this protected session.',
                            )
                        target_url = str(action.url)
                    else:
                        target_url = None

                    current_page = self.current_page
                    if action.action in {'click_link', 'update_field', 'submit_form'} and current_page is None:
                        raise ProtectedSessionError(
                            409,
                            'protected_session_empty',
                            'There is no active page loaded in the protected session.',
                        )

                    if action.action == 'click_link':
                        if not action.link_id:
                            raise ProtectedSessionError(
                                422,
                                'protected_session_missing_link_id',
                                'A link target is required for this action.',
                            )
                        link = next((item for item in current_page.links if item.id == action.link_id), None)
                        if link is None:
                            raise ProtectedSessionError(
                                404,
                                'protected_session_link_not_found',
                                'That remote link is no longer available.',
                            )
                        click_url = link.url
                    else:
                        click_url = None

                    if action.action == 'update_field':
                        form = self._require_form_locked(action.form_id)
                        if not action.field_name:
                            raise ProtectedSessionError(
                                422,
                                'protected_session_missing_field_name',
                                'A form field name is required for this action.',
                            )
                        field = next((item for item in form.fields if item.name == action.field_name and not item.is_hidden), None)
                        if field is None:
                            raise ProtectedSessionError(
                                404,
                                'protected_session_field_not_found',
                                'That form field is no longer available.',
                            )
                        field.value = action.value or ''
                        self._touch_locked()
                        self._detail_message = f'Updated {field.label.lower()} in the protected session.'
                        immediate_state = self._build_state_locked(force_frame=True)

                    if action.action == 'submit_form':
                        form_to_submit = self._require_form_locked(action.form_id)
                    else:
                        form_to_submit = None

                if immediate_state is not None:
                    await self._publish_state(immediate_state, event='state', source_action_id=source_action_id)
                    return immediate_state

                if action.action == 'reload':
                    return await self._navigate_and_commit(
                        reload_url,
                        replace_current=True,
                        detail_message='Reloaded page.',
                        source_action_id=source_action_id,
                    )

                if action.action == 'navigate_to_url':
                    return await self._navigate_and_commit(
                        target_url,
                        replace_current=False,
                        detail_message='Opened a new URL in the protected session.',
                        source_action_id=source_action_id,
                    )

                if action.action == 'click_link':
                    return await self._navigate_and_commit(
                        click_url,
                        replace_current=False,
                        detail_message='Opened the selected link in the protected session.',
                        source_action_id=source_action_id,
                    )

                if action.action == 'submit_form':
                    return await self._submit_form_operation(form_to_submit, source_action_id=source_action_id)

                raise ProtectedSessionError(422, 'protected_session_invalid_action', 'That protected-session action is not supported.')
            except asyncio.CancelledError as exc:
                async with self._state_lock:
                    raise self._operation_interrupted_error_locked() from exc
            except ProtectedSessionError:
                raise
            except Exception as exc:
                await self._finalize_terminal_state_under_operation(
                    ProtectedSessionLifecycle.FAILED,
                    self.FAILED_MESSAGE,
                )
                raise ProtectedSessionError(
                    502,
                    'protected_session_failed',
                    'Amon could not continue that protected session.',
                ) from exc
            finally:
                await self._clear_active_task(current_task)

    async def close(self) -> None:
        await self._begin_termination('Ending protected session.')
        async with self._state_lock:
            terminating_state = self._build_state_locked(force_frame=False)
        await self._publish_state(terminating_state, event='state')
        async with self._state_lock:
            if self.is_terminal:
                return
        async with self._operation_lock:
            await self._finalize_terminal_state_under_operation(
                ProtectedSessionLifecycle.CLOSED,
                self.CLOSED_MESSAGE,
            )

    async def expire(self) -> None:
        await self._begin_termination('Protected session expired.')
        async with self._state_lock:
            expiring_state = self._build_state_locked(force_frame=False)
        await self._publish_state(expiring_state, event='state')
        async with self._state_lock:
            if self.is_terminal:
                return
        async with self._operation_lock:
            await self._finalize_terminal_state_under_operation(
                ProtectedSessionLifecycle.EXPIRED,
                self.EXPIRED_MESSAGE,
            )

    async def dispose(self) -> None:
        if self._status == ProtectedSessionLifecycle.EXPIRED:
            await self.expire()
            return
        await self.close()

    def _touch_locked(self) -> None:
        self.last_activity_at = utcnow()
        self.expires_at = self.last_activity_at + timedelta(minutes=self.settings.protected_session_ttl_minutes)

    def _require_form_locked(self, form_id: str | None) -> RuntimeForm:
        if not form_id:
            raise ProtectedSessionError(422, 'protected_session_missing_form_id', 'A form target is required for this action.')
        current_page = self.current_page
        if current_page is None:
            raise ProtectedSessionError(409, 'protected_session_empty', 'There is no active page loaded in the protected session.')
        form = next((item for item in current_page.forms if item.id == form_id), None)
        if form is None:
            raise ProtectedSessionError(404, 'protected_session_form_not_found', 'That form is no longer available.')
        return form

    async def _submit_form_operation(
        self,
        form: RuntimeForm,
        *,
        source_action_id: str | None = None,
    ) -> ProtectedSessionState:
        payload = {
            field.name: field.value or ''
            for field in form.fields
            if field.name
        }

        if form.method == 'get':
            target = self._merge_query(form.action_url, payload)
            return await self._navigate_and_commit(
                target,
                replace_current=False,
                detail_message='Submitted the selected form in the protected session.',
                destination_kind='form_action',
                source_action_id=source_action_id,
            )

        response = await self._request_locked('POST', form.action_url, data=payload, destination_kind='form_action')
        page = self._page_from_response(response)
        return await self._commit_page_after_network(
            page,
            replace_current=False,
            detail_message='Submitted the selected form in the protected session.',
            source_action_id=source_action_id,
        )

    async def _navigate_and_commit(
        self,
        url: str,
        *,
        replace_current: bool,
        detail_message: str,
        activate_session: bool = False,
        destination_kind: str = 'navigate',
        source_action_id: str | None = None,
    ) -> ProtectedSessionState:
        response = await self._request_locked('GET', url, destination_kind=destination_kind)
        page = self._page_from_response(response)
        return await self._commit_page_after_network(
            page,
            replace_current=replace_current,
            detail_message=detail_message,
            activate_session=activate_session,
            source_action_id=source_action_id,
        )

    async def _request_locked(
        self,
        method: str,
        url: str,
        data: dict[str, str] | None = None,
        destination_kind: str = 'navigate',
    ) -> httpx.Response:
        target_url = await self._validated_url(url, destination_kind=destination_kind)
        current_method = method.upper()
        current_url = target_url
        current_data = data

        for _ in range(6):
            try:
                async with self._client.stream(
                    current_method,
                    current_url,
                    data=current_data if current_method == 'POST' else None,
                    follow_redirects=False,
                ) as response:
                    if response.status_code in {301, 302, 303, 307, 308}:
                        location = response.headers.get('location')
                        if not location:
                            break
                        current_url = await self._validated_url(
                            urljoin(str(response.url), location),
                            destination_kind='redirect',
                        )
                        if response.status_code in {301, 302, 303}:
                            current_method = 'GET'
                            current_data = None
                        continue

                    if response.status_code >= 400:
                        raise ProtectedSessionError(
                            502,
                            'protected_session_upstream_error',
                            'The protected session could not complete that site request.',
                        )

                    self._enforce_response_size(response)
                    content = bytearray()
                    async for chunk in response.aiter_bytes():
                        content.extend(chunk)
                        if len(content) > self.settings.protected_session_max_response_bytes:
                            raise ProtectedSessionError(
                                413,
                                'protected_session_response_too_large',
                                'That site response was too large for this protected-session build.',
                            )

                    return httpx.Response(
                        response.status_code,
                        headers=response.headers,
                        content=bytes(content),
                        request=response.request,
                        extensions=response.extensions,
                    )
            except ProtectedSessionError:
                raise
            except httpx.TimeoutException as exc:
                raise ProtectedSessionError(
                    504,
                    'protected_session_timeout',
                    'The remote protected session timed out while reaching that site.',
                ) from exc
            except httpx.HTTPError as exc:
                raise ProtectedSessionError(
                    502,
                    'protected_session_unreachable',
                    'Amon could not reach that site inside the protected session.',
                ) from exc

        raise ProtectedSessionError(
            502,
            'protected_session_redirect_loop',
            'That site redirected too many times for the protected session.',
        )

    async def _validated_url(self, url: str, *, destination_kind: str) -> str:
        decision, normalized = self.policy_engine.evaluate_runtime_destination(
            url,
            allowed_host=self.allowed_host,
            destination_kind=destination_kind,
        )
        if decision.disposition != 'ALLOW_PROTECTED' or normalized is None:
            self._record_blocked_destination(decision=decision, destination_kind=destination_kind)
            raise self._decision_error(decision, destination_kind=destination_kind)

        parsed = urlparse(normalized)
        host = normalize_host(parsed.hostname or '')
        scheme = (parsed.scheme or '').lower()
        try:
            port = parsed.port
        except ValueError as exc:
            raise ProtectedSessionError(
                400,
                'protected_session_invalid_port',
                'That destination is not allowed in a protected session.',
            ) from exc

        if self.transport is None:
            await self._ensure_host_resolves_publicly(host, port or (443 if scheme == 'https' else 80))

        return normalized

    def _page_from_response(self, response: httpx.Response) -> RuntimePage:
        content_type = response.headers.get('content-type', '')
        if 'text/html' not in content_type and 'application/xhtml+xml' not in content_type:
            raise ProtectedSessionError(
                415,
                'protected_session_non_html',
                'The protected session can only render HTML pages in this build.',
            )

        try:
            soup = BeautifulSoup(response.text, 'html.parser')
        except Exception as exc:
            raise ProtectedSessionError(
                502,
                'protected_session_parse_failed',
                'Amon could not interpret that page inside the protected session.',
            ) from exc
        url = str(response.url)
        title = self._extract_title(soup, url)
        excerpt, text_blocks = self._extract_text(soup)
        links = self._extract_links(soup, url)
        forms = self._extract_forms(soup, url)
        return RuntimePage(
            url=url,
            title=title,
            domain=urlparse(url).netloc,
            excerpt=excerpt,
            text_blocks=text_blocks,
            links=links,
            forms=forms,
            fetched_at=utcnow(),
        )

    def _enforce_response_size(self, response: httpx.Response) -> None:
        content_length = response.headers.get('content-length')
        if not content_length:
            return
        try:
            size = int(content_length)
        except ValueError:
            return
        if size > self.settings.protected_session_max_response_bytes:
            raise ProtectedSessionError(
                413,
                'protected_session_response_too_large',
                'That site response was too large for this protected-session build.',
            )

    def _ensure_host_not_blocked(self, host: str) -> None:
        if host in self.BLOCKED_HOSTNAMES:
            raise ProtectedSessionError(
                403,
                'protected_session_blocked_address',
                'That destination is blocked in a protected session.',
            )
        ip_address = parsed_ip_address(host)
        if ip_address is not None and is_blocked_ip_address(ip_address):
            raise ProtectedSessionError(
                403,
                'protected_session_blocked_address',
                'That destination is blocked in a protected session.',
            )

    async def _ensure_host_resolves_publicly(self, host: str, port: int) -> None:
        try:
            address_info = await asyncio.to_thread(socket.getaddrinfo, host, port, type=socket.SOCK_STREAM)
        except socket.gaierror as exc:
            raise ProtectedSessionError(
                502,
                'protected_session_resolution_failed',
                'Amon could not resolve that site for the protected session.',
            ) from exc

        resolved_addresses: set[str] = set()
        for _family, _socktype, _proto, _canonname, sockaddr in address_info:
            if sockaddr:
                resolved_addresses.add(str(sockaddr[0]))

        if not resolved_addresses:
            raise ProtectedSessionError(
                502,
                'protected_session_resolution_failed',
                'Amon could not resolve that site for the protected session.',
            )

        for raw_address in resolved_addresses:
            ip_address = parsed_ip_address(raw_address)
            if ip_address is None:
                continue
            if is_blocked_ip_address(ip_address):
                raise ProtectedSessionError(
                    403,
                    'protected_session_blocked_address',
                    'That destination is blocked in a protected session.',
                )

    async def _commit_page_after_network(
        self,
        page: RuntimePage,
        *,
        replace_current: bool,
        detail_message: str,
        activate_session: bool = False,
        source_action_id: str | None = None,
    ) -> ProtectedSessionState:
        should_expire = False
        should_emit_started = False
        built_state: ProtectedSessionState | None = None
        async with self._state_lock:
            if self._status == ProtectedSessionLifecycle.TERMINATING:
                raise ProtectedSessionError(409, 'protected_session_terminating', self.TERMINATING_MESSAGE)
            if self._status == ProtectedSessionLifecycle.CLOSED:
                raise ProtectedSessionError(410, 'protected_session_closed', self.CLOSED_MESSAGE)
            if self._status == ProtectedSessionLifecycle.EXPIRED:
                raise ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)
            if self._status == ProtectedSessionLifecycle.FAILED:
                raise ProtectedSessionError(502, 'protected_session_failed', self.FAILED_MESSAGE)
            if self.is_expired:
                should_expire = True
            else:
                self._append_page_locked(page, replace_current=replace_current)
                self._touch_locked()
                if activate_session:
                    self._status = ProtectedSessionLifecycle.ACTIVE
                    self.stream_session.mark_state('live', health='healthy')
                    should_emit_started = True
                self._detail_message = detail_message
                built_state = self._build_state_locked(force_frame=True)

        if should_emit_started:
            await self._emit_session_started()
            if built_state is not None:
                await self._publish_state(built_state, event='state', source_action_id=source_action_id)
            return built_state

        if should_expire:
            await self._finalize_terminal_state_under_operation(
                ProtectedSessionLifecycle.EXPIRED,
                self.EXPIRED_MESSAGE,
            )
            raise ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)

        if built_state is not None:
            await self._publish_state(built_state, event='state', source_action_id=source_action_id)
            return built_state
        raise ProtectedSessionError(502, 'protected_session_failed', self.FAILED_MESSAGE)

    def _append_page_locked(self, page: RuntimePage, *, replace_current: bool = False) -> None:
        if replace_current and self.current_page is not None:
            self._history[self._history_index] = page
            return
        if self.can_go_forward:
            self._history = self._history[: self._history_index + 1]
        self._history.append(page)
        self._history_index = len(self._history) - 1

    def _build_state_locked(self, *, force_frame: bool = False) -> ProtectedSessionState:
        current_page = self.current_page
        if force_frame or (current_page is not None and self.stream_session.current_frame is None):
            self.stream_session.capture(
                page=current_page,
                status=self._status.value,
                detail_message=self._detail_message,
                can_go_back=self.can_go_back,
                can_go_forward=self.can_go_forward,
            )
        return ProtectedSessionState(
            session_id=self.id,
            status=self._status.value,
            allowed_host=self.allowed_host,
            started_at=self.started_at,
            expires_at=self.expires_at,
            last_activity_at=self.last_activity_at,
            can_go_back=self.can_go_back,
            can_go_forward=self.can_go_forward,
            content_revision=self.content_revision,
            runtime_kind=self.worker.worker_type,
            stream_transport='websocket',
            worker_id=self.worker.worker_id,
            worker_type=self.worker.worker_type,
            worker_state=self.stream_session.worker_state,
            worker_health=self.stream_session.health,
            current_frame=self.stream_session.current_frame,
            current_page=(
                ProtectedSessionPage(
                    url=current_page.url,
                    title=current_page.title,
                    domain=current_page.domain,
                    excerpt=current_page.excerpt,
                    text_blocks=current_page.text_blocks,
                    links=[
                        ProtectedSessionLink(id=link.id, label=link.label, url=link.url)
                        for link in current_page.links
                    ],
                    forms=[
                        ProtectedSessionForm(
                            id=form.id,
                            action_url=form.action_url,
                            method=form.method,
                            submit_label=form.submit_label,
                            fields=[
                                ProtectedSessionField(
                                    name=field.name,
                                    label=field.label,
                                    field_type=field.field_type,
                                    value=field.value,
                                    placeholder=field.placeholder,
                                )
                                for field in form.fields
                                if not field.is_hidden
                            ],
                        )
                        for form in current_page.forms
                    ],
                    fetched_at=current_page.fetched_at,
                )
                if current_page is not None
                else None
            ),
            detail_message=self._detail_message,
        )

    async def _set_active_task(self, task: asyncio.Task[Any] | None) -> None:
        async with self._state_lock:
            self._active_task = task

    async def _clear_active_task(self, task: asyncio.Task[Any] | None) -> None:
        async with self._state_lock:
            if self._active_task is task:
                self._active_task = None

    async def _begin_termination(self, detail_message: str) -> None:
        async with self._state_lock:
            if self._status == ProtectedSessionLifecycle.CLOSED:
                return
            if self._status == ProtectedSessionLifecycle.EXPIRED:
                return
            if self._status == ProtectedSessionLifecycle.FAILED:
                return
            if self._status != ProtectedSessionLifecycle.TERMINATING:
                self._status = ProtectedSessionLifecycle.TERMINATING
                self._detail_message = detail_message
                self.stream_session.mark_state('terminating', health='healthy')
            task_to_cancel = self._active_task

        current_task = asyncio.current_task()
        if task_to_cancel is not None and task_to_cancel is not current_task and not task_to_cancel.done():
            task_to_cancel.cancel()

    async def _finalize_terminal_state_under_operation(
        self,
        terminal_status: ProtectedSessionLifecycle,
        detail_message: str,
    ) -> None:
        terminal_changed = False
        terminal_state: ProtectedSessionState | None = None
        async with self._state_lock:
            if self.is_terminal:
                return
            should_close_client = not self._client.is_closed

        if should_close_client:
            self._client.cookies.clear()
            await self._client.aclose()

        async with self._state_lock:
            worker_state = {
                ProtectedSessionLifecycle.CLOSED: 'closed',
                ProtectedSessionLifecycle.EXPIRED: 'expired',
                ProtectedSessionLifecycle.FAILED: 'failed',
            }.get(terminal_status, 'closed')
            worker_health = 'failed' if terminal_status == ProtectedSessionLifecycle.FAILED else 'healthy'
            self.stream_session.mark_state(worker_state, health=worker_health)
            self._history = []
            self._history_index = -1
            self._active_task = None
            self._status = terminal_status
            self._detail_message = detail_message
            self._terminal_at = utcnow()
            self._terminal_event.set()
            terminal_state = self._build_state_locked(force_frame=False)
            terminal_changed = True

        if terminal_changed:
            if terminal_state is not None:
                await self._publish_state(terminal_state, event='terminal')
            await self._emit_session_terminal(detail_message)

    async def _expire_if_needed(self) -> bool:
        async with self._state_lock:
            should_expire = self._status == ProtectedSessionLifecycle.ACTIVE and self.is_expired

        if should_expire:
            await self.expire()
            return True
        return False

    def _ensure_action_allowed_locked(self) -> None:
        if self._status == ProtectedSessionLifecycle.TERMINATING:
            raise ProtectedSessionError(409, 'protected_session_terminating', self.TERMINATING_MESSAGE)
        if self._status == ProtectedSessionLifecycle.CLOSED:
            raise ProtectedSessionError(410, 'protected_session_closed', self.CLOSED_MESSAGE)
        if self._status == ProtectedSessionLifecycle.EXPIRED:
            raise ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)
        if self._status == ProtectedSessionLifecycle.FAILED:
            raise ProtectedSessionError(502, 'protected_session_failed', self.FAILED_MESSAGE)
        if self._status != ProtectedSessionLifecycle.ACTIVE:
            raise ProtectedSessionError(409, 'protected_session_starting', 'That protected session is still starting.')

    def _ensure_expected_revision_locked(self, expected_content_revision: int | None) -> None:
        if expected_content_revision is None:
            return
        if expected_content_revision != self.content_revision:
            raise ProtectedSessionError(
                409,
                'protected_session_stale_view',
                'That remote view is out of date. Refresh the protected session before acting again.',
            )

    def _operation_interrupted_error_locked(self) -> ProtectedSessionError:
        if self._status == ProtectedSessionLifecycle.TERMINATING:
            return ProtectedSessionError(409, 'protected_session_terminating', self.TERMINATING_MESSAGE)
        if self._status == ProtectedSessionLifecycle.CLOSED:
            return ProtectedSessionError(410, 'protected_session_closed', self.CLOSED_MESSAGE)
        if self._status == ProtectedSessionLifecycle.EXPIRED:
            return ProtectedSessionError(410, 'protected_session_expired', self.EXPIRED_MESSAGE)
        if self._status == ProtectedSessionLifecycle.FAILED:
            return ProtectedSessionError(502, 'protected_session_failed', self.FAILED_MESSAGE)
        return ProtectedSessionError(502, 'protected_session_failed', self.FAILED_MESSAGE)

    async def _emit_session_started(self) -> None:
        if self.on_session_started is None:
            return
        try:
            await self.on_session_started(self)
        except Exception:
            return

    async def _emit_session_terminal(self, detail_message: str) -> None:
        if self.on_session_terminal is None:
            return
        try:
            await self.on_session_terminal(self, detail_message)
        except Exception:
            return

    async def _publish_state(
        self,
        state: ProtectedSessionState,
        *,
        event: str,
        source_action_id: str | None = None,
    ) -> None:
        await self.stream_session.publish_state(event=event, state=state, source_action_id=source_action_id)
        if self.on_state_updated is None:
            return
        try:
            await self.on_state_updated(self, state, event)
        except Exception:
            return

    async def subscribe_stream(
        self,
        *,
        last_stream_sequence: int | None = None,
    ) -> tuple[ProtectedSessionStreamSubscriber, dict[str, object | None]]:
        async with self._state_lock:
            initial_state = self._build_state_locked(force_frame=self.stream_session.current_frame is None)
        return self.stream_session.attach(initial_state=initial_state, last_stream_sequence=last_stream_sequence)

    def unsubscribe_stream(self, subscriber: ProtectedSessionStreamSubscriber) -> None:
        self.stream_session.detach(subscriber)

    def _record_blocked_destination(self, *, decision: Any, destination_kind: str) -> None:
        if self.event_sink is None:
            return
        event_type = 'blocked_redirect' if destination_kind == 'redirect' else 'blocked_form_destination'
        if destination_kind not in {'redirect', 'form_action'}:
            return
        self.event_sink.record(
            event_type,
            session_id=self.id,
            user_id=self.user_id,
            domain=self.allowed_host,
            reason_code=decision.reason_code,
            state=self._status.value,
            disposition=decision.disposition,
            budget_tier=decision.budget_tier,
        )

    @staticmethod
    def _decision_error(decision: Any, *, destination_kind: str) -> ProtectedSessionError:
        if 'invalid_port' in decision.reason_code:
            return ProtectedSessionError(
                400,
                'protected_session_invalid_port',
                'That destination is not allowed in a protected session.',
            )
        if 'invalid_url' in decision.reason_code or 'credentialed_url' in decision.reason_code:
            return ProtectedSessionError(
                400,
                'protected_session_invalid_url',
                'That URL cannot be opened in a protected session.',
            )
        if 'blocked_address' in decision.reason_code:
            return ProtectedSessionError(
                403,
                'protected_session_blocked_address',
                'That destination is blocked in a protected session.',
            )
        if destination_kind == 'form_action':
            return ProtectedSessionError(
                403,
                'protected_session_navigation_blocked',
                'That form destination is not allowed in the protected session.',
            )
        if destination_kind == 'redirect':
            return ProtectedSessionError(
                403,
                'protected_session_navigation_blocked',
                'That redirect destination is not allowed in the protected session.',
            )
        return ProtectedSessionError(
            403,
            'protected_session_navigation_blocked',
            'That remote session is limited to its original host.',
        )

    def _extract_links(self, soup: BeautifulSoup, base_url: str) -> list[RuntimeLink]:
        links: list[RuntimeLink] = []
        seen: set[str] = set()
        for tag in soup.find_all('a', href=True):
            href = tag.get('href')
            if not href:
                continue
            absolute = urljoin(base_url, href)
            parsed = urlparse(absolute)
            if parsed.scheme not in {'http', 'https'} or parsed.hostname != self.allowed_host:
                continue
            if absolute in seen:
                continue
            label = tag.get_text(' ', strip=True) or tag.get('title') or parsed.path or absolute
            if not label:
                continue
            seen.add(absolute)
            links.append(RuntimeLink(id=f'link_{len(links) + 1}', label=label[:120], url=absolute))
            if len(links) >= self.settings.protected_session_max_links:
                break
        return links

    def _extract_forms(self, soup: BeautifulSoup, base_url: str) -> list[RuntimeForm]:
        labels_by_for: dict[str, str] = {}
        for label in soup.find_all('label'):
            label_text = label.get_text(' ', strip=True)
            if label_text and label.get('for'):
                labels_by_for[label['for']] = label_text

        forms: list[RuntimeForm] = []
        for form_index, form_tag in enumerate(soup.find_all('form'), start=1):
            action_url = urljoin(base_url, form_tag.get('action') or base_url)
            parsed_action = urlparse(action_url)
            if parsed_action.scheme not in {'http', 'https'}:
                continue
            method = (form_tag.get('method') or 'get').lower()
            if method not in {'get', 'post'}:
                method = 'get'
            submit_label = self._submit_label(form_tag)
            fields: list[RuntimeField] = []
            for tag in form_tag.find_all(['input', 'textarea', 'select']):
                name = (tag.get('name') or '').strip()
                if not name:
                    continue
                field_type = (tag.get('type') or '').lower() if tag.name == 'input' else tag.name
                if not field_type:
                    field_type = 'text'
                if field_type in {'checkbox', 'radio', 'file', 'submit', 'button', 'image', 'reset'}:
                    continue
                default_value = self._default_field_value(tag)
                field_id = tag.get('id')
                label = labels_by_for.get(field_id or '', '') or self._implicit_label(tag) or name.replace('_', ' ').title()
                fields.append(
                    RuntimeField(
                        name=name,
                        label=label[:80],
                        field_type=field_type,
                        value=default_value,
                        placeholder=tag.get('placeholder'),
                        is_hidden=(field_type == 'hidden'),
                    )
                )
            if fields:
                forms.append(
                    RuntimeForm(
                        id=f'form_{form_index}',
                        action_url=action_url,
                        method=method,
                        submit_label=submit_label,
                        fields=fields,
                    )
                )
        return forms

    @staticmethod
    def _extract_title(soup: BeautifulSoup, url: str) -> str:
        if soup.title and soup.title.string:
            return soup.title.string.strip()
        h1 = soup.find('h1')
        if h1:
            return h1.get_text(' ', strip=True)
        og_title = soup.find('meta', attrs={'property': 'og:title'})
        if og_title and og_title.get('content'):
            return og_title['content'].strip()
        return url

    def _extract_text(self, soup: BeautifulSoup) -> tuple[str | None, list[str]]:
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc and meta_desc.get('content'):
            excerpt = meta_desc['content'].strip()
        else:
            excerpt = None

        blocks: list[str] = []
        for tag in soup.find_all(['p', 'li']):
            text = tag.get_text(' ', strip=True)
            if len(text) < 30:
                continue
            blocks.append(text)
            if len(blocks) >= self.settings.protected_session_max_text_blocks:
                break

        if excerpt is None and blocks:
            excerpt = blocks[0][:280]

        return excerpt[:280] if excerpt else None, blocks

    @staticmethod
    def _default_field_value(tag: Any) -> str | None:
        if tag.name == 'textarea':
            text = tag.get_text()
            return text if text else None
        if tag.name == 'select':
            selected = tag.find('option', selected=True) or tag.find('option')
            if selected and selected.get('value') is not None:
                return selected['value']
            if selected:
                return selected.get_text(' ', strip=True)
            return None
        value = tag.get('value')
        return value if value is not None else None

    @staticmethod
    def _implicit_label(tag: Any) -> str | None:
        parent = tag.parent
        while parent is not None:
            if getattr(parent, 'name', None) == 'label':
                text = parent.get_text(' ', strip=True)
                return text if text else None
            parent = getattr(parent, 'parent', None)
        return None

    @staticmethod
    def _submit_label(form_tag: Any) -> str:
        submit = form_tag.find(['button', 'input'], attrs={'type': ['submit', 'button']})
        if submit is not None:
            if submit.name == 'button':
                label = submit.get_text(' ', strip=True)
            else:
                label = submit.get('value')
            if label:
                return str(label)[:60]
        return 'Submit'

    @staticmethod
    def _merge_query(url: str, payload: dict[str, str]) -> str:
        parsed = urlparse(url)
        query = dict(parse_qsl(parsed.query, keep_blank_values=True))
        query.update(payload)
        updated_query = urlencode(query, doseq=True)
        return urlunparse(parsed._replace(query=updated_query))


class ProtectedSessionManager:
    def __init__(
        self,
        *,
        settings: Settings | None = None,
        transport: httpx.AsyncBaseTransport | None = None,
        policy_engine: ProtectedSessionPolicyEngine | None = None,
        event_sink: ProtectedSessionEventSink | None = None,
        on_session_started: Callable[[ProtectedSessionRuntime], Awaitable[None]] | None = None,
        on_session_terminal: Callable[[ProtectedSessionRuntime, str], Awaitable[None]] | None = None,
        on_state_updated: Callable[[ProtectedSessionRuntime, ProtectedSessionState, str], Awaitable[None]] | None = None,
    ) -> None:
        self.settings = settings or get_settings()
        self.transport = transport
        self.policy_engine = policy_engine or ProtectedSessionPolicyEngine(self.settings)
        self.event_sink = event_sink
        self.on_session_started = on_session_started
        self.on_session_terminal = on_session_terminal
        self.on_state_updated = on_state_updated
        self._cleanup_task: asyncio.Task[None] | None = None
        self._is_shutdown = False
        self._sessions: dict[str, ProtectedSessionRuntime] = {}
        self._lock = asyncio.Lock()

    async def create_session(
        self,
        *,
        user_id: str,
        url: str,
        session_id: str | None = None,
        worker: ProtectedSessionWorker | None = None,
    ) -> ProtectedSessionState:
        self.ensure_started()
        await self._purge_expired()
        allowed_host = self._validate_start_host(url)
        runtime = ProtectedSessionRuntime(
            session_id=session_id,
            user_id=user_id,
            start_url=url,
            allowed_host=allowed_host,
            settings=self.settings,
            transport=self.transport,
            policy_engine=self.policy_engine,
            event_sink=self.event_sink,
            on_session_started=self.on_session_started,
            on_session_terminal=self.on_session_terminal,
            on_state_updated=self.on_state_updated,
            worker=worker,
        )
        try:
            state = await runtime.start()
        except Exception:
            await runtime.close()
            raise
        async with self._lock:
            if self._is_shutdown:
                await runtime.close()
                raise ProtectedSessionError(
                    503,
                    'protected_session_unavailable',
                    'Protected Session is unavailable right now.',
                )
            self._sessions[runtime.id] = runtime
        return state

    async def get_state(self, *, user_id: str, session_id: str) -> ProtectedSessionState:
        self.ensure_started()
        await self._purge_expired()
        runtime = await self._session_for(user_id=user_id, session_id=session_id)
        return await runtime.get_state()

    async def apply_action(
        self,
        *,
        user_id: str,
        session_id: str,
        action: ProtectedSessionActionRequest,
        expected_content_revision: int | None = None,
        source_action_id: str | None = None,
    ) -> ProtectedSessionState:
        self.ensure_started()
        await self._purge_expired()
        runtime = await self._session_for(user_id=user_id, session_id=session_id)
        return await runtime.apply_action(
            action,
            expected_content_revision=expected_content_revision,
            source_action_id=source_action_id,
        )

    async def end_session(self, *, user_id: str, session_id: str) -> ProtectedSessionEndResponse:
        self.ensure_started()
        await self._purge_expired()
        runtime = await self._session_for(user_id=user_id, session_id=session_id)
        await runtime.close()
        return ProtectedSessionEndResponse(session_id=session_id)

    async def subscribe_stream(
        self,
        *,
        user_id: str,
        session_id: str,
        last_stream_sequence: int | None = None,
    ) -> tuple[ProtectedSessionRuntime, ProtectedSessionStreamSubscriber, dict[str, object | None]]:
        self.ensure_started()
        await self._purge_expired()
        runtime = await self._session_for(user_id=user_id, session_id=session_id)
        subscriber, subscribed = await runtime.subscribe_stream(last_stream_sequence=last_stream_sequence)
        return runtime, subscriber, subscribed

    def ensure_started(self) -> None:
        if self._is_shutdown:
            return
        if self._cleanup_task is None or self._cleanup_task.done():
            try:
                loop = asyncio.get_running_loop()
            except RuntimeError:
                return
            self._cleanup_task = loop.create_task(self._cleanup_loop())

    async def shutdown(self) -> None:
        self._is_shutdown = True
        cleanup_task = self._cleanup_task
        self._cleanup_task = None
        if cleanup_task is not None:
            cleanup_task.cancel()
            with suppress(asyncio.CancelledError):
                await cleanup_task

        async with self._lock:
            runtimes = list(self._sessions.values())
            self._sessions.clear()

        for runtime in runtimes:
            await runtime.close()

    async def _session_for(self, *, user_id: str, session_id: str) -> ProtectedSessionRuntime:
        async with self._lock:
            runtime = self._sessions.get(session_id)
        if runtime is None or runtime.user_id != user_id:
            raise ProtectedSessionError(404, 'protected_session_missing', 'That protected session is no longer available.')
        return runtime

    async def _purge_expired(self) -> None:
        self.ensure_started()
        async with self._lock:
            runtimes = list(self._sessions.values())

        for runtime in runtimes:
            if not runtime.is_terminal and runtime.is_expired:
                await runtime.expire()

        purge_before = utcnow()
        async with self._lock:
            purge_ids = [
                session_id
                for session_id, runtime in self._sessions.items()
                if runtime.is_purgeable(purge_before)
            ]
            for session_id in purge_ids:
                self._sessions.pop(session_id, None)

    def _validate_start_host(self, url: str) -> str:
        parsed = urlparse(url)
        host = normalize_host(parsed.hostname or '')
        decision = self.policy_engine.decide_url_open(url, intent='protected_session', current_user=None)
        if decision.disposition != 'ALLOW_PROTECTED':
            if decision.reason_code == 'blocked_address':
                raise ProtectedSessionError(
                    403,
                    'protected_session_blocked_address',
                    'That destination is blocked in a protected session.',
                )
            if decision.reason_code in {'invalid_url', 'credentialed_url_blocked'}:
                raise ProtectedSessionError(
                    400,
                    'protected_session_invalid_url',
                    'That URL cannot be opened in a protected session.',
                )
            if decision.reason_code == 'invalid_port':
                raise ProtectedSessionError(
                    400,
                    'protected_session_invalid_port',
                    'That destination is not allowed in a protected session.',
                )
            raise ProtectedSessionError(
                403,
                'protected_session_host_not_allowed',
                'Protected Session is limited to a small allowlist in this build.',
            )
        return host

    async def _cleanup_loop(self) -> None:
        while not self._is_shutdown:
            await asyncio.sleep(self.settings.protected_session_cleanup_interval_seconds)
            await self._purge_expired()


_protected_session_manager: ProtectedSessionManager | None = None


def get_protected_session_manager() -> ProtectedSessionManager:
    global _protected_session_manager
    if _protected_session_manager is None or _protected_session_manager._is_shutdown:
        _protected_session_manager = ProtectedSessionManager()
    _protected_session_manager.ensure_started()
    return _protected_session_manager
