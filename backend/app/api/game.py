from fastapi import APIRouter

from app.api.deps import CurrentPlayer, DbSession
from app.schemas.game import RunRequest, RunResponse
from app.services import game_runs

router = APIRouter(prefix="/game", tags=["gra"])


@router.post("/runs")
def submit_run(data: RunRequest, gracz: CurrentPlayer, db: DbSession) -> RunResponse:
    """Wynik rozegrania poziomu: po mecie (completed=true) albo po porażce (completed=false)."""
    return RunResponse(**game_runs.record_run(db, gracz, data))
