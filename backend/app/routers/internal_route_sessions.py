from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.schemas import RouteRelayValidationRequest, RouteRelayValidationResponse
from app.security_route_relay import require_route_relay_control
from app.services.route_session_control_plane import get_route_session_control_plane

router = APIRouter(prefix='/internal/route-sessions', tags=['internal_route_sessions'])


@router.post('/validate', response_model=RouteRelayValidationResponse)
async def validate_route_session_for_relay(
    request: RouteRelayValidationRequest,
    _: None = Depends(require_route_relay_control),
    db: Session = Depends(get_db),
) -> RouteRelayValidationResponse:
    control_plane = get_route_session_control_plane()
    return control_plane.validate_relay_request(request=request, db=db)
