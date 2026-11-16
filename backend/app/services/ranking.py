"""Ranking (2.3, 2.7): okresy tydzień, miesiąc, ogółem oraz ranking wśród znajomych.

Wpisy rankingu zapisuje POST /api/game/runs. Ostatnio wybrany filtr jest zapamiętywany
w ustawieniach gracza i używany, gdy portal lub gra nie poda okresu.
"""
import uuid
from datetime import UTC, datetime

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services import settings_store

PERIODS = ("tydzień", "miesiąc", "ogółem", "znajomi")
ALIASES = {"week": "tydzień", "month": "miesiąc", "overall": "ogółem", "friends": "znajomi",
           "tydzien": "tydzień", "miesiac": "miesiąc", "ogolem": "ogółem"}
LIMIT = 100


def normalize(period: str | None) -> str | None:
    if period is None:
        return None
    period = period.strip().lower()
    return ALIASES.get(period, period)


def _period_start(db: Session, period: str):
    if period == "ogółem":
        return None
    unit = "week" if period == "tydzień" else "month"
    return db.scalar(
        text(f"SELECT date_trunc('{unit}', (now() AT TIME ZONE :tz))::date"), {"tz": get_settings().game_timezone}
    )


def _row(row) -> dict:
    return {"position": row.pozycja, "player_id": row.gracz_id, "username": row.nazwa_uzytkownika, "score": row.wynik}


def read(db: Session, gracz_id: uuid.UUID, period: str | None) -> dict:
    if period is None:
        period = settings_store.ranking_filter(db, gracz_id)
        if period not in PERIODS:
            period = "ogółem"
    else:
        settings_store.save_ranking_filter(db, gracz_id, period)
        db.commit()

    start = None
    if period == "znajomi":
        # Ranking ogólny zawężony do gracza i jego znajomych, z pozycjami liczonymi od nowa.
        rows = db.execute(
            text(
                """
                SELECT ROW_NUMBER() OVER (ORDER BY r.wynik DESC, r.data_uzyskania_wyniku, r.gracz_id) AS pozycja,
                       r.gracz_id, r.nazwa_uzytkownika, r.wynik
                FROM v_ranking r
                WHERE r.okres = 'ogółem'
                  AND (r.gracz_id = :g OR r.gracz_id IN (SELECT znajomy_id FROM znajomy WHERE gracz_id = :g))
                ORDER BY pozycja
                """
            ),
            {"g": gracz_id},
        ).all()
        has_friends = db.scalar(text("SELECT EXISTS (SELECT 1 FROM znajomy WHERE gracz_id = :g)"), {"g": gracz_id})
    else:
        start = _period_start(db, period)
        condition = "r.okres = :okres" + ("" if start is None else " AND r.poczatek_okresu = :start")
        rows = db.execute(
            text(
                f"SELECT r.pozycja, r.gracz_id, r.nazwa_uzytkownika, r.wynik FROM v_ranking r"
                f" WHERE {condition} ORDER BY r.pozycja"
            ),
            {"okres": period, "start": start},
        ).all()
        has_friends = True

    items = [_row(row) for row in rows[:LIMIT]]
    mine = next((row for row in rows if row.gracz_id == gracz_id), None)
    if not has_friends:
        empty_reason = "no_friends"  # 2.7 A2: zachęta „Dodaj znajomych”
    elif not rows:
        empty_reason = "no_results"  # 2.7 A1: „Brak wyników w tym okresie”
    else:
        empty_reason = None
    return {
        "period": period,
        "period_start": start,
        "items": items,
        "me": mine and {"position": mine.pozycja, "score": mine.wynik},
        "empty_reason": empty_reason,
        "generated_at": datetime.now(UTC),
    }
