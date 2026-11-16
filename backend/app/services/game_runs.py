"""Wyniki z gry (4.3, 2.3, 2.4, 8.4): gra wysyła wynik po mecie albo po porażce.

W jednej transakcji serwer:
1. zapisuje rozegranie w ukonczenie_poziomu (to samo session_id drugi raz niczego nie zmienia),
2. aktualizuje postęp poziomu: liczba prób, najlepszy wynik i czas,
3. odblokowuje następny poziom po ukończeniu,
4. aktualizuje statystyki gracza,
5. przelicza ranking za tydzień, miesiąc i ogółem: suma najlepszych wyników z poziomów w danym okresie,
6. zapisuje próbę w aktywnych wyzwaniach tego poziomu i przelicza ich postęp.
"""
import logging
import math
from decimal import Decimal

from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.db.models import Gracz, Poziom
from app.schemas.game import RunRequest
from app.services import appearance

logger = logging.getLogger("jewelrunner")

PERIODS = ("tydzień", "miesiąc", "ogółem")


def _level(db: Session, order: int) -> Poziom:
    poziom = db.scalar(select(Poziom).where(Poziom.kolejnosc == order))
    if poziom is None:
        raise AppError(422, "unknown_level", "Nie ma takiego poziomu.")
    return poziom


def _is_unlocked(db: Session, gracz: Gracz, poziom: Poziom) -> bool:
    if poziom.warunek_odblokowania is None:
        return True
    return bool(
        db.scalar(
            text("SELECT czy_odblokowany FROM postep_poziomu WHERE gracz_id = :g AND poziom_id = :p"),
            {"g": gracz.id, "p": poziom.id},
        )
    )


def _unlock_next(db: Session, gracz: Gracz, poziom: Poziom, score: int) -> list[int]:
    """Po ukończeniu odblokowuje następny poziom. Warunek {"min_wynik": N} wymaga wyniku N na tym poziomie."""
    nxt = db.scalar(select(Poziom).where(Poziom.kolejnosc > poziom.kolejnosc).order_by(Poziom.kolejnosc).limit(1))
    if nxt is None:
        return []
    condition = nxt.warunek_odblokowania or {}
    if score < int(condition.get("min_wynik", 0)):
        return []
    newly = db.scalar(
        text(
            """
            INSERT INTO postep_poziomu (gracz_id, poziom_id, czy_odblokowany) VALUES (:g, :p, TRUE)
            ON CONFLICT (gracz_id, poziom_id) DO UPDATE SET czy_odblokowany = TRUE
                WHERE postep_poziomu.czy_odblokowany = FALSE
            RETURNING poziom_id
            """
        ),
        {"g": gracz.id, "p": nxt.id},
    )
    return [nxt.kolejnosc] if newly is not None else []


def _update_ranking(db: Session, gracz: Gracz) -> None:
    """Wynik w rankingu = suma najlepszych wyników z poziomów ukończonych w okresie. Wynik nigdy nie spada."""
    db.execute(
        text(
            """
            WITH teraz AS (SELECT (now() AT TIME ZONE :tz)::date AS dzien),
            okresy AS (
                SELECT 'tydzień' AS okres, date_trunc('week', dzien)::date AS poczatek FROM teraz
                UNION ALL SELECT 'miesiąc', date_trunc('month', dzien)::date FROM teraz
                UNION ALL SELECT 'ogółem', DATE '1970-01-01'
            ),
            wyniki AS (
                SELECT o.okres, o.poczatek, COALESCE(sum(n.najlepszy), 0) AS wynik
                FROM okresy o
                LEFT JOIN LATERAL (
                    SELECT max(u.wynik) AS najlepszy
                    FROM ukonczenie_poziomu u
                    WHERE u.gracz_id = :g AND u.czy_ukonczony
                      AND (u.data_ukonczenia AT TIME ZONE :tz)::date >= o.poczatek
                    GROUP BY u.poziom_id
                ) n ON TRUE
                GROUP BY o.okres, o.poczatek
            )
            INSERT INTO wpis_rankingu (gracz_id, okres, poczatek_okresu, wynik, data_uzyskania_wyniku)
            SELECT :g, okres, poczatek, wynik, now() FROM wyniki WHERE wynik > 0
            ON CONFLICT (gracz_id, okres, poczatek_okresu) DO UPDATE
                SET wynik = EXCLUDED.wynik, data_uzyskania_wyniku = EXCLUDED.data_uzyskania_wyniku
                WHERE wpis_rankingu.wynik < EXCLUDED.wynik
            """
        ),
        {"g": gracz.id, "tz": get_settings().game_timezone},
    )


