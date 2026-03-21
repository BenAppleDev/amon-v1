from __future__ import annotations

from typing import Protocol

from app.schemas import SearchResult


class SearchProvider(Protocol):
    async def search(self, query: str, count: int) -> list[SearchResult]:
        ...
