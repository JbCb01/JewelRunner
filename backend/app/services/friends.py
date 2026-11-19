"""Znajomi (2.7): lista, dodawanie po nazwie, usuwanie i wyszukiwanie graczy.

Znajomość jest jednostronna, jak obserwowanie: gracz dodaje kogoś do swojej listy,
a ranking „znajomi” pokazuje jego i osoby z tej listy.
"""
import uuid

from sqlalchemy import func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.models import Gracz

MAX_FRIENDS = 100
SEARCH_LIMIT = 10


def list_friends(db: Session, gracz_id: uuid.UUID) -> list[dict]:
    rows = db.execute(
        text(
            """
            SELECT g.id, g.nazwa_uzytkownika, z.data_dodania, r.wynik
            FROM znajomy z
            JOIN gracz g ON g.id = z.znajomy_id AND g.status_konta = 'aktywne'
            LEFT JOIN wpis_rankingu r ON r.gracz_id = g.id AND r.okres = 'ogółem'
            WHERE z.gracz_id = :g
            ORDER BY lower(g.nazwa_uzytkownika)
            """
        ),
        {"g": gracz_id},
    ).all()
    return [
        {"player_id": row.id, "username": row.nazwa_uzytkownika, "added_at": row.data_dodania, "score": row.wynik}
        for row in rows
    ]


def add(db: Session, gracz_id: uuid.UUID, username: str) -> dict:
    friend = db.scalar(
        select(Gracz).where(func.lower(Gracz.nazwa_uzytkownika) == username.strip().lower(), Gracz.status_konta == "aktywne")
    )
    if friend is None:
        raise AppError(404, "player_not_found", "Nie znaleziono gracza o tej nazwie.")
    if friend.id == gracz_id:
        raise AppError(422, "cannot_add_self", "Nie możesz dodać siebie do znajomych.")
    count = db.scalar(text("SELECT count(*) FROM znajomy WHERE gracz_id = :g"), {"g": gracz_id})
    if count >= MAX_FRIENDS:
        raise AppError(422, "too_many_friends", f"Możesz mieć maksymalnie {MAX_FRIENDS} znajomych.")
    try:
        db.execute(text("INSERT INTO znajomy (gracz_id, znajomy_id) VALUES (:g, :z)"), {"g": gracz_id, "z": friend.id})
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise AppError(409, "already_friend", "Ten gracz jest już na liście znajomych.") from exc
    return {"player_id": friend.id, "username": friend.nazwa_uzytkownika}


def remove(db: Session, gracz_id: uuid.UUID, friend_id: uuid.UUID) -> None:
    deleted = db.execute(
        text("DELETE FROM znajomy WHERE gracz_id = :g AND znajomy_id = :z"), {"g": gracz_id, "z": friend_id}
    ).rowcount
    db.commit()
    if not deleted:
        raise AppError(404, "not_found", "Tego gracza nie ma na liście znajomych.")


def search(db: Session, gracz_id: uuid.UUID, query: str) -> list[dict]:
    """Gracze, których nazwa zaczyna się od podanego tekstu (bez wielkości liter)."""
    pattern = query.strip().lower().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
    rows = db.execute(
        text(
            """
            SELECT g.id, g.nazwa_uzytkownika,
                   EXISTS (SELECT 1 FROM znajomy z WHERE z.gracz_id = :g AND z.znajomy_id = g.id) AS czy_znajomy
            FROM gracz g
            WHERE g.status_konta = 'aktywne' AND g.id <> :g AND lower(g.nazwa_uzytkownika) LIKE :p ESCAPE '\\'
            ORDER BY lower(g.nazwa_uzytkownika)
            LIMIT :limit
            """
        ),
        {"g": gracz_id, "p": pattern, "limit": SEARCH_LIMIT},
    ).all()
    return [{"player_id": row.id, "username": row.nazwa_uzytkownika, "is_friend": row.czy_znajomy} for row in rows]
