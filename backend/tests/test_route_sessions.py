from datetime import timedelta

from app.models import ProductSessionRecord, RouteSessionRecord, SessionRecord
from app.security import utcnow
from app.services.route_session_control_plane import RouteSessionControlPlane, RouteSessionError


def _login(client, subject: str = 'pytest-user') -> str:
    response = client.post('/v1/auth/dev-login', json={'apple_subject': subject})
    assert response.status_code == 200
    return response.json()['access_token']


def _relay_headers() -> dict[str, str]:
    return {'X-Amon-Route-Relay-Secret': 'amon-route-relay-dev'}


def test_route_session_mint_refresh_and_revoke(client):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}

    mint_response = client.post('/v1/route-sessions', headers=headers)
    assert mint_response.status_code == 200
    minted = mint_response.json()

    assert minted['status'] == 'active'
    assert minted['route_kind'] == 'local_routed'
    assert minted['transport_kind'] == 'packet_tunnel'
    assert minted['control_plane_kind'] == 'control_only'
    assert minted['access_token']
    assert minted['product_session_id'] == token
    assert 'auth_session_id' not in minted
    assert minted['refresh_after'] <= minted['expires_at']

    refresh_response = client.post(f"/v1/route-sessions/{minted['session_id']}/refresh", headers=headers)
    assert refresh_response.status_code == 200
    refreshed = refresh_response.json()

    assert refreshed['session_id'] == minted['session_id']
    assert refreshed['access_token'] != minted['access_token']
    assert refreshed['expires_at'] >= minted['expires_at']

    revoke_response = client.delete(f"/v1/route-sessions/{minted['session_id']}", headers=headers)
    assert revoke_response.status_code == 200
    revoked = revoke_response.json()

    assert revoked['session_id'] == minted['session_id']
    assert revoked['status'] == 'revoked'

    refresh_after_revoke = client.post(f"/v1/route-sessions/{minted['session_id']}/refresh", headers=headers)
    assert refresh_after_revoke.status_code == 410
    assert refresh_after_revoke.json()['detail']['code'] == 'route_session_revoked'


def test_route_session_refresh_rejects_other_authenticated_session(client):
    token_one = _login(client, subject='route-one')
    token_two = _login(client, subject='route-two')

    mint_response = client.post('/v1/route-sessions', headers={'Authorization': f'Bearer {token_one}'})
    session_id = mint_response.json()['session_id']

    other_refresh = client.post(
        f'/v1/route-sessions/{session_id}/refresh',
        headers={'Authorization': f'Bearer {token_two}'},
    )
    assert other_refresh.status_code == 404
    assert other_refresh.json()['detail']['code'] == 'route_session_missing'


def test_route_session_control_plane_access_token_resolution_marks_expired(client, db_session_factory):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    session_id = mint_response.json()['session_id']

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, session_id)
        assert record is not None
        record.expires_at = utcnow() - timedelta(seconds=1)
        db.add(record)
        db.commit()

        control_plane = RouteSessionControlPlane()
        try:
            control_plane.resolve_access_token(access_token=record.access_token, db=db)
            assert False, 'expected RouteSessionError'
        except RouteSessionError as exc:
            assert exc.code == 'route_session_expired'

        db.refresh(record)
        assert record.revoked_at is not None
        assert record.revoke_reason == 'expired'
    finally:
        db.close()


def test_internal_route_session_validation_accepts_matching_context(client):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_accept',
            'route_session_id': minted['session_id'],
            'route_access_token': minted['access_token'],
            'route_product_session_id': minted['product_session_id'],
            'requested_path': 'local_routed',
            'transport_kind': 'packet_tunnel',
            'client_platform': 'ios',
            'app_bundle_id': 'com.benappledev.Amon',
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'accepted'
    assert payload['code'] == 'route_session_valid'
    assert payload['session_id'] == minted['session_id']
    assert payload['product_session_id'] == minted['product_session_id']
    assert 'auth_session_id' not in payload
    assert 'user_id' not in payload


def test_internal_route_session_validation_keeps_legacy_auth_context_as_fallback_only(client, db_session_factory):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, minted['session_id'])
        assert record is not None
        auth_session_id = record.auth_session_id
    finally:
        db.close()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_legacy_auth_fallback',
            'route_session_id': minted['session_id'],
            'route_access_token': minted['access_token'],
            'route_auth_session_id': auth_session_id,
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'accepted'
    assert payload['product_session_id'] == minted['product_session_id']


def test_internal_route_session_validation_rejects_missing_or_malformed_token(client):
    missing_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={'request_id': 'req_missing'},
    )
    assert missing_response.status_code == 200
    assert missing_response.json()['status'] == 'rejected'
    assert missing_response.json()['code'] == 'route_session_missing_token'

    malformed_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_malformed',
            'route_access_token': 'bad token with spaces',
        },
    )
    assert malformed_response.status_code == 200
    assert malformed_response.json()['status'] == 'rejected'
    assert malformed_response.json()['code'] == 'route_session_malformed_token'


