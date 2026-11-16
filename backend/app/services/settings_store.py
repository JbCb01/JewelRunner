"""Ustawienia gracza (wiersz w ustawienia_gracza powstaje przy pierwszym zapisie)."""
import uuid

from sqlalchemy import text
from sqlalchemy.orm import Session


def ensure_row(db: Session, gracz_id: uuid.UUID) -> bool:
    """Tworzy wiersz z wartościami domyślnymi. Zwraca True, gdy wiersz powstał teraz."""
    created = db.scalar(
        text("INSERT INTO ustawienia_gracza (gracz_id) VALUES (:g) ON CONFLICT (gracz_id) DO NOTHING RETURNING gracz_id"),
        {"g": gracz_id},
    )
    return created is not None


def ranking_filter(db: Session, gracz_id: uuid.UUID) -> str:
    value = db.scalar(text("SELECT domyslny_filtr_rankingu FROM ustawienia_gracza WHERE gracz_id = :g"), {"g": gracz_id})
    return value or "ogółem"


def save_ranking_filter(db: Session, gracz_id: uuid.UUID, period: str) -> None:
    ensure_row(db, gracz_id)
    db.execute(
        text(
            "UPDATE ustawienia_gracza SET domyslny_filtr_rankingu = :f, data_modyfikacji = now()"
            " WHERE gracz_id = :g AND domyslny_filtr_rankingu <> :f"
        ),
        {"g": gracz_id, "f": period},
    )
