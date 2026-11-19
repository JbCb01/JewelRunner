from pydantic import BaseModel, Field


class AccessoryChoice(BaseModel):
    accessory_id: int = Field(ge=1)
    color_id: int | None = Field(default=None, ge=1)


class AppearanceUpdate(BaseModel):
    skin_id: int = Field(ge=1)
    color_id: int = Field(ge=1)
    # Maks. jedno akcesorium na punkt mocowania; pusta lista zdejmuje wszystkie.
    accessories: list[AccessoryChoice] = Field(default_factory=list, max_length=10)
    # Czas zmiany po stronie klienta (sekundy UTC); starsza zmiana niż zapisana dostaje 409 (5.3 A3).
    changed_at: int | None = Field(default=None, ge=0)


class SeenRequest(BaseModel):
    """Elementy obejrzane w menu: znika oznaczenie „nowy”. Brak listy: wszystkie."""

    element_ids: list[int] | None = Field(default=None, max_length=200)
