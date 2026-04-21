from fastapi import APIRouter, Depends

from app.schemas import UserView
from app.security import CurrentAccessContext, get_current_access_context

router = APIRouter(prefix='/v1', tags=['me'])


@router.get('/me', response_model=UserView)
def me(current: CurrentAccessContext = Depends(get_current_access_context)) -> UserView:
    return UserView(
        id=current.user.id,
        status=current.user.status,
        entitlement_tier=current.entitlement.tier,
        entitlement_status=current.entitlement.status,
    )
