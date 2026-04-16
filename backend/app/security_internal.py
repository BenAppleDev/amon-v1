from __future__ import annotations

from fastapi import Header, HTTPException, status

from app.config import Settings, get_settings


def expected_internal_admin_token(settings: Settings) -> str | None:
    return settings.internal_admin_token or ('amon-internal-dev' if settings.app_env == 'development' else None)


async def require_internal_admin(
    x_amon_internal_token: str | None = Header(default=None, alias='X-Amon-Internal-Token'),
) -> None:
    settings = get_settings()
    expected = expected_internal_admin_token(settings)
    if expected is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail='Internal admin API is not configured.',
        )
    if x_amon_internal_token != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid internal admin token.',
        )
