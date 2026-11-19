"""Zapis gry w chmurze (historyjka 8.2): ostatni stan gracza, żeby mógł grać na innym komputerze.

- Suma kontrolna: SHA-256 z „level|checkpoint|gems|saved_at|game_version”. Zapis z błędną sumą
  jest odrzucany (A3), a przy odczycie uszkodzony wiersz jest pomijany i gra dostaje poprzedni poprawny.
- Konflikt (A2): wygrywa późniejszy zapis. Starszy zapis z gry dostaje 409 z zapisem z serwera,
  chyba że gracz świadomie wybrał swój (force=true).
- Serwer trzyma kilka ostatnich zapisów gracza.
"""
import hashlib
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import Gracz, Poziom, ZapisGry
from app.schemas.game import SaveRequest

KEEP_SAVES = 5
MAX_CLOCK_SKEW = timedelta(minutes=5)


def checksum(level: int, checkpoint: str | None, gems: int, saved_at: int, game_version: str) -> str:
    text = f"{level}|{checkpoint or ''}|{gems}|{saved_at}|{game_version}"
    return hashlib.sha256(text.encode()).hexdigest()


def _as_dict(zapis: ZapisGry, poziom: Poziom) -> dict:
    saved_at = int(zapis.data_zapisu.timestamp())
    return {
        "level": poziom.kolejnosc,
        "level_name": poziom.nazwa,
        "checkpoint": zapis.punkt_kontrolny,
        "gems": zapis.zebrane_klejnoty,
        "saved_at": saved_at,
        "saved_at_iso": zapis.data_zapisu,
        "game_version": zapis.wersja_gry,
        "checksum": zapis.suma_kontrolna,
    }


def _is_valid(zapis: ZapisGry, poziom: Poziom) -> bool:
    expected = checksum(
        poziom.kolejnosc, zapis.punkt_kontrolny, zapis.zebrane_klejnoty,
        int(zapis.data_zapisu.timestamp()), zapis.wersja_gry,
    )
    return zapis.suma_kontrolna.lower() == expected


def latest_valid(db: Session, gracz: Gracz) -> dict | None:
    """Najnowszy poprawny zapis; uszkodzone są pomijane."""
    rows = db.execute(
        select(ZapisGry, Poziom)
        .join(Poziom, Poziom.id == ZapisGry.poziom_id)
        .where(ZapisGry.gracz_id == gracz.id)
        .order_by(ZapisGry.data_zapisu.desc(), ZapisGry.id.desc())
    ).all()
    for zapis, poziom in rows:
        if _is_valid(zapis, poziom):
            return _as_dict(zapis, poziom)
    return None


def store(db: Session, gracz: Gracz, data: SaveRequest, force: bool = False) -> dict:
    if data.checksum.lower() != checksum(data.level, data.checkpoint, data.gems, data.saved_at, data.game_version):
        raise AppError(422, "corrupted_save", "Zapis jest uszkodzony (niezgodna suma kontrolna) i nie został zapisany.")

    saved_at = datetime.fromtimestamp(data.saved_at, UTC)
    if saved_at > datetime.now(UTC) + MAX_CLOCK_SKEW:
        raise AppError(422, "invalid_save_time", "Data zapisu jest z przyszłości. Sprawdź zegar komputera.")

    poziom = db.scalar(select(Poziom).where(Poziom.kolejnosc == data.level))
    if poziom is None:
        raise AppError(422, "unknown_level", "Nie ma takiego poziomu.")

    # Blokada wiersza gracza: dwa równoczesne zapisy z dwóch komputerów są rozpatrywane po kolei.
    db.execute(select(Gracz.id).where(Gracz.id == gracz.id).with_for_update())
    current = latest_valid(db, gracz)
    if current and not force:
        if current["saved_at"] > data.saved_at:
            db.rollback()
            raise AppError(
                409, "save_conflict",
                "Na serwerze jest nowszy zapis. Wczytaj go albo nadpisz go swoim zapisem.",
                {"server_save": {**current, "saved_at_iso": current["saved_at_iso"].isoformat()}},
            )
        if current["saved_at"] == data.saved_at and current["checksum"] == data.checksum.lower():
            db.rollback()
            return current  # ten sam zapis wysłany ponownie, np. po zerwanym połączeniu

    zapis = ZapisGry(
        gracz_id=gracz.id,
        poziom_id=poziom.id,
        punkt_kontrolny=data.checkpoint,
        zebrane_klejnoty=data.gems,
        data_zapisu=saved_at,
        wersja_gry=data.game_version,
        suma_kontrolna=data.checksum.lower(),
    )
    db.add(zapis)
    db.flush()

    keep = select(ZapisGry.id).where(ZapisGry.gracz_id == gracz.id).order_by(
        ZapisGry.data_zapisu.desc(), ZapisGry.id.desc()
    ).limit(KEEP_SAVES)
    db.execute(delete(ZapisGry).where(ZapisGry.gracz_id == gracz.id, ZapisGry.id.not_in(keep)))
    db.commit()
    return _as_dict(zapis, poziom)
