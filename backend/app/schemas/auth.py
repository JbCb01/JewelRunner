import uuid
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
