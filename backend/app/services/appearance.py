"""Personalizacja postaci (5.1–5.4, 5.8): katalog, zapis wyglądu i odblokowywanie elementów.

Warunki odblokowania z element_personalizacji (warunek_typ, warunek_wartosc):
- „wynik w poziomie”: najlepszy wynik na którymkolwiek poziomie >= wartość,
- „liczba klejnotów”: łącznie zebrane klejnoty we wszystkich rozgrywkach >= wartość,
- „wyzwanie”: ukończone wyzwanie o id = wartość.
Odblokowanie sprawdzane jest po każdym wyniku z gry i przy otwarciu katalogu; element trafia do
posiadanych raz (bez duplikatów), z oznaczeniem „nowy”.
"""
import uuid
from datetime import UTC, datetime

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.schemas.appearance import AppearanceUpdate


def unlock_earned(db: Session, gracz_id: uuid.UUID) -> list[dict]:
    """Dodaje do posiadanych elementy, których warunek gracz już spełnia. Zwraca nowo odblokowane."""
    rows = db.execute(
        text(
            """
            WITH postep AS (
                SELECT
                    (SELECT COALESCE(max(najlepszy_wynik), 0) FROM postep_poziomu WHERE gracz_id = :g) AS wynik,
                    (SELECT COALESCE(sum(liczba_klejnotow), 0) FROM ukonczenie_poziomu WHERE gracz_id = :g) AS klejnoty
            )
            INSERT INTO posiadany_element (gracz_id, element_id)
            SELECT :g, e.id
            FROM element_personalizacji e, postep p
            WHERE e.warunek_typ IS NOT NULL
              AND NOT EXISTS (SELECT 1 FROM posiadany_element pe WHERE pe.gracz_id = :g AND pe.element_id = e.id)
              AND (
                    (e.warunek_typ = 'wynik w poziomie' AND p.wynik >= e.warunek_wartosc)
                 OR (e.warunek_typ = 'liczba klejnotów' AND p.klejnoty >= e.warunek_wartosc)
                 OR (e.warunek_typ = 'wyzwanie' AND EXISTS (
                        SELECT 1 FROM uczestnictwo_w_wyzwaniu u
                        WHERE u.gracz_id = :g AND u.wyzwanie_id = e.warunek_wartosc AND u.status = 'Ukończone'))
              )
            ON CONFLICT DO NOTHING
            RETURNING element_id
            """
        ),
        {"g": gracz_id},
    ).all()
    if not rows:
        return []
    ids = [row.element_id for row in rows]
    return [
        {"id": row.id, "type": row.typ, "name": row.nazwa}
        for row in db.execute(
            text("SELECT id, typ, nazwa FROM element_personalizacji WHERE id = ANY(:ids) ORDER BY id"), {"ids": ids}
        )
    ]


def _current(db: Session, gracz_id: uuid.UUID) -> dict | None:
    look = db.execute(
        text(
            """
            SELECT w.data_modyfikacji, s.id AS skin_id, s.nazwa AS skin_name, s.zasob_graficzny AS skin_asset,
                   k.id AS color_id, k.nazwa AS color_name, k.wartosc_koloru AS color_hex
            FROM wyglad_postaci w
            JOIN element_personalizacji s ON s.id = w.skorka_id
            JOIN element_personalizacji k ON k.id = w.kolor_id
            WHERE w.gracz_id = :g
            """
        ),
        {"g": gracz_id},
    ).first()
    if look is None:
        return None
    accessories = db.execute(
        text(
            """
            SELECT a.punkt_mocowania, e.id, e.nazwa, k.id AS color_id, k.nazwa AS color_name, k.wartosc_koloru
            FROM wyglad_akcesorium a
            JOIN element_personalizacji e ON e.id = a.akcesorium_id
            LEFT JOIN element_personalizacji k ON k.id = a.kolor_id
            WHERE a.gracz_id = :g ORDER BY a.punkt_mocowania
            """
        ),
        {"g": gracz_id},
    ).all()
    return {
        "skin": {"id": look.skin_id, "name": look.skin_name, "asset": look.skin_asset},
        "color": {"id": look.color_id, "name": look.color_name, "hex": look.color_hex},
        "accessories": [
            {
                "slot": row.punkt_mocowania,
                "accessory": {"id": row.id, "name": row.nazwa},
                "color": row.color_id and {"id": row.color_id, "name": row.color_name, "hex": row.wartosc_koloru},
            }
            for row in accessories
        ],
        "updated_at": look.data_modyfikacji,
    }


