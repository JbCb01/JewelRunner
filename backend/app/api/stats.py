from typing import Annotated

from fastapi import APIRouter, Query

from app.api.deps import CurrentPlayer, DbSession
from app.services import stats

router = APIRouter(prefix="/me", tags=["statystyki"])


@router.get("/stats")
def read_stats(gracz: CurrentPlayer, db: DbSession) -> dict:
    """Statystyki ogólne i dla każdego poziomu (8.4)."""
    return stats.overview(db, gracz.id)


@router.get("/runs")
def read_runs(
    gracz: CurrentPlayer,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    before_id: Annotated[int | None, Query(ge=1, le=2**63 - 1)] = None,
) -> dict:
    """Historia gier: ukończone poziomy i porażki, od najnowszych."""
    return stats.history(db, gracz.id, limit, before_id)


@router.post("/tutorial/complete")
def complete_tutorial(gracz: CurrentPlayer, db: DbSession) -> dict:
    """Zapisuje ukończenie samouczka przez gracza (3.6)."""
    return stats.complete_tutorial(db, gracz.id)
