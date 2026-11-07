import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import (
    ElementPersonalizacji,
    Gracz,
    Nagroda,
    Poziom,
    PostepPoziomu,
    ProbaWyzwania,
    UczestnictwoWWyzwaniu,
    Wyzwanie,
    Wzmocnienie,
)

logger = logging.getLogger("jewelrunner")


def _reward(nagroda: Nagroda, element_name: str | None, booster_type: str | None) -> dict:
    return {
        "type": nagroda.typ,
        "gems": nagroda.liczba_klejnotow,
        "element_name": element_name,
        "booster_type": booster_type,
    }


def _challenge_query():
    return (
        select(Wyzwanie, Nagroda, ElementPersonalizacji.nazwa, Wzmocnienie.typ)
        .join(Nagroda, Nagroda.id == Wyzwanie.nagroda_id)
        .outerjoin(ElementPersonalizacji, ElementPersonalizacji.id == Nagroda.element_id)
        .outerjoin(Wzmocnienie, Wzmocnienie.id == Nagroda.wzmocnienie_id)
    )


def _is_available(now):
    return (
        Wyzwanie.status == "Aktywne",
        Wyzwanie.data_rozpoczecia <= now,
        Wyzwanie.data_zakonczenia > now,
    )


def _unavailable() -> AppError:
    return AppError(404, "challenge_unavailable", "Wyzwanie jest niedostępne.")


def list_active(db: Session, gracz_id: uuid.UUID) -> list[dict]:
    rows = db.execute(
        _challenge_query()
        .add_columns(UczestnictwoWWyzwaniu.status)
        .outerjoin(
            UczestnictwoWWyzwaniu,
            (UczestnictwoWWyzwaniu.wyzwanie_id == Wyzwanie.id) & (UczestnictwoWWyzwaniu.gracz_id == gracz_id),
        )
        .where(*_is_available(datetime.now(UTC)))
        .order_by(Wyzwanie.data_zakonczenia, Wyzwanie.id)
    ).all()
    return [
        {
            "id": wyzwanie.id,
            "name": wyzwanie.nazwa,
            "difficulty": wyzwanie.poziom_trudnosci,
            "reward": _reward(nagroda, element_name, booster_type),
            "ends_at": wyzwanie.data_zakonczenia,
            "participation_status": status,
        }
        for wyzwanie, nagroda, element_name, booster_type, status in rows
    ]

