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


class ProtectedSessionCreateRequest(BaseModel):
    url: HttpUrl


class ProtectedSessionLink(BaseModel):
    id: str
    label: str
    url: HttpUrl


class ProtectedSessionField(BaseModel):
    name: str
    label: str
    field_type: str
    value: str | None = None
    placeholder: str | None = None


class ProtectedSessionForm(BaseModel):
    id: str
    action_url: HttpUrl
    method: Literal['get', 'post']
    submit_label: str
    fields: list[ProtectedSessionField] = Field(default_factory=list)


class ProtectedSessionPage(BaseModel):
    url: HttpUrl
    title: str
    domain: str
    excerpt: str | None = None
    text_blocks: list[str] = Field(default_factory=list)
    links: list[ProtectedSessionLink] = Field(default_factory=list)
    forms: list[ProtectedSessionForm] = Field(default_factory=list)
    fetched_at: datetime


class ProtectedSessionFrame(BaseModel):
    revision: int
    mime_type: Literal['image/svg+xml']
    document: str
    width: int
    height: int
    generated_at: datetime


class ProtectedSessionState(BaseModel):
    session_id: str
    status: Literal['creating', 'active', 'terminating', 'closed', 'expired', 'failed']
    allowed_host: str
    started_at: datetime
    expires_at: datetime
    last_activity_at: datetime
    can_go_back: bool
    can_go_forward: bool
    content_revision: int = 0
    runtime_kind: str = 'visual_stream_session'
    stream_transport: Literal['websocket'] | None = 'websocket'
    worker_id: str | None = None
    worker_type: str | None = None
    worker_state: str | None = None
    worker_health: str | None = None
    current_frame: ProtectedSessionFrame | None = None
    current_page: ProtectedSessionPage | None = None
    detail_message: str | None = None


class ProtectedSessionActionRequest(BaseModel):
    action: Literal['reload', 'back', 'forward', 'click_link', 'update_field', 'submit_form', 'navigate_to_url']
    link_id: str | None = Field(default=None, min_length=1, max_length=80)
    form_id: str | None = Field(default=None, min_length=1, max_length=80)
    field_name: str | None = Field(default=None, min_length=1, max_length=200)
    value: str | None = Field(default=None, max_length=4000)
    url: HttpUrl | None = None


class ProtectedSessionEndResponse(BaseModel):
    session_id: str
    status: Literal['ended'] = 'ended'


class ProtectedSessionStreamEvent(BaseModel):
    event: Literal['state', 'terminal', 'health']
    session_id: str
    state: ProtectedSessionState | None = None
    revision: int | None = None
    worker_state: str | None = None
    worker_health: str | None = None


class ProtectedSessionStreamClientMessage(BaseModel):
    type: Literal['subscribe', 'action', 'ping', 'detach']
    client_message_id: str | None = Field(default=None, min_length=1, max_length=120)
    client_action_id: str | None = Field(default=None, min_length=1, max_length=120)
    last_stream_sequence: int | None = Field(default=None, ge=0)
    expected_content_revision: int | None = Field(default=None, ge=0)
    action: ProtectedSessionActionRequest | None = None


class ProtectedSessionStreamServerMessage(BaseModel):
    type: Literal['subscribed', 'action_ack', 'state', 'heartbeat', 'terminal', 'error']
    session_id: str
    stream_sequence: int
    content_revision: int | None = Field(default=None, ge=0)
    state: ProtectedSessionState | None = None
    resumed: bool | None = None
    source_action_id: str | None = None
    client_action_id: str | None = None
    action_status: Literal['accepted', 'failed', 'rejected'] | None = None
    code: str | None = None
    message: str | None = None
    worker_state: str | None = None
    worker_health: str | None = None
    dropped_events: int | None = Field(default=None, ge=0)


class ServeDecisionRequest(BaseModel):
    url: HttpUrl
    intent: Literal['open', 'protected_session'] = 'open'


class ServeDecisionResponse(BaseModel):
    disposition: Literal['ALLOW_LOCAL', 'ALLOW_CLEAN_VIEW', 'RECOMMEND_PROTECTED', 'ALLOW_PROTECTED', 'DENY']
    reason_code: str
    confidence: float = Field(ge=0.0, le=1.0)
    policy_version: str
    site_class: str | None = None
    budget_tier: str | None = None


class ProtectedSessionPolicySummary(BaseModel):
    disposition: Literal['ALLOW_LOCAL', 'ALLOW_CLEAN_VIEW', 'RECOMMEND_PROTECTED', 'ALLOW_PROTECTED', 'DENY']
    reason_code: str
    confidence: float = Field(ge=0.0, le=1.0)
    policy_version: str
    site_class: str | None = None
    budget_tier: str | None = None


