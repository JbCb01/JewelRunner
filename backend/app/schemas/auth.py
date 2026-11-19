import uuid
from datetime import date, datetime
from typing import Annotated

from pydantic import BaseModel, EmailStr, Field, StringConstraints

# Górny limit chroni serwer przed haszowaniem bardzo długich danych.
Password = Annotated[str, Field(max_length=128)]
Username = Annotated[
    str, StringConstraints(strip_whitespace=True, min_length=3, max_length=32, pattern=r"^[^\x00-\x1f\x7f]+$")
]


class RegisterRequest(BaseModel):
    username: Username
    email: EmailStr
    password: Password


class LoginRequest(BaseModel):
    email: EmailStr
    password: Password


class MeResponse(BaseModel):
    id: uuid.UUID
    username: str
    email: str
    # Czy gracz ma aktywną sesję gry (sparowaną kodem) i kiedy gra ostatnio pobrała dane.
    game_linked: bool = False
    last_synced_at: datetime | None = None


class UpdateMeRequest(BaseModel):
    username: Username


class ChangeEmailRequest(BaseModel):
    new_email: EmailStr
    current_password: Password


class ConfirmEmailRequest(BaseModel):
    token: Annotated[str, Field(max_length=256)]


class ChangePasswordRequest(BaseModel):
    current_password: Password
    new_password: Password


class PairingCodeResponse(BaseModel):
    code: str
    expires_at: datetime


class PairRequest(BaseModel):
    code: Annotated[str, Field(max_length=32)]


class GameSessionResponse(BaseModel):
    """Gra trzyma token u siebie i wysyła go w nagłówku Authorization: Bearer."""

    token: str
    expires_at: datetime
    player: MeResponse


class DailyRewardDay(BaseModel):
    day: int
    gems: int
    special: bool


class DailyRewardResponse(BaseModel):
    """Stan nagrody dziennej. `available` mówi, czy pokazać powiadomienie."""

    today: date
    available: bool
    streak_day: int
    gems: int
    special: bool
    last_claimed: date | None
    rewards: list[DailyRewardDay]


class DailyRewardClaimResponse(DailyRewardResponse):
    balance: int
