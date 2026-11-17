import logging
import uuid
from datetime import UTC, datetime

from sqlalchemy import select, update
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import (
    ElementPersonalizacji,
    Gracz,
    Nagroda,
    PortfelGracza,
    PosiadaneWzmocnienie,
    PosiadanyElement,
    Poziom,
    PostepPoziomu,
    ProbaWyzwania,
    Transakcja,
    UczestnictwoWWyzwaniu,
    Wyzwanie,
    Wzmocnienie,
)

logger = logging.getLogger("jewelrunner")
DUPLICATE_ELEMENT_GEMS = 100


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


def get_details(db: Session, challenge_id: int, gracz_id: uuid.UUID) -> dict:
    row = db.execute(
        _challenge_query()
        .add_columns(Poziom.nazwa)
        .join(Poziom, Poziom.id == Wyzwanie.poziom_id)
        .where(Wyzwanie.id == challenge_id, *_is_available(datetime.now(UTC)))
    ).first()
    if row is None:
        raise _unavailable()
    wyzwanie, nagroda, element_name, booster_type, level = row
    participation = db.scalar(
        select(UczestnictwoWWyzwaniu).where(
            UczestnictwoWWyzwaniu.wyzwanie_id == challenge_id, UczestnictwoWWyzwaniu.gracz_id == gracz_id
        )
    )
    return {
        "id": wyzwanie.id,
        "name": wyzwanie.nazwa,
        "description": wyzwanie.opis,
        "difficulty": wyzwanie.poziom_trudnosci,
        "level": level,
        "completion_conditions": wyzwanie.warunki_ukonczenia,
        "reward": _reward(nagroda, element_name, booster_type),
        "starts_at": wyzwanie.data_rozpoczecia,
        "ends_at": wyzwanie.data_zakonczenia,
        "participation": participation
        and {"status": participation.status, "progress_percent": participation.postep_procent},
        "reward_status": participation.status_nagrody if participation else None,
    }


def _level_unlocked(db: Session, gracz_id: uuid.UUID, order: int) -> bool:
    poziom = db.scalar(select(Poziom).where(Poziom.kolejnosc == order))
    if poziom is None:
        return False
    if poziom.warunek_odblokowania is None:
        return True
    return bool(
        db.scalar(
            select(PostepPoziomu.czy_odblokowany).where(
                PostepPoziomu.gracz_id == gracz_id, PostepPoziomu.poziom_id == poziom.id
            )
        )
    )


def _check_requirements(db: Session, gracz_id: uuid.UUID, requirements: dict) -> None:
    for key, value in requirements.items():
        if key == "poziom_odblokowany":
            met = _level_unlocked(db, gracz_id, value)
        else:
            # Nieznany warunek odrzucamy, żeby nie przepuścić gracza przez błąd w danych.
            logger.error("Nieznany warunek udziału w wyzwaniu: %s", key)
            met = False
        if not met:
            raise AppError(
                409,
                "participation_requirements_not_met",
                "Nie spełniasz warunków udziału w tym wyzwaniu.",
                {key: value},
            )


def accept(db: Session, challenge_id: int, gracz_id: uuid.UUID) -> tuple[dict, bool]:
    """Zwraca dane uczestnictwa oraz informację, czy powstało nowe."""
    wyzwanie = db.scalar(select(Wyzwanie).where(Wyzwanie.id == challenge_id, *_is_available(datetime.now(UTC))))
    if wyzwanie is None:
        raise _unavailable()

    query = select(UczestnictwoWWyzwaniu).where(
        UczestnictwoWWyzwaniu.wyzwanie_id == challenge_id, UczestnictwoWWyzwaniu.gracz_id == gracz_id
    )
    created = False
    participation = db.scalar(query)
    if participation is None:
        _check_requirements(db, gracz_id, wyzwanie.warunki_udzialu)
        # ON CONFLICT obsługuje dwa równoczesne kliknięcia bez błędu.
        result = db.execute(
            insert(UczestnictwoWWyzwaniu)
            .values(gracz_id=gracz_id, wyzwanie_id=challenge_id)
            .on_conflict_do_nothing(index_elements=["gracz_id", "wyzwanie_id"])
            .returning(UczestnictwoWWyzwaniu.id)
        )
        created = result.scalar() is not None
        db.commit()
        participation = db.scalar(query)
    return (
        {
            "status": participation.status,
            "accepted_at": participation.data_przyjecia,
            "completion_conditions": wyzwanie.warunki_ukonczenia,
        },
        created,
    )


