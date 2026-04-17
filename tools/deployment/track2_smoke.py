#!/usr/bin/env python3
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from urllib.parse import urljoin

import httpx


@dataclass
class SmokeResult:
    ok: bool
    label: str
    detail: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description='Smoke-check the Track 2 deployment shape for api.getamon.com and ops.getamon.com.'
    )
    parser.add_argument('--api-origin', required=True, help='API origin, for example https://api.getamon.com')
    parser.add_argument('--ops-origin', help='Ops origin, for example https://ops.getamon.com')
    parser.add_argument(
        '--ops-route-mode',
        choices=('path-prefix', 'root-rewrite'),
        default='path-prefix',
        help='How the ops host is exposed externally.',
    )
    parser.add_argument('--operator-id', help='Operator id to use for trusted upstream bootstrap checks.')
    parser.add_argument(
        '--trusted-upstream-mode',
        choices=('disabled', 'shared-secret', 'asserted-identity'),
        default='disabled',
        help='Trusted upstream identity mode to validate.',
    )
    parser.add_argument('--trusted-upstream-secret', help='Shared secret used by the trusted upstream bootstrap path.')
    parser.add_argument(
        '--trusted-upstream-secret-header',
        default='X-Amon-Ops-Proxy-Secret',
        help='Header name used for the trusted upstream shared-secret bootstrap.',
    )
    parser.add_argument(
        '--trusted-upstream-operator-header',
        default='X-Amon-Operator-Id',
        help='Header name used for the upstream operator identity.',
    )
    parser.add_argument(
        '--asserted-operator-header',
        default='X-Amon-Operator-Identity',
        help='Header name used for asserted upstream operator identity mode.',
    )
    parser.add_argument(
        '--trusted-upstream-provider',
        choices=('generic', 'cloudflare-access'),
        default='generic',
        help='Provider contract used when --trusted-upstream-mode=asserted-identity.',
    )
    parser.add_argument(
        '--cloudflare-access-jwt-header',
        default='Cf-Access-Jwt-Assertion',
        help='Header name used for the Cloudflare Access JWT assertion.',
    )
    parser.add_argument(
        '--cloudflare-access-jwt-assertion',
        default='header.payload.signature',
        help='JWT-shaped assertion used for Cloudflare Access smoke checks.',
    )
    parser.add_argument('--forwarded-host', help='Optional X-Forwarded-Host override for local or direct-origin checks.')
    parser.add_argument('--forwarded-proto', help='Optional X-Forwarded-Proto override for local or direct-origin checks.')
    parser.add_argument('--timeout-seconds', type=float, default=10.0)
    return parser.parse_args()


def make_url(origin: str, path: str) -> str:
    return urljoin(origin.rstrip('/') + '/', path.lstrip('/'))


def record(results: list[SmokeResult], ok: bool, label: str, detail: str) -> None:
    results.append(SmokeResult(ok=ok, label=label, detail=detail))


def expect(results: list[SmokeResult], condition: bool, label: str, success: str, failure: str) -> None:
    record(results, condition, label, success if condition else failure)


def request_headers(args: argparse.Namespace) -> dict[str, str]:
    headers: dict[str, str] = {}
    if args.forwarded_host:
        headers['X-Forwarded-Host'] = args.forwarded_host
    if args.forwarded_proto:
        headers['X-Forwarded-Proto'] = args.forwarded_proto
    return headers


def verify_health(client: httpx.Client, api_origin: str, results: list[SmokeResult]) -> None:
    for path in ('/health', '/healthz'):
        response = client.get(make_url(api_origin, path))
        ok = response.status_code == 200 and response.json().get('status') == 'ok'
        expect(
            results,
            ok,
            f'health {path}',
            f'{path} returned ok',
            f'{path} returned {response.status_code}: {response.text[:200]}',
        )


