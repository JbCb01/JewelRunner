from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentPlayer, DbSession
from app.core.errors import AppError
from app.services import ranking

router = APIRouter(prefix="/ranking", tags=["ranking"])


@router.get("")
def read_ranking(
    gracz: CurrentPlayer,
    db: DbSession,
    period: Annotated[
        str | None, Query(description="tydzień, miesiąc, ogółem albo znajomi; bez parametru: ostatnio wybrany")
    ] = None,
) -> dict:
    normalized = ranking.normalize(period)
    if normalized is not None and normalized not in ranking.PERIODS:
        raise AppError(422, "invalid_period", "Nieznany okres rankingu.")
    return ranking.read(db, gracz.id, normalized)
