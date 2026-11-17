"""Statystyki gracza (8.4) i historia gier: dane do profilu w portalu i w grze."""
import uuid
from decimal import Decimal

from sqlalchemy import text
from sqlalchemy.orm import Session


def _num(value):
    return float(value) if isinstance(value, Decimal) else value


def overview(db: Session, gracz_id: uuid.UUID) -> dict:
    stats = db.execute(
        text(
            """
            SELECT s.laczny_czas_gry_s, s.liczba_ukonczonych_poziomow, s.liczba_pokonanych_wrogow, s.liczba_porazek,
                   s.czy_samouczek_ukonczony, g.data_ostatniej_synchronizacji, p.liczba_klejnotow,
                   (SELECT count(*) FROM ukonczenie_poziomu u WHERE u.gracz_id = :g) AS liczba_rozgrywek,
                   (SELECT COALESCE(sum(u.liczba_klejnotow), 0) FROM ukonczenie_poziomu u WHERE u.gracz_id = :g)
                       AS zebrane_klejnoty
            FROM statystyki_gracza s
            JOIN gracz g ON g.id = s.gracz_id
            LEFT JOIN portfel_gracza p ON p.gracz_id = s.gracz_id
            WHERE s.gracz_id = :g
            """
        ),
        {"g": gracz_id},
    ).first()
    levels = db.execute(
        text(
            """
            SELECT p.kolejnosc, p.nazwa, p.warunek_odblokowania,
                   COALESCE(pp.czy_odblokowany, p.warunek_odblokowania IS NULL) AS odblokowany,
                   pp.najlepszy_wynik, pp.najlepszy_czas_s, COALESCE(pp.liczba_prob, 0) AS liczba_prob
            FROM poziom p
            LEFT JOIN postep_poziomu pp ON pp.poziom_id = p.id AND pp.gracz_id = :g
            ORDER BY p.kolejnosc
            """
        ),
        {"g": gracz_id},
    ).all()
    overall = {
        "play_time_s": stats.laczny_czas_gry_s if stats else 0,
        "levels_completed": stats.liczba_ukonczonych_poziomow if stats else 0,
        "enemies_defeated": stats.liczba_pokonanych_wrogow if stats else 0,
        "defeats": stats.liczba_porazek if stats else 0,
        "runs": stats.liczba_rozgrywek if stats else 0,
        "gems_collected": int(stats.zebrane_klejnoty) if stats else 0,
        "gems_balance": (stats.liczba_klejnotow or 0) if stats else 0,
        "tutorial_completed": bool(stats and stats.czy_samouczek_ukonczony),
    }
    return {
        # 8.4 A1: nowe konto ma same zera; portal pokazuje wtedy zachętę do gry.
        "has_played": overall["runs"] > 0,
        "last_synced_at": stats.data_ostatniej_synchronizacji if stats else None,
        "overall": overall,
        "levels": [
            {
                "level": row.kolejnosc,
                "name": row.nazwa,
                "unlocked": bool(row.odblokowany),
                "unlock_condition": row.warunek_odblokowania,
                "best_score": row.najlepszy_wynik,
                "best_time_s": _num(row.najlepszy_czas_s),
                "attempts": row.liczba_prob,
                "completed": row.najlepszy_wynik is not None,
            }
            for row in levels
        ],
    }


def history(db: Session, gracz_id: uuid.UUID, limit: int, before_id: int | None) -> dict:
    """Ostatnie rozegrania, od najnowszych. Kolejną stronę pobiera się z before_id = next_before_id."""
    rows = db.execute(
        text(
            """
            SELECT u.id, p.kolejnosc, p.nazwa, u.czy_ukonczony, u.wynik, u.czas_s, u.liczba_klejnotow,
                   u.liczba_pokonanych_wrogow, u.data_ukonczenia, u.identyfikator_sesji_gry
            FROM ukonczenie_poziomu u JOIN poziom p ON p.id = u.poziom_id
            WHERE u.gracz_id = :g AND (CAST(:before AS BIGINT) IS NULL OR u.id < :before)
            ORDER BY u.id DESC
            LIMIT :limit
            """
        ),
        {"g": gracz_id, "before": before_id, "limit": limit + 1},
    ).all()
    page = rows[:limit]
    return {
        "items": [
            {
                "id": row.id,
                "level": row.kolejnosc,
                "level_name": row.nazwa,
                "completed": row.czy_ukonczony,
                "score": row.wynik,
                "time_s": _num(row.czas_s),
                "gems": row.liczba_klejnotow,
                "enemies_defeated": row.liczba_pokonanych_wrogow,
                "played_at": row.data_ukonczenia,
                "session_id": row.identyfikator_sesji_gry,
            }
            for row in page
        ],
        "next_before_id": page[-1].id if len(rows) > limit else None,
    }


def complete_tutorial(db: Session, gracz_id: uuid.UUID) -> dict:
    """Zapisuje ukończenie samouczka w statystykach gracza (3.6)."""
    db.execute(
        text(
            """
            INSERT INTO statystyki_gracza (gracz_id, czy_samouczek_ukonczony)
            VALUES (:g, TRUE)
            ON CONFLICT (gracz_id) DO UPDATE SET czy_samouczek_ukonczony = TRUE
            """
        ),
        {"g": gracz_id},
    )
    db.commit()
    return {"tutorial_completed": True}
