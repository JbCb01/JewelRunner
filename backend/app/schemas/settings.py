from typing import Annotated, Literal

from pydantic import BaseModel, Field, StringConstraints, field_validator

Volume = Annotated[int, Field(ge=0, le=100)]
Quality = Literal["Niski", "Średni", "Wysoki"]
Action = Annotated[str, StringConstraints(pattern=r"^[a-z_]{1,32}$")]
Key = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=32)]

# Klawisze zarezerwowane dla menu i systemu; nie można ich przypisać do akcji (3.5).
RESERVED_KEYS = {"escape", "esc", "f11", "f12", "printscreen"}


class SettingsUpdate(BaseModel):
    """Częściowa zmiana: pola pominięte zostają bez zmian."""

    music_volume: Volume | None = None
    level_music_volume: Volume | None = None
    sfx_volume: Volume | None = None
    resolution: Annotated[str, StringConstraints(pattern=r"^[0-9]{3,4}x[0-9]{3,4}$")] | None = None
    texture_quality: Quality | None = None
    effects_level: Quality | None = None
    graphics_profile: Quality | None = None
    language: Literal["pl", "en"] | None = None
    ranking_filter: Literal["tydzień", "miesiąc", "ogółem", "znajomi"] | None = None
    # Pełna lista przypisań; pusty słownik przywraca domyślne klawisze gry.
    keybindings: dict[Action, Key] | None = Field(default=None, max_length=40)
    # Czas zmiany po stronie klienta (sekundy UTC). Starsza zmiana niż zapisana na serwerze dostaje 409.
    changed_at: int | None = Field(default=None, ge=0)

    @field_validator("keybindings")
    @classmethod
    def check_keys(cls, value: dict[str, str] | None) -> dict[str, str] | None:
        if value is None:
            return value
        keys = [key.lower() for key in value.values()]
        if any(key in RESERVED_KEYS for key in keys):
            raise ValueError("klawisz jest zarezerwowany")
        if len(set(keys)) != len(keys):
            raise ValueError("ten sam klawisz przypisano do dwóch akcji")
        return value
