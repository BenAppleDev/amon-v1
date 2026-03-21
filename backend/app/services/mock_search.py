from __future__ import annotations

from urllib.parse import quote_plus

from app.schemas import ProviderInfo, SearchResult


def _infer_result_type(query: str, index: int) -> str:
    lowered = query.lower()
    if any(word in lowered for word in ['best', 'guide', 'review', 'news']):
        return 'article'
    if any(word in lowered for word in ['restaurant', 'hotel', 'neighborhood', 'near me']):
        return 'place'
    if any(word in lowered for word in ['buy', 'price', 'laptop', 'phone', 'product']):
        return 'product'
    return 'web_page' if index % 2 == 0 else 'article'


class MockSearchProvider:
    async def search(self, query: str, count: int) -> list[SearchResult]:
        results: list[SearchResult] = []
        slug = quote_plus(query.lower())
        for index in range(1, count + 1):
            domain = f'example{index}.com'
            results.append(
                SearchResult(
                    id=f'mock_{index}',
                    title=f'{query.title()} — result {index}',
                    url=f'https://{domain}/{slug}/{index}',
                    snippet=f'Mock result {index} for "{query}". Replace this provider with Brave or another search API in production.',
                    result_type=_infer_result_type(query, index),
                    domain=domain,
                    typed_metadata={
                        'mock_rank': index,
                        'hint': 'provider-fallback',
                    },
                    provider=ProviderInfo(name='mock', provider_result_id=f'mock_{index}'),
                )
            )
        return results
