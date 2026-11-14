from typing import Annotated

from fastapi import Cookie, Depends, Header, Path
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import Gracz
from app.db.session import get_db
from app.services import auth as auth_service

SESSION_COOKIE = "jr_session"
DbSession = Annotated[Session, Depends(get_db)]
ChallengeId = Annotated[int, Path(ge=1, le=2**63 - 1)]


def get_session_token(
    cookie: Annotated[str | None, Cookie(alias=SESSION_COOKIE)] = None,
    authorization: Annotated[str | None, Header()] = None,
) -> str | None:
    """Portal wysyła token w cookie, gra w nagłówku „Authorization: Bearer <token>”."""
    if authorization:
        scheme, _, value = authorization.partition(" ")
        if scheme.lower() == "bearer" and value.strip():
            return value.strip()
    return cookie


SessionToken = Annotated[str | None, Depends(get_session_token)]


def get_current_player(db: DbSession, token: SessionToken) -> Gracz:
    gracz = auth_service.player_from_token(db, token)
    if gracz is None:
        raise AppError(401, "unauthorized", "Zaloguj się, aby kontynuować.")
    return gracz


CurrentPlayer = Annotated[Gracz, Depends(get_current_player)]
