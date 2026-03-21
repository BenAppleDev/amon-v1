from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import models  # noqa: F401  # ensure models register
from app.config import get_settings
from app.db import Base, engine
from app.routers.auth import router as auth_router
from app.routers.compare import router as compare_router
from app.routers.health import router as health_router
from app.routers.me import router as me_router
from app.routers.research import router as research_router
from app.routers.retrieve import router as retrieve_router
from app.routers.search import router as search_router

settings = get_settings()


@asynccontextmanager
async def lifespan(_app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description='Amon v1 privacy-first retrieval backend. Queries and page content are handled transiently.',
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_allow_origins or ['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)


app.include_router(health_router)
app.include_router(auth_router)
app.include_router(me_router)
app.include_router(search_router)
app.include_router(retrieve_router)
app.include_router(compare_router)
app.include_router(research_router)
