from fastapi import APIRouter, Depends

from app.schemas import UserView
from app.security import CurrentUser, get_current_user

router = APIRouter(prefix='/v1', tags=['me'])


@router.get('/me', response_model=UserView)
def me(current: CurrentUser = Depends(get_current_user)) -> UserView:
    return UserView(
        id=current.user.id,
        status=current.user.status,
        entitlement_tier=current.entitlement.tier,
        entitlement_status=current.entitlement.status,
    )
