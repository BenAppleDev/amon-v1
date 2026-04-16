import asyncio
from datetime import timedelta

import httpx
import pytest

from app.config import Settings
from app.routers import protected_sessions as protected_sessions_router_module
from app.schemas import ProtectedSessionActionRequest
from app.security import utcnow
from app.services.protected_session_control_plane import ProtectedSessionControlPlane
from app.services.protected_sessions import (
    ProtectedSessionError,
    ProtectedSessionLifecycle,
    ProtectedSessionManager,
)


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


def _base_mock_transport() -> httpx.MockTransport:
    async def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path

        if path == '/start':
            html = """
            <html>
                <head>
                    <title>Protected Start</title>
                    <meta name="description" content="A real protected-session start page." />
                </head>
                <body>
                    <p>This page is rendered through the protected session runtime.</p>
                    <a href="/page-two">Continue deeper</a>
                    <form action="/search" method="get">
                        <label for="q">Query</label>
                        <input id="q" name="q" placeholder="Search term" />
                        <button type="submit">Search</button>
                    </form>
                </body>
            </html>
            """
            return _html_response(request, html, headers={'set-cookie': 'visit=alpha; Path=/'})

        if path == '/page-two':
            cookie = request.headers.get('cookie', '')
            title = 'Protected Page Two' if 'visit=alpha' in cookie else 'Missing Cookie'
            html = f"""
            <html>
                <head><title>{title}</title></head>
                <body>
                    <p>Second page reached with cookie state: {cookie or 'none'}.</p>
                </body>
            </html>
            """
            return _html_response(request, html)

        if path == '/search':
            query = request.url.params.get('q', '')
            html = f"""
            <html>
                <head><title>Protected Search</title></head>
                <body>
                    <p>Remote search query was {query}.</p>
                </body>
            </html>
            """
            return _html_response(request, html)

        return httpx.Response(404, text='missing', request=request)

    return httpx.MockTransport(handler)


def _slow_action_transport(
    *,
    ignore_first_cancellation: bool = True,
) -> tuple[httpx.MockTransport, asyncio.Event, asyncio.Event, asyncio.Event]:
    slow_started = asyncio.Event()
    release_slow = asyncio.Event()
    cancellation_seen = asyncio.Event()

    async def handler(request: httpx.Request) -> httpx.Response:
        path = request.url.path

        if path == '/start':
            html = """
            <html>
                <head><title>Protected Start</title></head>
                <body>
                    <p>This page is rendered through the protected session runtime.</p>
                    <a href="/slow">Slow page</a>
                </body>
            </html>
            """
            return _html_response(request, html)

        if path == '/slow':
            slow_started.set()
            if ignore_first_cancellation:
                try:
                    await release_slow.wait()
                except asyncio.CancelledError:
                    cancellation_seen.set()
                    await release_slow.wait()
                    raise
            else:
                await release_slow.wait()

            html = """
            <html>
                <head><title>Slow page</title></head>
                <body>
                    <p>The slow page completed after a delayed remote request.</p>
                </body>
            </html>
            """
            return _html_response(request, html)

        return httpx.Response(404, text='missing', request=request)

    return httpx.MockTransport(handler), slow_started, release_slow, cancellation_seen


async def _wait_for_runtime_status(
    runtime,
    expected_status: ProtectedSessionLifecycle,
    *,
    timeout: float = 1.0,
) -> None:
    async def wait_until_ready() -> None:
        while runtime.status != expected_status:
            await asyncio.sleep(0.01)

    await asyncio.wait_for(wait_until_ready(), timeout=timeout)


@pytest.mark.asyncio
async def test_protected_session_manager_preserves_remote_state_across_actions():
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    assert created.current_page is not None
    assert created.current_page.title == 'Protected Start'
    assert created.current_page.links[0].label == 'Continue deeper'

    clicked = await manager.apply_action(
        user_id='user_1',
        session_id=created.session_id,
        action=ProtectedSessionActionRequest(action='click_link', link_id=created.current_page.links[0].id),
    )
    assert clicked.current_page is not None
    assert clicked.current_page.title == 'Protected Page Two'
    assert 'visit=alpha' in ' '.join(clicked.current_page.text_blocks)

    went_back = await manager.apply_action(
        user_id='user_1',
        session_id=created.session_id,
        action=ProtectedSessionActionRequest(action='back'),
    )
    assert went_back.current_page is not None
    assert went_back.current_page.title == 'Protected Start'

    updated = await manager.apply_action(
        user_id='user_1',
        session_id=created.session_id,
        action=ProtectedSessionActionRequest(
            action='update_field',
            form_id=went_back.current_page.forms[0].id,
            field_name='q',
            value='amon',
        ),
    )
    assert updated.current_page is not None
    assert updated.current_page.forms[0].fields[0].value == 'amon'

    submitted = await manager.apply_action(
        user_id='user_1',
        session_id=created.session_id,
        action=ProtectedSessionActionRequest(
            action='submit_form',
            form_id=updated.current_page.forms[0].id,
        ),
    )
    assert submitted.current_page is not None
    assert submitted.current_page.title == 'Protected Search'
    assert 'amon' in ' '.join(submitted.current_page.text_blocks)