def verify_ops_paths(client: httpx.Client, ops_origin: str, route_mode: str, results: list[SmokeResult]) -> None:
    if route_mode == 'path-prefix':
        redirect = client.get(make_url(ops_origin, '/ops'), follow_redirects=False)
        expect(
            results,
            redirect.status_code in {307, 308} and redirect.headers.get('location') == '/ops/',
            'ops redirect',
            '/ops redirects to /ops/',
            f"/ops did not redirect cleanly: {redirect.status_code} {redirect.headers.get('location')!r}",
        )
        dashboard = client.get(make_url(ops_origin, '/ops/'))
        expect(
            results,
            dashboard.status_code == 200 and 'Amon Ops' in dashboard.text,
            'ops dashboard shell',
            '/ops/ served the dashboard shell',
            f'/ops/ failed with {dashboard.status_code}',
        )
        return

    root = client.get(make_url(ops_origin, '/'), follow_redirects=False)
    root_ok = (root.status_code == 200 and 'Amon Ops' in root.text) or (
        root.status_code in {307, 308} and root.headers.get('location') in {'/ops/', '/'}
    )
    expect(
        results,
        root_ok,
        'ops root expectation',
        'ops root matched the configured root-rewrite expectation',
        f'ops root did not match the configured expectation: {root.status_code}',
    )


