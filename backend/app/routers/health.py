from fastapi import APIRouter

from app.config import get_settings
from app.schemas import HealthResponse

router = APIRouter(tags=['health'])


def _health_payload() -> HealthResponse:
    settings = get_settings()
    return HealthResponse(
        app_name=settings.app_name,
        version=settings.app_version,
        environment=settings.app_env,
    )


@router.get('/healthz', response_model=HealthResponse)
def healthz() -> HealthResponse:
    return _health_payload()


@router.get('/health', response_model=HealthResponse)
def health() -> HealthResponse:
    return _health_payload()
