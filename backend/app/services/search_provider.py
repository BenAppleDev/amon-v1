from __future__ import annotations

from typing import Protocol

from app.config import Settings, get_settings
from app.schemas import SearchResult
from app.services.brave_search import BraveSearchProvider
from app.services.mock_search import MockSearchProvider


class SearchProviderConfigurationError(RuntimeError):
    pass


class SearchProvider(Protocol):
    async def search(self, query: str, count: int) -> list[SearchResult]:
        ...


def get_search_provider(settings: Settings | None = None) -> SearchProvider:
    settings = settings or get_settings()
    if settings.search_provider == 'brave':
        if settings.brave_api_key:
            return BraveSearchProvider(
                api_key=settings.brave_api_key,
                base_url=settings.brave_base_url,
                timeout_seconds=settings.brave_timeout_seconds,
            )
        if settings.app_env.lower() == 'development':
            return MockSearchProvider()
        raise SearchProviderConfigurationError('SEARCH_PROVIDER=brave requires BRAVE_API_KEY outside development')
    return MockSearchProvider()
