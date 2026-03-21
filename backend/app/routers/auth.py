from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import AuthIdentity, Entitlement, User
from app.schemas import AuthResponse, DevLoginRequest, UserView
from app.security import build_session_record, create_record_id, create_user_id

router = APIRouter(prefix='/v1/auth', tags=['auth'])


@router.post('/dev-login', response_model=AuthResponse)
def dev_login(payload: DevLoginRequest, db: Session = Depends(get_db)) -> AuthResponse:
    identity = (
        db.query(AuthIdentity)
        .filter(AuthIdentity.provider == 'apple', AuthIdentity.provider_subject == payload.apple_subject)
        .first()
    )

    if identity is None:
        user = User(id=create_user_id(), status='active')
        db.add(user)
        db.flush()
        identity = AuthIdentity(
            id=create_record_id('auth'),
            user_id=user.id,
            provider='apple',
            provider_subject=payload.apple_subject,
        )
        db.add(identity)
        entitlement = Entitlement(
            id=create_record_id('ent'),
            user_id=user.id,
            tier='full_access',
            status='active',
        )
        db.add(entitlement)
    else:
        user = db.get(User, identity.user_id)
        entitlement = (
            db.query(Entitlement)
            .filter(Entitlement.user_id == identity.user_id)
            .order_by(Entitlement.created_at.desc())
            .first()
        )
        if entitlement is None:
            entitlement = Entitlement(
                id=create_record_id('ent'),
                user_id=identity.user_id,
                tier='full_access',
                status='active',
            )
            db.add(entitlement)

    session_record = build_session_record(user.id)
    db.add(session_record)
    db.commit()
    db.refresh(session_record)
    db.refresh(user)
    db.refresh(entitlement)

    return AuthResponse(
        access_token=session_record.id,
        expires_at=session_record.expires_at,
        user=UserView(
            id=user.id,
            status=user.status,
            entitlement_tier=entitlement.tier,
            entitlement_status=entitlement.status,
        ),
    )
