from functools import lru_cache
from typing import List

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', env_file_encoding='utf-8', extra='ignore')

    app_env: str = Field(default='development', alias='APP_ENV')
    app_name: str = Field(default='Amon API', alias='APP_NAME')
    app_version: str = Field(default='0.1.0', alias='APP_VERSION')

    database_url: str = Field(default='sqlite:///./amon_server.db', alias='DATABASE_URL')
    search_provider: str = Field(default='mock', alias='SEARCH_PROVIDER')
    brave_api_key: str | None = Field(default=None, alias='BRAVE_API_KEY')

    requests_per_minute: int = Field(default=60, alias='REQUESTS_PER_MINUTE')
    session_ttl_hours: int = Field(default=24, alias='SESSION_TTL_HOURS')
    cors_allow_origins: List[str] = Field(
        default_factory=lambda: ['http://localhost:3000', 'http://127.0.0.1:3000'],
        alias='CORS_ALLOW_ORIGINS',
    )

    @field_validator('cors_allow_origins', mode='before')
    @classmethod
    def split_origins(cls, value: str | list[str]) -> list[str]:
        if isinstance(value, list):
            return value
        if not value:
            return []
        return [item.strip() for item in value.split(',') if item.strip()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
