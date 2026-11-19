"""Saldo klejnotów z gry (historyjka 7.1): gra wysyła klejnoty zebrane w rozgrywce, także po powrocie internetu.

Gra trzyma operacje w lokalnej kolejce i wysyła je, gdy jest połączenie. Każda operacja ma własny
identyfikator: ponowne wysłanie tej samej operacji (np. po zerwanym połączeniu) nie dolicza klejnotów
drugi raz, bo klucz transakcji „game:<gracz>:<id>” jest unikalny w bazie.
"""
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import Gracz, PortfelGracza, Transakcja
from app.schemas.game import WalletOperation

# Ograniczenie zaufania do gry: jedna operacja to maks. 500 klejnotów (schemat), jedno żądanie maks. 2000,
# a w ciągu doby z gry można dopisać maks. 10 000 klejnotów.
MAX_GEMS_PER_REQUEST = 2_000
MAX_GEMS_PER_DAY = 10_000
GAME_KEY_PREFIX = "game:"


def balance(db: Session, gracz: Gracz) -> int:
    return db.scalar(select(PortfelGracza.liczba_klejnotow).where(PortfelGracza.gracz_id == gracz.id)) or 0


def sync(db: Session, gracz: Gracz, operations: list[WalletOperation]) -> tuple[int, list[str], list[str]]:
    if sum(op.gems for op in operations) > MAX_GEMS_PER_REQUEST:
        raise AppError(422, "too_many_gems", "Za dużo klejnotów w jednym żądaniu.")
    ids = [op.id for op in operations]
    if len(set(ids)) != len(ids):
        raise AppError(422, "duplicate_operation", "Ta sama operacja występuje dwa razy w żądaniu.")

    wallet = db.scalar(select(PortfelGracza).where(PortfelGracza.gracz_id == gracz.id).with_for_update())
    if wallet is None:
        raise RuntimeError(f"Gracz {gracz.id} nie ma portfela.")

    last_day = db.scalar(
        select(func.coalesce(func.sum(Transakcja.kwota_klejnotow), 0)).where(
            Transakcja.gracz_id == gracz.id,
            Transakcja.klucz_idempotencji.startswith(f"{GAME_KEY_PREFIX}{gracz.id}:"),
            Transakcja.data_transakcji > datetime.now(UTC) - timedelta(days=1),
        )
    )

    applied, duplicates = [], []
    for op in operations:
        inserted = db.scalar(
            insert(Transakcja)
            .values(
                gracz_id=gracz.id,
                typ="zmiana stanu konta",
                kwota_klejnotow=op.gems,
                klucz_idempotencji=f"{GAME_KEY_PREFIX}{gracz.id}:{op.id}",
            )
            .on_conflict_do_nothing(index_elements=["klucz_idempotencji"])
            .returning(Transakcja.id)
        )
        if inserted is None:
            duplicates.append(op.id)
            continue
        last_day += op.gems
        if last_day > MAX_GEMS_PER_DAY:
            db.rollback()
            raise AppError(429, "daily_gem_limit", "Przekroczono dzienny limit klejnotów z gry.")
        wallet.liczba_klejnotow += op.gems
        applied.append(op.id)
    db.commit()
    return wallet.liczba_klejnotow, applied, duplicates
