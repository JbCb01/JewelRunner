import uuid

from fastapi import APIRouter
from sqlalchemy import select

from app.api.deps import CurrentPlayer, DbSession
from app.core.errors import AppError
from app.db.models import Gracz, StatystykiGracza

router = APIRouter(prefix="/players", tags=["ranking"])


@router.get("/{player_id}")
def read_player(player_id: uuid.UUID, _: CurrentPlayer, db: DbSession) -> dict:
    row = db.execute(
        select(Gracz.id, Gracz.nazwa_uzytkownika, StatystykiGracza)
        .join(StatystykiGracza, StatystykiGracza.gracz_id == Gracz.id)
        .where(Gracz.id == player_id, Gracz.status_konta == "aktywne")
    ).first()
    if row is None:
        raise AppError(404, "not_found", "Nie znaleziono gracza.")
    player_id, username, stats = row
    return {
        "id": player_id,
        "username": username,
        "statistics": {
            "play_time_seconds": stats.laczny_czas_gry_s,
            "levels_completed": stats.liczba_ukonczonych_poziomow,
            "enemies_defeated": stats.liczba_pokonanych_wrogow,
            "defeats": stats.liczba_porazek,
            "longest_combo": stats.najdluzsze_combo,
        },
    }
