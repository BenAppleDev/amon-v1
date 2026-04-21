import asyncio
from time import perf_counter
from contextlib import suppress

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from pydantic import ValidationError
from sqlalchemy.orm import Session

from app.db import get_db
from app.rate_limit import RateLimiter
from app.schemas import (
    ProtectedSessionActionRequest,
    ProtectedSessionCreateRequest,
    ProtectedSessionEndResponse,
    ProtectedSessionState,
    ProtectedSessionStreamClientMessage,
    ServeDecisionRequest,
    ServeDecisionResponse,
)
from app.security import (
    CurrentAccessContext,
    extract_bearer_token,
    get_current_access_context,
    resolve_current_access_context_from_token,
)
from app.services.protected_session_control_plane import get_protected_session_control_plane
from app.services.protected_sessions import ProtectedSessionError

router = APIRouter(prefix='/v1/protected-sessions', tags=['protected_sessions'])


async def _read_stream_message(websocket: WebSocket) -> ProtectedSessionStreamClientMessage:
    payload = await websocket.receive_json()
    return ProtectedSessionStreamClientMessage.model_validate(payload)


async def _stream_sender(
    websocket: WebSocket,
    *,
    outbound: asyncio.Queue[dict[str, object | None]],
    runtime,
    heartbeat_seconds: int,
) -> None:
    while True:
        try:
            payload = await asyncio.wait_for(outbound.get(), timeout=heartbeat_seconds)
        except asyncio.TimeoutError:
            payload = runtime.stream_session.heartbeat_message()
        await websocket.send_json(payload)


async def _state_forwarder(
    *,
    outbound: asyncio.Queue[dict[str, object | None]],
    subscriber,
    on_dropped_events=None,
) -> None:
    while True:
        payload = await subscriber.get()
        dropped_events = subscriber.consume_dropped_events()
        if dropped_events > 0:
            if on_dropped_events is not None:
                await on_dropped_events(dropped_events)
            payload = dict(payload)
            payload['dropped_events'] = dropped_events
        await outbound.put(payload)


