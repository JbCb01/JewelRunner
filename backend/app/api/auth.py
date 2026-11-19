from datetime import datetime

from fastapi import APIRouter, Response, status

from app.api.deps import SESSION_COOKIE, DbSession, SessionToken
from app.core.config import get_settings
from app.db.models import Gracz
from app.schemas.auth import (
    ForgotPasswordRequest,
    GameSessionResponse,
    LoginRequest,
    MeResponse,
    PairRequest,
    RegisterRequest,
    ResetPasswordRequest,
)
from app.services import auth as auth_service
from app.services import pairing, password_reset

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


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(response: Response, db: DbSession, token: SessionToken) -> None:
    auth_service.logout(db, token)
    response.delete_cookie(SESSION_COOKIE, **_cookie_options())


@router.post("/pair")
def pair(data: PairRequest, db: DbSession) -> GameSessionResponse:
    """Gra wymienia kod z portalu na sesję. Odpowiedź nie ustawia cookie."""
    gracz, token, expires_at = pairing.redeem_code(db, data.code)
    return GameSessionResponse(
        token=token,
        expires_at=expires_at,
        player=MeResponse(id=gracz.id, username=gracz.nazwa_uzytkownika, email=gracz.email),
    )


@router.post("/forgot", status_code=status.HTTP_202_ACCEPTED)
def forgot_password(data: ForgotPasswordRequest, db: DbSession) -> dict:
    """Zawsze ta sama odpowiedź, żeby nie ujawniać, czy konto istnieje (8.5 A1)."""
    password_reset.request_reset(db, data.email)
    return {"status": "sent_if_exists", "message": "Jeśli konto istnieje, wysłaliśmy link do ustawienia nowego hasła."}


@router.post("/reset", status_code=status.HTTP_204_NO_CONTENT)
def reset_password(data: ResetPasswordRequest, response: Response, db: DbSession) -> None:
    password_reset.reset_password(db, data.token, data.new_password)
    response.delete_cookie(SESSION_COOKIE, **_cookie_options())
