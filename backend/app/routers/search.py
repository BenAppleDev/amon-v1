from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import get_settings
from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import SearchRequest, SearchResponse
from app.security import CurrentUser, get_current_user
from app.services.brave_search import BraveSearchProvider
from app.services.mock_search import MockSearchProvider

router = APIRouter(prefix='/v1', tags=['search'])


@router.post('/search', response_model=SearchResponse)
async def search(
    payload: SearchRequest,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SearchResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    settings = get_settings()
    provider = MockSearchProvider()
    if settings.search_provider.lower() == 'brave' and settings.brave_api_key:
        provider = BraveSearchProvider()
    results = await provider.search(payload.query, payload.count)
    return SearchResponse(results=results)
