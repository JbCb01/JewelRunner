"""Parowanie gry z kontem kodem z portalu i logowanie gry tokenem Bearer."""
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import UTC, datetime, timedelta

import pytest
from sqlalchemy import text

from app.core.security import token_hash
from app.services import pairing

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
PASSWORD = "Tajne1234"


@pytest.fixture(autouse=True)
def reset_limiter():
    pairing.failures.reset()
    yield
    pairing.failures.reset()


def scalar(engine, sql, **params):
    with engine.connect() as connection:
        return connection.scalar(text(sql), params)


def register(client, username="Kubas", email="kubas@example.com"):
    response = client.post("/api/auth/register", json={"username": username, "email": email, "password": PASSWORD})
    assert response.status_code == 201
    return response


def new_code(client):
    response = client.post("/api/me/pairing-code")
    assert response.status_code == 201
    return response.json()["code"]


def pair(client, code):
    # Gra nie ma cookie portalu, więc każde żądanie gry wysyłamy bez ciasteczek.
    client.cookies.clear()
    return client.post("/api/auth/pair", json={"code": code})


def test_code_format_and_expiry(client):
    register(client)
    response = client.post("/api/me/pairing-code")
    body = response.json()
    assert len(body["code"]) == 6
    assert set(body["code"]) <= set(pairing.ALPHABET)
    expires = datetime.fromisoformat(body["expires_at"])
    assert timedelta(minutes=4) < expires - datetime.now(UTC) <= timedelta(minutes=5)


def test_code_requires_login(client):
    assert client.post("/api/me/pairing-code").status_code == 401


def test_code_is_stored_as_hash(client, engine):
    register(client)
    code = new_code(client)
    assert scalar(engine, "SELECT count(*) FROM kod_parowania WHERE skrot_kodu = :h", h=token_hash(code)) == 1
    assert scalar(engine, "SELECT count(*) FROM kod_parowania WHERE skrot_kodu = :c", c=code) == 0


def test_pair_creates_game_session_and_bearer_works(client, engine):
    register(client)
    code = new_code(client)

    response = pair(client, code)
    assert response.status_code == 200
    body = response.json()
    assert body["player"]["username"] == "Kubas"
    assert "set-cookie" not in response.headers
    assert scalar(engine, "SELECT urzadzenie FROM sesja_logowania WHERE skrot_tokenu = :h", h=token_hash(body["token"])) == "gra"

    me = client.get("/api/me", headers={"Authorization": f"Bearer {body['token']}"})
    assert me.status_code == 200
    assert me.json()["username"] == "Kubas"


def test_code_is_case_and_separator_insensitive(client):
    register(client)
    code = new_code(client)
    assert pair(client, f" {code[:3].lower()}-{code[3:].lower()} ").status_code == 200


def test_code_works_only_once(client):
    register(client)
    code = new_code(client)
    assert pair(client, code).status_code == 200
    second = pair(client, code)
    assert second.status_code == 400
    assert second.json()["error"]["code"] == "invalid_pairing_code"


def test_concurrent_redeem_gives_one_session(client, engine):
    register(client)
    code = new_code(client)
    client.cookies.clear()
    with ThreadPoolExecutor(max_workers=4) as pool:
        codes = list(pool.map(lambda _: client.post("/api/auth/pair", json={"code": code}).status_code, range(4)))
    assert sorted(codes) == [200, 400, 400, 400]
    assert scalar(engine, "SELECT count(*) FROM sesja_logowania WHERE urzadzenie = 'gra'") == 1


def test_expired_code_is_rejected(client, engine):
    register(client)
    code = new_code(client)
    with engine.begin() as connection:
        connection.execute(
            text("UPDATE kod_parowania SET data_utworzenia = now() - interval '10 minutes', data_wygasniecia = now() - interval '1 second'")
        )
    assert pair(client, code).status_code == 400


def test_new_code_invalidates_previous(client):
    register(client)
    old = new_code(client)
    new = new_code(client)
    assert pair(client, old).status_code == 400
    assert pair(client, new).status_code == 200


@pytest.mark.parametrize("code", ["", "ABC", "ABCDEFGH", "ZZZZZZ"])
def test_wrong_codes(client, code):
    response = pair(client, code)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_pairing_code"


def test_too_many_wrong_codes_are_limited(client):
    register(client)
    code = new_code(client)
    for _ in range(pairing.MAX_FAILURES):
        assert pair(client, "ZZZZZZ").status_code == 400
    locked = pair(client, code)
    assert locked.status_code == 429
    assert locked.json()["error"]["code"] == "pairing_locked"


def test_blocked_account_cannot_pair(client, engine):
    register(client)
    code = new_code(client)
    with engine.begin() as connection:
        connection.execute(text("UPDATE gracz SET status_konta = 'zablokowane'"))
    response = pair(client, code)
    assert response.status_code == 403
    assert scalar(engine, "SELECT count(*) FROM sesja_logowania WHERE urzadzenie = 'gra'") == 0


def test_game_logout_with_bearer_invalidates_session(client, engine):
    register(client)
    token = pair(client, new_code(client)).json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    assert client.post("/api/auth/logout", headers=headers).status_code == 204
    assert client.get("/api/me", headers=headers).status_code == 401
    assert scalar(engine, "SELECT data_uniewaznienia IS NOT NULL FROM sesja_logowania WHERE skrot_tokenu = :h", h=token_hash(token))


def test_portal_session_survives_game_pairing(client):
    register(client)
    code = new_code(client)
    portal_cookie = client.cookies.get("jr_session")
    pair(client, code)
    client.cookies.set("jr_session", portal_cookie)
    assert client.get("/api/me").status_code == 200


@pytest.mark.parametrize("header", ["Bearer zlytoken", "Basic abc", "Bearer "])
def test_bad_authorization_header(client, header):
    assert client.get("/api/me", headers={"Authorization": header}).status_code == 401


def test_deleted_player_codes_are_removed(client, engine):
    register(client)
    new_code(client)
    with engine.begin() as connection:
        connection.execute(text("DELETE FROM gracz"))
    assert scalar(engine, "SELECT count(*) FROM kod_parowania") == 0
