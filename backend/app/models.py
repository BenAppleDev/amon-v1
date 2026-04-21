from __future__ import annotations

from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now(), onupdate=func.now()
    )


class User(TimestampMixin, Base):
    __tablename__ = 'users'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    status: Mapped[str] = mapped_column(String(32), default='active', nullable=False)

    auth_identities: Mapped[list['AuthIdentity']] = relationship(back_populates='user', cascade='all, delete-orphan')
    entitlements: Mapped[list['Entitlement']] = relationship(back_populates='user', cascade='all, delete-orphan')
    sessions: Mapped[list['SessionRecord']] = relationship(back_populates='user', cascade='all, delete-orphan')
    rate_limits: Mapped[list['RateLimitWindow']] = relationship(back_populates='user', cascade='all, delete-orphan')


class AuthIdentity(TimestampMixin, Base):
    __tablename__ = 'auth_identities'
    __table_args__ = (UniqueConstraint('provider', 'provider_subject', name='uq_provider_subject'),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    provider_subject: Mapped[str] = mapped_column(String(255), nullable=False)

    user: Mapped['User'] = relationship(back_populates='auth_identities')


class Entitlement(TimestampMixin, Base):
    __tablename__ = 'entitlements'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    tier: Mapped[str] = mapped_column(String(64), nullable=False, default='full_access')
    status: Mapped[str] = mapped_column(String(32), nullable=False, default='active')
    starts_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ends_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped['User'] = relationship(back_populates='entitlements')


class SessionRecord(Base):
    __tablename__ = 'sessions'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped['User'] = relationship(back_populates='sessions')


class RouteSessionRecord(Base):
    __tablename__ = 'route_sessions'
    __table_args__ = (UniqueConstraint('access_token', name='uq_route_sessions_access_token'),)

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    auth_session_id: Mapped[str] = mapped_column(ForeignKey('sessions.id', ondelete='CASCADE'), nullable=False, index=True)
    route_kind: Mapped[str] = mapped_column(String(64), nullable=False, default='local_routed')
    transport_kind: Mapped[str] = mapped_column(String(64), nullable=False, default='packet_tunnel')
    control_plane_kind: Mapped[str] = mapped_column(String(64), nullable=False, default='control_only')
    access_token: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    last_refreshed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    revoke_reason: Mapped[str | None] = mapped_column(String(128), nullable=True)
    refresh_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)


class RateLimitWindow(TimestampMixin, Base):
    __tablename__ = 'rate_limit_windows'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    window_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    request_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    user: Mapped['User'] = relationship(back_populates='rate_limits')


class OpsOperatorSession(Base):
    __tablename__ = 'ops_operator_sessions'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    operator_id: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    environment: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    auth_method: Mapped[str] = mapped_column(String(64), nullable=False)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, server_default=func.now())
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ProtectedSessionOpsEventRecord(Base):
    __tablename__ = 'protected_session_ops_events'

    event_id: Mapped[str] = mapped_column(String, primary_key=True)
    environment: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    event_type: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    session_id: Mapped[str | None] = mapped_column(String, nullable=True, index=True)
    user_id: Mapped[str | None] = mapped_column(String, nullable=True, index=True)
    domain: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)
    worker_id: Mapped[str | None] = mapped_column(String, nullable=True, index=True)
    reason_code: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)
    state: Mapped[str | None] = mapped_column(String(64), nullable=True)
    disposition: Mapped[str | None] = mapped_column(String(64), nullable=True)
    budget_tier: Mapped[str | None] = mapped_column(String(64), nullable=True)
    metric_value: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)


class ProtectedSessionOpsSnapshotRecord(Base):
    __tablename__ = 'protected_session_ops_snapshots'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    environment: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    recorded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    total_sessions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    active_sessions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    active_streams: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    users_with_active_sessions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    users_with_live_streams: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_workers: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    healthy_workers: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    degraded_workers: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_worker_capacity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_worker_stream_capacity: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_assigned_sessions: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    quota_rejections_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    protocol_errors_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    heartbeat_timeouts_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    dropped_events_total: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
