"""Status połączenia z grą, zapis gry w chmurze (8.2) i saldo klejnotów z gry z kolejką offline."""
import os
import time
from concurrent.futures import ThreadPoolExecutor

import pytest
from sqlalchemy import text

from app.services import pairing
from app.services.game_save import KEEP_SAVES, checksum
from app.services.wallet import MAX_GEMS_PER_DAY

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
PASSWORD = "Tajne1234"


def scalar(engine, sql, **params):
    with engine.connect() as connection:
        return connection.scalar(text(sql), params)


@pytest.fixture(autouse=True)
def reset_limiter():
    pairing.failures.reset()


def register(client, username="Kubas", email="kubas@example.com"):
    response = client.post("/api/auth/register", json={"username": username, "email": email, "password": PASSWORD})
    assert response.status_code == 201


def game_headers(client):
    """Paruje grę i zwraca nagłówek z tokenem gry. Cookie portalu zostaje w kliencie."""
    code = client.post("/api/me/pairing-code").json()["code"]
    portal_cookie = client.cookies.get("jr_session")
    client.cookies.clear()
    token = client.post("/api/auth/pair", json={"code": code}).json()["token"]
    client.cookies.set("jr_session", portal_cookie)
    return {"Authorization": f"Bearer {token}"}


def save_body(level=1, checkpoint="cp-2", gems=12, saved_at=None, game_version="0.3.0", bad=False):
    saved_at = saved_at if saved_at is not None else int(time.time()) - 60
    digest = checksum(level, checkpoint, gems, saved_at, game_version)
    if bad:
        digest = "0" * 64
    return {
        "level": level, "checkpoint": checkpoint, "gems": gems,
        "saved_at": saved_at, "game_version": game_version, "checksum": digest,
    }


# ---------- status połączenia z grą w portalu


def test_me_shows_game_not_linked_before_pairing(client):
    register(client)
    body = client.get("/api/me").json()
    assert body["game_linked"] is False
    assert body["last_synced_at"] is None


def test_me_shows_linked_after_pairing_and_sync_time_after_game_state(client):
    register(client)
    headers = game_headers(client)
    assert client.get("/api/me").json()["game_linked"] is True
    assert client.get("/api/me/game-state", headers=headers).status_code == 200
    assert client.get("/api/me").json()["last_synced_at"] is not None


def test_game_logout_unlinks(client):
    register(client)
    headers = game_headers(client)
    client.post("/api/auth/logout", headers=headers)
    assert client.get("/api/me").json()["game_linked"] is False


# ---------- zapis gry w chmurze


def test_no_save_yet(client):
    register(client)
    assert client.get("/api/me/save").json() == {"save": None}


def test_save_requires_login(client):
    assert client.get("/api/me/save").status_code == 401
    assert client.put("/api/me/save", json=save_body()).status_code == 401


def test_save_and_load_from_another_device(client):
    register(client)
    body = save_body()
    stored = client.put("/api/me/save", json=body, headers=game_headers(client))
    assert stored.status_code == 200
    # Drugi komputer: nowe parowanie, nowy token, ten sam zapis.
    loaded = client.get("/api/me/save", headers=game_headers(client)).json()["save"]
    assert loaded["level"] == 1
    assert loaded["level_name"] == "Poziom 1"
    assert loaded["checkpoint"] == "cp-2"
    assert loaded["gems"] == 12
    assert loaded["saved_at"] == body["saved_at"]
    assert loaded["checksum"] == body["checksum"]


def test_a3_corrupted_save_is_rejected(client, engine):
    register(client)
    response = client.put("/api/me/save", json=save_body(bad=True))
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "corrupted_save"
    assert scalar(engine, "SELECT count(*) FROM zapis_gry") == 0


def test_a3_corrupted_row_is_skipped_and_previous_returned(client, engine):
    register(client)
    now = int(time.time())
    client.put("/api/me/save", json=save_body(gems=5, saved_at=now - 100))
    client.put("/api/me/save", json=save_body(gems=9, saved_at=now - 50))
    with engine.begin() as connection:
        connection.execute(text("UPDATE zapis_gry SET zebrane_klejnoty = 999 WHERE zebrane_klejnoty = 9"))
    assert client.get("/api/me/save").json()["save"]["gems"] == 5


def test_a2_newer_save_wins_and_older_gets_conflict(client):
    register(client)
    now = int(time.time())
    assert client.put("/api/me/save", json=save_body(gems=20, saved_at=now - 10)).status_code == 200
    older = client.put("/api/me/save", json=save_body(gems=3, saved_at=now - 500))
    assert older.status_code == 409
    error = older.json()["error"]
    assert error["code"] == "save_conflict"
    assert error["details"]["server_save"]["gems"] == 20
    assert client.get("/api/me/save").json()["save"]["gems"] == 20


