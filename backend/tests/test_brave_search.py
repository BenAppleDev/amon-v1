import hashlib

import httpx
import pytest

from app.services.brave_search import BraveSearchProvider
from app.services.mock_search import MockSearchProvider
from app.services.search_provider import SearchProviderConfigurationError, get_search_provider


@pytest.mark.asyncio
async def test_brave_provider_normalizes_web_results():
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.url.path == '/res/v1/web/search'
        assert request.url.params['q'] == 'privacy browser'
        assert request.url.params['count'] == '2'
        assert request.headers['X-Subscription-Token'] == 'test-key'
        return httpx.Response(
            200,
            json={
                'web': {
                    'results': [
                        {
                            'uuid': 'brave-result-1',
                            'title': 'Privacy Browser Guide',
                            'url': 'https://example.com/guide',
                            'description': 'An overview of privacy browser options.',
                            'age': '2 days ago',
                            'language': 'en',
                        },
                        {
                            'title': 'Vendor docs',
                            'url': 'https://docs.example.com/search',
                            'description': 'Product documentation for search.',
                        },
                    ]
                }
            },
        )

    provider = BraveSearchProvider(api_key='test-key', transport=httpx.MockTransport(handler))
    results = await provider.search('privacy browser', 2)

    assert len(results) == 2
    assert results[0].id == 'brave-result-1'
    assert results[0].provider.provider_result_id == 'brave-result-1'
    assert results[0].provider.name == 'brave'
    assert results[0].result_type == 'article'
    assert results[0].domain == 'example.com'
    assert results[0].typed_metadata == {'age': '2 days ago', 'language': 'en'}

    expected_id = f"brave_{hashlib.sha256('https://docs.example.com/search'.encode('utf-8')).hexdigest()[:24]}"
    assert results[1].id == expected_id
    assert results[1].provider.provider_result_id is None
    assert results[1].result_type == 'web_page'
    assert results[1].typed_metadata is None


@pytest.mark.asyncio
async def test_brave_provider_returns_empty_list_for_missing_web_results():
    def handler(_request: httpx.Request) -> httpx.Response:
        return httpx.Response(200, json={'web': {'results': [{'title': 'missing url'}]}})

    provider = BraveSearchProvider(api_key='test-key', transport=httpx.MockTransport(handler))
    results = await provider.search('privacy browser', 5)

    assert results == []


def test_get_search_provider_falls_back_to_mock_in_development(monkeypatch):
    monkeypatch.setenv('APP_ENV', 'development')
    monkeypatch.setenv('SEARCH_PROVIDER', 'brave')
    monkeypatch.delenv('BRAVE_API_KEY', raising=False)

    provider = get_search_provider()

    assert isinstance(provider, MockSearchProvider)


def test_get_search_provider_requires_api_key_outside_development(monkeypatch):
    monkeypatch.setenv('APP_ENV', 'production')
    monkeypatch.setenv('SEARCH_PROVIDER', 'brave')
    monkeypatch.delenv('BRAVE_API_KEY', raising=False)

    with pytest.raises(SearchProviderConfigurationError):
        get_search_provider()
