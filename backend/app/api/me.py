import uuid

from fastapi import APIRouter, status
from sqlalchemy.orm import Session

from app.api.deps import ChallengeId, CurrentPlayer, DbSession, SessionToken
from app.db.models import Gracz
from app.schemas.auth import (
    ChangeEmailRequest,
    ChangePasswordRequest,
    ConfirmEmailRequest,
    DailyRewardClaimResponse,
    DailyRewardDay,
    DailyRewardResponse,
    MeResponse,
    PairingCodeResponse,
    UpdateMeRequest,
)
from app.services import auth as auth_service
from app.services import account, challenges, daily_reward, pairing

router = APIRouter(prefix="/me", tags=["konto"])


def _me(gracz: Gracz, db: Session) -> MeResponse:
    return MeResponse(
        id=gracz.id,
        username=gracz.nazwa_uzytkownika,
        email=gracz.email,
        game_linked=auth_service.has_game_session(db, gracz),
        last_synced_at=gracz.data_ostatniej_synchronizacji,
    )


@router.get("")
def read_me(gracz: CurrentPlayer, db: DbSession) -> MeResponse:
    return _me(gracz, db)


@router.patch("")
def update_me(data: UpdateMeRequest, gracz: CurrentPlayer, db: DbSession) -> MeResponse:
    account.change_username(db, gracz, data.username)
    return _me(gracz, db)


@router.post("/email", status_code=status.HTTP_202_ACCEPTED)
def request_email_change(data: ChangeEmailRequest, gracz: CurrentPlayer, db: DbSession) -> dict:
    account.request_email_change(db, gracz, data.new_email, data.current_password)
    return {"status": "confirmation_sent"}


@router.post("/email/confirm")
def confirm_email_change(data: ConfirmEmailRequest, gracz: CurrentPlayer, db: DbSession) -> MeResponse:
    account.confirm_email_change(db, gracz, data.token)
    return _me(gracz, db)


@router.post("/password", status_code=status.HTTP_204_NO_CONTENT)
def change_password(data: ChangePasswordRequest, gracz: CurrentPlayer, db: DbSession) -> None:
    account.change_password(db, gracz, data.current_password, data.new_password)


@router.post("/pairing-code", status_code=status.HTTP_201_CREATED)
def create_pairing_code(gracz: CurrentPlayer, db: DbSession) -> PairingCodeResponse:
    """Kod do wpisania w grze. Nowy kod unieważnia poprzedni."""
    code, expires_at = pairing.create_code(db, gracz)
    return PairingCodeResponse(code=code, expires_at=expires_at)


def _daily(state: daily_reward.DailyState) -> dict:
    return {
        "today": state.today,
        "available": state.available,
        "streak_day": state.streak_day,
        "gems": state.gems,
        "special": state.streak_day == daily_reward.SPECIAL_DAY,
        "last_claimed": state.last_claimed,
        "rewards": [
            DailyRewardDay(day=day, gems=gems, special=day == daily_reward.SPECIAL_DAY)
            for day, gems in daily_reward.REWARDS.items()
        ],
    }


@router.get("/daily-reward", tags=["klejnoty"])
def read_daily_reward(gracz: CurrentPlayer, db: DbSession) -> DailyRewardResponse:
    return DailyRewardResponse(**_daily(daily_reward.get_state(db, gracz)))


@router.post("/daily-reward/claim", tags=["klejnoty"])
def claim_daily_reward(gracz: CurrentPlayer, db: DbSession) -> DailyRewardClaimResponse:
    state, balance = daily_reward.claim(db, gracz)
    return DailyRewardClaimResponse(**_daily(state), balance=balance)


@router.get("/challenges", tags=["wyzwania"])
def my_challenges(gracz: CurrentPlayer, db: DbSession) -> dict:
    return {"items": challenges.list_mine(db, gracz.id)}


@router.get("/challenges/{challenge_id}/attempts", tags=["wyzwania"])
def my_attempts(challenge_id: ChallengeId, gracz: CurrentPlayer, db: DbSession) -> dict:
    return challenges.attempts(db, challenge_id, gracz)


@router.post("/challenges/{challenge_id}/claim", tags=["wyzwania"])
def claim_challenge_reward(challenge_id: ChallengeId, gracz: CurrentPlayer, db: DbSession) -> dict:
    """Odbiór nagrody za ukończone wyzwanie (2.5)."""
    return challenges.claim_reward(db, challenge_id, gracz)


@router.get("/sessions", tags=["konto"])
def read_sessions(gracz: CurrentPlayer, db: DbSession, token: SessionToken) -> dict:
    """Lista aktywnych sesji konta (gra i przeglądarka)."""
    return {"items": auth_service.list_sessions(db, gracz, token)}


@router.delete("/sessions/{session_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["konto"])
def delete_session(session_id: uuid.UUID, gracz: CurrentPlayer, db: DbSession) -> None:
    """Unieważnienie wybranej sesji, np. odłączenie gry."""
    auth_service.revoke_session(db, gracz, session_id)


@router.get("/game-state", tags=["konto"])
def read_game_state(gracz: CurrentPlayer, db: DbSession) -> dict:
    """Kompletna synchronizacja profilu gracza, ustawień, skórek i wyzwań dla klienta gry."""
    return account.get_game_state(db, gracz)