def read(db: Session, gracz_id: uuid.UUID) -> dict:
    newly = unlock_earned(db, gracz_id)
    db.commit()
    rows = db.execute(
        text(
            """
            SELECT e.id, e.typ, e.nazwa, e.zasob_graficzny, e.wartosc_koloru, e.punkt_mocowania,
                   e.warunek_typ, e.warunek_wartosc, e.czy_domyslny,
                   pe.element_id IS NOT NULL AS posiadany,
                   COALESCE(pe.czy_nowy, FALSE) AND NOT e.czy_domyslny AS nowy,  -- domyślne elementy z rejestracji nie są „nowe”
                   w.nazwa AS nazwa_wyzwania
            FROM element_personalizacji e
            LEFT JOIN posiadany_element pe ON pe.element_id = e.id AND pe.gracz_id = :g
            LEFT JOIN wyzwanie w ON e.warunek_typ = 'wyzwanie' AND w.id = e.warunek_wartosc
            ORDER BY CASE e.typ WHEN 'skórka' THEN 1 WHEN 'kolor' THEN 2 ELSE 3 END, e.czy_domyslny DESC, e.id
            """
        ),
        {"g": gracz_id},
    ).all()
    catalog = [
        {
            "id": row.id,
            "type": row.typ,
            "name": row.nazwa,
            "asset": row.zasob_graficzny,
            "color_hex": row.wartosc_koloru,
            "slot": row.punkt_mocowania,
            "owned": row.posiadany,
            "is_new": row.nowy,
            # Element bez warunku i nieposiadany można zdobyć tylko jako nagrodę (wyzwanie, sklep).
            "unlock_condition": None if row.posiadany or row.warunek_typ is None else {
                "type": row.warunek_typ, "value": row.warunek_wartosc, "challenge_name": row.nazwa_wyzwania,
            },
        }
        for row in rows
    ]
    return {
        "current": _current(db, gracz_id),
        "catalog": catalog,
        "new_count": sum(1 for item in catalog if item["is_new"]),
        "newly_unlocked": newly,
    }


def _owned(db: Session, gracz_id: uuid.UUID, element_id: int, kind: str) -> dict:
    row = db.execute(
        text(
            """
            SELECT e.id, e.typ, e.punkt_mocowania FROM element_personalizacji e
            JOIN posiadany_element pe ON pe.element_id = e.id AND pe.gracz_id = :g
            WHERE e.id = :e
            """
        ),
        {"g": gracz_id, "e": element_id},
    ).first()
    if row is None or row.typ != kind:
        # 5.3 A1: elementu nie ma albo jest zablokowany.
        raise AppError(
            422, "element_not_owned", "Ten element jest zablokowany albo nie pasuje do wybranego miejsca.",
            {"element_id": element_id, "expected_type": kind},
        )
    return {"id": row.id, "slot": row.punkt_mocowania}


def update(db: Session, gracz_id: uuid.UUID, data: AppearanceUpdate) -> dict:
    current = db.scalar(
        text("SELECT data_modyfikacji FROM wyglad_postaci WHERE gracz_id = :g FOR UPDATE"), {"g": gracz_id}
    )
    if current is not None and data.changed_at is not None and datetime.fromtimestamp(data.changed_at, UTC) < current:
        db.rollback()
        look = _current(db, gracz_id)
        raise AppError(
            409, "appearance_conflict", "Wygląd zmieniono później na innym urządzeniu.",
            {"server_appearance": {**look, "updated_at": look["updated_at"].isoformat()}},
        )

    _owned(db, gracz_id, data.skin_id, "skórka")
    _owned(db, gracz_id, data.color_id, "kolor")
    slots: dict[str, tuple[int, int | None]] = {}
    for choice in data.accessories:
        accessory = _owned(db, gracz_id, choice.accessory_id, "akcesorium")
        if choice.color_id is not None:
            _owned(db, gracz_id, choice.color_id, "kolor")
        if accessory["slot"] in slots:
            raise AppError(422, "slot_taken", "W jednym miejscu na postaci może być tylko jedno akcesorium.",
                           {"slot": accessory["slot"]})
        slots[accessory["slot"]] = (choice.accessory_id, choice.color_id)

    db.execute(
        text(
            """
            INSERT INTO wyglad_postaci (gracz_id, skorka_id, kolor_id) VALUES (:g, :s, :k)
            ON CONFLICT (gracz_id) DO UPDATE SET skorka_id = :s, kolor_id = :k, data_modyfikacji = now()
            """
        ),
        {"g": gracz_id, "s": data.skin_id, "k": data.color_id},
    )
    db.execute(text("DELETE FROM wyglad_akcesorium WHERE gracz_id = :g"), {"g": gracz_id})
    for slot, (accessory_id, color_id) in slots.items():
        db.execute(
            text(
                "INSERT INTO wyglad_akcesorium (gracz_id, punkt_mocowania, akcesorium_id, kolor_id)"
                " VALUES (:g, :slot, :a, :k)"
            ),
            {"g": gracz_id, "slot": slot, "a": accessory_id, "k": color_id},
        )
    db.commit()
    return _current(db, gracz_id)


def mark_seen(db: Session, gracz_id: uuid.UUID, element_ids: list[int] | None) -> int:
    if element_ids is None:
        result = db.execute(
            text("UPDATE posiadany_element SET czy_nowy = FALSE WHERE gracz_id = :g AND czy_nowy"), {"g": gracz_id}
        )
    else:
        result = db.execute(
            text("UPDATE posiadany_element SET czy_nowy = FALSE WHERE gracz_id = :g AND element_id = ANY(:ids)"),
            {"g": gracz_id, "ids": element_ids},
        )
    db.commit()
    return result.rowcount
