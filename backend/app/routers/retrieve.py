from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import RetrieveRequest, StructuredRetrievalResponse
from app.security import CurrentAccessContext, get_current_access_context
from app.services.retrieval import RetrievalError, RetrievalService

router = APIRouter(prefix='/v1', tags=['retrieve'])


@router.post('/retrieve', response_model=StructuredRetrievalResponse)
async def retrieve(
    payload: RetrieveRequest,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> StructuredRetrievalResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        return await RetrievalService().retrieve(str(payload.url))
    except RetrievalError as exc:
        raise HTTPException(
            status_code=exc.status_code,
            detail={
                'code': exc.code,
                'message': exc.message,
            },
        ) from exc
