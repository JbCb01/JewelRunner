from typing import Annotated

from fastapi import Cookie, Depends, Path
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import Gracz
from app.db.session import get_db
from app.services import auth as auth_service

SESSION_COOKIE = "jr_session"
SessionToken = Annotated[str | None, Cookie(alias=SESSION_COOKIE)]
DbSession = Annotated[Session, Depends(get_db)]
ChallengeId = Annotated[int, Path(ge=1, le=2**63 - 1)]


def get_current_player(db: DbSession, token: SessionToken = None) -> Gracz:
    gracz = auth_service.player_from_token(db, token)
    if gracz is None:
        raise AppError(401, "unauthorized", "Zaloguj się, aby kontynuować.")
    return gracz


CurrentPlayer = Annotated[Gracz, Depends(get_current_player)]
