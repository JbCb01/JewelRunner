from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from app.api import auth, challenges, health, me, players, ranking
from app.core.config import get_settings
from app.core.errors import catch_unhandled, check_origin, register_error_handlers
from app.core.portal import register_portal


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="JewelRunner API",
        version="0.1.0",
        docs_url="/api/docs",
        openapi_url="/api/openapi.json",
        redoc_url=None,
    )
    register_error_handlers(app)
    app.add_middleware(BaseHTTPMiddleware, dispatch=catch_unhandled)
    app.add_middleware(BaseHTTPMiddleware, dispatch=check_origin)
    # Dodany jako ostatni, więc jest najbardziej zewnętrzny i obejmuje też odpowiedzi z błędami.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Content-Type"],
    )
    app.include_router(health.router, prefix="/api")
    app.include_router(auth.router, prefix="/api")
    app.include_router(me.router, prefix="/api")
    app.include_router(challenges.router, prefix="/api")
    app.include_router(ranking.router, prefix="/api")
    app.include_router(players.router, prefix="/api")
    if settings.portal_dist:
        register_portal(app, Path(settings.portal_dist))
    return app


app = create_app()
