from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import RetrieveRequest, StructuredRetrievalResponse
from app.security import CurrentUser, get_current_user
from app.services.retrieval import RetrievalService

router = APIRouter(prefix='/v1', tags=['retrieve'])


@router.post('/retrieve', response_model=StructuredRetrievalResponse)
async def retrieve(
    payload: RetrieveRequest,
    current: CurrentUser = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> StructuredRetrievalResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    return await RetrievalService().retrieve(str(payload.url))
