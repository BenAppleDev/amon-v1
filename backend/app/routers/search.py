from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import SearchRequest, SearchResponse
from app.security import CurrentUser, get_current_user
from app.services.search_provider import SearchProviderConfigurationError, get_search_provider

router = APIRouter(prefix='/v1', tags=['search'])


@router.post('/search', response_model=SearchResponse)
async def search(
    payload: SearchRequest,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> SearchResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        provider = get_search_provider()
    except SearchProviderConfigurationError as exc:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(exc)) from exc
    results = await provider.search(payload.query, payload.count)
    return SearchResponse(results=results)
