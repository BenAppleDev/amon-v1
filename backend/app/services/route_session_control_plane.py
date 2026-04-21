from __future__ import annotations

from datetime import timedelta

from sqlalchemy.orm import Session

from app.config import Settings, get_settings
from app.models import RouteSessionRecord
from app.schemas import RouteSessionRevokeResponse, RouteSessionState
from app.security import CurrentUser, create_record_id, create_session_token, utcnow


class RouteSessionError(Exception):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(message)
        self.status_code = status_code
        self.code = code
        self.message = message


class RouteSessionControlPlane:
    def __init__(self, *, settings: Settings | None = None) -> None:
        self.settings = settings or get_settings()

    def mint_session(self, *, current: CurrentUser, db: Session) -> RouteSessionState:
        self._expire_stale_sessions(db)
        self._revoke_active_sessions_for_auth_session(
            db,
            user_id=current.user.id,
            auth_session_id=current.session.id,
            reason='replaced',
        )

        now = utcnow()
        record = RouteSessionRecord(
            id=create_record_id('route'),
            user_id=current.user.id,
            auth_session_id=current.session.id,
            route_kind='local_routed',
            transport_kind='packet_tunnel',
            control_plane_kind='control_only',
            access_token=create_session_token(),
            issued_at=now,
            last_refreshed_at=now,
            expires_at=now + timedelta(seconds=self.settings.route_session_ttl_seconds),
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        return self._state_for(record)

    def refresh_session(self, *, current: CurrentUser, session_id: str, db: Session) -> RouteSessionState:
        self._expire_stale_sessions(db)
        record = self._owned_record_for(current=current, session_id=session_id, db=db)
        if record.revoked_at is not None:
            raise RouteSessionError(410, 'route_session_revoked', 'That routed-local session was revoked.')
        if record.expires_at <= utcnow():
            self._expire_record(record, db)
            raise RouteSessionError(410, 'route_session_expired', 'That routed-local session expired.')

        now = utcnow()
        record.access_token = create_session_token()
        record.last_refreshed_at = now
        record.expires_at = now + timedelta(seconds=self.settings.route_session_ttl_seconds)
        record.refresh_count += 1
        db.add(record)
        db.commit()
        db.refresh(record)
        return self._state_for(record)

    def revoke_session(
        self,
        *,
        current: CurrentUser,
        session_id: str,
        db: Session,
        reason: str = 'client_revoked',
    ) -> RouteSessionRevokeResponse:
        self._expire_stale_sessions(db)
        record = self._owned_record_for(current=current, session_id=session_id, db=db)
        revoked_at = record.revoked_at or utcnow()
        record.revoked_at = revoked_at
        record.revoke_reason = reason
        db.add(record)
        db.commit()
        return RouteSessionRevokeResponse(
            session_id=record.id,
            status='revoked',
            revoked_at=revoked_at,
        )

    def resolve_access_token(self, *, access_token: str, db: Session) -> RouteSessionRecord:
        self._expire_stale_sessions(db)
        record = db.query(RouteSessionRecord).filter(RouteSessionRecord.access_token == access_token).first()
        if record is None:
            raise RouteSessionError(401, 'route_session_invalid', 'That routed-local access token is invalid.')
        if record.revoke_reason == 'expired':
            raise RouteSessionError(401, 'route_session_expired', 'That routed-local access token expired.')
        if record.revoked_at is not None:
            raise RouteSessionError(401, 'route_session_revoked', 'That routed-local access token was revoked.')
        if record.expires_at <= utcnow():
            self._expire_record(record, db)
            raise RouteSessionError(401, 'route_session_expired', 'That routed-local access token expired.')
        return record

    def _owned_record_for(self, *, current: CurrentUser, session_id: str, db: Session) -> RouteSessionRecord:
        record = db.get(RouteSessionRecord, session_id)
        if record is None or record.user_id != current.user.id or record.auth_session_id != current.session.id:
            raise RouteSessionError(404, 'route_session_missing', 'That routed-local session is not available.')
        return record

    def _expire_stale_sessions(self, db: Session) -> None:
        now = utcnow()
        stale_records = (
            db.query(RouteSessionRecord)
            .filter(RouteSessionRecord.revoked_at.is_(None), RouteSessionRecord.expires_at <= now)
            .all()
        )
        if not stale_records:
            return
        for record in stale_records:
            record.revoked_at = now
            record.revoke_reason = 'expired'
            db.add(record)
        db.commit()

    def _revoke_active_sessions_for_auth_session(
        self,
        db: Session,
        *,
        user_id: str,
        auth_session_id: str,
        reason: str,
    ) -> None:
        active_records = (
            db.query(RouteSessionRecord)
            .filter(
                RouteSessionRecord.user_id == user_id,
                RouteSessionRecord.auth_session_id == auth_session_id,
                RouteSessionRecord.revoked_at.is_(None),
            )
            .all()
        )
        if not active_records:
            return
        revoked_at = utcnow()
        for record in active_records:
            record.revoked_at = revoked_at
            record.revoke_reason = reason
            db.add(record)
        db.commit()

    def _expire_record(self, record: RouteSessionRecord, db: Session) -> None:
        if record.revoked_at is None:
            record.revoked_at = utcnow()
            record.revoke_reason = 'expired'
            db.add(record)
            db.commit()

    def _state_for(self, record: RouteSessionRecord) -> RouteSessionState:
        now = utcnow()
        status = 'active'
        if record.revoked_at is not None:
            status = 'expired' if record.revoke_reason == 'expired' else 'revoked'
        refresh_after = record.expires_at - timedelta(seconds=self.settings.route_session_refresh_leeway_seconds)
        if refresh_after <= now:
            refresh_after = now
        return RouteSessionState(
            session_id=record.id,
            access_token=record.access_token,
            status=status,
            route_kind='local_routed',
            transport_kind=record.transport_kind,
            control_plane_kind=record.control_plane_kind,
            auth_session_id=record.auth_session_id,
            issued_at=record.issued_at,
            refresh_after=refresh_after,
            expires_at=record.expires_at,
        )

def get_route_session_control_plane() -> RouteSessionControlPlane:
    return RouteSessionControlPlane()
