from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import ResearchRequest, ResearchResponse
from app.security import CurrentAccessContext, get_current_access_context
from app.services.research import ResearchService

router = APIRouter(prefix='/v1', tags=['research'])


@router.post('/research', response_model=ResearchResponse)
def research(
    payload: ResearchRequest,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> ResearchResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    return ResearchService().build_summary(
        title=payload.title,
        prompt_context=payload.prompt_context,
        items=payload.items,
    )
