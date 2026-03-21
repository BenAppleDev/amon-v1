from __future__ import annotations

from typing import Any
from urllib.parse import urlparse

import httpx

from app.config import get_settings
from app.schemas import ProviderInfo, SearchResult


class BraveSearchProvider:
    BASE_URL = 'https://api.search.brave.com/res/v1/web/search'

    def __init__(self) -> None:
        settings = get_settings()
        if not settings.brave_api_key:
            raise ValueError('BRAVE_API_KEY is required for BraveSearchProvider')
        self.api_key = settings.brave_api_key

    async def search(self, query: str, count: int) -> list[SearchResult]:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                self.BASE_URL,
                headers={'X-Subscription-Token': self.api_key},
                params={'q': query, 'count': count, 'search_lang': 'en', 'country': 'us'},
            )
            response.raise_for_status()
            payload = response.json()

        web_results = payload.get('web', {}).get('results', [])
        return [self._to_result(item, idx) for idx, item in enumerate(web_results, start=1)]

    def _to_result(self, item: dict[str, Any], idx: int) -> SearchResult:
        url = item.get('url') or item.get('profile', {}).get('url') or 'https://example.com'
        parsed = urlparse(url)
        result_type = self._infer_type(item)
        typed_metadata: dict[str, Any] = {}
        age = item.get('age') or item.get('page_age')
        if age:
            typed_metadata['published_at'] = age
        if item.get('profile', {}).get('name'):
            typed_metadata['author'] = item['profile']['name']

        return SearchResult(
            id=str(item.get('uuid') or item.get('id') or f'brave_{idx}'),
            title=item.get('title') or url,
            url=url,
            snippet=item.get('description') or item.get('meta_description'),
            result_type=result_type,
            domain=parsed.netloc,
            typed_metadata=typed_metadata or None,
            provider=ProviderInfo(name='brave', provider_result_id=str(item.get('uuid') or f'brave_{idx}')),
        )

    @staticmethod
    def _infer_type(item: dict[str, Any]) -> str:
        title = (item.get('title') or '').lower()
        description = (item.get('description') or '').lower()
        combined = f'{title} {description}'
        if any(token in combined for token in ['restaurant', 'hotel', 'neighborhood', 'address', 'map']):
            return 'place'
        if any(token in combined for token in ['price', 'buy', 'sale', 'product', 'review']):
            return 'product'
        if any(token in combined for token in ['news', 'guide', 'article', 'opinion']):
            return 'article'
        return 'web_page'
