from __future__ import annotations

from fastapi import Header, HTTPException, status

from app.config import Settings, get_settings


def expected_route_relay_shared_secret(settings: Settings) -> str | None:
    return settings.route_relay_shared_secret or (
        'amon-route-relay-dev' if settings.is_local_like_env() else None
    )


async def require_route_relay_control(
    x_amon_route_relay_secret: str | None = Header(default=None, alias='X-Amon-Route-Relay-Secret'),
) -> None:
    settings = get_settings()
    expected = expected_route_relay_shared_secret(settings)
    if expected is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail='Route relay validation is not configured.',
        )
    if x_amon_route_relay_secret != expected:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid route relay secret.',
        )