def _condition_met(key: str, value, run: RunRequest) -> bool:
    if key == "ukoncz_poziom":
        return run.completed or not value
    if key == "min_klejnotow":
        return run.gems >= int(value)
    if key == "min_wynik":
        return run.score >= int(value)
    if key == "max_czas_s":
        return run.completed and run.time_s <= float(value)
    logger.error("Nieznany warunek ukończenia wyzwania: %s", key)
    return False


def _evaluate_challenges(db: Session, gracz: Gracz, poziom: Poziom, run: RunRequest) -> dict[int, bool]:
    """Próba w każdym aktywnym wyzwaniu tego poziomu. Zwraca {id wyzwania: czy zaliczona}."""
    rows = db.execute(
        text(
            """
            SELECT u.id, u.wyzwanie_id, u.postep_procent, w.warunki_ukonczenia
            FROM uczestnictwo_w_wyzwaniu u
            JOIN wyzwanie w ON w.id = u.wyzwanie_id
            WHERE u.gracz_id = :g AND u.status = 'Aktywne' AND w.poziom_id = :p
              AND w.status = 'Aktywne' AND w.data_rozpoczecia <= now() AND w.data_zakonczenia > now()
            FOR UPDATE OF u
            """
        ),
        {"g": gracz.id, "p": poziom.id},
    ).all()
    results = {}
    for row in rows:
        conditions = row.warunki_ukonczenia or {}
        met = [_condition_met(key, value, run) for key, value in conditions.items()]
        # Wyzwanie zalicza tylko ukończony poziom, w którym spełniono wszystkie warunki.
        passed = run.completed and all(met)
        if passed:
            progress = 100
        else:
            # Część spełnionych warunków; 100% tylko po zaliczeniu.
            progress = min(99, math.floor(100 * sum(met) / len(met))) if met else 0
        db.execute(
            text("INSERT INTO proba_wyzwania (uczestnictwo_id, wynik, czy_zaliczona) VALUES (:u, :w, :z)"),
            {"u": row.id, "w": run.score, "z": passed},
        )
        db.execute(
            text(
                """
                UPDATE uczestnictwo_w_wyzwaniu SET
                    najlepszy_wynik = GREATEST(COALESCE(najlepszy_wynik, 0), :w),
                    postep_procent = GREATEST(postep_procent, :p),
                    status = CASE WHEN :z THEN 'Ukończone' ELSE status END,
                    status_nagrody = CASE WHEN :z THEN 'Do odebrania' ELSE status_nagrody END
                WHERE id = :u
                """
            ),
            {"u": row.id, "w": run.score, "p": progress, "z": passed},
        )
        results[row.wyzwanie_id] = passed
    return results


def _summary(db: Session, gracz: Gracz, poziom: Poziom, run: RunRequest, duplicate: bool, new_best: bool,
             unlocked: list[int], passed: dict[int, bool]) -> dict:
    progress = db.execute(
        text(
            "SELECT najlepszy_wynik, najlepszy_czas_s, liczba_prob FROM postep_poziomu"
            " WHERE gracz_id = :g AND poziom_id = :p"
        ),
        {"g": gracz.id, "p": poziom.id},
    ).first()
    ranking = {
        row.okres: {"position": row.pozycja, "score": row.wynik}
        for row in db.execute(
            text(
                """
                SELECT r.okres, r.pozycja, r.wynik FROM v_ranking r
                WHERE r.gracz_id = :g AND (r.okres = 'ogółem'
                   OR r.poczatek_okresu = CASE r.okres
                        WHEN 'tydzień' THEN date_trunc('week', (now() AT TIME ZONE :tz))::date
                        ELSE date_trunc('month', (now() AT TIME ZONE :tz))::date END)
                """
            ),
            {"g": gracz.id, "tz": get_settings().game_timezone},
        )
    }
    challenges = [
        {
            "challenge_id": row.wyzwanie_id,
            "name": row.nazwa,
            "passed": passed.get(row.wyzwanie_id) if not duplicate else None,
            "progress_percent": row.postep_procent,
            "status": row.status,
            "reward_status": row.status_nagrody,
        }
        for row in db.execute(
            text(
                """
                SELECT u.wyzwanie_id, w.nazwa, u.postep_procent, u.status, u.status_nagrody
                FROM uczestnictwo_w_wyzwaniu u JOIN wyzwanie w ON w.id = u.wyzwanie_id
                WHERE u.gracz_id = :g AND w.poziom_id = :p ORDER BY u.wyzwanie_id
                """
            ),
            {"g": gracz.id, "p": poziom.id},
        )
    ]
    best_time = progress.najlepszy_czas_s if progress else None
    return {
        "duplicate": duplicate,
        "level": poziom.kolejnosc,
        "completed": run.completed,
        "best_score": progress.najlepszy_wynik if progress else None,
        "best_time_s": float(best_time) if isinstance(best_time, Decimal) else best_time,
        "attempts": progress.liczba_prob if progress else 0,
        "new_best": new_best,
        "unlocked_levels": unlocked,
        "ranking": {period: ranking.get(period) for period in PERIODS},
        "challenges": challenges,
    }


