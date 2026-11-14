"""Nagroda dzienna (7.5): raz dziennie, seria dni, reset po przerwie i nagroda specjalna."""
import os
from concurrent.futures import ThreadPoolExecutor
from datetime import date, timedelta

import pytest
from sqlalchemy import text

from app.services import daily_reward
from app.services.daily_reward import REWARDS, next_streak_day

URL = os.environ.get("TEST_DATABASE_URL")
PASSWORD = "Tajne1234"
DAY = date(2026, 11, 14)


def scalar(engine, sql, **params):
    with engine.connect() as connection:
        return connection.scalar(text(sql), params)


@pytest.fixture
def clock(monkeypatch):
    """Podmienia „dzisiaj” serwera, żeby testować kolejne dni."""
    current = {"day": DAY}
    monkeypatch.setattr(daily_reward, "today", lambda _db: current["day"])
    return current


def register(client):
    response = client.post(
        "/api/auth/register", json={"username": "Kubas", "email": "kubas@example.com", "password": PASSWORD}
    )
    assert response.status_code == 201


def claim(client):
    return client.post("/api/me/daily-reward/claim")


# Logika serii bez bazy.


@pytest.mark.parametrize(
    ("last", "streak", "expected"),
    [
        (None, 0, 1),
        (DAY - timedelta(days=1), 1, 2),
        (DAY - timedelta(days=1), 6, 7),
        (DAY - timedelta(days=1), 7, 1),
        (DAY - timedelta(days=2), 5, 1),
        (DAY - timedelta(days=30), 3, 1),
    ],
)
def test_next_streak_day(last, streak, expected):
    assert next_streak_day(last, streak, DAY) == expected


# Endpointy na prawdziwej bazie.

db = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")


@db
def test_requires_login(client):
    assert client.get("/api/me/daily-reward").status_code == 401
    assert claim(client).status_code == 401


@db
def test_new_player_sees_first_day(client, clock):
    register(client)
    body = client.get("/api/me/daily-reward").json()
    assert body["available"] is True
    assert body["streak_day"] == 1
    assert body["gems"] == REWARDS[1]
    assert body["last_claimed"] is None
    assert [r["day"] for r in body["rewards"]] == list(range(1, 8))
    assert [r["special"] for r in body["rewards"]] == [False] * 6 + [True]


@db
def test_claim_adds_gems_and_transaction(client, engine, clock):
    register(client)
    response = claim(client)
    assert response.status_code == 200
    body = response.json()
    assert body["balance"] == REWARDS[1]
    assert body["available"] is False
    assert body["last_claimed"] == DAY.isoformat()
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza") == REWARDS[1]
    assert scalar(engine, "SELECT dlugosc_serii FROM nagroda_dzienna") == 1
    assert scalar(engine, "SELECT kwota_klejnotow FROM transakcja WHERE typ = 'zmiana stanu konta'") == REWARDS[1]


@db
def test_a1_second_claim_same_day_is_rejected(client, engine, clock):
    register(client)
    assert claim(client).status_code == 200
    second = claim(client)
    assert second.status_code == 409
    assert second.json()["error"]["code"] == "daily_reward_claimed"
    assert client.get("/api/me/daily-reward").json()["available"] is False
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza") == REWARDS[1]


@db
def test_concurrent_claims_pay_once(client, engine, clock):
    register(client)
    with ThreadPoolExecutor(max_workers=4) as pool:
        codes = list(pool.map(lambda _: claim(client).status_code, range(4)))
    assert sorted(codes) == [200, 409, 409, 409]
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza") == REWARDS[1]
    assert scalar(engine, "SELECT count(*) FROM transakcja") == 1


@db
def test_streak_grows_daily_and_restarts_after_special(client, engine, clock):
    register(client)
    total = 0
    for day in range(1, 8):
        body = claim(client).json()
        assert body["streak_day"] == day
        assert body["special"] is (day == 7)
        total += REWARDS[day]
        clock["day"] += timedelta(days=1)
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza") == total
    # A3: po 7 dniach seria zaczyna się od nowa
    assert claim(client).json()["streak_day"] == 1


@db
def test_a2_break_resets_streak(client, clock):
    register(client)
    claim(client)
    clock["day"] += timedelta(days=1)
    assert claim(client).json()["streak_day"] == 2
    clock["day"] += timedelta(days=2)
    preview = client.get("/api/me/daily-reward").json()
    assert preview["streak_day"] == 1
    assert claim(client).json()["streak_day"] == 1


@db
def test_a4_reward_waits_until_end_of_day(client, clock):
    """Zamknięcie powiadomienia niczego nie zapisuje; nagrodę można odebrać później tego dnia."""
    register(client)
    for _ in range(3):
        assert client.get("/api/me/daily-reward").json()["available"] is True
    assert claim(client).status_code == 200


@db
def test_server_today_uses_database_clock(client, engine):
    register(client)
    with engine.connect() as connection:
        expected = connection.scalar(text("SELECT (now() AT TIME ZONE 'Europe/Warsaw')::date"))
    assert client.get("/api/me/daily-reward").json()["today"] == expected.isoformat()


@db
def test_deleted_player_reward_is_removed(client, engine, clock):
    register(client)
    claim(client)
    with engine.begin() as connection:
        connection.execute(text("DELETE FROM gracz"))
    assert scalar(engine, "SELECT count(*) FROM nagroda_dzienna") == 0
