"""Sklep ze wzmocnieniami (7.3, 6.4) oraz zużywanie posiadanych wzmocnień z gry."""
import uuid

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import (
    Gracz,
    OfertaSklepu,
    PortfelGracza,
    PosiadaneWzmocnienie,
    Transakcja,
    Wzmocnienie,
)

SHOP_KEY_PREFIX = "shop:"
BOOSTER_USE_KEY_PREFIX = "booster_use:"


def owned_boosters_map(db: Session, gracz_id: uuid.UUID) -> dict[str, int]:
    """Zwraca mapę typ wzmocnienia -> posiadana liczba sztuk (0 gdy gracz nie ma wiersza)."""
    rows = db.execute(
        select(Wzmocnienie.typ, PosiadaneWzmocnienie.liczba)
        .outerjoin(
            PosiadaneWzmocnienie,
            (PosiadaneWzmocnienie.wzmocnienie_id == Wzmocnienie.id) & (PosiadaneWzmocnienie.gracz_id == gracz_id),
        )
        .order_by(Wzmocnienie.id)
    ).all()
    return {typ: (liczba or 0) for typ, liczba in rows}


def list_shop(db: Session, gracz: Gracz) -> dict:
    wallet = db.get(PortfelGracza, gracz.id)
    balance = wallet.liczba_klejnotow if wallet else 0
    rows = db.execute(
        select(Wzmocnienie, OfertaSklepu, PosiadaneWzmocnienie.liczba)
        .join(OfertaSklepu, OfertaSklepu.wzmocnienie_id == Wzmocnienie.id)
        .outerjoin(
            PosiadaneWzmocnienie,
            (PosiadaneWzmocnienie.wzmocnienie_id == Wzmocnienie.id) & (PosiadaneWzmocnienie.gracz_id == gracz.id),
        )
        .where(OfertaSklepu.dostepnosc.is_(True))
        .order_by(Wzmocnienie.id)
    ).all()
    return {
        "balance": balance,
        "items": [
            {
                "booster_id": booster.id,
                "type": booster.typ,
                "effect": booster.efekt,
                "duration_s": booster.czas_trwania_s,
                "price": offer.cena_w_klejnotach,
                "owned": owned or 0,
            }
            for booster, offer, owned in rows
        ],
    }


def _owned_count(db: Session, gracz_id: uuid.UUID, booster_id: int) -> int:
    return (
        db.scalar(
            select(PosiadaneWzmocnienie.liczba).where(
                PosiadaneWzmocnienie.gracz_id == gracz_id,
                PosiadaneWzmocnienie.wzmocnienie_id == booster_id,
            )
        )
        or 0
    )


