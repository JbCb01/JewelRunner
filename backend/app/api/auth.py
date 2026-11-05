from datetime import datetime

from fastapi import APIRouter, Response, status

from app.api.deps import SESSION_COOKIE, DbSession, SessionToken
from app.core.config import get_settings
from app.db.models import Gracz
from app.schemas.auth import LoginRequest, MeResponse, RegisterRequest
from app.services import auth as auth_service

router = APIRouter(prefix="/auth", tags=["konto"])


def _cookie_options() -> dict:
    settings = get_settings()
    return {
        "httponly": True,
        "secure": settings.session_cookie_secure,
        "samesite": settings.session_cookie_samesite,
        "path": "/",
    }


def _start_session(response: Response, gracz: Gracz, token: str, expires_at: datetime) -> MeResponse:
    response.set_cookie(SESSION_COOKIE, token, expires=expires_at, **_cookie_options())
    return MeResponse(id=gracz.id, username=gracz.nazwa_uzytkownika, email=gracz.email)


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, response: Response, db: DbSession) -> MeResponse:
    return _start_session(response, *auth_service.register(db, data))


@router.post("/login")
def login(data: LoginRequest, response: Response, db: DbSession) -> MeResponse:
    return _start_session(response, *auth_service.login(db, data))

