"""Odzyskiwanie hasła (8.5): link z jednorazowym tokenem wysyłany e-mailem.

- Odpowiedź jest zawsze taka sama, także dla nieistniejącego adresu (A1), żeby nie ujawniać kont.
- Token ważny 30 minut, w bazie tylko jego skrót. Nowy link unieważnia poprzednie.
- Maks. 3 wysyłki na godzinę na konto (A4); kolejne prośby są po cichu pomijane.
- Ustawienie nowego hasła unieważnia token i wylogowuje wszystkie sesje, także w grze (krok 6).
"""
import logging
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import hash_password, is_strong_password, new_session_token, token_hash, verify_dummy_password
from app.db.models import Gracz
from app.services import mailer

logger = logging.getLogger("jewelrunner")

TOKEN_TTL = timedelta(minutes=30)
MAX_PER_HOUR = 3


def request_reset(db: Session, email: str) -> None:
    gracz = db.scalar(
        select(Gracz).where(func.lower(Gracz.email) == email.lower(), Gracz.status_konta == "aktywne").with_for_update()
    )
    if gracz is None:
        verify_dummy_password(email)  # podobny czas odpowiedzi jak dla istniejącego konta
        return
    sent_last_hour = db.scalar(
        text("SELECT count(*) FROM token_resetu_hasla WHERE gracz_id = :g AND data_utworzenia > now() - interval '1 hour'"),
        {"g": gracz.id},
    )
    if sent_last_hour >= MAX_PER_HOUR:
        db.rollback()
        logger.info("Limit wysyłek resetu hasła dla gracza %s", gracz.id)
        return

    db.execute(text("UPDATE token_resetu_hasla SET czy_uzyty = TRUE WHERE gracz_id = :g AND NOT czy_uzyty"), {"g": gracz.id})
    token = new_session_token()
    db.execute(
        text("INSERT INTO token_resetu_hasla (gracz_id, skrot_wartosci, data_waznosci) VALUES (:g, :h, :d)"),
        {"g": gracz.id, "h": token_hash(token), "d": datetime.now(UTC) + TOKEN_TTL},
    )
    link = f"{get_settings().portal_url}/nowe-haslo?token={token}"
    try:
        mailer.send_email(
            gracz.email,
            "Ustaw nowe hasło w JewelRunner",
            f"Aby ustawić nowe hasło, otwórz link (ważny 30 minut):\n{link}\n\n"
            "Jeśli to nie Ty prosiłeś o zmianę hasła, zignoruj tę wiadomość.",
        )
    except AppError:
        # Nie zdradzamy, że konto istnieje: gracz dostaje ten sam komunikat i może spróbować ponownie.
        db.rollback()
        logger.exception("Nie udało się wysłać linku resetu hasła")
        return
    db.commit()


def reset_password(db: Session, token: str, new_password: str) -> None:
    if not is_strong_password(new_password):
        raise AppError(422, "weak_password", "Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.")
    row = db.execute(
        text(
            """
            SELECT id, gracz_id FROM token_resetu_hasla
            WHERE skrot_wartosci = :h AND NOT czy_uzyty AND data_waznosci > now()
            FOR UPDATE
            """
        ),
        {"h": token_hash(token)},
    ).first()
    if row is None:
        raise AppError(400, "invalid_token", "Link wygasł lub został już użyty. Wyślij nowy.")
    db.execute(text("UPDATE token_resetu_hasla SET czy_uzyty = TRUE WHERE id = :id"), {"id": row.id})
    db.execute(
        text(
            """
            UPDATE gracz SET skrot_hasla = :p, liczba_nieudanych_logowan = 0, zablokowany_do = NULL,
                data_modyfikacji = now()
            WHERE id = :g
            """
        ),
        {"p": hash_password(new_password), "g": row.gracz_id},
    )
    db.execute(
        text("UPDATE sesja_logowania SET data_uniewaznienia = now() WHERE gracz_id = :g AND data_uniewaznienia IS NULL"),
        {"g": row.gracz_id},
    )
    db.commit()
