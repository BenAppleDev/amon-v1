from __future__ import annotations

from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup

from app.schemas import StructuredRetrievalResponse
from app.security import utcnow


class RetrievalService:
    async def retrieve(self, url: str) -> StructuredRetrievalResponse:
        async with httpx.AsyncClient(timeout=20.0, follow_redirects=True, headers={'User-Agent': 'AmonBot/0.1'}) as client:
            response = await client.get(url)
            response.raise_for_status()

        soup = BeautifulSoup(response.text, 'html.parser')
        title = self._extract_title(soup, response.url)
        excerpt, bullet_points = self._extract_text(soup)
        return StructuredRetrievalResponse(
            url=str(response.url),
            canonical_url=str(response.url),
            title=title,
            domain=urlparse(str(response.url)).netloc,
            excerpt=excerpt,
            bullet_points=bullet_points,
            retrieved_at=utcnow(),
        )

    @staticmethod
    def _extract_title(soup: BeautifulSoup, final_url: httpx.URL) -> str:
        if soup.title and soup.title.string:
            return soup.title.string.strip()
        og_title = soup.find('meta', attrs={'property': 'og:title'})
        if og_title and og_title.get('content'):
            return og_title['content'].strip()
        h1 = soup.find('h1')
        if h1:
            return h1.get_text(' ', strip=True)
        return str(final_url)

    @staticmethod
    def _extract_text(soup: BeautifulSoup) -> tuple[str | None, list[str]]:
        meta_desc = soup.find('meta', attrs={'name': 'description'})
        if meta_desc and meta_desc.get('content'):
            description = meta_desc['content'].strip()
        else:
            paragraphs = [p.get_text(' ', strip=True) for p in soup.find_all('p')]
            paragraphs = [p for p in paragraphs if len(p) > 60]
            description = ' '.join(paragraphs[:2]).strip() if paragraphs else None

        bullet_points: list[str] = []
        if description:
            sentences = [segment.strip() for segment in description.replace('\n', ' ').split('.') if segment.strip()]
            bullet_points = [f'{sentence}.' for sentence in sentences[:3]]

        return (description[:600] if description else None, bullet_points)
