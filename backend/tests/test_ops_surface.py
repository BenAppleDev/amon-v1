from __future__ import annotations

import asyncio
from datetime import timedelta

import httpx

from app.config import Settings
from app.models import Entitlement, SessionRecord, User
from app.routers import internal_protected_sessions as internal_router_module
from app.routers import ops_protected_sessions as ops_router_module
from app.routers import protected_sessions as protected_sessions_router_module
from app.security import CurrentUser, utcnow
from app.services.protected_session_control_plane import ProtectedSessionControlPlane
from app.services.protected_session_ops_history import ProtectedSessionOpsHistoryStore


def _current_user(*, user_id: str = 'user_1') -> CurrentUser:
    now = utcnow()
    user = User(id=user_id, status='active')
    entitlement = Entitlement(id=f'ent_{user_id}', user_id=user_id, tier='full_access', status='active')
    session = SessionRecord(
        id=f'session_{user_id}',
        user_id=user_id,
        issued_at=now,
        expires_at=now + timedelta(hours=24),
    )
    return CurrentUser(user=user, entitlement=entitlement, session=session)


def _login(client, subject: str = 'ops-user') -> str:
    response = client.post('/v1/auth/dev-login', json={'apple_subject': subject})
    assert response.status_code == 200
    return response.json()['access_token']


def _html_response(request: httpx.Request, html: str) -> httpx.Response:
    return httpx.Response(
        200,
        text=html,
        request=request,
        headers={'content-type': 'text/html; charset=utf-8'},
    )


def _simple_transport() -> httpx.MockTransport:
    async def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == '/start':
            return _html_response(
                request,
                """
                <html>
                  <head><title>Ops Test</title></head>
                  <body>
                    <p>Test page</p>
                    <a href="/next">Next</a>
                  </body>
                </html>
                """,
            )
        if request.url.path == '/next':
            return _html_response(
                request,
                """
                <html>
                  <head><title>Next</title></head>
                  <body><p>Next page</p></body>
                </html>
                """,
            )
        return httpx.Response(404, text='missing', request=request)

    return httpx.MockTransport(handler)


def _patch_router_control_plane(monkeypatch, control_plane: ProtectedSessionControlPlane) -> None:
    monkeypatch.setattr(protected_sessions_router_module, 'get_protected_session_control_plane', lambda: control_plane)
    monkeypatch.setattr(internal_router_module, 'get_protected_session_control_plane', lambda: control_plane)
    monkeypatch.setattr(ops_router_module, 'get_protected_session_control_plane', lambda: control_plane)


def _control_plane(*, settings: Settings, transport: httpx.AsyncBaseTransport, db_session_factory) -> ProtectedSessionControlPlane:
    history_store = ProtectedSessionOpsHistoryStore(settings=settings, session_factory=db_session_factory)
    return ProtectedSessionControlPlane(
        settings=settings,
        transport=transport,
        history_store=history_store,
    )


def test_ops_dev_login_uses_cookie_backed_session_for_metadata_routes(client, monkeypatch, db_session_factory):
    monkeypatch.setenv('APP_ENV', 'development')
    monkeypatch.setenv('INTERNAL_ADMIN_TOKEN', 'ops-dev-token')
    monkeypatch.setenv('OPS_ENVIRONMENT_KEY', 'local')
    monkeypatch.setenv('OPS_ENVIRONMENT_LABEL', 'Local')

    settings = Settings(
        PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
        INTERNAL_ADMIN_TOKEN='ops-dev-token',
        OPS_ENVIRONMENT_KEY='local',
        OPS_ENVIRONMENT_LABEL='Local',
    )
    control_plane = _control_plane(settings=settings, transport=_simple_transport(), db_session_factory=db_session_factory)
    try:
        _patch_router_control_plane(monkeypatch, control_plane)

        token = _login(client)
        user_headers = {'Authorization': f'Bearer {token}'}
        created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=user_headers)
        assert created.status_code == 200
        session_id = created.json()['session_id']

        auth_response = client.post(
            '/ops/auth/session',
            json={'admin_token': 'ops-dev-token', 'operator_id': 'ops-local@example.com'},
        )
        assert auth_response.status_code == 200
        auth_json = auth_response.json()
        assert auth_json['authenticated'] is True
        assert auth_json['auth_method'] == 'dev_token'
        assert auth_json['environment']['key'] == 'local'
        assert settings.ops_session_cookie_name in auth_response.headers['set-cookie']

        status_response = client.get('/ops/auth/status')
        overview = client.get('/ops/api/protected-sessions/overview')
        detail = client.get(f'/ops/api/protected-sessions/sessions/{session_id}')
        internal_unauthorized = client.get('/internal/protected-sessions/overview')

        assert status_response.status_code == 200
        assert status_response.json()['authenticated'] is True
        assert overview.status_code == 200
        assert detail.status_code == 200
        assert internal_unauthorized.status_code == 401
        assert 'current_page' not in detail.json()
        assert 'current_frame' not in detail.json()
    finally:
        asyncio.run(control_plane.shutdown())


