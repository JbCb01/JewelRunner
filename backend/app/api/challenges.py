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


@router.post("/{challenge_id}/accept", status_code=status.HTTP_201_CREATED)
def accept_challenge(challenge_id: ChallengeId, response: Response, gracz: CurrentPlayer, db: DbSession) -> dict:
    participation, created = service.accept(db, challenge_id, gracz.id)
    if not created:
        response.status_code = status.HTTP_200_OK
    return participation
