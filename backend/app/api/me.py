from fastapi import APIRouter, status

from app.api.deps import ChallengeId, CurrentPlayer, DbSession
from app.db.models import Gracz
from app.schemas.auth import (
    ChangeEmailRequest,
    ChangePasswordRequest,
    ConfirmEmailRequest,
    MeResponse,
    UpdateMeRequest,
)
from app.services import account, challenges

router = APIRouter(prefix="/me", tags=["konto"])


def _me(gracz: Gracz) -> MeResponse:
    return MeResponse(id=gracz.id, username=gracz.nazwa_uzytkownika, email=gracz.email)


@router.get("")
def read_me(gracz: CurrentPlayer) -> MeResponse:
    return _me(gracz)


@router.patch("")
def update_me(data: UpdateMeRequest, gracz: CurrentPlayer, db: DbSession) -> MeResponse:
    account.change_username(db, gracz, data.username)
    return _me(gracz)



@router.get("/challenges", tags=["wyzwania"])
def my_challenges(gracz: CurrentPlayer, db: DbSession) -> dict:
    return {"items": challenges.list_mine(db, gracz.id)}


@router.get("/challenges/{challenge_id}/attempts", tags=["wyzwania"])
def my_attempts(challenge_id: ChallengeId, gracz: CurrentPlayer, db: DbSession) -> dict:
    return challenges.attempts(db, challenge_id, gracz)
