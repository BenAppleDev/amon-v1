from __future__ import annotations

import asyncio
import time
from datetime import timedelta

import httpx
import pytest
from starlette.websockets import WebSocketDisconnect

from app.config import Settings
from app.models import Entitlement, SessionRecord, User
from app.routers import internal_protected_sessions as internal_router_module
from app.routers import protected_sessions as protected_sessions_router_module
from app.schemas import ProtectedSessionActionRequest
from app.security import CurrentUser, utcnow
from app.services.protected_session_control_plane import ProtectedSessionControlPlane
from app.services.protected_sessions import ProtectedSessionError


def _current_user(*, user_id: str = 'user_1', tier: str = 'full_access') -> CurrentUser:
    now = utcnow()
    user = User(id=user_id, status='active')
    entitlement = Entitlement(id=f'ent_{user_id}', user_id=user_id, tier=tier, status='active')
    session = SessionRecord(
        id=f'session_{user_id}',
        user_id=user_id,
        issued_at=now,
        expires_at=now + timedelta(hours=24),
    )
    return CurrentUser(user=user, entitlement=entitlement, session=session)


def _login(client, subject: str = 'pytest-user') -> str:
    response = client.post('/v1/auth/dev-login', json={'apple_subject': subject})
    assert response.status_code == 200
    return response.json()['access_token']


def _html_response(
    request: httpx.Request,
    html: str,
    *,
    status_code: int = 200,
    headers: dict[str, str] | None = None,
) -> httpx.Response:
    resolved_headers = {'content-type': 'text/html; charset=utf-8'}
    if headers:
        resolved_headers.update(headers)
    return httpx.Response(status_code, text=html, request=request, headers=resolved_headers)


def _simple_transport() -> httpx.MockTransport:
    async def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == '/start':
            return _html_response(
                request,
                """
                <html>
                    <head><title>Protected Start</title></head>
                    <body>
                        <p>Protected control-plane test page.</p>
                        <a href="/page-two">Continue</a>
                    </body>
                </html>
                """,
            )
        if path == '/page-two':
            return _html_response(
                request,
                """
                <html>
                    <head><title>Protected Page Two</title></head>
                    <body><p>Second page.</p></body>
                </html>
                """,
            )
        return httpx.Response(404, text='missing', request=request)

    return httpx.MockTransport(handler)


def _blocked_destination_transport() -> httpx.MockTransport:
    async def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path
        if path == '/start':
            return _html_response(
                request,
                """
                <html>
                    <head><title>Protected Start</title></head>
                    <body>
                        <a href="/bounce">Blocked Redirect</a>
                        <form action="https://evil.example/submit" method="post">
                            <label for="q">Query</label>
                            <input id="q" name="q" />
                            <button type="submit">Submit</button>
                        </form>
                    </body>
                </html>
                """,
            )
        if path == '/bounce':
            return httpx.Response(302, headers={'location': 'https://evil.example/landing'}, request=request)
        return httpx.Response(404, text='missing', request=request)

    return httpx.MockTransport(handler)


def _patch_router_control_plane(monkeypatch, control_plane: ProtectedSessionControlPlane) -> None:
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)
    monkeypatch.setattr(internal_router_module, 'get_protected_session_control_plane', lambda: control_plane)


@pytest.mark.asyncio
async def test_control_plane_decisions_cover_recommend_local_clean_and_deny():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_simple_transport(),
    )
    try:
        current = _current_user()

        recommend = await control_plane.decide_url_open(current=current, url='https://example.com/start')
        clean = await control_plane.decide_url_open(current=current, url='https://docs.example.org/news/article')
        local = await control_plane.decide_url_open(current=current, url='https://random.example.org/home')
        deny = await control_plane.decide_url_open(current=current, url='http://127.0.0.1/admin')
        explicit = await control_plane.decide_url_open(
            current=current,
            url='https://example.com/start',
            intent='protected_session',
        )

        assert recommend.disposition == 'RECOMMEND_PROTECTED'
        assert recommend.reason_code == 'allowlisted_protected_host'
        assert clean.disposition == 'ALLOW_CLEAN_VIEW'
        assert clean.site_class == 'readable_public_page'
        assert local.disposition == 'ALLOW_LOCAL'
        assert local.reason_code == 'uncertain_local_only'
        assert deny.disposition == 'DENY'
        assert deny.reason_code == 'blocked_address'
        assert explicit.disposition == 'ALLOW_PROTECTED'

        counters = control_plane.policy_counters()
        assert counters.policy_decisions == {
            'RECOMMEND_PROTECTED': 1,
            'ALLOW_CLEAN_VIEW': 1,
            'ALLOW_LOCAL': 1,
            'DENY': 1,
        }
    finally:
        await control_plane.shutdown()


