"""Parowanie gry z kontem: portal generuje krótki kod, gra wymienia go na sesję.

Gracz nie wpisuje hasła w grze. Kod jest jednorazowy, ważny kilka minut i przechowywany
jako skrót, tak jak token sesji.
"""
import secrets
import threading
import time
from collections import deque
from datetime import UTC, datetime, timedelta

from sqlalchemy import delete, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.security import token_hash
from app.db.models import Gracz, KodParowania
from app.services.auth import DEVICE_GAME, create_session

# Bez znaków łatwych do pomylenia: 0/O, 1/I/L.
ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
CODE_LENGTH = 6
CODE_TTL = timedelta(minutes=5)

# Limit błędnych kodów dla całego serwera. 31^6 to ok. 887 mln kombinacji, więc przy tym
# limicie zgadnięcie aktywnego kodu w ciągu jego 5 minut ważności jest praktycznie niemożliwe.
MAX_FAILURES = 30
FAILURE_WINDOW_S = 60.0


class _FailureLimiter:
    """Prosty licznik w pamięci; API działa jako jeden proces uvicorn."""

    def __init__(self, limit: int, window_s: float) -> None:
        self.limit, self.window_s = limit, window_s
        self._times: deque[float] = deque()
        self._lock = threading.Lock()

    def _trim(self, now: float) -> None:
        while self._times and now - self._times[0] > self.window_s:
            self._times.popleft()

    def blocked(self) -> bool:
        with self._lock:
            self._trim(time.monotonic())
            return len(self._times) >= self.limit

    def record(self) -> None:
        with self._lock:
            now = time.monotonic()
            self._trim(now)
            self._times.append(now)

    def reset(self) -> None:
        with self._lock:
            self._times.clear()


failures = _FailureLimiter(MAX_FAILURES, FAILURE_WINDOW_S)


def normalize_code(code: str) -> str:
    """Gracz może wpisać małe litery, spacje lub myślnik, np. „abc-123”."""
    return "".join(char for char in code.upper() if char.isalnum())


def create_code(db: Session, gracz: Gracz) -> tuple[str, datetime]:
    """Tworzy nowy kod. Poprzednie kody gracza przestają działać."""
    now = datetime.now(UTC)
    db.execute(delete(KodParowania).where(KodParowania.gracz_id == gracz.id))
    # Sprzątanie starych kodów wszystkich graczy, żeby tabela nie rosła.
    db.execute(delete(KodParowania).where(KodParowania.data_wygasniecia < now - timedelta(days=1)))
    expires_at = now + CODE_TTL
    for _ in range(5):
        code = "".join(secrets.choice(ALPHABET) for _ in range(CODE_LENGTH))
        try:
            with db.begin_nested():
                db.add(KodParowania(gracz_id=gracz.id, skrot_kodu=token_hash(code), data_wygasniecia=expires_at))
            db.commit()
            return code, expires_at
        except IntegrityError:
            continue  # ten sam skrót istnieje już u innego gracza; losujemy jeszcze raz
    raise RuntimeError("Nie udało się wygenerować unikalnego kodu parowania.")


def redeem_code(db: Session, code: str) -> tuple[Gracz, str, datetime]:
    """Wymienia kod na sesję gry. Kod działa tylko raz, także przy dwóch równoczesnych próbach."""
    if failures.blocked():
        raise AppError(429, "pairing_locked", "Zbyt wiele prób. Spróbuj ponownie za minutę.")

    invalid = AppError(400, "invalid_pairing_code", "Kod jest nieprawidłowy lub wygasł. Wygeneruj nowy w portalu.")
    normalized = normalize_code(code)
    if len(normalized) != CODE_LENGTH:
        failures.record()
        raise invalid

    now = datetime.now(UTC)
    # Jedno UPDATE z warunkiem: z dwóch równoczesnych żądań tylko jedno dostanie wiersz.
    gracz_id = db.scalar(
        update(KodParowania)
        .where(
            KodParowania.skrot_kodu == token_hash(normalized),
            KodParowania.data_uzycia.is_(None),
            KodParowania.data_wygasniecia > now,
        )
        .values(data_uzycia=now)
        .returning(KodParowania.gracz_id)
    )
    gracz = db.get(Gracz, gracz_id) if gracz_id else None
    if gracz is None:
        db.rollback()
        failures.record()
        raise invalid
    if gracz.status_konta != "aktywne":
        db.commit()  # kod zostaje zużyty
        raise AppError(403, "account_blocked", "Konto zostało zablokowane.")

    gracz.data_ostatniego_logowania = now
    token, expires_at = create_session(db, gracz, DEVICE_GAME)
    db.commit()
    return gracz, token, expires_at

