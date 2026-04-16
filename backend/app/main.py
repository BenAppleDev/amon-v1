from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app import models  # noqa: F401  # ensure models register
from app.config import get_settings
from app.db import Base, engine
from app.routers.auth import router as auth_router
from app.routers.compare import router as compare_router
from app.routers.health import router as health_router
from app.routers.internal_protected_sessions import router as internal_protected_sessions_router
from app.routers.me import router as me_router
from app.routers.ops_auth import router as ops_auth_router
from app.routers.ops_protected_sessions import router as ops_protected_sessions_router
from app.routers.ops_surface import router as ops_surface_router
from app.routers.protected_sessions import router as protected_sessions_router
from app.routers.research import router as research_router
from app.routers.retrieve import router as retrieve_router
from app.routers.search import router as search_router
from app.services.protected_session_control_plane import get_protected_session_control_plane

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    Base.metadata.create_all(bind=engine)
    control_plane = get_protected_session_control_plane()
    try:
        yield
    finally:
        await control_plane.shutdown()


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description='Amon v1 privacy-first retrieval backend. Queries and page content are handled transiently.',
    lifespan=lifespan,
)

if settings.trust_proxy_headers:
    app.add_middleware(
        ProxyHeadersMiddleware,
        trusted_hosts=settings.trusted_proxy_ips or '127.0.0.1',
    )

if settings.trusted_host_patterns:
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.trusted_host_patterns,
        www_redirect=False,
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.resolved_cors_allow_origins() or ['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)


app.include_router(health_router)
app.include_router(auth_router)
app.include_router(me_router)
app.include_router(search_router)
app.include_router(retrieve_router)
app.include_router(protected_sessions_router)
app.include_router(internal_protected_sessions_router)
app.include_router(ops_auth_router)
app.include_router(ops_protected_sessions_router)
app.include_router(ops_surface_router)
app.include_router(compare_router)
app.include_router(research_router)