def purchase(db: Session, gracz: Gracz, booster_id: int, idempotency_key: str) -> dict:
    """Kupuje jedną sztukę wzmocnienia w jednej transakcji (blokada portfela + klucz idempotencji)."""
    wallet = db.scalar(select(PortfelGracza).where(PortfelGracza.gracz_id == gracz.id).with_for_update())
    if wallet is None:
        db.rollback()
        raise RuntimeError(f"Gracz {gracz.id} nie ma portfela.")

    row = db.execute(
        select(Wzmocnienie, OfertaSklepu)
        .join(OfertaSklepu, OfertaSklepu.wzmocnienie_id == Wzmocnienie.id)
        .where(Wzmocnienie.id == booster_id)
    ).first()
    if row is None or not row[1].dostepnosc:
        db.rollback()
        raise AppError(404, "offer_unavailable", "To wzmocnienie nie jest obecnie dostępne w sklepie.")
    booster, offer = row

    db_key = f"{SHOP_KEY_PREFIX}{gracz.id}:{idempotency_key}"
    existing = db.scalar(select(Transakcja.id).where(Transakcja.klucz_idempotencji == db_key))
    if existing is not None:
        owned = _owned_count(db, gracz.id, booster.id)
        current_balance = wallet.liczba_klejnotow
        db.rollback()
        return {
            "booster_id": booster.id,
            "type": booster.typ,
            "price": offer.cena_w_klejnotach,
            "balance": current_balance,
            "owned": owned,
            "duplicate": True,
        }

    price = offer.cena_w_klejnotach
    if wallet.liczba_klejnotow < price:
        missing = price - wallet.liczba_klejnotow
        current_balance = wallet.liczba_klejnotow
        db.rollback()
        raise AppError(
            409,
            "insufficient_gems",
            f"Brakuje {missing} klejnotów.",
            {"missing_gems": missing, "balance": current_balance, "price": price},
        )

    try:
        inserted = db.scalar(
            insert(Transakcja)
            .values(
                gracz_id=gracz.id,
                typ="zakup w sklepie",
                kwota_klejnotow=-price,
                wzmocnienie_id=booster.id,
                klucz_idempotencji=db_key,
            )
            .on_conflict_do_nothing(index_elements=["klucz_idempotencji"])
            .returning(Transakcja.id)
        )
        if inserted is None:
            owned = _owned_count(db, gracz.id, booster.id)
            current_balance = wallet.liczba_klejnotow
            db.rollback()
            return {
                "booster_id": booster.id,
                "type": booster.typ,
                "price": price,
                "balance": current_balance,
                "owned": owned,
                "duplicate": True,
            }

        wallet.liczba_klejnotow -= price
        new_owned = db.scalar(
            insert(PosiadaneWzmocnienie)
            .values(gracz_id=gracz.id, wzmocnienie_id=booster.id, liczba=1)
            .on_conflict_do_update(
                index_elements=["gracz_id", "wzmocnienie_id"],
                set_={"liczba": PosiadaneWzmocnienie.liczba + 1},
            )
            .returning(PosiadaneWzmocnienie.liczba)
        )
        db.commit()
    except Exception:
        db.rollback()
        raise

    return {
        "booster_id": booster.id,
        "type": booster.typ,
        "price": price,
        "balance": wallet.liczba_klejnotow,
        "owned": new_owned,
        "duplicate": False,
    }


def use_booster(db: Session, gracz: Gracz, booster_type: str, operation_id: str) -> dict:
    """Zużywa jedną sztukę wzmocnienia z gry. Idempotentne po operation_id."""
    booster = db.scalar(select(Wzmocnienie).where(Wzmocnienie.typ == booster_type))
    if booster is None:
        raise AppError(422, "unknown_booster", "Nieznany typ wzmocnienia.")

    db.execute(
        insert(PosiadaneWzmocnienie)
        .values(gracz_id=gracz.id, wzmocnienie_id=booster.id, liczba=0)
        .on_conflict_do_nothing(index_elements=["gracz_id", "wzmocnienie_id"])
    )
    owned = db.scalar(
        select(PosiadaneWzmocnienie)
        .where(
            PosiadaneWzmocnienie.gracz_id == gracz.id,
            PosiadaneWzmocnienie.wzmocnienie_id == booster.id,
        )
        .with_for_update()
    )

    db_key = f"{BOOSTER_USE_KEY_PREFIX}{gracz.id}:{operation_id}"
    existing = db.scalar(select(Transakcja.id).where(Transakcja.klucz_idempotencji == db_key))
    if existing is not None:
        remaining = owned.liczba if owned else 0
        db.rollback()
        return {"booster_type": booster.typ, "remaining": remaining, "duplicate": True}

    if owned is None or owned.liczba < 1:
        db.rollback()
        raise AppError(409, "booster_not_owned", "Nie posiadasz tego wzmocnienia.")

    try:
        inserted = db.scalar(
            insert(Transakcja)
            .values(
                gracz_id=gracz.id,
                typ="zmiana stanu konta",
                kwota_klejnotow=0,
                wzmocnienie_id=booster.id,
                klucz_idempotencji=db_key,
            )
            .on_conflict_do_nothing(index_elements=["klucz_idempotencji"])
            .returning(Transakcja.id)
        )
        if inserted is None:
            remaining = owned.liczba
            db.rollback()
            return {"booster_type": booster.typ, "remaining": remaining, "duplicate": True}

        owned.liczba -= 1
        remaining = owned.liczba
        db.commit()
    except Exception:
        db.rollback()
        raise

    return {"booster_type": booster.typ, "remaining": remaining, "duplicate": False}
