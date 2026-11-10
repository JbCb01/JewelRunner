from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import (
    hash_password,
    is_strong_password,
    new_session_token,
    token_hash,
)
from app.db.models import Gracz, TokenZmianyEmaila
from app.services import mailer
from app.services.auth import check_password_with_lock

EMAIL_TOKEN_TTL = timedelta(hours=24)


def _require_password(db: Session, gracz: Gracz, password: str) -> None:
    db.refresh(gracz, with_for_update=True)
    if not check_password_with_lock(db, gracz, password):
        raise AppError(403, "invalid_password", "Aktualne hasło jest nieprawidłowe.")
    if gracz.liczba_nieudanych_logowan:
        gracz.liczba_nieudanych_logowan = 0


def _commit_unique(db: Session, constraint: str, error: AppError) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.orig.diag.constraint_name == constraint:
            raise error from exc
        raise


def change_username(db: Session, gracz: Gracz, username: str) -> None:
    gracz.nazwa_uzytkownika = username
    gracz.data_modyfikacji = datetime.now(UTC)
    _commit_unique(db, "ux_gracz_nazwa", AppError(409, "username_taken", "Nazwa jest zajęta."))

