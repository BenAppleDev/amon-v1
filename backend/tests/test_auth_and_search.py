from datetime import timedelta

from app.models import ProductSessionRecord, SessionRecord
from app.security import resolve_current_access_context_from_token, utcnow


def _login(client):
    response = client.post('/v1/auth/dev-login', json={'apple_subject': 'pytest-user'})
    assert response.status_code == 200
    return response.json()['access_token']


def test_dev_login_and_me(client):
    token = _login(client)
    response = client.get('/v1/me', headers={'Authorization': f'Bearer {token}'})
    assert response.status_code == 200
    payload = response.json()
    assert payload['entitlement_tier'] == 'full_access'


def test_dev_login_creates_distinct_product_session_context(client, db_session_factory):
    token = _login(client)

    db = db_session_factory()
    try:
        context = resolve_current_access_context_from_token(token, db)

        assert context.product_session.id == token
        assert context.auth_session.id != token
        assert context.product_session.account_id == context.account.id
        assert context.product_session.entitlement_id == context.entitlement.id
        assert context.product_session.auth_session_id == context.auth_session.id

        product_session = db.get(ProductSessionRecord, token)
        auth_session = db.get(SessionRecord, context.auth_session.id)
        assert product_session is not None
        assert auth_session is not None
        assert auth_session.user_id == product_session.account_id
    finally:
        db.close()


def test_product_session_is_rejected_when_parent_auth_session_expires(client, db_session_factory):
    token = _login(client)

    db = db_session_factory()
    try:
        product_session = db.get(ProductSessionRecord, token)
        assert product_session is not None

        auth_session = db.get(SessionRecord, product_session.auth_session_id)
        assert auth_session is not None
        auth_session.expires_at = utcnow() - timedelta(seconds=1)
        db.add(auth_session)
        db.commit()
    finally:
        db.close()

    response = client.get('/v1/me', headers={'Authorization': f'Bearer {token}'})
    assert response.status_code == 401

    db = db_session_factory()
    try:
        product_session = db.get(ProductSessionRecord, token)
        assert product_session is not None
        assert product_session.revoked_at is not None
    finally:
        db.close()


def test_search_returns_mock_results(client):
    token = _login(client)
    response = client.post(
        '/v1/search',
        json={'query': 'best neighborhoods in chicago', 'count': 3},
        headers={'Authorization': f'Bearer {token}'},
    )
    assert response.status_code == 200
    payload = response.json()
    assert len(payload['results']) == 3
    assert payload['results'][0]['provider']['name'] == 'mock'


def test_compare_and_research(client):
    token = _login(client)
    headers = {'Authorization': f'Bearer {token}'}
    items = [
        {
            'item_id': 'item_1',
            'title': 'Lincoln Park',
            'url': 'https://example.com/lincoln-park',
            'domain': 'example.com',
            'snippet': 'Walkable and family-friendly.',
            'cleaned_excerpt': 'Lincoln Park offers walkability, green space, and a residential feel.',
            'bullet_points': ['Walkable', 'Family-friendly'],
            'typed_metadata': {'rating': 4.7},
        },
        {
            'item_id': 'item_2',
            'title': 'Wicker Park',
            'url': 'https://example.com/wicker-park',
            'domain': 'example.com',
            'snippet': 'Nightlife and arts.',
            'cleaned_excerpt': 'Wicker Park is known for nightlife, culture, and restaurants.',
            'bullet_points': ['Nightlife', 'Artsy'],
            'typed_metadata': {'rating': 4.5},
        },
    ]

    compare_response = client.post('/v1/compare', json={'title': 'Neighborhood compare', 'items': items}, headers=headers)
    assert compare_response.status_code == 200
    assert compare_response.json()['title'] == 'Neighborhood compare'

    research_response = client.post(
        '/v1/research',
        json={'title': 'Neighborhood research', 'prompt_context': 'Best fit for relocation', 'items': items},
        headers=headers,
    )
    assert research_response.status_code == 200
    assert research_response.json()['model']['name'] == 'amon-grounded-heuristic'
