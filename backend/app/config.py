from functools import lru_cache
from typing import Annotated, List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')

    app_env: str = Field(default='development', alias='APP_ENV')
    app_name: str = Field(default='Amon API', alias='APP_NAME')
    app_version: str = Field(default='0.1.0', alias='APP_VERSION')
    api_external_origin: str = Field(default='http://127.0.0.1:8000', alias='API_EXTERNAL_ORIGIN')
    ops_surface_origin: str = Field(default='http://127.0.0.1:8000/ops/', alias='OPS_SURFACE_ORIGIN')

    database_url: str = Field(default='sqlite:///./amon_server.db', alias='DATABASE_URL')
    search_provider: str = Field(default='mock', alias='SEARCH_PROVIDER')
    brave_api_key: str | None = Field(default=None, alias='BRAVE_API_KEY')
    brave_base_url: str = Field(default='https://api.search.brave.com', alias='BRAVE_BASE_URL')
    brave_timeout_seconds: float = Field(default=15.0, alias='BRAVE_TIMEOUT_SECONDS')

    requests_per_minute: int = Field(default=60, alias='REQUESTS_PER_MINUTE')
    session_ttl_hours: int = Field(default=24, alias='SESSION_TTL_HOURS')
    protected_session_allowed_hosts: Annotated[List[str], NoDecode] = Field(
        default_factory=lambda: ['example.com', 'books.toscrape.com', 'quotes.toscrape.com', 'httpbin.org'],
        alias='PROTECTED_SESSION_ALLOWED_HOSTS',
    )
    protected_session_ttl_minutes: int = Field(default=10, alias='PROTECTED_SESSION_TTL_MINUTES')
    protected_session_cleanup_interval_seconds: int = Field(
        default=30, alias='PROTECTED_SESSION_CLEANUP_INTERVAL_SECONDS'
    )
    protected_session_terminal_retention_seconds: int = Field(
        default=120, alias='PROTECTED_SESSION_TERMINAL_RETENTION_SECONDS'
    )
    protected_session_max_concurrent_sessions_per_user: int = Field(
        default=2, alias='PROTECTED_SESSION_MAX_CONCURRENT_SESSIONS_PER_USER'
    )
    protected_session_session_start_window_seconds: int = Field(
        default=600, alias='PROTECTED_SESSION_SESSION_START_WINDOW_SECONDS'
    )
    protected_session_max_session_starts_per_window: int = Field(
        default=6, alias='PROTECTED_SESSION_MAX_SESSION_STARTS_PER_WINDOW'
    )
    protected_session_max_actions_per_session: int = Field(
        default=25, alias='PROTECTED_SESSION_MAX_ACTIONS_PER_SESSION'
    )
    protected_session_event_buffer_size: int = Field(
        default=512, alias='PROTECTED_SESSION_EVENT_BUFFER_SIZE'
    )
    protected_session_worker_capacity: int = Field(
        default=8, alias='PROTECTED_SESSION_WORKER_CAPACITY'
    )
    protected_session_worker_stream_capacity: int = Field(
        default=8, alias='PROTECTED_SESSION_WORKER_STREAM_CAPACITY'
    )
    protected_session_max_live_streams: int = Field(
        default=8, alias='PROTECTED_SESSION_MAX_LIVE_STREAMS'
    )
    protected_session_max_live_streams_per_user: int = Field(
        default=2, alias='PROTECTED_SESSION_MAX_LIVE_STREAMS_PER_USER'
    )
    protected_session_stream_heartbeat_seconds: int = Field(
        default=12, alias='PROTECTED_SESSION_STREAM_HEARTBEAT_SECONDS'
    )
    protected_session_stream_idle_timeout_seconds: int = Field(
        default=30, alias='PROTECTED_SESSION_STREAM_IDLE_TIMEOUT_SECONDS'
    )
    protected_session_stream_subscriber_queue_size: int = Field(
        default=4, alias='PROTECTED_SESSION_STREAM_SUBSCRIBER_QUEUE_SIZE'
    )
    internal_admin_token: str | None = Field(default=None, alias='INTERNAL_ADMIN_TOKEN')
    ops_environment_key: str = Field(default='local', alias='OPS_ENVIRONMENT_KEY')
    ops_environment_label: str = Field(default='Local', alias='OPS_ENVIRONMENT_LABEL')
    ops_session_cookie_name: str = Field(default='amon_ops_session', alias='OPS_SESSION_COOKIE_NAME')
    ops_session_ttl_hours: int = Field(default=12, alias='OPS_SESSION_TTL_HOURS')
    ops_session_cookie_secure: bool | None = Field(default=None, alias='OPS_SESSION_COOKIE_SECURE')
    ops_session_cookie_domain: str | None = Field(default=None, alias='OPS_SESSION_COOKIE_DOMAIN')
    ops_session_cookie_same_site: str = Field(default='lax', alias='OPS_SESSION_COOKIE_SAME_SITE')
    ops_allow_dev_token_login: bool = Field(default=False, alias='OPS_ALLOW_DEV_TOKEN_LOGIN')
    ops_trusted_proxy_secret: str | None = Field(default=None, alias='OPS_TRUSTED_PROXY_SECRET')
    ops_allowed_operator_ids: Annotated[List[str], NoDecode] = Field(default_factory=list, alias='OPS_ALLOWED_OPERATOR_IDS')
    ops_history_snapshot_interval_seconds: int = Field(default=30, alias='OPS_HISTORY_SNAPSHOT_INTERVAL_SECONDS')
    protected_session_max_links: int = Field(default=12, alias='PROTECTED_SESSION_MAX_LINKS')
    protected_session_max_text_blocks: int = Field(default=6, alias='PROTECTED_SESSION_MAX_TEXT_BLOCKS')
    protected_session_max_response_bytes: int = Field(
        default=1_000_000, alias='PROTECTED_SESSION_MAX_RESPONSE_BYTES'
    )
    public_site_origins: Annotated[List[str], NoDecode] = Field(
        default_factory=lambda: ['https://www.getamon.com', 'https://getamon.com'],
        alias='PUBLIC_SITE_ORIGINS',
    )
    ops_frontend_origins: Annotated[List[str], NoDecode] = Field(
        default_factory=lambda: ['https://ops.getamon.com', 'http://localhost:3000', 'http://127.0.0.1:3000'],
        alias='OPS_FRONTEND_ORIGINS',
    )
    cors_allow_origins: Annotated[List[str], NoDecode] = Field(
        default_factory=list,
        alias='CORS_ALLOW_ORIGINS',
    )
    trusted_host_patterns: Annotated[List[str], NoDecode] = Field(
        default_factory=lambda: ['127.0.0.1', 'localhost', 'api.getamon.com', 'ops.getamon.com'],
        alias='TRUSTED_HOST_PATTERNS',
    )
    trust_proxy_headers: bool = Field(default=False, alias='TRUST_PROXY_HEADERS')
    trusted_proxy_ips: Annotated[List[str], NoDecode] = Field(
        default_factory=lambda: ['127.0.0.1', '::1'],
        alias='TRUSTED_PROXY_IPS',
    )

    @field_validator(
        'protected_session_allowed_hosts',
        'public_site_origins',
        'ops_frontend_origins',
        'cors_allow_origins',
        'trusted_host_patterns',
        'trusted_proxy_ips',
        'ops_allowed_operator_ids',
        mode='before',
    )
    @classmethod
    def split_csv_values(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, list):
            return value
        if not value:
            return []
        return [item.strip() for item in value.split(',') if item.strip()]

    @field_validator('protected_session_allowed_hosts')
    @classmethod
    def normalize_allowed_hosts(cls, value: list[str]) -> list[str]:
        normalized: list[str] = []
        for item in value:
            host = item.strip().lower().rstrip('.')
            if host:
                normalized.append(host)
        return list(dict.fromkeys(normalized))

    @field_validator('public_site_origins', 'ops_frontend_origins', 'cors_allow_origins')
    @classmethod
    def normalize_origins(cls, value: list[str]) -> list[str]:
        normalized: list[str] = []
        for item in value:
            origin = item.strip().rstrip('/')
            if origin:
                normalized.append(origin)
        return list(dict.fromkeys(normalized))

    @field_validator('trusted_host_patterns', 'trusted_proxy_ips', 'ops_allowed_operator_ids')
    @classmethod
    def normalize_string_lists(cls, value: list[str]) -> list[str]:
        normalized: list[str] = []
        for item in value:
            cleaned = item.strip()
            if cleaned:
                normalized.append(cleaned)
        return list(dict.fromkeys(normalized))

    @field_validator('search_provider', mode='before')
    @classmethod
    def normalize_search_provider(cls, value: str) -> str:
        return value.strip().lower()

    @field_validator('ops_environment_key', 'ops_environment_label', 'api_external_origin', 'ops_surface_origin', mode='before')
    @classmethod
    def normalize_ops_strings(cls, value: str) -> str:
        return value.strip()

    @field_validator('ops_session_cookie_domain', mode='before')
    @classmethod
    def normalize_cookie_domain(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip().lower()
        return cleaned or None

    @field_validator('ops_session_cookie_same_site', mode='before')
    @classmethod
    def normalize_same_site(cls, value: str) -> str:
        normalized = value.strip().lower()
        if normalized not in {'lax', 'strict', 'none'}:
            raise ValueError('OPS_SESSION_COOKIE_SAME_SITE must be one of: lax, strict, none')
        return normalized

    def resolved_cors_allow_origins(self) -> list[str]:
        return list(dict.fromkeys([*self.public_site_origins, *self.ops_frontend_origins, *self.cors_allow_origins]))

    def resolved_ops_session_cookie_secure(self) -> bool:
        if self.ops_session_cookie_secure is not None:
            return self.ops_session_cookie_secure
        return self.app_env not in {'development', 'local'}


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