class ProtectedSessionQuotaSummary(BaseModel):
    budget_tier: str | None = None
    max_concurrent_sessions_per_user: int
    max_session_starts_per_window: int
    session_start_window_seconds: int
    max_actions_per_session: int


class ProtectedSessionMetadataView(BaseModel):
    session_id: str
    user_id: str
    domain: str
    state: str
    created_at: datetime
    last_activity_at: datetime
    action_count: int
    termination_reason: str | None = None
    policy: ProtectedSessionPolicySummary
    quota: ProtectedSessionQuotaSummary
    worker_id: str | None = None
    worker_type: str | None = None
    runtime_kind: str | None = None
    worker_state: str | None = None
    worker_health: str | None = None
    frame_revision: int | None = None
    frames_emitted: int = 0
    last_frame_at: datetime | None = None
    active_streams: int = 0
    total_stream_attaches: int = 0
    total_stream_detaches: int = 0
    reconnect_attempts: int = 0
    successful_resumes: int = 0
    heartbeat_timeout_count: int = 0
    dropped_events_total: int = 0
    protocol_error_count: int = 0
    last_protocol_error_code: str | None = None
    state_update_count: int = 0
    frame_update_count: int = 0
    action_ack_accepted_count: int = 0
    action_ack_failed_count: int = 0
    action_ack_rejected_count: int = 0
    action_completed_count: int = 0
    action_failed_count: int = 0
    average_action_duration_ms: float | None = None
    last_action_duration_ms: int | None = None
    last_stream_attached_at: datetime | None = None
    last_stream_detached_at: datetime | None = None


class InternalProtectedSessionsOverview(BaseModel):
    total_sessions: int
    active_sessions: int
    state_counts: dict[str, int] = Field(default_factory=dict)
    sessions: list[ProtectedSessionMetadataView] = Field(default_factory=list)


class InternalProtectedOverview(BaseModel):
    generated_at: datetime
    total_sessions: int = 0
    active_sessions: int = 0
    active_streams: int = 0
    users_with_active_sessions: int = 0
    users_with_live_streams: int = 0
    total_workers: int = 0
    healthy_workers: int = 0
    degraded_workers: int = 0
    total_worker_capacity: int = 0
    total_worker_stream_capacity: int = 0
    total_assigned_sessions: int = 0
    quota_rejections_total: int = 0
    protocol_errors_total: int = 0
    heartbeat_timeouts_total: int = 0
    dropped_events_total: int = 0


class ProtectedSessionWorkerView(BaseModel):
    worker_id: str
    worker_type: str
    capacity: int
    stream_capacity: int
    state: str
    health: str = 'healthy'
    capabilities: list[str] = Field(default_factory=list)
    assigned_sessions: list[str] = Field(default_factory=list)
    assigned_count: int
    active_streams: int = 0
    assignment_count: int = 0
    release_count: int = 0
    attach_count: int = 0
    detach_count: int = 0
    heartbeat_timeout_count: int = 0
    protocol_error_count: int = 0
    degraded_reason: str | None = None


class InternalProtectedWorkersOverview(BaseModel):
    total_workers: int
    total_capacity: int
    total_stream_capacity: int
    total_assigned_sessions: int
    total_active_streams: int
    workers: list[ProtectedSessionWorkerView] = Field(default_factory=list)


class ProtectedSessionEventView(BaseModel):
    event_id: str
    event_type: str
    occurred_at: datetime
    session_id: str | None = None
    user_id: str | None = None
    domain: str | None = None
    worker_id: str | None = None
    reason_code: str | None = None
    state: str | None = None
    disposition: str | None = None
    budget_tier: str | None = None
    metric_value: int | None = None
    duration_ms: int | None = None


class InternalProtectedEventFeed(BaseModel):
    total_events: int = 0
    events: list[ProtectedSessionEventView] = Field(default_factory=list)


class InternalProtectedPolicyCounters(BaseModel):
    policy_decisions: dict[str, int] = Field(default_factory=dict)
    event_counts: dict[str, int] = Field(default_factory=dict)
    reason_counts: dict[str, int] = Field(default_factory=dict)
    recent_events: list[ProtectedSessionEventView] = Field(default_factory=list)


class InternalProtectedQuotaCounters(BaseModel):
    quota_rejections: dict[str, int] = Field(default_factory=dict)
    total_rejections: int = 0
    active_sessions_total: int = 0
    users_with_active_sessions: int = 0