def test_a2_player_can_force_own_save(client):
    register(client)
    now = int(time.time())
    client.put("/api/me/save", json=save_body(gems=20, saved_at=now - 10))
    forced = client.put("/api/me/save?force=true", json=save_body(gems=3, saved_at=now - 500))
    assert forced.status_code == 200
    # Wymuszony zapis jest starszy, więc odczyt dalej zwraca nowszy. Gra po force wysyła zapis z bieżącą datą.
    assert client.put("/api/me/save?force=true", json=save_body(gems=3, saved_at=now)).status_code == 200
    assert client.get("/api/me/save").json()["save"]["gems"] == 3


def test_same_save_sent_twice_is_not_duplicated(client, engine):
    register(client)
    body = save_body()
    assert client.put("/api/me/save", json=body).status_code == 200
    assert client.put("/api/me/save", json=body).status_code == 200
    assert scalar(engine, "SELECT count(*) FROM zapis_gry") == 1


def test_only_last_saves_are_kept(client, engine):
    register(client)
    now = int(time.time())
    for i in range(KEEP_SAVES + 3):
        assert client.put("/api/me/save", json=save_body(gems=i, saved_at=now - 1000 + i)).status_code == 200
    assert scalar(engine, "SELECT count(*) FROM zapis_gry") == KEEP_SAVES
    assert client.get("/api/me/save").json()["save"]["gems"] == KEEP_SAVES + 2


def test_unknown_level_and_future_time(client):
    register(client)
    unknown = client.put("/api/me/save", json=save_body(level=99))
    assert unknown.json()["error"]["code"] == "unknown_level"
    future = client.put("/api/me/save", json=save_body(saved_at=int(time.time()) + 3600))
    assert future.json()["error"]["code"] == "invalid_save_time"


@pytest.mark.parametrize(
    "change", [{"gems": -1}, {"checksum": "abc"}, {"game_version": ""}, {"level": 0}, {"checkpoint": "x" * 65}]
)
def test_invalid_save_fields(client, change):
    register(client)
    assert client.put("/api/me/save", json={**save_body(), **change}).status_code == 422


def test_saves_of_players_are_separate(client):
    register(client)
    client.put("/api/me/save", json=save_body(gems=7))
    client.post("/api/auth/logout")
    register(client, "Basia", "basia@example.com")
    assert client.get("/api/me/save").json() == {"save": None}


# ---------- saldo klejnotów z gry (kolejka offline)


def op(op_id, gems=10):
    return {"id": op_id, "gems": gems, "reason": "poziom"}


def test_wallet_starts_empty(client):
    register(client)
    assert client.get("/api/me/wallet").json() == {"gems": 0}


def test_wallet_sync_adds_gems(client, engine):
    register(client)
    response = client.post("/api/me/wallet/sync", json={"operations": [op("run-0001", 15), op("run-0002", 5)]})
    assert response.status_code == 200
    assert response.json() == {"gems": 20, "applied": ["run-0001", "run-0002"], "duplicates": []}
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza") == 20
    assert scalar(engine, "SELECT count(*) FROM transakcja WHERE klucz_idempotencji LIKE 'game:%'") == 2


def test_offline_queue_resent_is_not_counted_twice(client):
    register(client)
    client.post("/api/me/wallet/sync", json={"operations": [op("run-0001", 15)]})
    # Gra nie dostała odpowiedzi i wysyła całą kolejkę jeszcze raz, z nową operacją.
    response = client.post("/api/me/wallet/sync", json={"operations": [op("run-0001", 15), op("run-0002", 5)]})
    assert response.json() == {"gems": 20, "applied": ["run-0002"], "duplicates": ["run-0001"]}


def test_concurrent_sync_counts_once(client):
    register(client)
    body = {"operations": [op("run-0001", 15)]}
    with ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda _: client.post("/api/me/wallet/sync", json=body), range(4)))
    assert client.get("/api/me/wallet").json()["gems"] == 15


def test_wallet_balance_matches_game_state(client):
    register(client)
    client.post("/api/me/wallet/sync", json={"operations": [op("run-0001", 40)]})
    assert client.get("/api/me/game-state").json()["wallet"]["gems"] == 40


@pytest.mark.parametrize(
    "operations",
    [
        [op("run-0001", 0)],
        [op("run-0001", -5)],
        [op("run-0001", 501)],
        [op("x", 5)],
        [op("run-0001", 5), op("run-0001", 5)],
        [op(f"run-{i:04d}", 500) for i in range(5)],
        [op(f"run-{i:04d}", 1) for i in range(51)],
    ],
)
def test_wallet_rejects_invalid_operations(client, operations):
    register(client)
    assert client.post("/api/me/wallet/sync", json={"operations": operations}).status_code == 422
    assert client.get("/api/me/wallet").json()["gems"] == 0


def test_daily_gem_limit(client):
    register(client)
    batches = MAX_GEMS_PER_DAY // 2000
    for b in range(batches):
        ops = [op(f"run-{b:02d}-{i:02d}", 500) for i in range(4)]
        assert client.post("/api/me/wallet/sync", json={"operations": ops}).status_code == 200
    over = client.post("/api/me/wallet/sync", json={"operations": [op("run-over-1", 1)]})
    assert over.status_code == 429
    assert over.json()["error"]["code"] == "daily_gem_limit"
    assert client.get("/api/me/wallet").json()["gems"] == MAX_GEMS_PER_DAY
