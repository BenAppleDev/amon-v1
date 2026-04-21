from __future__ import annotations

import ipaddress
from dataclasses import dataclass
from typing import Literal
from urllib.parse import urlparse, urlunparse

from app.config import Settings, get_settings
from app.security import CurrentAccessContext

AnyIPAddress = ipaddress.IPv4Address | ipaddress.IPv6Address
ServeDisposition = Literal['ALLOW_LOCAL', 'ALLOW_CLEAN_VIEW', 'RECOMMEND_PROTECTED', 'ALLOW_PROTECTED', 'DENY']
ServeIntent = Literal['open', 'protected_session']
RuntimeDestinationKind = Literal['navigate', 'redirect', 'form_action']

BLOCKED_HOSTNAMES = {
    'localhost',
    'localhost.localdomain',
    'ip6-localhost',
    'metadata',
    'metadata.google.internal',
}


def normalize_host(value: str) -> str:
    return value.strip().lower().rstrip('.')


def parsed_ip_address(value: str) -> AnyIPAddress | None:
    try:
        return ipaddress.ip_address(value)
    except ValueError:
        return None


def is_blocked_ip_address(address: AnyIPAddress) -> bool:
    return not address.is_global


@dataclass(frozen=True)
class ServeDecision:
    disposition: ServeDisposition
    reason_code: str
    confidence: float
    policy_version: str
    site_class: str | None = None
    budget_tier: str | None = None