@pytest.mark.asyncio
async def test_control_plane_enforces_concurrent_session_limit_and_releases_worker_on_end():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(
            PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
            PROTECTED_SESSION_MAX_CONCURRENT_SESSIONS_PER_USER='1',
        ),
        transport=_simple_transport(),
    )
    try:
        current = _current_user()

        created = await control_plane.create_session(current=current, url='https://example.com/start')
        metadata = control_plane.session_detail(created.session_id)
        workers_before_end = control_plane.workers_overview()

        assert metadata.state == 'active'
        assert metadata.worker_id is not None
        assert workers_before_end.total_assigned_sessions == 1

        with pytest.raises(ProtectedSessionError) as error:
            await control_plane.create_session(current=current, url='https://example.com/start')
        assert error.value.code == 'protected_session_concurrent_limit'

        await control_plane.end_session(current=current, session_id=created.session_id)

        workers_after_end = control_plane.workers_overview()
        quotas = control_plane.quota_counters()
        assert workers_after_end.total_assigned_sessions == 0
        assert quotas.quota_rejections['concurrent_session_limit'] == 1
    finally:
        await control_plane.shutdown()


@pytest.mark.asyncio
async def test_control_plane_enforces_session_start_window_and_action_limit():
    current = _current_user()

    start_limited = ProtectedSessionControlPlane(
        settings=Settings(
            PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
            PROTECTED_SESSION_MAX_CONCURRENT_SESSIONS_PER_USER='3',
            PROTECTED_SESSION_MAX_SESSION_STARTS_PER_WINDOW='1',
        ),
        transport=_simple_transport(),
    )
    try:
        created = await start_limited.create_session(current=current, url='https://example.com/start')
        await start_limited.end_session(current=current, session_id=created.session_id)

        with pytest.raises(ProtectedSessionError) as start_error:
            await start_limited.create_session(current=current, url='https://example.com/start')
        assert start_error.value.code == 'protected_session_start_rate_limited'
        assert start_limited.quota_counters().quota_rejections['session_start_rate_limit'] == 1
    finally:
        await start_limited.shutdown()

    action_limited = ProtectedSessionControlPlane(
        settings=Settings(
            PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
            PROTECTED_SESSION_MAX_ACTIONS_PER_SESSION='1',
        ),
        transport=_simple_transport(),
    )
    try:
        created = await action_limited.create_session(current=current, url='https://example.com/start')
        await action_limited.apply_action(
            current=current,
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='click_link', link_id=created.current_page.links[0].id),
        )

        with pytest.raises(ProtectedSessionError) as action_error:
            await action_limited.apply_action(
                current=current,
                session_id=created.session_id,
                action=ProtectedSessionActionRequest(action='back'),
            )
        assert action_error.value.code == 'protected_session_action_limit_reached'

        detail = action_limited.session_detail(created.session_id)
        quotas = action_limited.quota_counters()
        assert detail.action_count == 1
        assert quotas.quota_rejections['session_action_limit'] == 1
    finally:
        await action_limited.shutdown()


@pytest.mark.asyncio
async def test_control_plane_records_blocked_redirect_and_form_events():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_blocked_destination_transport(),
    )
    try:
        current = _current_user()

        created = await control_plane.create_session(current=current, url='https://example.com/start')

        with pytest.raises(ProtectedSessionError) as redirect_error:
            await control_plane.apply_action(
                current=current,
                session_id=created.session_id,
                action=ProtectedSessionActionRequest(action='click_link', link_id=created.current_page.links[0].id),
            )
        assert redirect_error.value.code == 'protected_session_navigation_blocked'

        with pytest.raises(ProtectedSessionError) as form_error:
            await control_plane.apply_action(
                current=current,
                session_id=created.session_id,
                action=ProtectedSessionActionRequest(action='submit_form', form_id=created.current_page.forms[0].id),
            )
        assert form_error.value.code == 'protected_session_navigation_blocked'

        counters = control_plane.policy_counters()
        assert counters.event_counts['blocked_redirect'] == 1
        assert counters.event_counts['blocked_form_destination'] == 1
        assert {event.event_type for event in counters.recent_events} >= {'blocked_redirect', 'blocked_form_destination'}
    finally:
        await control_plane.shutdown()


