from __future__ import annotations

from dataclasses import dataclass
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


@dataclass(frozen=True)
class DemoTarget:
    domain: str
    url: str
    label: str


DEMO_TARGETS: tuple[DemoTarget, ...] = (
    DemoTarget(domain='example.com', url='https://example.com/', label='Reference page'),
    DemoTarget(domain='quotes.toscrape.com', url='https://quotes.toscrape.com/', label='Quote feed'),
    DemoTarget(domain='books.toscrape.com', url='https://books.toscrape.com/', label='Catalog page'),
    DemoTarget(domain='httpbin.org', url='https://httpbin.org/forms/post', label='Form demo'),
)


class MockSearchProvider:
    async def search(self, query: str, count: int) -> list[SearchResult]:
        results: list[SearchResult] = []
        slug = quote_plus(query.lower())
        for index in range(1, count + 1):
            target = DEMO_TARGETS[(index - 1) % len(DEMO_TARGETS)]
            results.append(
                SearchResult(
                    id=f'mock_{index}',
                    title=f'{query.title()} — {target.label}',
                    url=target.url,
                    snippet=(
                        f'Mock result {index} for "{query}" pointing at a real demo page on {target.domain}. '
                        f'Useful for local Standard, Clean View, and Protected Session testing.'
                    ),
                    result_type=_infer_result_type(query, index),
                    domain=target.domain,
                    typed_metadata={
                        'mock_rank': index,
                        'hint': 'provider-fallback',
                        'query_slug': slug,
                    },
                    provider=ProviderInfo(name='mock', provider_result_id=f'mock_{index}'),
                )
            )
        return results