def verify_ops_auth(client: httpx.Client, args: argparse.Namespace, ops_origin: str, results: list[SmokeResult]) -> None:
    status = client.get(make_url(ops_origin, '/ops/auth/status'))
    status_json = status.json() if status.headers.get('content-type', '').startswith('application/json') else {}
    expect(
        results,
        status.status_code == 200 and status_json.get('authenticated') is False,
        'ops unauthenticated status',
        'ops auth status is unauthenticated before bootstrap',
        f"unexpected unauthenticated status response: {status.status_code} {status.text[:200]}",
    )
    expected_mode = {
        'disabled': 'disabled',
        'shared-secret': 'shared_secret_headers',
        'asserted-identity': 'asserted_identity_headers',
    }[args.trusted_upstream_mode]
    expect(
        results,
        status_json.get('trusted_upstream_mode') == expected_mode,
        'trusted upstream mode status',
        f"trusted upstream mode reports {expected_mode}",
        f"unexpected trusted upstream mode: {status_json.get('trusted_upstream_mode')!r}",
    )
    expected_provider = None
    if args.trusted_upstream_mode == 'asserted-identity':
        expected_provider = 'cloudflare_access' if args.trusted_upstream_provider == 'cloudflare-access' else 'generic'
        expect(
            results,
            status_json.get('trusted_upstream_provider') == expected_provider,
            'trusted upstream provider status',
            f"trusted upstream provider reports {expected_provider}",
            f"unexpected trusted upstream provider: {status_json.get('trusted_upstream_provider')!r}",
        )

    if args.trusted_upstream_mode == 'disabled':
        record(
            results,
            True,
            'trusted upstream bootstrap',
            'Skipped because trusted upstream mode is disabled.',
        )
        return

    if not args.operator_id:
        record(results, False, 'trusted upstream bootstrap', '--operator-id is required for trusted upstream smoke checks.')
        return

    if args.trusted_upstream_mode == 'shared-secret':
        if not args.trusted_upstream_secret:
            record(
                results,
                False,
                'trusted upstream bootstrap',
                '--trusted-upstream-secret is required for shared-secret mode.',
            )
            return
        upstream_headers = {
            args.trusted_upstream_secret_header: args.trusted_upstream_secret,
            args.trusted_upstream_operator_header: args.operator_id,
        }
        expected_auth_method = 'trusted_upstream_shared_secret'
    else:
        if args.trusted_upstream_provider == 'cloudflare-access':
            upstream_headers = {
                args.asserted_operator_header: args.operator_id,
                args.cloudflare_access_jwt_header: args.cloudflare_access_jwt_assertion,
            }
            expected_auth_method = 'trusted_upstream_asserted_identity_cloudflare_access'
        else:
            upstream_headers = {
                args.asserted_operator_header: args.operator_id,
            }
            expected_auth_method = 'trusted_upstream_asserted_identity'

    bootstrap = client.get(make_url(ops_origin, '/ops/auth/status'), headers=upstream_headers)
    bootstrap_json = bootstrap.json() if bootstrap.headers.get('content-type', '').startswith('application/json') else {}
    set_cookie_headers = bootstrap.headers.get_list('set-cookie')
    secure_expected = ops_origin.startswith('https://')

    expect(
        results,
        bootstrap.status_code == 200 and bootstrap_json.get('authenticated') is True,
        'trusted upstream status bootstrap',
        'trusted upstream bootstrap authenticated successfully',
        f"trusted upstream bootstrap failed: {bootstrap.status_code} {bootstrap.text[:200]}",
    )
    expect(
        results,
        bootstrap_json.get('auth_method') == expected_auth_method,
        'trusted upstream auth method',
        f"ops auth method is '{expected_auth_method}'",
        f"unexpected auth method: {bootstrap_json.get('auth_method')!r}",
    )
    expect(
        results,
        bootstrap_json.get('trusted_upstream_mode') == expected_mode,
        'trusted upstream mode',
        f'{expected_mode} bootstrap mode is reported',
        f"unexpected trusted upstream mode: {bootstrap_json.get('trusted_upstream_mode')!r}",
    )
    if expected_provider is not None:
        expect(
            results,
            bootstrap_json.get('trusted_upstream_provider') == expected_provider,
            'trusted upstream provider',
            f'{expected_provider} asserted-identity provider is reported',
            f"unexpected trusted upstream provider: {bootstrap_json.get('trusted_upstream_provider')!r}",
        )
    expect(
        results,
        any('Path=/ops' in header for header in set_cookie_headers),
        'ops cookie path',
        'ops session cookie is path-scoped to /ops',
        f'ops session cookie did not include Path=/ops: {set_cookie_headers!r}',
    )
    if secure_expected:
        expect(
            results,
            any('Secure' in header for header in set_cookie_headers),
            'ops cookie secure flag',
            'ops session cookie is secure on an https origin',
            f'ops session cookie did not include Secure: {set_cookie_headers!r}',
        )

    overview = client.get(make_url(ops_origin, '/ops/api/protected-sessions/overview'))
    expect(
        results,
        overview.status_code == 200,
        'ops metadata overview',
        'metadata-only ops overview is reachable after bootstrap',
        f'ops overview failed after bootstrap: {overview.status_code} {overview.text[:200]}',
    )

    if args.trusted_upstream_mode == 'shared-secret':
        wrong_headers = {
            args.trusted_upstream_secret_header: '__wrong__',
            args.trusted_upstream_operator_header: args.operator_id,
        }
    else:
        if args.trusted_upstream_provider == 'cloudflare-access':
            wrong_headers = {
                args.asserted_operator_header: args.operator_id,
                args.cloudflare_access_jwt_header: 'not-a-jwt',
            }
        else:
            wrong_headers = {
                args.asserted_operator_header: '   ',
            }
    negative = httpx.Client(
        headers=request_headers(args),
        timeout=args.timeout_seconds,
        follow_redirects=False,
    )
    try:
        negative_status = negative.get(make_url(ops_origin, '/ops/auth/status'), headers=wrong_headers)
    finally:
        negative.close()
    negative_json = (
        negative_status.json()
        if negative_status.headers.get('content-type', '').startswith('application/json')
        else {}
    )
    negative_ok = negative_status.status_code in {400, 401}
    negative_detail = negative_json.get('detail', {})
    negative_code = negative_detail.get('code') if isinstance(negative_detail, dict) else None
    expect(
        results,
        negative_ok and negative_code is not None,
        'trusted upstream negative check',
        f'bad trusted upstream assertion is explicitly rejected with {negative_status.status_code}',
        f'trusted upstream negative check did not reject explicitly: {negative_status.status_code} {negative_status.text[:200]}',
    )


def main() -> int:
    args = parse_args()
    api_origin = args.api_origin.rstrip('/')
    ops_origin = (args.ops_origin or args.api_origin).rstrip('/')
    results: list[SmokeResult] = []

    with httpx.Client(
        headers=request_headers(args),
        timeout=args.timeout_seconds,
        follow_redirects=False,
    ) as client:
        verify_health(client, api_origin, results)
        verify_ops_paths(client, ops_origin, args.ops_route_mode, results)
        verify_ops_auth(client, args, ops_origin, results)

    failed = [result for result in results if not result.ok]
    for result in results:
        icon = 'PASS' if result.ok else 'FAIL'
        print(f'[{icon}] {result.label}: {result.detail}')

    if failed:
        print(f'\nSmoke checks failed: {len(failed)} issue(s).', file=sys.stderr)
        return 1

    print('\nAll deployment smoke checks passed.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