@pytest.mark.asyncio
async def test_protected_session_manager_rejects_non_allowlisted_hosts():
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )

    with pytest.raises(ProtectedSessionError) as error:
        await manager.create_session(user_id='user_1', url='https://not-allowed.example.org/start')
    assert error.value.code == 'protected_session_host_not_allowed'


@pytest.mark.asyncio
async def test_protected_session_blocks_localhost_and_private_ip_targets():
    for host in ['localhost', '127.0.0.1', '169.254.169.254', '10.0.0.5']:
        manager = ProtectedSessionManager(
            settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS=host),
            transport=_base_mock_transport(),
        )
        scheme = 'http'
        target = f'{scheme}://{host}/'
        with pytest.raises(ProtectedSessionError) as error:
            await manager.create_session(user_id='user_1', url=target)
        assert error.value.code == 'protected_session_blocked_address'


@pytest.mark.asyncio
async def test_protected_session_blocks_redirect_to_disallowed_host():
    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == '/start':
            return _html_response(
                request,
                """
                <html><body>
                    <a href="/bounce">Bounce</a>
                </body></html>
                """,
            )
        if request.url.path == '/bounce':
            return httpx.Response(302, headers={'location': 'https://evil.example/landing'}, request=request)
        return httpx.Response(404, text='missing', request=request)

    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=httpx.MockTransport(handler),
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')

    with pytest.raises(ProtectedSessionError) as error:
        await manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='click_link', link_id=created.current_page.links[0].id),
        )
    assert error.value.code == 'protected_session_navigation_blocked'


@pytest.mark.asyncio
async def test_protected_session_blocks_form_submit_redirect_escape():
    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == '/start':
            return _html_response(
                request,
                """
                <html><body>
                    <form action="/submit" method="post">
                        <label for="q">Query</label>
                        <input id="q" name="q" />
                        <button type="submit">Submit</button>
                    </form>
                </body></html>
                """,
            )
        if request.url.path == '/submit':
            return httpx.Response(302, headers={'location': 'https://evil.example/landing'}, request=request)
        return httpx.Response(404, text='missing', request=request)

    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=httpx.MockTransport(handler),
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')

    with pytest.raises(ProtectedSessionError) as error:
        await manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='submit_form', form_id=created.current_page.forms[0].id),
        )
    assert error.value.code == 'protected_session_navigation_blocked'


@pytest.mark.asyncio
async def test_protected_session_expired_session_action_is_rejected_and_purged():
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    runtime = manager._sessions[created.session_id]
    runtime.expires_at = utcnow() - timedelta(seconds=1)

    with pytest.raises(ProtectedSessionError) as error:
        await manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='reload'),
        )
    assert error.value.code == 'protected_session_expired'
    assert created.session_id in manager._sessions
    assert manager._sessions[created.session_id].status == ProtectedSessionLifecycle.EXPIRED


@pytest.mark.asyncio
async def test_protected_session_teardown_clears_remote_state():
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    runtime = manager._sessions[created.session_id]
    assert runtime.current_page is not None
    assert runtime._client.cookies

    ended = await manager.end_session(user_id='user_1', session_id=created.session_id)

    assert ended.status == 'ended'
    assert runtime.status == ProtectedSessionLifecycle.CLOSED
    assert runtime.current_page is None
    assert runtime._history == []
    assert not runtime._client.cookies