class InternalProtectedStreamCounters(BaseModel):
    active_streams_total: int = 0
    users_with_live_streams: int = 0
    attach_count: int = 0
    detach_count: int = 0
    reconnect_attempts: int = 0
    successful_resumes: int = 0
    heartbeat_timeout_count: int = 0
    dropped_events_total: int = 0
    protocol_error_count: int = 0
    protocol_error_codes: dict[str, int] = Field(default_factory=dict)
    state_update_count: int = 0
    frame_update_count: int = 0
    action_ack_counts: dict[str, int] = Field(default_factory=dict)
    action_result_counts: dict[str, int] = Field(default_factory=dict)
    average_action_duration_ms: float | None = None
    worker_assignments: int = 0
    worker_releases: int = 0
    total_live_stream_capacity: int = 0


class InternalProtectedTerminationCounters(BaseModel):
    terminal_event_counts: dict[str, int] = Field(default_factory=dict)
    terminal_reason_counts: dict[str, int] = Field(default_factory=dict)
    failure_reason_counts: dict[str, int] = Field(default_factory=dict)


class OpsEnvironmentView(BaseModel):
    key: str
    label: str
    app_env: str


class OpsAuthStatusResponse(BaseModel):
    authenticated: bool
    environment: OpsEnvironmentView
    operator_id: str | None = None
    auth_method: str | None = None
    session_expires_at: datetime | None = None
    dev_token_login_enabled: bool = False
    trusted_upstream_enabled: bool = False
    trusted_upstream_mode: Literal['disabled', 'shared_secret_headers', 'asserted_identity_headers'] = 'disabled'
    trusted_upstream_provider: Literal['generic', 'cloudflare_access'] | None = None


class OpsDevLoginRequest(BaseModel):
    admin_token: str = Field(min_length=3, max_length=200)
    operator_id: str | None = Field(default=None, min_length=3, max_length=255)


class ProtectedSessionOpsSnapshotView(BaseModel):
    recorded_at: datetime
    environment: str
    total_sessions: int = 0
    active_sessions: int = 0
    active_streams: int = 0
    users_with_active_sessions: int = 0
    users_with_live_streams: int = 0
    total_workers: int = 0
    healthy_workers: int = 0
    degraded_workers: int = 0
    total_worker_capacity: int = 0
    total_worker_stream_capacity: int = 0
    total_assigned_sessions: int = 0
    quota_rejections_total: int = 0
    protocol_errors_total: int = 0
    heartbeat_timeouts_total: int = 0
    dropped_events_total: int = 0


class ProtectedSessionOpsSnapshotSeries(BaseModel):
    environment: OpsEnvironmentView
    snapshots: list[ProtectedSessionOpsSnapshotView] = Field(default_factory=list)


class ProtectedSessionOpsHistoricalSummary(BaseModel):
    environment: OpsEnvironmentView
    window_hours: int
    total_events: int = 0
    event_counts: dict[str, int] = Field(default_factory=dict)
    reason_counts: dict[str, int] = Field(default_factory=dict)
    terminal_reason_counts: dict[str, int] = Field(default_factory=dict)
    stream_error_counts: dict[str, int] = Field(default_factory=dict)
    latest_snapshot: ProtectedSessionOpsSnapshotView | None = None


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


class RouteSessionState(BaseModel):
    session_id: str
    access_token: str
    status: Literal['active', 'revoked', 'expired']
    route_kind: Literal['local_routed'] = 'local_routed'
    transport_kind: Literal['packet_tunnel'] = 'packet_tunnel'
    control_plane_kind: Literal['control_only'] = 'control_only'
    auth_session_id: str
    issued_at: datetime
    refresh_after: datetime
    expires_at: datetime


class RouteSessionRevokeResponse(BaseModel):
    session_id: str
    status: Literal['revoked'] = 'revoked'
    revoked_at: datetime


class RouteRelayValidationRequest(BaseModel):
    request_id: str | None = Field(default=None, min_length=1, max_length=120)
    route_session_id: str | None = Field(default=None, min_length=1, max_length=120)
    route_access_token: str | None = Field(default=None, min_length=1, max_length=512)
    route_auth_session_id: str | None = Field(default=None, min_length=1, max_length=120)
    requested_path: Literal['local_routed'] = 'local_routed'
    transport_kind: Literal['packet_tunnel'] = 'packet_tunnel'
    client_platform: Literal['ios'] | None = None
    app_bundle_id: str | None = Field(default=None, max_length=255)


class RouteRelayValidationResponse(BaseModel):
    status: Literal['accepted', 'rejected']
    code: str
    message: str
    request_id: str | None = None
    session_id: str | None = None
    user_id: str | None = None
    auth_session_id: str | None = None
    route_kind: Literal['local_routed'] | None = None
    transport_kind: Literal['packet_tunnel'] | None = None
    control_plane_kind: Literal['control_only'] | None = None
    expires_at: datetime | None = None
    validated_at: datetime


class HealthResponse(BaseModel):
    status: Literal['ok'] = 'ok'
    app_name: str
    version: str
    environment: str
