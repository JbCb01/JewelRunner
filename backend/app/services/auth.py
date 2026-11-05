from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import (
    hash_password,
    is_strong_password,
    new_session_token,
    password_needs_rehash,
    token_hash,
    verify_dummy_password,
    verify_password,
)
from app.db.models import (
    ElementPersonalizacji,
    Gracz,
    PortfelGracza,
    PosiadanyElement,
    SesjaLogowania,
    StatystykiGracza,
    WygladPostaci,
)
from app.schemas.auth import LoginRequest, RegisterRequest

MAX_FAILED_LOGINS = 5
LOCK_DURATION = timedelta(minutes=15)
DEVICE_BROWSER = "przeglądarka"


def _create_session(db: Session, gracz: Gracz) -> tuple[str, datetime]:
    token = new_session_token()
    expires_at = datetime.now(UTC) + timedelta(hours=get_settings().session_ttl_hours)
    db.add(
        SesjaLogowania(
            gracz_id=gracz.id,
            skrot_tokenu=token_hash(token),
            urzadzenie=DEVICE_BROWSER,
            data_wygasniecia=expires_at,
        )
    )
    return token, expires_at


def check_password_with_lock(db: Session, gracz: Gracz, password: str) -> bool:
    """Sprawdza hasło i liczy nieudane próby. Wiersz gracza musi być zablokowany przez FOR UPDATE."""
    now = datetime.now(UTC)
    if gracz.zablokowany_do and gracz.zablokowany_do > now:
        raise AppError(429, "login_locked", "Zbyt wiele nieudanych prób. Spróbuj ponownie później.")
    if verify_password(gracz.skrot_hasla, password):
        return True
    gracz.liczba_nieudanych_logowan += 1
    if gracz.liczba_nieudanych_logowan >= MAX_FAILED_LOGINS:
        gracz.zablokowany_do = now + LOCK_DURATION
        gracz.liczba_nieudanych_logowan = 0
    db.commit()
    return False


def _default_element_id(db: Session, element_type: str) -> int:
    element_id = db.scalar(
        select(ElementPersonalizacji.id).where(
            ElementPersonalizacji.typ == element_type, ElementPersonalizacji.czy_domyslny
        )
    )
    if element_id is None:
        raise RuntimeError(f"Brak domyślnego elementu typu {element_type}. Czy wczytano dane startowe?")
    return element_id


def register(db: Session, data: RegisterRequest) -> tuple[Gracz, str, datetime]:
    if not is_strong_password(data.password):
        raise AppError(422, "weak_password", "Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.")

    skin_id = _default_element_id(db, "skórka")
    color_id = _default_element_id(db, "kolor")
    gracz = Gracz(
        nazwa_uzytkownika=data.username,
        email=data.email.lower(),
        skrot_hasla=hash_password(data.password),
        data_ostatniego_logowania=datetime.now(UTC),
    )
    db.add(gracz)
    try:
        db.flush()
    except IntegrityError as exc:
        db.rollback()
        constraint = exc.orig.diag.constraint_name
        if constraint == "ux_gracz_nazwa":
            raise AppError(409, "username_taken", "Nazwa jest zajęta.") from exc
        if constraint == "ux_gracz_email":
            raise AppError(409, "email_taken", "Adres e-mail jest już zarejestrowany.") from exc
        raise

    db.add_all(
        [
            StatystykiGracza(gracz_id=gracz.id),
            PortfelGracza(gracz_id=gracz.id),
            PosiadanyElement(gracz_id=gracz.id, element_id=skin_id),
            PosiadanyElement(gracz_id=gracz.id, element_id=color_id),
            WygladPostaci(gracz_id=gracz.id, skorka_id=skin_id, kolor_id=color_id),
        ]
    )
    token, expires_at = _create_session(db, gracz)
    db.commit()
    return gracz, token, expires_at


def login(db: Session, data: LoginRequest) -> tuple[Gracz, str, datetime]:
    invalid = AppError(401, "invalid_credentials", "Nieprawidłowy login lub hasło.")
    gracz = db.scalar(select(Gracz).where(func.lower(Gracz.email) == data.email.lower()).with_for_update())
    if gracz is None:
        verify_dummy_password(data.password)
        raise invalid

    if not check_password_with_lock(db, gracz, data.password):
        raise invalid

    # Po poprawnym haśle, żeby bez niego nie dało się sprawdzić stanu konta.
    if gracz.status_konta != "aktywne":
        raise AppError(403, "account_blocked", "Konto zostało zablokowane.")

    if password_needs_rehash(gracz.skrot_hasla):
        gracz.skrot_hasla = hash_password(data.password)
    gracz.liczba_nieudanych_logowan = 0
    gracz.zablokowany_do = None
    gracz.data_ostatniego_logowania = datetime.now(UTC)
    token, expires_at = _create_session(db, gracz)
    db.commit()
    return gracz, token, expires_at

