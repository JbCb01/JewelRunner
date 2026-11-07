from fastapi import APIRouter, Response, status

from app.api.deps import ChallengeId, CurrentPlayer, DbSession
from app.services import challenges as service

router = APIRouter(prefix="/challenges", tags=["wyzwania"])


@router.get("")
def list_challenges(gracz: CurrentPlayer, db: DbSession) -> dict:
    return {"items": service.list_active(db, gracz.id)}


@router.get("/{challenge_id}")
def read_challenge(challenge_id: ChallengeId, gracz: CurrentPlayer, db: DbSession) -> dict:
    return service.get_details(db, challenge_id, gracz.id)

