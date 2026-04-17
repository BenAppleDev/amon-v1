from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from fastapi import Request

from app.config import Settings, get_settings

TrustedUpstreamIdentityMode = Literal['disabled', 'shared_secret_headers', 'asserted_identity_headers']
TrustedUpstreamResolutionStatus = Literal['disabled', 'no_assertion', 'resolved', 'rejected']


@dataclass
class TrustedUpstreamIdentity:
    operator_id: str
    auth_method: str
    bootstrap_mode: TrustedUpstreamIdentityMode


@dataclass
class TrustedUpstreamIdentityResult:
    mode: TrustedUpstreamIdentityMode
    status: TrustedUpstreamResolutionStatus
    identity: TrustedUpstreamIdentity | None = None
    failure_code: str | None = None
    failure_message: str | None = None
    failure_status_code: int | None = None

    @property
    def rejected(self) -> bool:
        return self.status == 'rejected'


def resolve_trusted_upstream_identity(
    *,
    request: Request,
    settings: Settings | None = None,
) -> TrustedUpstreamIdentityResult:
    """Resolve an operator identity asserted by a trusted upstream.

    This is the deliberate swap point for stronger edge identity later. The rest
    of the ops session flow should only care about a resolved operator identity,
    not about which upstream mechanism produced it.
    """

    settings = settings or get_settings()
    mode = settings.resolved_ops_trusted_upstream_mode()

    if mode == 'disabled':
        return TrustedUpstreamIdentityResult(mode='disabled', status='disabled')
    if mode == 'shared_secret_headers':
        return _resolve_shared_secret_header_identity(request=request, settings=settings)
    if mode == 'asserted_identity_headers':
        return _resolve_asserted_identity_headers(request=request, settings=settings)

    return TrustedUpstreamIdentityResult(
        mode='disabled',
        status='rejected',
        failure_code='unsupported_trusted_upstream_mode',
        failure_message='Trusted upstream identity mode is not supported.',
        failure_status_code=503,
    )


def _resolve_shared_secret_header_identity(
    *,
    request: Request,
    settings: Settings,
) -> TrustedUpstreamIdentityResult:
    secret_header = settings.ops_trusted_upstream_secret_header
    operator_header = settings.ops_trusted_upstream_operator_id_header
    provided_secret = request.headers.get(secret_header)
    provided_operator = request.headers.get(operator_header)
    attempted = provided_secret is not None or provided_operator is not None

    if not attempted:
        return TrustedUpstreamIdentityResult(mode='shared_secret_headers', status='no_assertion')
    if provided_secret is None:
        return TrustedUpstreamIdentityResult(
            mode='shared_secret_headers',
            status='rejected',
            failure_code='missing_trusted_upstream_secret_header',
            failure_message=f'Missing trusted upstream secret header {secret_header}.',
            failure_status_code=401,
        )
    if provided_secret != settings.ops_trusted_proxy_secret:
        return TrustedUpstreamIdentityResult(
            mode='shared_secret_headers',
            status='rejected',
            failure_code='invalid_trusted_upstream_secret_header',
            failure_message='Trusted upstream secret header did not match the configured value.',
            failure_status_code=401,
        )
    if provided_operator is None:
        return TrustedUpstreamIdentityResult(
            mode='shared_secret_headers',
            status='rejected',
            failure_code='missing_trusted_upstream_operator_header',
            failure_message=f'Missing trusted upstream operator header {operator_header}.',
            failure_status_code=400,
        )

    operator_id = provided_operator.strip()
    if not operator_id:
        return TrustedUpstreamIdentityResult(
            mode='shared_secret_headers',
            status='rejected',
            failure_code='empty_trusted_upstream_operator_header',
            failure_message=f'Trusted upstream operator header {operator_header} was empty.',
            failure_status_code=400,
        )

    return TrustedUpstreamIdentityResult(
        mode='shared_secret_headers',
        status='resolved',
        identity=TrustedUpstreamIdentity(
            operator_id=operator_id,
            auth_method='trusted_upstream_shared_secret',
            bootstrap_mode='shared_secret_headers',
        ),
    )


def _resolve_asserted_identity_headers(
    *,
    request: Request,
    settings: Settings,
) -> TrustedUpstreamIdentityResult:
    operator_header = settings.ops_trusted_upstream_asserted_operator_id_header
    provided_operator = request.headers.get(operator_header)

    if provided_operator is None:
        return TrustedUpstreamIdentityResult(mode='asserted_identity_headers', status='no_assertion')

    operator_id = provided_operator.strip()
    if not operator_id:
        return TrustedUpstreamIdentityResult(
            mode='asserted_identity_headers',
            status='rejected',
            failure_code='empty_asserted_operator_identity_header',
            failure_message=f'Asserted operator identity header {operator_header} was empty.',
            failure_status_code=400,
        )

    return TrustedUpstreamIdentityResult(
        mode='asserted_identity_headers',
        status='resolved',
        identity=TrustedUpstreamIdentity(
            operator_id=operator_id,
            auth_method='trusted_upstream_asserted_identity',
            bootstrap_mode='asserted_identity_headers',
        ),
    )