def test_internal_route_session_validation_rejects_mismatched_context(client):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_mismatch',
            'route_session_id': 'route_other',
            'route_access_token': minted['access_token'],
            'route_product_session_id': minted['product_session_id'],
        },
    )

    assert validate_response.status_code == 200
    assert validate_response.json()['status'] == 'rejected'
    assert validate_response.json()['code'] == 'route_session_context_mismatch'


def test_internal_route_session_validation_prefers_product_session_lineage_over_legacy_auth_context(
    client,
    db_session_factory,
):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    db = db_session_factory()
    try:
        product_session = db.get(ProductSessionRecord, minted['product_session_id'])
        assert product_session is not None
        legacy_row = RouteSessionRecord(
            id='route_legacy_null_parent',
            product_session_id=None,
            user_id=product_session.account_id,
            auth_session_id=product_session.auth_session_id,
            route_kind='local_routed',
            transport_kind='packet_tunnel',
            control_plane_kind='control_only',
            access_token='legacycompatrouteaccess0001',
            issued_at=utcnow(),
            last_refreshed_at=utcnow(),
            expires_at=utcnow() + timedelta(minutes=5),
        )
        db.add(legacy_row)
        db.commit()
    finally:
        db.close()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_product_preferred',
            'route_session_id': 'route_legacy_null_parent',
            'route_access_token': 'legacycompatrouteaccess0001',
            'route_product_session_id': minted['product_session_id'],
            'route_auth_session_id': 'wrong_auth_session',
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'accepted'
    assert payload['product_session_id'] == minted['product_session_id']


def test_internal_route_session_validation_backfills_legacy_null_parent_rows(client, db_session_factory):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, minted['session_id'])
        assert record is not None
        record.product_session_id = None
        db.add(record)
        db.commit()
    finally:
        db.close()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_legacy_backfill',
            'route_session_id': minted['session_id'],
            'route_access_token': minted['access_token'],
            'route_product_session_id': minted['product_session_id'],
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'accepted'
    assert payload['product_session_id'] == minted['product_session_id']

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, minted['session_id'])
        assert record is not None
        assert record.product_session_id == minted['product_session_id']
    finally:
        db.close()


def test_internal_route_session_validation_rejects_when_parent_auth_session_expires(client, db_session_factory):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, minted['session_id'])
        assert record is not None
        auth_session_id = record.auth_session_id
        session_record = db.get(SessionRecord, auth_session_id)
        assert session_record is not None
        session_record.expires_at = utcnow() - timedelta(seconds=1)
        db.add(session_record)
        db.commit()
    finally:
        db.close()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_auth_expired',
            'route_session_id': minted['session_id'],
            'route_access_token': minted['access_token'],
            'route_product_session_id': minted['product_session_id'],
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'rejected'
    assert payload['code'] == 'route_auth_session_invalid'


def test_internal_route_session_validation_rejects_when_parent_product_session_expires(client, db_session_factory):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    db = db_session_factory()
    try:
        product_session = db.get(ProductSessionRecord, minted['product_session_id'])
        assert product_session is not None
        product_session.expires_at = utcnow() - timedelta(seconds=1)
        db.add(product_session)
        db.commit()
    finally:
        db.close()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_product_expired',
            'route_session_id': minted['session_id'],
            'route_access_token': minted['access_token'],
            'route_product_session_id': minted['product_session_id'],
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'rejected'
    assert payload['code'] == 'route_product_session_invalid'


def test_internal_route_session_validation_rejects_legacy_rows_without_valid_product_parent(client, db_session_factory):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    mint_response = client.post('/v1/route-sessions', headers=headers)
    minted = mint_response.json()

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, minted['session_id'])
        assert record is not None
        record.product_session_id = None
        db.add(record)

        product_session = db.get(ProductSessionRecord, minted['product_session_id'])
        assert product_session is not None
        product_session.revoked_at = utcnow() - timedelta(seconds=1)
        db.add(product_session)
        db.commit()
    finally:
        db.close()

    validate_response = client.post(
        '/internal/route-sessions/validate',
        headers=_relay_headers(),
        json={
            'request_id': 'req_legacy_missing_parent',
            'route_session_id': minted['session_id'],
            'route_access_token': minted['access_token'],
            'route_product_session_id': minted['product_session_id'],
        },
    )

    assert validate_response.status_code == 200
    payload = validate_response.json()
    assert payload['status'] == 'rejected'
    assert payload['code'] == 'route_product_session_missing'

    db = db_session_factory()
    try:
        record = db.get(RouteSessionRecord, minted['session_id'])
        assert record is not None
        assert record.revoke_reason == 'product_session_missing'
        assert record.revoked_at is not None
    finally:
        db.close()
