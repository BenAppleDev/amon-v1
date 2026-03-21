from __future__ import annotations

import hashlib
from collections.abc import Mapping
from typing import Any
from urllib.parse import urlparse

import httpx
from pydantic import ValidationError

from app.config import get_settings
from app.schemas import ProviderInfo, SearchResult


class BraveSearchProvider:
    WEB_SEARCH_PATH = '/res/v1/web/search'

    def __init__(
        self,
        api_key: str | None = None,
        base_url: str | None = None,
        timeout_seconds: float | None = None,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        settings = get_settings()
        self.api_key = api_key or settings.brave_api_key
        if not self.api_key:
            raise ValueError('BRAVE_API_KEY is required for BraveSearchProvider')
        resolved_base_url = (base_url or settings.brave_base_url).rstrip('/')
        self.search_url = f'{resolved_base_url}{self.WEB_SEARCH_PATH}'
        self.timeout_seconds = timeout_seconds or settings.brave_timeout_seconds
        self.transport = transport

    async def search(self, query: str, count: int) -> list[SearchResult]:
        async with httpx.AsyncClient(timeout=self.timeout_seconds, transport=self.transport) as client:
            response = await client.get(
                self.search_url,
                headers={'X-Subscription-Token': self.api_key},
                params={'q': query, 'count': count},
            )
            response.raise_for_status()
            payload = response.json()
        return self._normalize_results(payload)

    def _normalize_results(self, payload: dict[str, Any]) -> list[SearchResult]:
        web_payload = payload.get('web')
        if not isinstance(web_payload, dict):
            return []
        raw_results = web_payload.get('results')
        if not isinstance(raw_results, list):
            return []

        normalized: list[SearchResult] = []
        for item in raw_results:
            result = self._to_result(item)
            if result is not None:
                normalized.append(result)
        return normalized

    def _to_result(self, item: Any) -> SearchResult | None:
        if not isinstance(item, Mapping):
            return None

        url = self._extract_url(item)
        if not url:
            return None
        parsed = urlparse(url)
        if not parsed.netloc:
            return None

        provider_result_id = self._extract_provider_result_id(item)
        typed_metadata = self._typed_metadata(item)

        try:
            return SearchResult(
                id=provider_result_id or self._fallback_result_id(url),
                title=self._first_non_empty(item.get('title'), item.get('meta_title')) or url,
                url=url,
                snippet=self._first_non_empty(
                    item.get('description'),
                    item.get('snippet'),
                    item.get('meta_description'),
                ),
                result_type=self._infer_type(item),
                domain=parsed.netloc,
                typed_metadata=typed_metadata or None,
                provider=ProviderInfo(name='brave', provider_result_id=provider_result_id),
            )
        except ValidationError:
            return None

    @staticmethod
    def _extract_url(item: Mapping[str, Any]) -> str | None:
        for candidate in (item.get('url'), item.get('profile', {}).get('url') if isinstance(item.get('profile'), Mapping) else None):
            if isinstance(candidate, str) and candidate.strip():
                return candidate.strip()
        return None

    @staticmethod
    def _extract_provider_result_id(item: Mapping[str, Any]) -> str | None:
        for candidate in (item.get('uuid'), item.get('id')):
            if isinstance(candidate, str) and candidate.strip():
                return candidate.strip()
        return None

    @staticmethod
    def _typed_metadata(item: Mapping[str, Any]) -> dict[str, Any]:
        typed_metadata: dict[str, Any] = {}
        age = item.get('age') or item.get('page_age')
        if age:
            typed_metadata['age'] = age
        language = item.get('language')
        if language:
            typed_metadata['language'] = language
        return typed_metadata

    @staticmethod
    def _first_non_empty(*values: Any) -> str | None:
        for value in values:
            if isinstance(value, str) and value.strip():
                return value.strip()
        return None

    @staticmethod
    def _fallback_result_id(url: str) -> str:
        digest = hashlib.sha256(url.encode('utf-8')).hexdigest()[:24]
        return f'brave_{digest}'

    @staticmethod
    def _infer_type(item: Mapping[str, Any]) -> str:
        title = (item.get('title') or '').lower()
        description = (item.get('description') or '').lower()
        combined = f'{title} {description}'
        if item.get('age') or item.get('page_age'):
            return 'article'
        if any(token in combined for token in ['news', 'guide', 'article', 'opinion']):
            return 'article'
        return 'web_page'