def test_internal_admin_routes_are_metadata_only_and_decision_route_is_exposed(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_simple_transport(),
    )
    try:
        _patch_router_control_plane(monkeypatch, control_plane)

        token = _login(client)
        headers = {'Authorization': f'Bearer {token}'}
        admin_headers = {'X-Amon-Internal-Token': 'amon-internal-dev'}

        recommend = client.post(
            '/v1/protected-sessions/decision',
            json={'url': 'https://example.com/start', 'intent': 'open'},
            headers=headers,
        )
        local = client.post(
            '/v1/protected-sessions/decision',
            json={'url': 'https://random.example.org/home', 'intent': 'open'},
            headers=headers,
        )
        deny = client.post(
            '/v1/protected-sessions/decision',
            json={'url': 'http://127.0.0.1/admin', 'intent': 'open'},
            headers=headers,
        )

        assert recommend.status_code == 200
        assert recommend.json()['disposition'] == 'RECOMMEND_PROTECTED'
        assert local.status_code == 200
        assert local.json()['disposition'] == 'ALLOW_LOCAL'
        assert deny.status_code == 200
        assert deny.json()['disposition'] == 'DENY'

        created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=headers)
        assert created.status_code == 200
        session_id = created.json()['session_id']

        unauthorized = client.get('/internal/protected-sessions/sessions')
        assert unauthorized.status_code == 401

        sessions = client.get('/internal/protected-sessions/sessions', headers=admin_headers)
        active_sessions = client.get('/internal/protected-sessions/sessions/active', headers=admin_headers)
        detail = client.get(f'/internal/protected-sessions/sessions/{session_id}', headers=admin_headers)
        workers = client.get('/internal/protected-sessions/workers', headers=admin_headers)
        overview = client.get('/internal/protected-sessions/overview', headers=admin_headers)
        stream = client.get('/internal/protected-sessions/counters/stream', headers=admin_headers)
        terminations = client.get('/internal/protected-sessions/counters/terminations', headers=admin_headers)
        policy = client.get('/internal/protected-sessions/counters/policy', headers=admin_headers)
        quota = client.get('/internal/protected-sessions/counters/quota', headers=admin_headers)
        events = client.get('/internal/protected-sessions/events?limit=10', headers=admin_headers)

        assert sessions.status_code == 200
        assert active_sessions.status_code == 200
        assert detail.status_code == 200
        assert workers.status_code == 200
        assert overview.status_code == 200
        assert stream.status_code == 200
        assert terminations.status_code == 200
        assert policy.status_code == 200
        assert quota.status_code == 200
        assert events.status_code == 200

        session_item = sessions.json()['sessions'][0]
        detail_item = detail.json()
        assert 'current_page' not in session_item
        assert 'current_frame' not in session_item
        assert 'text_blocks' not in session_item
        assert session_item['session_id'] == session_id
        assert detail_item['session_id'] == session_id
        assert detail_item['policy']['disposition'] == 'ALLOW_PROTECTED'
        assert detail_item['quota']['max_concurrent_sessions_per_user'] >= 1
        assert detail_item['active_streams'] == 0
        assert workers.json()['total_assigned_sessions'] == 1
        assert workers.json()['total_stream_capacity'] >= 1
        assert overview.json()['total_sessions'] == 1
        assert overview.json()['active_sessions'] == 1
        assert stream.json()['worker_assignments'] == 1
        assert terminations.json()['terminal_event_counts'] == {}
        assert policy.json()['event_counts']['session_created'] == 1
        assert quota.json()['active_sessions_total'] == 1
        assert events.json()['events'][0].get('metric_value') is None
    finally:
        asyncio.run(control_plane.shutdown())