def list_mine(db: Session, gracz_id: uuid.UUID) -> list[dict]:
    expired = select(Wyzwanie.id).where(Wyzwanie.data_zakonczenia <= datetime.now(UTC))
    db.execute(
        update(UczestnictwoWWyzwaniu)
        .where(
            UczestnictwoWWyzwaniu.gracz_id == gracz_id,
            UczestnictwoWWyzwaniu.status == "Aktywne",
            UczestnictwoWWyzwaniu.wyzwanie_id.in_(expired),
        )
        .values(status="Wygasłe")
    )
    db.commit()
    rows = db.execute(
        select(UczestnictwoWWyzwaniu, Wyzwanie, Nagroda, ElementPersonalizacji.nazwa, Wzmocnienie.typ)
        .join(Wyzwanie, Wyzwanie.id == UczestnictwoWWyzwaniu.wyzwanie_id)
        .join(Nagroda, Nagroda.id == Wyzwanie.nagroda_id)
        .outerjoin(ElementPersonalizacji, ElementPersonalizacji.id == Nagroda.element_id)
        .outerjoin(Wzmocnienie, Wzmocnienie.id == Nagroda.wzmocnienie_id)
        .where(UczestnictwoWWyzwaniu.gracz_id == gracz_id)
        .order_by(UczestnictwoWWyzwaniu.data_przyjecia.desc(), UczestnictwoWWyzwaniu.id.desc())
    ).all()
    return [
        {
            "challenge_id": wyzwanie.id,
            "name": wyzwanie.nazwa,
            "status": participation.status,
            "progress_percent": participation.postep_procent,
            "ends_at": wyzwanie.data_zakonczenia,
            "best_score": participation.najlepszy_wynik,
            "reward_status": participation.status_nagrody,
            "reward": _reward(nagroda, element_name, booster_type),
        }
        for participation, wyzwanie, nagroda, element_name, booster_type in rows
    ]


def claim_reward(db: Session, challenge_id: int, gracz: Gracz) -> dict:
    """Wypłaca nagrodę za ukończone wyzwanie (status_nagrody = 'Do odebrania') w jednej transakcji."""
    participation = db.scalar(
        select(UczestnictwoWWyzwaniu)
        .where(UczestnictwoWWyzwaniu.wyzwanie_id == challenge_id, UczestnictwoWWyzwaniu.gracz_id == gracz.id)
        .with_for_update()
    )
    if participation is None:
        raise AppError(404, "not_found", "Nie znaleziono uczestnictwa w tym wyzwaniu.")
    if participation.status_nagrody == "Odebrana":
        db.rollback()
        raise AppError(409, "reward_already_claimed", "Nagroda za to wyzwanie została już odebrana.")
    if participation.status_nagrody != "Do odebrania":
        db.rollback()
        raise AppError(409, "reward_not_available", "Nagroda nie jest gotowa do odebrania.")

    row = db.execute(_challenge_query().where(Wyzwanie.id == challenge_id)).first()
    if row is None:
        db.rollback()
        raise AppError(404, "not_found", "Nie znaleziono wyzwania.")
    _, nagroda, element_name, booster_type = row

    wallet = db.scalar(select(PortfelGracza).where(PortfelGracza.gracz_id == gracz.id).with_for_update())
    if wallet is None:
        db.rollback()
        raise RuntimeError(f"Gracz {gracz.id} nie ma portfela.")

    gems_awarded = 0
    converted_to_gems = False
    if nagroda.typ == "klejnoty":
        gems_awarded = nagroda.liczba_klejnotow or 0
        wallet.liczba_klejnotow += gems_awarded
    elif nagroda.typ in ("skórka", "kolor", "akcesorium"):
        inserted = db.scalar(
            insert(PosiadanyElement)
            .values(gracz_id=gracz.id, element_id=nagroda.element_id)
            .on_conflict_do_nothing(index_elements=["gracz_id", "element_id"])
            .returning(PosiadanyElement.element_id)
        )
        if inserted is None:
            gems_awarded = DUPLICATE_ELEMENT_GEMS
            wallet.liczba_klejnotow += gems_awarded
            converted_to_gems = True
    elif nagroda.typ == "wzmocnienie":
        db.execute(
            insert(PosiadaneWzmocnienie)
            .values(gracz_id=gracz.id, wzmocnienie_id=nagroda.wzmocnienie_id, liczba=1)
            .on_conflict_do_update(
                index_elements=["gracz_id", "wzmocnienie_id"],
                set_={"liczba": PosiadaneWzmocnienie.liczba + 1},
            )
        )

    participation.status_nagrody = "Odebrana"
    participation.data_odebrania_nagrody = datetime.now(UTC)
    db.add(
        Transakcja(
            gracz_id=gracz.id,
            typ="odbiór nagrody",
            kwota_klejnotow=gems_awarded,
            wzmocnienie_id=nagroda.wzmocnienie_id,
            uczestnictwo_id=participation.id,
            klucz_idempotencji=f"challenge_reward:{participation.id}",
        )
    )
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise AppError(409, "reward_already_claimed", "Nagroda za to wyzwanie została już odebrana.") from exc

    return {
        "challenge_id": challenge_id,
        "reward_status": "Odebrana",
        "reward": _reward(nagroda, element_name, booster_type),
        "gems_awarded": gems_awarded,
        "converted_to_gems": converted_to_gems,
        "balance": wallet.liczba_klejnotow,
    }


def attempts(db: Session, challenge_id: int, gracz: Gracz) -> dict:
    participation = db.scalar(
        select(UczestnictwoWWyzwaniu).where(
            UczestnictwoWWyzwaniu.wyzwanie_id == challenge_id, UczestnictwoWWyzwaniu.gracz_id == gracz.id
        )
    )
    if participation is None:
        raise AppError(404, "not_found", "Nie znaleziono uczestnictwa w tym wyzwaniu.")
    rows = db.scalars(
        select(ProbaWyzwania)
        .where(ProbaWyzwania.uczestnictwo_id == participation.id)
        .order_by(ProbaWyzwania.data_proby.desc(), ProbaWyzwania.id.desc())
    ).all()
    return {
        "best_score": participation.najlepszy_wynik,
        "items": [{"score": r.wynik, "attempted_at": r.data_proby, "passed": r.czy_zaliczona} for r in rows],
    }
