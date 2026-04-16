from __future__ import annotations

import asyncio
from datetime import timedelta

import httpx
import pytest

from app.config import Settings
from app.models import Entitlement, SessionRecord, User
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
                        <p>Protected stream test page.</p>
                        <a href="/page-two">Continue</a>
                        <form action="/search" method="get">
                            <label for="q">Search</label>
                            <input id="q" name="q" value="amon" />
                            <button type="submit">Go</button>
                        </form>
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
        if path == '/search':
            query = request.url.params.get('q', '')
            return _html_response(
                request,
                f"""
                <html>
                    <head><title>Search {query}</title></head>
                    <body><p>Search results for {query}.</p></body>
                </html>
                """,
            )
        return httpx.Response(404, text='missing', request=request)

    return httpx.MockTransport(handler)


def _login(client, subject: str = 'pytest-user') -> str:
    response = client.post('/v1/auth/dev-login', json={'apple_subject': subject})
    assert response.status_code == 200
    return response.json()['access_token']


@pytest.mark.asyncio
async def test_stream_runtime_state_contains_visual_frame_and_worker_metadata():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_simple_transport(),
    )
    try:
        current = _current_user()
        created = await control_plane.create_session(current=current, url='https://example.com/start')
        detail = control_plane.session_detail(created.session_id)

        assert created.runtime_kind == 'visual_stream_session'
        assert created.stream_transport == 'websocket'
        assert created.worker_type == 'visual_stream_session'
        assert created.current_frame is not None
        assert created.current_frame.mime_type == 'image/svg+xml'
        assert '<svg' in created.current_frame.document

        assert detail.runtime_kind == 'visual_stream_session'
        assert detail.worker_state == 'live'
        assert detail.frame_revision == created.current_frame.revision
        assert detail.frames_emitted >= 1
    finally:
        await control_plane.shutdown()


@pytest.mark.asyncio
async def test_stream_runtime_subscriptions_receive_visual_updates():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_simple_transport(),
    )
    try:
        current = _current_user()
        created = await control_plane.create_session(current=current, url='https://example.com/start')
        _runtime, subscriber, subscribed = await control_plane.subscribe_stream(
            current=current,
            session_id=created.session_id,
            last_stream_sequence=None,
        )

        assert subscribed['type'] == 'subscribed'
        first_revision = subscribed['state']['content_revision']
        link_id = subscribed['state']['current_page']['links'][0]['id']

        await control_plane.apply_action(
            current=current,
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='click_link', link_id=link_id),
            expected_content_revision=first_revision,
            source_action_id='action_open_link',
        )

        updated = await asyncio.wait_for(subscriber.get(timeout=1), timeout=1)
        assert updated['type'] == 'state'
        assert updated['source_action_id'] == 'action_open_link'
        assert updated['content_revision'] > first_revision
        assert updated['state']['current_page']['title'] == 'Protected Page Two'
    finally:
        await control_plane.shutdown()


def test_stream_websocket_route_emits_state_and_navigation_updates(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_simple_transport(),
    )
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)

    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}

    try:
        created = client.post(
            '/v1/protected-sessions',
            json={'url': 'https://example.com/start'},
            headers=headers,
        )
        assert created.status_code == 200
        session_id = created.json()['session_id']

        with client.websocket_connect(f'/v1/protected-sessions/{session_id}/stream', headers=headers) as websocket:
            websocket.send_json({'type': 'subscribe', 'last_stream_sequence': 0})
            initial = websocket.receive_json()
            assert initial['type'] == 'subscribed'
            assert initial['state']['runtime_kind'] == 'visual_stream_session'
            initial_revision = initial['state']['content_revision']
            link_id = initial['state']['current_page']['links'][0]['id']

            websocket.send_json(
                {
                    'type': 'action',
                    'client_action_id': 'action_1',
                    'expected_content_revision': initial_revision,
                    'action': {'action': 'click_link', 'link_id': link_id},
                }
            )
            ack = websocket.receive_json()
            assert ack['type'] == 'action_ack'
            assert ack['client_action_id'] == 'action_1'
            assert ack['action_status'] == 'accepted'

            updated = websocket.receive_json()
            assert updated['type'] == 'state'
            assert updated['source_action_id'] == 'action_1'
            assert updated['content_revision'] > initial_revision
            assert updated['state']['current_page']['title'] == 'Protected Page Two'
    finally:
        asyncio.run(control_plane.shutdown())


@pytest.mark.asyncio
async def test_stream_runtime_rejects_stale_revision_and_coalesces_slow_subscribers():
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_simple_transport(),
    )
    try:
        current = _current_user()
        created = await control_plane.create_session(current=current, url='https://example.com/start')
        _runtime, subscriber, subscribed = await control_plane.subscribe_stream(
            current=current,
            session_id=created.session_id,
            last_stream_sequence=None,
        )

        form_id = subscribed['state']['current_page']['forms'][0]['id']
        field_name = subscribed['state']['current_page']['forms'][0]['fields'][0]['name']
        current_revision = subscribed['state']['content_revision']

        with pytest.raises(ProtectedSessionError) as stale_error:
            await control_plane.apply_action(
                current=current,
                session_id=created.session_id,
                action=ProtectedSessionActionRequest(
                    action='update_field',
                    form_id=form_id,
                    field_name=field_name,
                    value='stale',
                ),
                expected_content_revision=current_revision + 99,
                source_action_id='stale_action',
            )
        assert stale_error.value.code == 'protected_session_stale_view'

        await control_plane.apply_action(
            current=current,
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(
                action='update_field',
                form_id=form_id,
                field_name=field_name,
                value='first',
            ),
            expected_content_revision=current_revision,
            source_action_id='action_first',
        )

        latest_revision = control_plane.session_detail(created.session_id).frame_revision
        await control_plane.apply_action(
            current=current,
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(
                action='update_field',
                form_id=form_id,
                field_name=field_name,
                value='second',
            ),
            expected_content_revision=latest_revision,
            source_action_id='action_second',
        )

        coalesced = await asyncio.wait_for(subscriber.get(timeout=1), timeout=1)
        assert coalesced['type'] == 'state'
        assert coalesced['source_action_id'] == 'action_second'
        assert subscriber.consume_dropped_events() >= 1
    finally:
        await control_plane.shutdown()
