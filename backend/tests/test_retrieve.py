import asyncio

import httpx

from app.routers import retrieve as retrieve_router_module
from app.services.retrieval import RetrievalError, RetrievalService


def _login(client):
    response = client.post('/v1/auth/dev-login', json={'apple_subject': 'pytest-user'})
    assert response.status_code == 200
    return response.json()['access_token']


def test_retrieval_service_extracts_readable_content():
    async def handler(request: httpx.Request) -> httpx.Response:
        html = """
        <html>
            <head>
                <title>Readable Page</title>
                <meta name="description" content="A useful readable summary for testing retrieval." />
            </head>
            <body></body>
        </html>
        """
        return httpx.Response(200, text=html, request=request)

    service = RetrievalService(transport=httpx.MockTransport(handler))
    payload = asyncio.run(service.retrieve('https://example.com/article'))

    assert payload.title == 'Readable Page'
    assert payload.domain == 'example.com'
    assert payload.excerpt == 'A useful readable summary for testing retrieval.'


def test_retrieval_service_maps_blocked_fetch_to_structured_error():
    async def handler(request: httpx.Request) -> httpx.Response:
        return httpx.Response(403, text='forbidden', request=request)

    service = RetrievalService(transport=httpx.MockTransport(handler))

    try:
        asyncio.run(service.retrieve('https://example.com/blocked'))
        raise AssertionError('Expected RetrievalError')
    except RetrievalError as error:
        assert error.status_code == 403
        assert error.code == 'retrieve_blocked'


def test_retrieve_route_returns_structured_403_error(client, monkeypatch):
    async def blocked_retrieve(self, url: str):
        raise RetrievalError(
            status_code=403,
            code='retrieve_blocked',
            message='That site blocked Amon from preparing a clean view. You can still open the original page directly.',
        )

    monkeypatch.setattr(retrieve_router_module.RetrievalService, 'retrieve', blocked_retrieve)

    token = _login(client)
    response = client.post(
        '/v1/retrieve',
        json={'url': 'https://example.com/blocked'},
        headers={'Authorization': f'Bearer {token}'},
    )

    assert response.status_code == 403
    assert response.json()['detail']['code'] == 'retrieve_blocked'