def test_ops_proxy_bootstrap_and_history_are_metadata_only(client, monkeypatch, db_session_factory):
    monkeypatch.setenv('APP_ENV', 'production')
    monkeypatch.setenv('OPS_TRUSTED_PROXY_SECRET', 'proxy-secret')
    monkeypatch.setenv('OPS_ALLOWED_OPERATOR_IDS', 'ops@example.com')
    monkeypatch.setenv('OPS_ENVIRONMENT_KEY', 'staging')
    monkeypatch.setenv('OPS_ENVIRONMENT_LABEL', 'Staging')
    monkeypatch.setenv('OPS_ALLOW_DEV_TOKEN_LOGIN', 'false')

    settings = Settings(
        PROTECTED_SESSION_ALLOWED_HOSTS='example.com',
        OPS_TRUSTED_PROXY_SECRET='proxy-secret',
        OPS_ALLOWED_OPERATOR_IDS='ops@example.com',
        OPS_ENVIRONMENT_KEY='staging',
        OPS_ENVIRONMENT_LABEL='Staging',
        OPS_ALLOW_DEV_TOKEN_LOGIN='false',
    )
    control_plane = _control_plane(settings=settings, transport=_simple_transport(), db_session_factory=db_session_factory)
    try:
        _patch_router_control_plane(monkeypatch, control_plane)

        token = _login(client, subject='ops-history-user')
        user_headers = {'Authorization': f'Bearer {token}'}
        created = client.post('/v1/protected-sessions', json={'url': 'https://example.com/start'}, headers=user_headers)
        assert created.status_code == 200
        session_id = created.json()['session_id']
        ended = client.delete(f'/v1/protected-sessions/{session_id}', headers=user_headers)
        assert ended.status_code == 200

        proxy_headers = {
            'X-Amon-Ops-Proxy-Secret': 'proxy-secret',
            'X-Amon-Operator-Id': 'ops@example.com',
        }

        surface = client.get('/ops/')
        status_response = client.get('/ops/auth/status', headers=proxy_headers)
        events = client.get('/ops/api/protected-sessions/events?limit=20')
        history_summary = client.get('/ops/api/protected-sessions/history/summary?hours=24')
        snapshots = client.get('/ops/api/protected-sessions/history/snapshots?limit=12')

        assert surface.status_code == 200
        assert 'Amon Ops' in surface.text
        assert status_response.status_code == 200
        assert status_response.json()['authenticated'] is True
        assert status_response.json()['auth_method'] == 'trusted_proxy'
        assert status_response.json()['environment']['label'] == 'Staging'

        assert events.status_code == 200
        assert history_summary.status_code == 200
        assert snapshots.status_code == 200

        events_json = events.json()
        summary_json = history_summary.json()
        snapshots_json = snapshots.json()

        assert events_json['events']
        assert summary_json['environment']['key'] == 'staging'
        assert summary_json['total_events'] >= 2
        assert snapshots_json['snapshots']
        assert 'document' not in str(snapshots_json)
        assert 'current_page' not in str(events_json)

        logout = client.post('/ops/auth/logout')
        assert logout.status_code == 200
        unauthorized = client.get('/ops/api/protected-sessions/overview')
        assert unauthorized.status_code == 401
    finally:
        asyncio.run(control_plane.shutdown())
