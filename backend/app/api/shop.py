from typing import Annotated

from fastapi import APIRouter
from pydantic import BaseModel, Field, StringConstraints

from app.api.deps import CurrentPlayer, DbSession
from app.services import shop

router = APIRouter(prefix="/shop", tags=["sklep"])


class ShopPurchaseRequest(BaseModel):
    booster_id: int = Field(ge=1, le=2**63 - 1)
    idempotency_key: Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9_.:-]{8,64}$")]


@router.get("")
def read_shop(gracz: CurrentPlayer, db: DbSession) -> dict:
    """Lista dostępnych wzmocnień, cen, salda oraz posiadanych sztuk."""
    return shop.list_shop(db, gracz)


@router.post("/purchase")
def purchase_booster(data: ShopPurchaseRequest, gracz: CurrentPlayer, db: DbSession) -> dict:
    """Zakup wzmocnienia z kluczem idempotencji (podwójne kliknięcie daje jeden zakup)."""
    return shop.purchase(db, gracz, data.booster_id, data.idempotency_key)