def record_run(db: Session, gracz: Gracz, run: RunRequest) -> dict:
    poziom = _level(db, run.level)
    # Jeden wynik gracza na raz: blokada wiersza gracza porządkuje równoczesne wysyłki.
    db.execute(select(Gracz.id).where(Gracz.id == gracz.id).with_for_update())
    if not _is_unlocked(db, gracz, poziom):
        db.rollback()
        raise AppError(409, "level_locked", "Ten poziom nie jest jeszcze odblokowany.")

    time_s = round(run.time_s, 1)
    inserted = db.scalar(
        text(
            """
            INSERT INTO ukonczenie_poziomu (gracz_id, poziom_id, identyfikator_sesji_gry, wynik, czas_s,
                liczba_klejnotow, czy_ukonczony, liczba_pokonanych_wrogow)
            VALUES (:g, :p, :s, :w, :c, :k, :u, :e)
            ON CONFLICT (gracz_id, identyfikator_sesji_gry) DO NOTHING
            RETURNING id
            """
        ),
        {"g": gracz.id, "p": poziom.id, "s": run.session_id, "w": run.score, "c": time_s, "k": run.gems,
         "u": run.completed, "e": run.enemies_defeated},
    )
    if inserted is None:
        # Gra wysłała ten sam wynik drugi raz (np. po zerwanym połączeniu): nic nie liczymy ponownie.
        db.rollback()
        return {**_summary(db, gracz, poziom, run, duplicate=True, new_best=False, unlocked=[], passed={}),
                "unlocked_items": []}

    previous = db.execute(
        text("SELECT najlepszy_wynik FROM postep_poziomu WHERE gracz_id = :g AND poziom_id = :p"),
        {"g": gracz.id, "p": poziom.id},
    ).first()
    first_completion = run.completed and (previous is None or previous.najlepszy_wynik is None)
    new_best = run.completed and (previous is None or previous.najlepszy_wynik is None
                                  or run.score > previous.najlepszy_wynik)

    db.execute(
        text(
            """
            INSERT INTO postep_poziomu (gracz_id, poziom_id, czy_odblokowany, najlepszy_wynik, najlepszy_czas_s, liczba_prob)
            VALUES (:g, :p, TRUE, CASE WHEN :u THEN :w END, CASE WHEN :u THEN :c END, 1)
            ON CONFLICT (gracz_id, poziom_id) DO UPDATE SET
                czy_odblokowany = TRUE,
                liczba_prob = postep_poziomu.liczba_prob + 1,
                najlepszy_wynik = CASE WHEN :u THEN GREATEST(COALESCE(postep_poziomu.najlepszy_wynik, 0), :w)
                                       ELSE postep_poziomu.najlepszy_wynik END,
                najlepszy_czas_s = CASE WHEN :u THEN LEAST(COALESCE(postep_poziomu.najlepszy_czas_s, :c), :c)
                                        ELSE postep_poziomu.najlepszy_czas_s END
            """
        ),
        {"g": gracz.id, "p": poziom.id, "u": run.completed, "w": run.score, "c": time_s},
    )
    db.execute(
        text(
            """
            UPDATE statystyki_gracza SET
                laczny_czas_gry_s = laczny_czas_gry_s + :c,
                liczba_pokonanych_wrogow = liczba_pokonanych_wrogow + :e,
                liczba_ukonczonych_poziomow = liczba_ukonczonych_poziomow + CASE WHEN :f THEN 1 ELSE 0 END,
                liczba_porazek = liczba_porazek + CASE WHEN :u THEN 0 ELSE 1 END
            WHERE gracz_id = :g
            """
        ),
        {"g": gracz.id, "c": int(round(run.time_s)), "e": run.enemies_defeated, "f": first_completion,
         "u": run.completed},
    )
    db.execute(text("UPDATE gracz SET data_ostatniej_synchronizacji = now() WHERE id = :g"), {"g": gracz.id})

    unlocked = _unlock_next(db, gracz, poziom, run.score) if run.completed else []
    if run.completed:
        _update_ranking(db, gracz)
    passed = _evaluate_challenges(db, gracz, poziom, run)
    unlocked_items = appearance.unlock_earned(db, gracz.id)
    db.commit()
    summary = _summary(db, gracz, poziom, run, duplicate=False, new_best=new_best, unlocked=unlocked, passed=passed)
    return {**summary, "unlocked_items": unlocked_items}
