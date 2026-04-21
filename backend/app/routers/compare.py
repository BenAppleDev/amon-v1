from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import CompareRequest, CompareResponse
from app.security import CurrentAccessContext, get_current_access_context
from app.services.compare import CompareService

router = APIRouter(prefix='/v1', tags=['compare'])


@router.post('/compare', response_model=CompareResponse)
def compare(
    payload: CompareRequest,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> CompareResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    return CompareService().build_compare(title=payload.title, items=payload.items)
