"""Testy 8.1 na prawdziwym PostgreSQL. Baza z TEST_DATABASE_URL jest czyszczona."""
import os

import pytest
from sqlalchemy import text

from app.core.security import token_hash

from .conftest import clear_caches

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
PASSWORD = "Tajne1234"


def register(client, username="Kubas", email="kubas@example.com", password=PASSWORD):
    return client.post("/api/auth/register", json={"username": username, "email": email, "password": password})


def login(client, email="kubas@example.com", password=PASSWORD):
    return client.post("/api/auth/login", json={"email": email, "password": password})


def scalar(engine, sql, **params):
    with engine.connect() as connection:
        return connection.scalar(text(sql), params)


def test_register_creates_profile_and_logs_in(client, engine):
    response = register(client)
    assert response.status_code == 201
    body = response.json()
    assert body["username"] == "Kubas" and body["email"] == "kubas@example.com"
    gracz = body["id"]
    assert scalar(engine, "SELECT count(*) FROM statystyki_gracza WHERE gracz_id = :g", g=gracz) == 1
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza WHERE gracz_id = :g", g=gracz) == 0
    assert scalar(engine, "SELECT count(*) FROM wyglad_postaci WHERE gracz_id = :g", g=gracz) == 1
    assert scalar(engine, "SELECT count(*) FROM posiadany_element WHERE gracz_id = :g", g=gracz) == 2
    assert client.get("/api/me").json()["id"] == gracz


def test_password_and_token_are_not_stored_in_plain_text(client, engine):
    response = register(client)
    assert scalar(engine, "SELECT skrot_hasla FROM gracz").startswith("$argon2id$")
    token = response.cookies["jr_session"]
    assert scalar(engine, "SELECT skrot_tokenu FROM sesja_logowania") == token_hash(token)


def test_session_cookie_flags(client):
    cookie = register(client).headers["set-cookie"].lower()
    assert "httponly" in cookie and "samesite=lax" in cookie and "secure" not in cookie


def test_session_cookie_is_secure_outside_development(client, monkeypatch):
    monkeypatch.setenv("ENVIRONMENT", "production")
    clear_caches()
    assert "secure" in register(client).headers["set-cookie"].lower()


@pytest.mark.parametrize("username", ["Kubas", "KUBAS"])
def test_a1_username_taken(client, username):
    register(client)
    response = register(client, username=username, email="inny@example.com")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "username_taken"


@pytest.mark.parametrize("email", ["kubas@example.com", "KUBAS@example.com"])
def test_a2_email_taken(client, email):
    register(client)
    response = register(client, username="Inny", email=email)
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_taken"


def test_failed_registration_leaves_no_data(client, engine):
    register(client)
    register(client, username="Inny")
    assert scalar(engine, "SELECT count(*) FROM gracz") == 1
    assert scalar(engine, "SELECT count(*) FROM portfel_gracza") == 1


@pytest.mark.parametrize("password", ["Krotk1", "samelitery", "12345678"])
def test_a3_weak_password(client, engine, password):
    response = register(client, password=password)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "weak_password"
    assert password not in response.text
    assert scalar(engine, "SELECT count(*) FROM gracz") == 0


@pytest.mark.parametrize(
    "fields", [{"username": "ab"}, {"username": "x" * 33}, {"email": "to-nie-email"}]
)
def test_invalid_registration_data(client, fields):
    payload = {"username": "Kubas", "email": "kubas@example.com", "password": PASSWORD, **fields}
    response = client.post("/api/auth/register", json=payload)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_a4_login_with_existing_account(client, engine):
    register(client)
    client.post("/api/auth/logout")
    response = login(client, email="KUBAS@example.com")
    assert response.status_code == 200
    assert response.json()["username"] == "Kubas"
    assert client.get("/api/me").status_code == 200
    assert scalar(engine, "SELECT count(*) FROM sesja_logowania WHERE urzadzenie = 'przeglądarka'") == 2


def test_wrong_password_and_unknown_email_look_the_same(client):
    register(client)
    client.post("/api/auth/logout")
    wrong = login(client, password="Zle12345")
    unknown = login(client, email="brak@example.com")
    assert wrong.status_code == unknown.status_code == 401
    assert wrong.json() == unknown.json()
    assert "jr_session" not in client.cookies


def test_login_locks_after_five_failures_and_unlocks(client, engine):
    register(client)
    client.post("/api/auth/logout")
    for _ in range(5):
        assert login(client, password="Zle12345").status_code == 401
    locked = login(client)
    assert locked.status_code == 429
    assert locked.json()["error"]["code"] == "login_locked"

    with engine.begin() as connection:
        connection.execute(text("UPDATE gracz SET zablokowany_do = now() - interval '1 second'"))
    assert login(client).status_code == 200
    assert scalar(engine, "SELECT zablokowany_do FROM gracz") is None


def test_success_resets_failed_counter(client, engine):
    register(client)
    client.post("/api/auth/logout")
    login(client, password="Zle12345")
    login(client)
    assert scalar(engine, "SELECT liczba_nieudanych_logowan FROM gracz") == 0


def test_blocked_account_cannot_log_in_and_loses_session(client, engine):
    register(client)
    with engine.begin() as connection:
        connection.execute(text("UPDATE gracz SET status_konta = 'zablokowane'"))
    assert client.get("/api/me").status_code == 401
    response = login(client)
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "account_blocked"


def test_me_requires_session(client):
    response = client.get("/api/me")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


def test_forged_token_is_rejected(client):
    client.cookies.set("jr_session", "wymyslony-token")
    assert client.get("/api/me").status_code == 401


def test_expired_session_is_rejected(client, engine):
    register(client)
    with engine.begin() as connection:
        connection.execute(text("UPDATE sesja_logowania SET data_wygasniecia = now() - interval '1 second'"))
    assert client.get("/api/me").status_code == 401


def test_logout_invalidates_session_on_server(client, engine):
    token = register(client).cookies["jr_session"]
    response = client.post("/api/auth/logout")
    assert response.status_code == 204
    assert "jr_session" not in client.cookies
    assert scalar(engine, "SELECT data_uniewaznienia FROM sesja_logowania") is not None
    client.cookies.set("jr_session", token)
    assert client.get("/api/me").status_code == 401


def test_logout_without_session_is_allowed(client):
    assert client.post("/api/auth/logout").status_code == 204


def test_deleted_player_loses_session(client, engine):
    register(client)
    with engine.begin() as connection:
        connection.execute(text("DELETE FROM gracz"))
    assert client.get("/api/me").status_code == 401
