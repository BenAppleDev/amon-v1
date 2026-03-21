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


class RateLimitWindow(TimestampMixin, Base):
    __tablename__ = 'rate_limit_windows'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    user_id: Mapped[str] = mapped_column(ForeignKey('users.id', ondelete='CASCADE'), nullable=False, index=True)
    window_start: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    window_end: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    request_count: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    user: Mapped['User'] = relationship(back_populates='rate_limits')
