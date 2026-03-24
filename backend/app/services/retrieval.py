from __future__ import annotations

from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup

from app.schemas import StructuredRetrievalResponse
from app.security import utcnow


class RetrievalError(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


class RetrievalService:
    DEFAULT_HEADERS = {
        'User-Agent': (
            'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) '
            'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 '
            'Mobile/15E148 Safari/604.1 Amon/0.1'
        ),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
    }

    def __init__(self, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self.transport = transport

    async def retrieve(self, url: str) -> StructuredRetrievalResponse:
        try:
            async with httpx.AsyncClient(
                timeout=20.0,
                follow_redirects=True,
                headers=self.DEFAULT_HEADERS,
                transport=self.transport,
            ) as client:
                response = await client.get(url)
                response.raise_for_status()
        except httpx.HTTPStatusError as exc:
            raise self._map_http_status_error(exc) from exc
        except httpx.TimeoutException as exc:
            raise RetrievalError(
                status_code=504,
                code='retrieve_timeout',
                message='Amon could not prepare a clean view because the site took too long to respond.',
            ) from exc
        except httpx.InvalidURL as exc:
            raise RetrievalError(
                status_code=400,
                code='retrieve_invalid_url',
                message='Amon could not prepare a clean view for that address.',
            ) from exc
        except httpx.HTTPError as exc:
            raise RetrievalError(
                status_code=502,
                code='retrieve_unreachable',
                message='Amon could not reach that site to prepare a clean view.',
            ) from exc

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
    def _map_http_status_error(error: httpx.HTTPStatusError) -> RetrievalError:
        status_code = error.response.status_code

        if status_code in {401, 403, 429, 451}:
            return RetrievalError(
                status_code=403,
                code='retrieve_blocked',
                message='That site blocked Amon from preparing a clean view. You can still open the original page directly.',
            )

        if status_code == 404:
            return RetrievalError(
                status_code=404,
                code='retrieve_not_found',
                message='Amon could not find that page to prepare a clean view.',
            )

        if 400 <= status_code < 500:
            return RetrievalError(
                status_code=502,
                code='retrieve_client_error',
                message='The site would not provide a clean view to Amon right now.',
            )

        return RetrievalError(
            status_code=502,
            code='retrieve_upstream_error',
            message='The site failed while Amon was preparing a clean view.',
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
