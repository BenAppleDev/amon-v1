from __future__ import annotations

from fastapi import Request

from app.config import Settings
from app.security_ops_identity import TrustedUpstreamIdentity, TrustedUpstreamIdentityResult


def resolve_cloudflare_access_identity(
    *,
    request: Request,
    settings: Settings,
) -> TrustedUpstreamIdentityResult:
    operator_header = settings.resolved_ops_trusted_upstream_asserted_operator_id_header()
    jwt_header = settings.resolved_ops_trusted_upstream_cloudflare_access_jwt_header()
    provided_operator = request.headers.get(operator_header)
    provided_jwt = request.headers.get(jwt_header)
    attempted = provided_operator is not None or provided_jwt is not None

    if not attempted:
        return TrustedUpstreamIdentityResult(mode='asserted_identity_headers', status='no_assertion')
    if provided_operator is None:
        return TrustedUpstreamIdentityResult(
            mode='asserted_identity_headers',
            status='rejected',
            failure_code='missing_cloudflare_access_operator_identity_header',
            failure_message=(
                f'Missing Cloudflare Access operator identity header {operator_header}.'
            ),
            failure_status_code=400,
        )
    if provided_jwt is None:
        return TrustedUpstreamIdentityResult(
            mode='asserted_identity_headers',
            status='rejected',
            failure_code='missing_cloudflare_access_jwt_assertion_header',
            failure_message=(
                f'Missing Cloudflare Access JWT assertion header {jwt_header}.'
            ),
            failure_status_code=401,
        )

    operator_id = provided_operator.strip()
    if not operator_id:
        return TrustedUpstreamIdentityResult(
            mode='asserted_identity_headers',
            status='rejected',
            failure_code='empty_cloudflare_access_operator_identity_header',
            failure_message=(
                f'Cloudflare Access operator identity header {operator_header} was empty.'
            ),
            failure_status_code=400,
        )

    jwt_assertion = provided_jwt.strip()
    if not jwt_assertion:
        return TrustedUpstreamIdentityResult(
            mode='asserted_identity_headers',
            status='rejected',
            failure_code='empty_cloudflare_access_jwt_assertion_header',
            failure_message=(
                f'Cloudflare Access JWT assertion header {jwt_header} was empty.'
            ),
            failure_status_code=401,
        )
    if not _looks_like_jwt(jwt_assertion):
        return TrustedUpstreamIdentityResult(
            mode='asserted_identity_headers',
            status='rejected',
            failure_code='invalid_cloudflare_access_jwt_assertion_format',
            failure_message=(
                f'Cloudflare Access JWT assertion header {jwt_header} did not look like a JWT.'
            ),
            failure_status_code=401,
        )

    return TrustedUpstreamIdentityResult(
        mode='asserted_identity_headers',
        status='resolved',
        identity=TrustedUpstreamIdentity(
            operator_id=operator_id,
            auth_method='trusted_upstream_asserted_identity_cloudflare_access',
            bootstrap_mode='asserted_identity_headers',
        ),
    )


def _looks_like_jwt(value: str) -> bool:
    parts = value.split('.')
    return len(parts) == 3 and all(part.strip() for part in parts)
