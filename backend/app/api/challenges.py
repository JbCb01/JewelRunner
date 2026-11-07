from fastapi import APIRouter, Response, status

from app.api.deps import ChallengeId, CurrentPlayer, DbSession
from app.services import challenges as service

router = APIRouter(prefix="/challenges", tags=["wyzwania"])


@router.get("")
def list_challenges(gracz: CurrentPlayer, db: DbSession) -> dict:
    return {"items": service.list_active(db, gracz.id)}