class ProtectedSessionPolicyEngine:
    POLICY_VERSION = 'protected-session-control-plane-v1'

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def decide_url_open(
        self,
        url: str,
        *,
        intent: ServeIntent = 'open',
        current_user: CurrentAccessContext | None = None,
    ) -> ServeDecision:
        budget_tier = self._budget_tier_for(current_user)
        parsed, host, _port, _normalized_url, failure = self._parse_url(url)
        if failure is not None:
            return self._deny(failure, budget_tier=budget_tier)
        assert parsed is not None
        assert host is not None

        blocked_reason = self._blocked_reason(host)
        if blocked_reason is not None:
            return self._deny(blocked_reason, budget_tier=budget_tier)

        site_class = self._site_class_for(host=host, path=parsed.path, query=parsed.query)
        if host in self.settings.protected_session_allowed_hosts:
            if intent == 'protected_session':
                return ServeDecision(
                    disposition='ALLOW_PROTECTED',
                    reason_code='allowlisted_protected_host',
                    confidence=0.95,
                    policy_version=self.POLICY_VERSION,
                    site_class=site_class,
                    budget_tier=budget_tier,
                )
            return ServeDecision(
                disposition='RECOMMEND_PROTECTED',
                reason_code='allowlisted_protected_host',
                confidence=0.88,
                policy_version=self.POLICY_VERSION,
                site_class=site_class,
                budget_tier=budget_tier,
            )

        if site_class == 'readable_public_page':
            return ServeDecision(
                disposition='ALLOW_CLEAN_VIEW',
                reason_code='readable_public_page',
                confidence=0.58,
                policy_version=self.POLICY_VERSION,
                site_class=site_class,
                budget_tier=budget_tier,
            )

        return ServeDecision(
            disposition='ALLOW_LOCAL',
            reason_code='uncertain_local_only',
            confidence=0.35,
            policy_version=self.POLICY_VERSION,
            site_class=site_class,
            budget_tier=budget_tier,
        )

    def evaluate_runtime_destination(
        self,
        url: str,
        *,
        allowed_host: str,
        destination_kind: RuntimeDestinationKind,
        budget_tier: str | None = None,
    ) -> tuple[ServeDecision, str | None]:
        _parsed, host, _port, normalized_url, failure = self._parse_url(url)
        if failure is not None:
            return self._deny(self._contextual_reason(destination_kind, failure), budget_tier=budget_tier), None
        assert host is not None
        assert normalized_url is not None

        blocked_reason = self._blocked_reason(host)
        if blocked_reason is not None:
            return self._deny(self._contextual_reason(destination_kind, blocked_reason), budget_tier=budget_tier), None

        if host != normalize_host(allowed_host):
            return (
                self._deny(
                    self._contextual_reason(destination_kind, 'cross_host_destination_blocked'),
                    budget_tier=budget_tier,
                ),
                None,
            )

        return (
            ServeDecision(
                disposition='ALLOW_PROTECTED',
                reason_code=self._contextual_reason(destination_kind, 'same_host_destination_allowed'),
                confidence=0.96,
                policy_version=self.POLICY_VERSION,
                site_class='protected_runtime_destination',
                budget_tier=budget_tier,
            ),
            normalized_url,
        )

    def quota_profile_for(self, current_user: CurrentAccessContext | None) -> dict[str, int | str]:
        budget_tier = self._budget_tier_for(current_user)
        concurrent = self.settings.protected_session_max_concurrent_sessions_per_user
        starts = self.settings.protected_session_max_session_starts_per_window
        actions = self.settings.protected_session_max_actions_per_session

        if budget_tier == 'limited':
            concurrent = max(1, concurrent - 1)
            starts = max(1, starts - 2)
            actions = max(5, actions - 5)

        return {
            'budget_tier': budget_tier,
            'max_concurrent_sessions_per_user': concurrent,
            'max_session_starts_per_window': starts,
            'session_start_window_seconds': self.settings.protected_session_session_start_window_seconds,
            'max_actions_per_session': actions,
        }

    def _budget_tier_for(self, current_user: CurrentAccessContext | None) -> str:
        if current_user is None:
            return 'standard'

        tier = (current_user.entitlement.tier or '').strip().lower()
        if tier in {'free', 'trial', 'limited'}:
            return 'limited'
        return 'standard'

    def _site_class_for(self, *, host: str, path: str, query: str) -> str | None:
        lowered_path = path.lower()
        if host in {'httpbin.org'} and '/forms/' in lowered_path:
            return 'lightweight_form_workflow'
        if host in {'books.toscrape.com', 'quotes.toscrape.com'}:
            return 'public_dynamic_page'
        if any(token in lowered_path for token in ('article', 'blog', 'docs', 'guide', 'help', 'news', 'read')):
            return 'readable_public_page'
        if query and any(token in query.lower() for token in ('q=', 'query=', 'search=')):
            return 'public_dynamic_page'
        return None

    def _parse_url(
        self,
        url: str,
    ) -> tuple[object | None, str | None, int | None, str | None, str | None]:
        parsed = urlparse(url)
        scheme = (parsed.scheme or '').lower()
        if scheme not in {'http', 'https'} or not parsed.netloc or not parsed.hostname:
            return None, None, None, None, 'invalid_url'
        if parsed.username or parsed.password:
            return None, None, None, None, 'credentialed_url_blocked'
        try:
            port = parsed.port
        except ValueError:
            return None, None, None, None, 'invalid_port'
        if port not in {None, 80, 443}:
            return None, None, None, None, 'invalid_port'

        host = normalize_host(parsed.hostname)
        netloc = host if port is None else f'{host}:{port}'
        normalized = urlunparse(parsed._replace(scheme=scheme, netloc=netloc, fragment=''))
        return parsed, host, port, normalized, None

    def _blocked_reason(self, host: str) -> str | None:
        if host in BLOCKED_HOSTNAMES:
            return 'blocked_address'
        ip_address = parsed_ip_address(host)
        if ip_address is not None and is_blocked_ip_address(ip_address):
            return 'blocked_address'
        return None

    def _deny(self, reason_code: str, *, budget_tier: str | None) -> ServeDecision:
        return ServeDecision(
            disposition='DENY',
            reason_code=reason_code,
            confidence=0.99,
            policy_version=self.POLICY_VERSION,
            site_class=None,
            budget_tier=budget_tier,
        )

    @staticmethod
    def _contextual_reason(destination_kind: RuntimeDestinationKind, base_reason: str) -> str:
        if destination_kind == 'redirect':
            if base_reason == 'cross_host_destination_blocked':
                return 'blocked_redirect_destination'
            return f'redirect_{base_reason}'
        if destination_kind == 'form_action':
            if base_reason == 'cross_host_destination_blocked':
                return 'blocked_form_destination'
            return f'form_{base_reason}'
        return f'navigate_{base_reason}'
