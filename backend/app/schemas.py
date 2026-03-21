from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, HttpUrl


class ProviderInfo(BaseModel):
    name: str
    provider_result_id: str | None = None


class SearchResult(BaseModel):
    id: str
    title: str
    url: HttpUrl
    snippet: str | None = None
    result_type: Literal['web_page', 'article', 'place', 'product'] = 'web_page'
    domain: str
    typed_metadata: dict[str, Any] | None = None
    provider: ProviderInfo


class SearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=300)
    count: int = Field(default=10, ge=1, le=20)


class SearchResponse(BaseModel):
    results: list[SearchResult]


class RetrieveRequest(BaseModel):
    url: HttpUrl


class StructuredRetrievalResponse(BaseModel):
    url: HttpUrl
    canonical_url: HttpUrl
    title: str
    domain: str
    excerpt: str | None = None
    bullet_points: list[str] = Field(default_factory=list)
    retrieved_at: datetime


class ItemSourcePayload(BaseModel):
    item_id: str | None = None
    title: str
    url: HttpUrl
    domain: str
    snippet: str | None = None
    page_title: str | None = None
    cleaned_excerpt: str | None = None
    bullet_points: list[str] = Field(default_factory=list)
    typed_metadata: dict[str, Any] | None = None


class CompareCellPayload(BaseModel):
    item_id: str | None = None
    value_text: str | None = None
    value_json: Any | None = None


class CompareRowPayload(BaseModel):
    field_key: str
    field_label: str
    row_type: Literal['text', 'number', 'bullet_list', 'url']
    cells: list[CompareCellPayload]


class CompareRequest(BaseModel):
    title: str
    items: list[ItemSourcePayload] = Field(min_length=2, max_length=8)


class CompareResponse(BaseModel):
    title: str
    summary: str
    rows: list[CompareRowPayload]


class ResearchRequest(BaseModel):
    title: str
    prompt_context: str | None = None
    items: list[ItemSourcePayload] = Field(min_length=2, max_length=10)


class ResearchSourceRef(BaseModel):
    item_id: str | None = None


class ModelInfo(BaseModel):
    name: str
    version: str


class ResearchResponse(BaseModel):
    title: str
    summary_text: str
    bullet_summary: list[str]
    sources: list[ResearchSourceRef]
    model: ModelInfo


class DevLoginRequest(BaseModel):
    apple_subject: str = Field(min_length=3, max_length=120)


class UserView(BaseModel):
    id: str
    status: str
    entitlement_tier: str
    entitlement_status: str

    model_config = ConfigDict(from_attributes=True)


class AuthResponse(BaseModel):
    access_token: str
    token_type: Literal['bearer'] = 'bearer'
    expires_at: datetime
    user: UserView


class HealthResponse(BaseModel):
    status: Literal['ok'] = 'ok'
    app_name: str
    version: str
    environment: str
