from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field, StringConstraints

ShortText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=64)]


class SaveRequest(BaseModel):
    """Zapis gry. `checksum` to SHA-256 (hex) z tekstu „level|checkpoint|gems|saved_at|game_version”."""

    level: int = Field(ge=1, le=10_000)  # numer poziomu = kolejność poziomu w bazie
    checkpoint: Annotated[str, Field(max_length=64)] | None = None
    gems: int = Field(ge=0, le=100_000)
    saved_at: int = Field(ge=0)  # czas zapisu w grze, sekundy od 1970-01-01 UTC
    game_version: ShortText
    checksum: Annotated[str, StringConstraints(pattern=r"^[0-9a-fA-F]{64}$")]


class SaveResponse(BaseModel):
    level: int
    level_name: str
    checkpoint: str | None
    gems: int
    saved_at: int
    saved_at_iso: datetime
    game_version: str
    checksum: str


class SaveState(BaseModel):
    """`save` jest null, gdy gracz nie ma jeszcze zapisu w chmurze."""

    save: SaveResponse | None


class WalletOperation(BaseModel):
    id: Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9_.:-]{8,64}$")]
    gems: int = Field(ge=1, le=500)
    reason: Annotated[str, StringConstraints(strip_whitespace=True, max_length=64)] = "rozgrywka"


class WalletSyncRequest(BaseModel):
    operations: list[WalletOperation] = Field(max_length=50)


class WalletResponse(BaseModel):
    gems: int


class WalletSyncResponse(WalletResponse):
    applied: list[str]
    duplicates: list[str]


class UseBoosterRequest(BaseModel):
    operation_id: Annotated[str, StringConstraints(pattern=r"^[A-Za-z0-9_.:-]{8,64}$")]
    booster_type: ShortText


class UseBoosterResponse(BaseModel):
    booster_type: str
    remaining: int
    duplicate: bool


class RunRequest(BaseModel):
    """Wynik jednego rozegrania poziomu wysłany przez grę po mecie albo po porażce."""

    session_id: Annotated[str, StringConstraints(pattern=r"^SES-[0-9]{1,20}-[0-9]{4}$")]
    level: int = Field(ge=1, le=10_000)  # numer poziomu = kolejność w bazie
    completed: bool  # true: dotarł do mety; false: porażka
    score: int = Field(ge=0, le=1_000_000)
    time_s: float = Field(ge=0, le=36_000)
    gems: int = Field(ge=0, le=10_000)
    enemies_defeated: int = Field(default=0, ge=0, le=10_000)


class RunChallenge(BaseModel):
    challenge_id: int
    name: str
    passed: bool | None  # wynik tej próby; null, gdy wynik był już wcześniej zapisany
    progress_percent: int
    status: str
    reward_status: str | None


class RunResponse(BaseModel):
    duplicate: bool  # true: ten wynik (ten sam session_id) był już zapisany
    level: int
    completed: bool
    best_score: int | None
    best_time_s: float | None
    attempts: int
    new_best: bool
    unlocked_levels: list[int]
    unlocked_items: list[dict] = []  # elementy personalizacji odblokowane tym wynikiem
    ranking: dict
    challenges: list[RunChallenge]