@pytest.mark.asyncio
async def test_protected_session_rejects_oversized_html_responses():
    body = '<html><body>' + ('x' * 600) + '</body></html>'

    async def handler(request: httpx.Request) -> httpx.Response:
        return _html_response(request, body, headers={'content-length': str(len(body.encode("utf-8")))})

    manager = ProtectedSessionManager(
        settings=Settings(
            PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
            PROTECTED_SESSION_MAX_RESPONSE_BYTES='128',
        ),
        transport=httpx.MockTransport(handler),
    )

    with pytest.raises(ProtectedSessionError) as error:
        await manager.create_session(user_id='user_1', url='https://example.com/start')
    assert error.value.code == 'protected_session_response_too_large'


def test_protected_session_routes_expose_real_remote_session_flow(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)

    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}

    created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=headers)
    assert created.status_code == 200
    state = created.json()
    assert state['current_page']['title'] == 'Protected Start'

    session_id = state['session_id']
    form_id = state['current_page']['forms'][0]['id']
    link_id = state['current_page']['links'][0]['id']

    clicked = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'click_link', 'link_id': link_id},
        headers=headers,
    )
    assert clicked.status_code == 200
    assert clicked.json()['current_page']['title'] == 'Protected Page Two'

    back = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'back'},
        headers=headers,
    )
    assert back.status_code == 200
    assert back.json()['current_page']['title'] == 'Protected Start'

    update = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'update_field', 'form_id': form_id, 'field_name': 'q', 'value': 'amon'},
        headers=headers,
    )
    assert update.status_code == 200
    assert update.json()['current_page']['forms'][0]['fields'][0]['value'] == 'amon'

    submit = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'submit_form', 'form_id': form_id},
        headers=headers,
    )
    assert submit.status_code == 200
    assert submit.json()['current_page']['title'] == 'Protected Search'

    ended = client.delete(f'/v1/protected-sessions/{session_id}', headers=headers)
    assert ended.status_code == 200
    assert ended.json()['status'] == 'ended'


def test_protected_session_hides_sessions_from_other_users(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)

    token_one = _login(client, 'pytest-user-one')
    token_two = _login(client, 'pytest-user-two')
    headers_one = {'Authorization': f'Bearer {token_one}'}
    headers_two = {'Authorization': f'Bearer {token_two}'}

    created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=headers_one)
    assert created.status_code == 200
    session_id = created.json()['session_id']

    for method, payload in (
        ('get', None),
        ('post', {'action': 'reload'}),
        ('delete', None),
    ):
        if method == 'get':
            response = client.get(f'/v1/protected-sessions/{session_id}', headers=headers_two)
        elif method == 'post':
            response = client.post(f'/v1/protected-sessions/{session_id}/actions', json=payload, headers=headers_two)
        else:
            response = client.delete(f'/v1/protected-sessions/{session_id}', headers=headers_two)
        assert response.status_code == 404
        assert response.json()['detail']['code'] == 'protected_session_missing'

    ended = client.delete(f'/v1/protected-sessions/{session_id}', headers=headers_one)
    assert ended.status_code == 200


def test_protected_session_double_end_and_stale_actions_return_stable_closed_errors(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)

    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}

    created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=headers)
    session_id = created.json()['session_id']

    ended = client.delete(f'/v1/protected-sessions/{session_id}', headers=headers)
    assert ended.status_code == 200

    second_end = client.delete(f'/v1/protected-sessions/{session_id}', headers=headers)
    assert second_end.status_code == 200
    assert second_end.json()['status'] == 'ended'

    stale_action = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'reload'},
        headers=headers,
    )
    assert stale_action.status_code == 410
    assert stale_action.json()['detail']['code'] == 'protected_session_closed'

    stale_state = client.get(f'/v1/protected-sessions/{session_id}', headers=headers)
    assert stale_state.status_code == 410
    assert stale_state.json()['detail']['code'] == 'protected_session_closed'


def test_protected_session_rejects_malformed_action_payloads(client, monkeypatch):
    control_plane = ProtectedSessionControlPlane(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)

    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}

    created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=headers)
    session_id = created.json()['session_id']

    invalid_action = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'steal_everything'},
        headers=headers,
    )
    assert invalid_action.status_code == 422

    missing_action = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'form_id': 'form_1'},
        headers=headers,
    )
    assert missing_action.status_code == 422

    oversized_value = client.post(
        f'/v1/protected-sessions/{session_id}/actions',
        json={'action': 'update_field', 'form_id': 'form_1', 'field_name': 'q', 'value': 'x' * 5001},
        headers=headers,
    )
    assert oversized_value.status_code == 422


