from fastapi import APIRouter

from app.api.deps import CurrentPlayer, DbSession
from app.schemas.appearance import AppearanceUpdate, SeenRequest
from app.services import appearance

router = APIRouter(prefix="/me/appearance", tags=["personalizacja"])


@router.get("")
def read_appearance(gracz: CurrentPlayer, db: DbSession) -> dict:
    """Aktualny wygląd i katalog elementów (posiadane, zablokowane z warunkiem, nowe)."""
    return appearance.read(db, gracz.id)


@router.put("")
def update_appearance(data: AppearanceUpdate, gracz: CurrentPlayer, db: DbSession) -> dict:
    return appearance.update(db, gracz.id, data)


@router.post("/seen")
def mark_seen(data: SeenRequest, gracz: CurrentPlayer, db: DbSession) -> dict:
    """Usuwa oznaczenie „nowy” z obejrzanych elementów."""
    return {"updated": appearance.mark_seen(db, gracz.id, data.element_ids)}
