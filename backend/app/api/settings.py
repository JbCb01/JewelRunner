from fastapi import APIRouter

from app.api.deps import CurrentPlayer, DbSession
from app.schemas.settings import SettingsUpdate
from app.services import player_settings

router = APIRouter(prefix="/me/settings", tags=["ustawienia"])


@router.get("")
def read_settings(gracz: CurrentPlayer, db: DbSession) -> dict:
    return player_settings.read(db, gracz.id)


@router.patch("")
def update_settings(data: SettingsUpdate, gracz: CurrentPlayer, db: DbSession) -> dict:
    """Zmienia tylko podane pola. `keybindings` zastępuje całą listę przypisań."""
    return player_settings.update(db, gracz.id, data)
