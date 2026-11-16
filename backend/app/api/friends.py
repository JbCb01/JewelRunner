import uuid
from typing import Annotated

from fastapi import APIRouter, status
from pydantic import BaseModel, StringConstraints

from app.api.deps import CurrentPlayer, DbSession
from app.services import friends

router = APIRouter(prefix="/me/friends", tags=["ranking"])


class AddFriendRequest(BaseModel):
    username: Annotated[str, StringConstraints(strip_whitespace=True, min_length=3, max_length=32)]


@router.get("")
def list_friends(gracz: CurrentPlayer, db: DbSession) -> dict:
    return {"items": friends.list_friends(db, gracz.id)}


@router.post("", status_code=status.HTTP_201_CREATED)
def add_friend(data: AddFriendRequest, gracz: CurrentPlayer, db: DbSession) -> dict:
    return friends.add(db, gracz.id, data.username)


@router.delete("/{player_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_friend(player_id: uuid.UUID, gracz: CurrentPlayer, db: DbSession) -> None:
    friends.remove(db, gracz.id, player_id)
