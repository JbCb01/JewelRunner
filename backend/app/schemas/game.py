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
