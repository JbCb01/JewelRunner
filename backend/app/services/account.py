from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import (
    hash_password,
    is_strong_password,
    new_session_token,
    token_hash,
)
from app.db.models import (
    ElementPersonalizacji,
    Gracz,
    PortfelGracza,
    PosiadanyElement,
    TokenZmianyEmaila,
    Wzmocnienie,
)
from app.services import appearance, challenges, mailer, player_settings, shop
from app.services.auth import check_password_with_lock

EMAIL_TOKEN_TTL = timedelta(hours=24)


def _require_password(db: Session, gracz: Gracz, password: str) -> None:
    db.refresh(gracz, with_for_update=True)
    if not check_password_with_lock(db, gracz, password):
        raise AppError(403, "invalid_password", "Aktualne hasło jest nieprawidłowe.")
    if gracz.liczba_nieudanych_logowan:
        gracz.liczba_nieudanych_logowan = 0


def _commit_unique(db: Session, constraint: str, error: AppError) -> None:
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        if exc.orig.diag.constraint_name == constraint:
            raise error from exc
        raise


def change_username(db: Session, gracz: Gracz, username: str) -> None:
    gracz.nazwa_uzytkownika = username
    gracz.data_modyfikacji = datetime.now(UTC)
    _commit_unique(db, "ux_gracz_nazwa", AppError(409, "username_taken", "Nazwa jest zajęta."))


def request_email_change(db: Session, gracz: Gracz, new_email: str, password: str) -> None:
    _require_password(db, gracz, password)
    new_email = new_email.lower()
    if db.scalar(select(Gracz.id).where(func.lower(Gracz.email) == new_email)):
        raise AppError(409, "email_taken", "Adres e-mail jest już zarejestrowany.")

    # Ważny jest tylko ostatnio wysłany link.
    db.execute(
        update(TokenZmianyEmaila)
        .where(TokenZmianyEmaila.gracz_id == gracz.id, TokenZmianyEmaila.czy_uzyty.is_(False))
        .values(czy_uzyty=True)
    )
    token = new_session_token()
    db.add(
        TokenZmianyEmaila(
            gracz_id=gracz.id,
            nowy_email=new_email,
            skrot_wartosci=token_hash(token),
            data_waznosci=datetime.now(UTC) + EMAIL_TOKEN_TTL,
        )
    )
    link = f"{get_settings().portal_url}/potwierdz-email?token={token}"
    mailer.send_email(new_email, "Potwierdź zmianę adresu e-mail", f"Aby potwierdzić nowy adres, otwórz link:\n{link}")
    db.commit()


def confirm_email_change(db: Session, gracz: Gracz, token: str) -> None:
    record = db.scalar(
        select(TokenZmianyEmaila)
        .where(
            TokenZmianyEmaila.skrot_wartosci == token_hash(token),
            TokenZmianyEmaila.gracz_id == gracz.id,
            TokenZmianyEmaila.czy_uzyty.is_(False),
            TokenZmianyEmaila.data_waznosci > datetime.now(UTC),
        )
        .with_for_update()
    )
    if record is None:
        raise AppError(400, "invalid_token", "Link jest nieprawidłowy lub wygasł.")
    record.czy_uzyty = True
    gracz.email = record.nowy_email
    gracz.data_modyfikacji = datetime.now(UTC)
    _commit_unique(db, "ux_gracz_email", AppError(409, "email_taken", "Adres e-mail jest już zarejestrowany."))


def change_password(db: Session, gracz: Gracz, current_password: str, new_password: str) -> None:
    _require_password(db, gracz, current_password)
    if not is_strong_password(new_password):
        raise AppError(422, "weak_password", "Hasło musi mieć co najmniej 8 znaków, literę i cyfrę.")
    gracz.skrot_hasla = hash_password(new_password)
    gracz.data_modyfikacji = datetime.now(UTC)
    db.commit()


def get_game_state(db: Session, gracz: Gracz) -> dict:
    """Zwraca pełny stan profilu gracza dla gry (ustawienia, skórki, kolory, akcesoria, wzmocnienia i zadania)."""
    wallet = db.get(PortfelGracza, gracz.id)
    gems = wallet.liczba_klejnotow if wallet else 0

    look = appearance.current_look(db, gracz.id)
    active_skin = "Skórka podstawowa"
    active_skin_id = None
    active_color_name = "Fioletowy"
    active_color_hex = "#6A3FB5"
    active_color_id = None
    equipped_accessories: dict[str, str] = {}
    equipped_accessories_detail: list[dict] = []
    if look is not None:
        active_skin = look["skin"]["name"]
        active_skin_id = look["skin"]["id"]
        active_color_name = look["color"]["name"]
        active_color_hex = look["color"]["hex"] or "#6A3FB5"
        active_color_id = look["color"]["id"]
        equipped_accessories = {acc["slot"]: acc["accessory"]["name"] for acc in look["accessories"]}
        equipped_accessories_detail = [
            {
                "slot": acc["slot"],
                "accessory_id": acc["accessory"]["id"],
                "name": acc["accessory"]["name"],
                "color_id": acc["color"]["id"] if acc["color"] else None,
            }
            for acc in look["accessories"]
        ]

    owned_rows = db.execute(
        select(ElementPersonalizacji)
        .join(PosiadanyElement, PosiadanyElement.element_id == ElementPersonalizacji.id)
        .where(PosiadanyElement.gracz_id == gracz.id)
    ).scalars().all()
    owned_items = [
        {
            "id": el.id,
            "type": el.typ,
            "name": el.nazwa,
            **({"color_hex": el.wartosc_koloru} if el.wartosc_koloru else {}),
            **({"mount_point": el.punkt_mocowania} if el.punkt_mocowania else {}),
        }
        for el in owned_rows
    ]

    active_ch = challenges.list_mine(db, gracz.id)
    enriched_challenges = []
    for ch in active_ch:
        try:
            details = challenges.get_details(db, ch["challenge_id"], gracz.id)
            enriched_challenges.append({
                **ch,
                "description": details.get("description", ""),
                "difficulty": details.get("difficulty", "średni"),
                "completion_conditions": details.get("completion_conditions", {}),
                "reward": details.get("reward", {}),
            })
        except AppError:
            enriched_challenges.append(ch)

    # Gra pobrała dane: portal pokazuje tę datę jako „Ostatnia synchronizacja”.
    gracz.data_ostatniej_synchronizacji = datetime.now(UTC)
    db.commit()

    return {
        "player": {
            "id": str(gracz.id),
            "username": gracz.nazwa_uzytkownika,
            "email": gracz.email,
        },
        "wallet": {
            "gems": gems,
            "special_gems": 0,
        },
        # Puste pola (gracz jeszcze ich nie ustawił) pomijamy, żeby gra została przy swoich domyślnych.
        "settings": {k: v for k, v in player_settings.read(db, gracz.id).items() if v is not None},
        "appearance": {
            "active_skin": active_skin,
            "active_skin_id": active_skin_id,
            "active_color_name": active_color_name,
            "active_color_hex": active_color_hex,
            "active_color_id": active_color_id,
            "equipped_accessories": equipped_accessories,
            "equipped_accessories_detail": equipped_accessories_detail,
            "owned_items": owned_items,
        },
        "boosters": shop.owned_boosters_map(db, gracz.id),
        "challenges": enriched_challenges,
    }
