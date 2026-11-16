"""Ustawienia gracza (3.2–3.5): dźwięk, grafika, język, filtr rankingu i przypisania klawiszy.

Gra i portal czytają i zapisują te same ustawienia. Przy konflikcie wygrywa późniejsza zmiana:
gdy klient poda changed_at starszy niż ostatnia zmiana na serwerze, dostaje 409 z aktualnymi danymi.
"""
import uuid
from datetime import UTC, datetime

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.schemas.settings import SettingsUpdate
from app.services import settings_store

COLUMNS = {
    "music_volume": "glosnosc_muzyki",
    "level_music_volume": "glosnosc_muzyki_poziomu",
    "sfx_volume": "glosnosc_efektow",
    "resolution": "rozdzielczosc",
    "texture_quality": "jakosc_tekstur",
    "effects_level": "poziom_efektow",
    "graphics_profile": "profil_graficzny",
    "language": "jezyk",
    "ranking_filter": "domyslny_filtr_rankingu",
}
DEFAULTS = {
    "music_volume": 100, "level_music_volume": 100, "sfx_volume": 100, "resolution": None,
    "texture_quality": None, "effects_level": None, "graphics_profile": None, "language": "pl",
    "ranking_filter": "ogółem",
}


def read(db: Session, gracz_id: uuid.UUID) -> dict:
    row = db.execute(
        text(f"SELECT {', '.join(COLUMNS.values())}, data_modyfikacji FROM ustawienia_gracza WHERE gracz_id = :g"),
        {"g": gracz_id},
    ).mappings().first()
    result = {name: (row[column] if row else DEFAULTS[name]) for name, column in COLUMNS.items()}
    result["keybindings"] = {
        r.akcja_sterowania: r.klawisz
        for r in db.execute(
            text("SELECT akcja_sterowania, klawisz FROM przypisanie_klawisza WHERE gracz_id = :g ORDER BY 1"),
            {"g": gracz_id},
        )
    }
    result["updated_at"] = row["data_modyfikacji"] if row else None
    return result


def update(db: Session, gracz_id: uuid.UUID, data: SettingsUpdate) -> dict:
    created = settings_store.ensure_row(db, gracz_id)
    current = db.scalar(
        text("SELECT data_modyfikacji FROM ustawienia_gracza WHERE gracz_id = :g FOR UPDATE"), {"g": gracz_id}
    )
    if not created and data.changed_at is not None and datetime.fromtimestamp(data.changed_at, UTC) < current:
        db.rollback()
        settings = read(db, gracz_id)
        raise AppError(
            409, "settings_conflict", "Ustawienia zmieniono później na innym urządzeniu.",
            {"server_settings": {**settings, "updated_at": settings["updated_at"].isoformat()}},
        )

    changes = data.model_dump(exclude_unset=True, exclude={"keybindings", "changed_at"})
    if changes:
        assignments = ", ".join(f"{COLUMNS[name]} = :{name}" for name in changes)
        db.execute(
            text(f"UPDATE ustawienia_gracza SET {assignments}, data_modyfikacji = now() WHERE gracz_id = :g"),
            {**changes, "g": gracz_id},
        )
    if data.keybindings is not None:
        db.execute(text("DELETE FROM przypisanie_klawisza WHERE gracz_id = :g"), {"g": gracz_id})
        for action, key in data.keybindings.items():
            db.execute(
                text("INSERT INTO przypisanie_klawisza (gracz_id, akcja_sterowania, klawisz) VALUES (:g, :a, :k)"),
                {"g": gracz_id, "a": action, "k": key},
            )
        db.execute(text("UPDATE ustawienia_gracza SET data_modyfikacji = now() WHERE gracz_id = :g"), {"g": gracz_id})
    db.commit()
    return read(db, gracz_id)