@router.post('/decision', response_model=ServeDecisionResponse)
async def protected_session_decision(
    payload: ServeDecisionRequest,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> ServeDecisionResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    control_plane = get_protected_session_control_plane()
    return await control_plane.decide_url_open(current=current, url=str(payload.url), intent=payload.intent)


@router.post('', response_model=ProtectedSessionState)
async def create_protected_session(
    payload: ProtectedSessionCreateRequest,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> ProtectedSessionState:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_protected_session_control_plane()
        return await control_plane.create_session(current=current, url=str(payload.url))
    except ProtectedSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.get('/{session_id}', response_model=ProtectedSessionState)
async def get_protected_session(
    session_id: str,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> ProtectedSessionState:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_protected_session_control_plane()
        return await control_plane.get_state(current=current, session_id=session_id)
    except ProtectedSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.post('/{session_id}/actions', response_model=ProtectedSessionState)
async def act_on_protected_session(
    session_id: str,
    payload: ProtectedSessionActionRequest,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> ProtectedSessionState:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_protected_session_control_plane()
        return await control_plane.apply_action(current=current, session_id=session_id, action=payload)
    except ProtectedSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.delete('/{session_id}', response_model=ProtectedSessionEndResponse)
async def end_protected_session(
    session_id: str,
    current: CurrentAccessContext = Depends(get_current_access_context),
    db: Session = Depends(get_db),
) -> ProtectedSessionEndResponse:
    RateLimiter(db).check_and_increment(current.user.id)
    try:
        control_plane = get_protected_session_control_plane()
        return await control_plane.end_session(current=current, session_id=session_id)
    except ProtectedSessionError as exc:
        raise HTTPException(status_code=exc.status_code, detail={'code': exc.code, 'message': exc.message}) from exc


@router.websocket('/{session_id}/stream')
async def stream_protected_session(
    websocket: WebSocket,
    session_id: str,
    db: Session = Depends(get_db),
) -> None:
    runtime = None
    subscriber = None
    outbound: asyncio.Queue[dict[str, object | None]] | None = None
    sender_task: asyncio.Task[None] | None = None
    forwarder_task: asyncio.Task[None] | None = None
    active_action_task: asyncio.Task[None] | None = None
    current = None
    disconnect_reason = 'stream_detached'
    stream_registered = False
    try:
        token = extract_bearer_token(websocket.headers.get('authorization'))
        current = resolve_current_access_context_from_token(token, db)
        RateLimiter(db).check_and_increment(current.user.id)
        control_plane = get_protected_session_control_plane()
        await websocket.accept()
        try:
            initial_message = await asyncio.wait_for(_read_stream_message(websocket), timeout=10)
        except (asyncio.TimeoutError, ValidationError):
            await websocket.close(code=4400)
            return

        if initial_message.type != 'subscribe':
            await websocket.close(code=4400)
            return

        runtime, subscriber, subscribed = await control_plane.subscribe_stream(
            current=current,
            session_id=session_id,
            last_stream_sequence=initial_message.last_stream_sequence,
        )
        stream_registered = True

        outbound = asyncio.Queue()
        await outbound.put(subscribed)
        sender_task = asyncio.create_task(
            _stream_sender(
                websocket,
                outbound=outbound,
                runtime=runtime,
                heartbeat_seconds=control_plane.settings.protected_session_stream_heartbeat_seconds,
            )
        )
        forwarder_task = asyncio.create_task(
            _state_forwarder(
                outbound=outbound,
                subscriber=subscriber,
                on_dropped_events=lambda count: control_plane.note_stream_dropped_events(
                    current=current,
                    session_id=session_id,
                    count=count,
                ),
            )
        )

        while True:
            try:
                message = await asyncio.wait_for(
                    _read_stream_message(websocket),
                    timeout=control_plane.settings.protected_session_stream_idle_timeout_seconds,
                )
            except asyncio.TimeoutError:
                disconnect_reason = 'client_heartbeat_timeout'
                await websocket.close(code=4408)
                break
            except ValidationError:
                await control_plane.note_stream_protocol_error(
                    current=current,
                    session_id=session_id,
                    code='invalid_stream_message',
                )
                await outbound.put(
                    runtime.stream_session.error_message(
                        code='protected_session_stream_protocol_error',
                        message='That stream message was invalid.',
                    )
                )
                continue

            if message.type == 'ping':
                await outbound.put(runtime.stream_session.heartbeat_message())
                continue

            if message.type == 'detach':
                disconnect_reason = 'client_detach'
                await websocket.close(code=1000)
                break

            if message.type == 'subscribe':
                await control_plane.note_stream_protocol_error(
                    current=current,
                    session_id=session_id,
                    code='already_subscribed',
                )
                await outbound.put(
                    runtime.stream_session.error_message(
                        code='protected_session_stream_already_subscribed',
                        message='That stream connection is already subscribed.',
                    )
                )
                continue

            if message.type != 'action':
                await control_plane.note_stream_protocol_error(
                    current=current,
                    session_id=session_id,
                    code='unsupported_stream_message',
                )
                await outbound.put(
                    runtime.stream_session.error_message(
                        code='protected_session_stream_protocol_error',
                        message='That stream message is not supported.',
                    )
                )
                continue

            if message.client_action_id is None or message.action is None:
                await control_plane.note_stream_protocol_error(
                    current=current,
                    session_id=session_id,
                    code='invalid_stream_action',
                )
                await outbound.put(
                    runtime.stream_session.error_message(
                        code='protected_session_stream_invalid_action',
                        message='A protected-session action id and payload are required.',
                    )
                )
                continue

            if active_action_task is not None and not active_action_task.done():
                await control_plane.note_stream_action_ack(
                    current=current,
                    session_id=session_id,
                    status='rejected',
                    reason_code='protected_session_busy',
                )
                await outbound.put(
                    runtime.stream_session.action_ack_message(
                        client_action_id=message.client_action_id,
                        action_status='rejected',
                        code='protected_session_busy',
                        message='A previous protected-session action is still running.',
                    )
                )
                continue

            await control_plane.note_stream_action_ack(
                current=current,
                session_id=session_id,
                status='accepted',
            )
            await outbound.put(
                runtime.stream_session.action_ack_message(
                    client_action_id=message.client_action_id,
                    action_status='accepted',
                )
            )

            async def run_action(client_action_id: str, request_message: ProtectedSessionStreamClientMessage) -> None:
                started = perf_counter()
                try:
                    await control_plane.apply_action(
                        current=current,
                        session_id=session_id,
                        action=request_message.action,
                        expected_content_revision=request_message.expected_content_revision,
                        source_action_id=client_action_id,
                    )
                    await control_plane.note_stream_action_result(
                        current=current,
                        session_id=session_id,
                        status='completed',
                        duration_ms=max(0, int((perf_counter() - started) * 1000)),
                    )
                except ProtectedSessionError as exc:
                    await control_plane.note_stream_action_ack(
                        current=current,
                        session_id=session_id,
                        status='failed',
                        reason_code=exc.code,
                    )
                    await control_plane.note_stream_action_result(
                        current=current,
                        session_id=session_id,
                        status='failed',
                        duration_ms=max(0, int((perf_counter() - started) * 1000)),
                        reason_code=exc.code,
                    )
                    await outbound.put(
                        runtime.stream_session.action_ack_message(
                            client_action_id=client_action_id,
                            action_status='failed',
                            code=exc.code,
                            message=exc.message,
                        )
                    )

            active_action_task = asyncio.create_task(run_action(message.client_action_id, message))
    except HTTPException as exc:
        close_code = 4403 if exc.status_code == 403 else 4401
        await websocket.close(code=close_code)
    except ProtectedSessionError:
        await websocket.close(code=4404)
    except WebSocketDisconnect:
        disconnect_reason = 'client_disconnect'
        return
    finally:
        if forwarder_task is not None:
            forwarder_task.cancel()
            with suppress(asyncio.CancelledError):
                await forwarder_task
        if sender_task is not None:
            sender_task.cancel()
            with suppress(asyncio.CancelledError):
                await sender_task
        if runtime is not None and subscriber is not None:
            runtime.unsubscribe_stream(subscriber)
        if current is not None and stream_registered:
            try:
                control_plane = get_protected_session_control_plane()
                await control_plane.note_stream_detached(
                    current=current,
                    session_id=session_id,
                    reason_code=disconnect_reason,
                    heartbeat_timeout=(disconnect_reason == 'client_heartbeat_timeout'),
                )
            except Exception:
                pass
