"""Nagroda dzienna (historyjka 7.5): klejnoty za codzienną grę i seria dni z rzędu.

Dzień ustala serwer (strefa z ustawienia GAME_TIMEZONE), nie zegar gracza, więc zmiana
daty na komputerze nic nie daje. Odbiór jest możliwy raz dziennie: pilnuje tego blokada
wiersza i unikalny klucz transakcji „daily:<gracz>:<data>”.
"""
from dataclasses import dataclass
from datetime import date, timedelta

from sqlalchemy import select, text
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.db.models import Gracz, NagrodaDzienna, PortfelGracza, Transakcja

# Tabela nagród: klejnoty za kolejny dzień serii. Dzień 7 to nagroda specjalna, po nim seria zaczyna się od nowa.
REWARDS = {1: 10, 2: 15, 3: 20, 4: 25, 5: 30, 6: 40, 7: 100}
STREAK_LENGTH = 7
SPECIAL_DAY = 7


@dataclass
class DailyState:
    today: date
    available: bool
    streak_day: int  # dzień serii, który gracz dostanie dziś (albo już dostał)
    gems: int
    last_claimed: date | None


def today(db: Session) -> date:
    """Data według zegara bazy w strefie gry; ten sam zegar dla wszystkich instancji API."""
    return db.scalar(text("SELECT (now() AT TIME ZONE :tz)::date"), {"tz": get_settings().game_timezone})


def next_streak_day(last: date | None, streak: int, current: date) -> int:
    """Dzień serii przy odbiorze w dniu `current`."""
    if last is None or current - last > timedelta(days=1):
        return 1  # pierwsza nagroda albo przerwa dłuższa niż jeden dzień (A2)
    if streak >= STREAK_LENGTH:
        return 1  # po nagrodzie specjalnej seria zaczyna się od nowa (A3)
    return streak + 1


def _state(row: NagrodaDzienna | None, current: date) -> DailyState:
    last = row.data_ostatniej_nagrody if row else None
    streak = row.dlugosc_serii if row else 0
    if last is not None and last >= current:
        # Już odebrana dziś (A1). Data z przyszłości (np. po zmianie strefy) też blokuje odbiór.
        return DailyState(current, False, streak, REWARDS.get(streak, 0), last)
    day = next_streak_day(last, streak, current)
    return DailyState(current, True, day, REWARDS[day], last)


def get_state(db: Session, gracz: Gracz) -> DailyState:
    return _state(db.get(NagrodaDzienna, gracz.id), today(db))


def claim(db: Session, gracz: Gracz) -> tuple[DailyState, int]:
    """Przyznaje dzisiejszą nagrodę. Zwraca stan po odbiorze i nowe saldo."""
    current = today(db)
    db.execute(insert(NagrodaDzienna).values(gracz_id=gracz.id).on_conflict_do_nothing())
    row = db.scalar(select(NagrodaDzienna).where(NagrodaDzienna.gracz_id == gracz.id).with_for_update())
    state = _state(row, current)
    if not state.available:
        db.rollback()
        raise AppError(409, "daily_reward_claimed", "Nagroda dzienna została już dziś odebrana.")

    wallet = db.scalar(select(PortfelGracza).where(PortfelGracza.gracz_id == gracz.id).with_for_update())
    if wallet is None:
        db.rollback()
        raise RuntimeError(f"Gracz {gracz.id} nie ma portfela.")

    wallet.liczba_klejnotow += state.gems
    row.data_ostatniej_nagrody = current
    row.dlugosc_serii = state.streak_day
    db.add(
        Transakcja(
            gracz_id=gracz.id,
            typ="zmiana stanu konta",
            kwota_klejnotow=state.gems,
            klucz_idempotencji=f"daily:{gracz.id}:{current.isoformat()}",
        )
    )
    try:
        db.commit()
    except IntegrityError as exc:
        # Ostatnia linia obrony: transakcja z tym kluczem już istnieje.
        db.rollback()
        raise AppError(409, "daily_reward_claimed", "Nagroda dzienna została już dziś odebrana.") from exc
    return DailyState(current, False, state.streak_day, state.gems, current), wallet.liczba_klejnotow
