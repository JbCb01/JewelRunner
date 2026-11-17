from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentPlayer, DbSession
from app.schemas.game import (
    SaveRequest,
    SaveResponse,
    SaveState,
    UseBoosterRequest,
    UseBoosterResponse,
    WalletResponse,
    WalletSyncRequest,
    WalletSyncResponse,
)
from app.services import game_save, shop, wallet

router = APIRouter(prefix="/me", tags=["gra"])


@router.get("/save")
def read_save(gracz: CurrentPlayer, db: DbSession) -> SaveState:
    """Najnowszy poprawny zapis gry z chmury."""
    return SaveState(save=game_save.latest_valid(db, gracz))


@router.put("/save")
def write_save(
    data: SaveRequest,
    gracz: CurrentPlayer,
    db: DbSession,
    force: Annotated[bool, Query(description="Nadpisz nowszy zapis z serwera, gdy gracz wybrał swój")] = False,
) -> SaveResponse:
    return SaveResponse(**game_save.store(db, gracz, data, force))


@router.get("/wallet")
def read_wallet(gracz: CurrentPlayer, db: DbSession) -> WalletResponse:
    return WalletResponse(gems=wallet.balance(db, gracz))


@router.post("/wallet/sync")
def sync_wallet(data: WalletSyncRequest, gracz: CurrentPlayer, db: DbSession) -> WalletSyncResponse:
    """Klejnoty zebrane w grze, także te zebrane bez internetu i wysłane później."""
    gems, applied, duplicates = wallet.sync(db, gracz, data.operations)
    return WalletSyncResponse(gems=gems, applied=applied, duplicates=duplicates)


@router.post("/boosters/use")
def use_booster(data: UseBoosterRequest, gracz: CurrentPlayer, db: DbSession) -> UseBoosterResponse:
    """Zgłoszenie zużycia wzmocnienia z gry; idempotentne po operation_id."""
    return UseBoosterResponse(**shop.use_booster(db, gracz, data.booster_type, data.operation_id))
