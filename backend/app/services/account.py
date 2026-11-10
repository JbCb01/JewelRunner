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


def request_email_change(db: Session, gracz: Gracz, new_email: str, password: str) -> None:
    _require_password(db, gracz, password)
    new_email = new_email.lower()
    if db.scalar(select(Gracz.id).where(func.lower(Gracz.email) == new_email)):
        raise AppError(409, "email_taken", "Adres e-mail jest już zarejestrowany.")

    # Ważny jest tylko ostatnio wysłany link.
    db.execute(
        update(TokenZmianyEmaila)
        .where(TokenZmianyEmaila.gracz_id == gracz.id, TokenZmianyEmaila.czy_uzyty.is_(False))
        .values(czy_uzyty=True)
    )
    token = new_session_token()
    db.add(
        TokenZmianyEmaila(
            gracz_id=gracz.id,
            nowy_email=new_email,
            skrot_wartosci=token_hash(token),
            data_waznosci=datetime.now(UTC) + EMAIL_TOKEN_TTL,
        )
    )
    link = f"{get_settings().portal_url}/potwierdz-email?token={token}"
    mailer.send_email(new_email, "Potwierdź zmianę adresu e-mail", f"Aby potwierdzić nowy adres, otwórz link:\n{link}")
    db.commit()


def confirm_email_change(db: Session, gracz: Gracz, token: str) -> None:
    record = db.scalar(
        select(TokenZmianyEmaila)
        .where(
            TokenZmianyEmaila.skrot_wartosci == token_hash(token),
            TokenZmianyEmaila.gracz_id == gracz.id,
            TokenZmianyEmaila.czy_uzyty.is_(False),
            TokenZmianyEmaila.data_waznosci > datetime.now(UTC),
        )
        .with_for_update()
    )
    if record is None:
        raise AppError(400, "invalid_token", "Link jest nieprawidłowy lub wygasł.")
    record.czy_uzyty = True
    gracz.email = record.nowy_email
    gracz.data_modyfikacji = datetime.now(UTC)
    _commit_unique(db, "ux_gracz_email", AppError(409, "email_taken", "Adres e-mail jest już zarejestrowany."))


def change_password(db: Session, gracz: Gracz, current_password: str, new_password: str) -> None:
    _require_password(db, gracz, current_password)
    if not is_strong_password(new_password):
        raise AppError(422, "weak_password", "Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.")
    gracz.skrot_hasla = hash_password(new_password)
    gracz.data_modyfikacji = datetime.now(UTC)
    db.commit()