@pytest.mark.asyncio
async def test_control_plane_tracks_live_stream_limits_and_worker_degraded_mode():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(
            PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
            PROTECTED_SESSION_MAX_CONCURRENT_SESSIONS_PER_USER='2',
            PROTECTED_SESSION_MAX_LIVE_STREAMS='2',
            PROTECTED_SESSION_MAX_LIVE_STREAMS_PER_USER='1',
            PROTECTED_SESSION_WORKER_STREAM_CAPACITY='1',
        ),
        transport=_simple_transport(),
    )
    try:
        current = _current_user()
        first = await control_plane.create_session(current=current, url='https://example.com/start')
        second = await control_plane.create_session(current=current, url='https://example.com/start')

        runtime, subscriber, _subscribed = await control_plane.subscribe_stream(
            current=current,
            session_id=first.session_id,
            last_stream_sequence=None,
        )
        detail = control_plane.session_detail(first.session_id)
        assert detail.active_streams == 1

        with pytest.raises(ProtectedSessionError) as stream_limit_error:
            await control_plane.subscribe_stream(
                current=current,
                session_id=second.session_id,
                last_stream_sequence=None,
            )
        assert stream_limit_error.value.code == 'protected_session_live_stream_limit'
        assert control_plane.quota_counters().quota_rejections['live_stream_user_limit'] == 1

        runtime.unsubscribe_stream(subscriber)
        await control_plane.note_stream_detached(current=current, session_id=first.session_id, reason_code='test_cleanup')

        worker_id = control_plane.session_detail(second.session_id).worker_id
        assert worker_id is not None
        control_plane.workers.mark_degraded(worker_id, 'worker_degraded')

        with pytest.raises(ProtectedSessionError) as degraded_error:
            await control_plane.subscribe_stream(
                current=current,
                session_id=second.session_id,
                last_stream_sequence=None,
            )
        assert degraded_error.value.code == 'protected_session_stream_worker_degraded'
        assert control_plane.stream_counters().protocol_error_codes['worker_degraded'] == 1
    finally:
        await control_plane.shutdown()


def test_internal_admin_stream_health_updates_on_protocol_error_and_heartbeat_timeout(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(
            PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
            PROTECTED_SESSION_STREAM_IDLE_TIMEOUT_SECONDS='1',
            PROTECTED_SESSION_STREAM_HEARTBEAT_SECONDS='10',
        ),
        transport=_simple_transport(),
    )
    try:
        _patch_router_control_plane(monkeypatch, control_plane)

        token = _login(client, subject='stream-health-user')
        headers = {'Authorization': f'Bearer {token}'}
        admin_headers = {'X-Amon-Internal-Token': 'amon-internal-dev'}

        created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=headers)
        assert created.status_code == 200
        session_id = created.json()['session_id']

        with client.websocket_connect(f'/v1/protected-sessions/{session_id}/stream', headers=headers) as websocket:
            websocket.send_json({'type': 'subscribe', 'client_message_id': 'm1', 'last_stream_sequence': None})
            subscribed = websocket.receive_json()
            assert subscribed['type'] == 'subscribed'
            websocket.send_json({'type': 'subscribe', 'client_message_id': 'm2', 'last_stream_sequence': None})
            protocol_error = websocket.receive_json()
            assert protocol_error['type'] == 'error'
            time.sleep(1.2)
            with pytest.raises(WebSocketDisconnect) as timeout_error:
                websocket.receive_json()
            assert timeout_error.value.code == 4408

        overview = client.get('/internal/protected-sessions/overview', headers=admin_headers)
        stream = client.get('/internal/protected-sessions/counters/stream', headers=admin_headers)
        detail = client.get(f'/internal/protected-sessions/sessions/{session_id}', headers=admin_headers)
        workers = client.get('/internal/protected-sessions/workers', headers=admin_headers)
        events = client.get('/internal/protected-sessions/events?limit=20', headers=admin_headers)

        assert overview.status_code == 200
        assert stream.status_code == 200
        assert detail.status_code == 200
        assert workers.status_code == 200
        assert events.status_code == 200

        detail_json = detail.json()
        stream_json = stream.json()
        worker_json = workers.json()['workers'][0]
        event_types = {event['event_type'] for event in events.json()['events']}

        assert detail_json['active_streams'] == 0
        assert detail_json['protocol_error_count'] >= 1
        assert detail_json['heartbeat_timeout_count'] == 1
        assert stream_json['attach_count'] == 1
        assert stream_json['detach_count'] == 1
        assert stream_json['heartbeat_timeout_count'] == 1
        assert stream_json['protocol_error_count'] >= 1
        assert stream_json['protocol_error_codes']['already_subscribed'] == 1
        assert worker_json['heartbeat_timeout_count'] == 1
        assert worker_json['protocol_error_count'] >= 1
        assert {'stream_attached', 'stream_protocol_error', 'stream_heartbeat_timeout', 'stream_detached'} <= event_types
        assert 'current_page' not in detail_json
        assert 'current_frame' not in detail_json
    finally:
        asyncio.run(control_plane.shutdown())