@pytest.mark.asyncio
async def test_protected_session_end_session_cancels_inflight_action_and_surfaces_terminating_state():
    transport, slow_started, release_slow, _ = _slow_action_transport()
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=transport,
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    runtime = manager._sessions[created.session_id]
    link_id = created.current_page.links[0].id

    action_task = asyncio.create_task(
        manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='click_link', link_id=link_id),
        )
    )
    await asyncio.wait_for(slow_started.wait(), timeout=1.0)

    end_task = asyncio.create_task(manager.end_session(user_id='user_1', session_id=created.session_id))
    await _wait_for_runtime_status(runtime, ProtectedSessionLifecycle.TERMINATING)

    terminating_state = await manager.get_state(user_id='user_1', session_id=created.session_id)
    assert terminating_state.status == 'terminating'
    assert terminating_state.current_page is not None
    assert terminating_state.current_page.title == 'Protected Start'

    with pytest.raises(ProtectedSessionError) as blocked:
        await manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='reload'),
        )
    assert blocked.value.code in {'protected_session_terminating', 'protected_session_expired'}

    release_slow.set()

    with pytest.raises(ProtectedSessionError) as action_error:
        await action_task
    assert action_error.value.code == 'protected_session_terminating'

    ended = await end_task
    assert ended.status == 'ended'
    assert runtime.status == ProtectedSessionLifecycle.CLOSED
    assert runtime.current_page is None


@pytest.mark.asyncio
async def test_protected_session_repeated_end_session_is_idempotent_during_active_request():
    transport, slow_started, release_slow, _ = _slow_action_transport()
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=transport,
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    runtime = manager._sessions[created.session_id]

    action_task = asyncio.create_task(
        manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='click_link', link_id=created.current_page.links[0].id),
        )
    )
    await asyncio.wait_for(slow_started.wait(), timeout=1.0)

    first_end = asyncio.create_task(manager.end_session(user_id='user_1', session_id=created.session_id))
    await _wait_for_runtime_status(runtime, ProtectedSessionLifecycle.TERMINATING)

    second_end = asyncio.create_task(manager.end_session(user_id='user_1', session_id=created.session_id))
    release_slow.set()

    with pytest.raises(ProtectedSessionError):
        await action_task

    first_result = await first_end
    second_result = await second_end
    assert first_result.status == 'ended'
    assert second_result.status == 'ended'
    assert runtime.status == ProtectedSessionLifecycle.CLOSED


@pytest.mark.asyncio
async def test_protected_session_expiry_during_active_request_prevents_late_commit():
    transport, slow_started, release_slow, _ = _slow_action_transport()
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=transport,
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    runtime = manager._sessions[created.session_id]

    action_task = asyncio.create_task(
        manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='click_link', link_id=created.current_page.links[0].id),
        )
    )
    await asyncio.wait_for(slow_started.wait(), timeout=1.0)

    runtime.expires_at = utcnow() - timedelta(seconds=1)
    poll_task = asyncio.create_task(manager.get_state(user_id='user_1', session_id=created.session_id))
    await _wait_for_runtime_status(runtime, ProtectedSessionLifecycle.TERMINATING)

    with pytest.raises(ProtectedSessionError) as blocked:
        await manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='reload'),
        )
    assert blocked.value.code == 'protected_session_terminating'

    release_slow.set()

    with pytest.raises(ProtectedSessionError) as action_error:
        await action_task
    assert action_error.value.code == 'protected_session_terminating'

    with pytest.raises(ProtectedSessionError) as poll_error:
        await poll_task
    assert poll_error.value.code == 'protected_session_expired'
    assert runtime.status == ProtectedSessionLifecycle.EXPIRED
    assert runtime.current_page is None


@pytest.mark.asyncio
async def test_protected_session_terminal_state_is_stable_after_close():
    manager = ProtectedSessionManager(
        settings=Settings(PROTECTED_SESSION_ALLOWED_HOSTS='example.com'),
        transport=_base_mock_transport(),
    )

    created = await manager.create_session(user_id='user_1', url='https://example.com/start')
    await manager.end_session(user_id='user_1', session_id=created.session_id)

    with pytest.raises(ProtectedSessionError) as state_error:
        await manager.get_state(user_id='user_1', session_id=created.session_id)
    assert state_error.value.code == 'protected_session_closed'

    with pytest.raises(ProtectedSessionError) as action_error:
        await manager.apply_action(
            user_id='user_1',
            session_id=created.session_id,
            action=ProtectedSessionActionRequest(action='reload'),
        )
    assert action_error.value.code == 'protected_session_closed'
