"""Testy historyjek 2.1, 2.2, 2.3, 2.4, 2.6 i 8.6 na prawdziwym PostgreSQL."""
import os
import re
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.main import create_app
from app.services import mailer

pytestmark = pytest.mark.skipif(not os.environ.get("TEST_DATABASE_URL"), reason="brak TEST_DATABASE_URL")
PASSWORD = "Tajne1234"


def signup(client, name="Kubas"):
    response = client.post(
        "/api/auth/register", json={"username": name, "email": f"{name.lower()}@example.com", "password": PASSWORD}
    )
    assert response.status_code == 201, response.text
    return response.json()["id"]


def other_client():
    return TestClient(create_app())


def execute(engine, sql, **params):
    with engine.begin() as connection:
        return connection.execute(text(sql), params)


def challenge_id(engine, name):
    return execute(engine, "SELECT id FROM wyzwanie WHERE nazwa = :n", n=name).scalar()


def make_challenge(engine, name, requirements="{}", start="-1 day", end="7 days", status="Aktywne"):
    return execute(
        engine,
        """INSERT INTO wyzwanie (nazwa, opis, poziom_trudnosci, poziom_id, warunki_udzialu, warunki_ukonczenia,
                                 nagroda_id, data_rozpoczecia, data_zakonczenia, status)
           SELECT :n, 'opis', 'łatwy', (SELECT id FROM poziom WHERE kolejnosc = 1), CAST(:r AS jsonb), '{"a": 1}',
                  (SELECT min(id) FROM nagroda), now() + CAST(:s AS interval), now() + CAST(:e AS interval), :st
           ON CONFLICT (nazwa) DO UPDATE SET data_rozpoczecia = EXCLUDED.data_rozpoczecia,
               data_zakonczenia = EXCLUDED.data_zakonczenia, status = EXCLUDED.status, warunki_udzialu = EXCLUDED.warunki_udzialu
           RETURNING id""",
        n=name, r=requirements, s=start, e=end, st=status,
    ).scalar()


@pytest.fixture(autouse=True)
def clean_extra_challenges(engine):
    yield
    execute(engine, "DELETE FROM gracz")
    execute(engine, "DELETE FROM wyzwanie WHERE opis = 'opis'")


@pytest.mark.parametrize(
    "method,path",
    [
        ("get", "/api/challenges"),
        ("get", "/api/challenges/1"),
        ("post", "/api/challenges/1/accept"),
        ("get", "/api/me/challenges"),
        ("get", "/api/me/challenges/1/attempts"),
        ("get", "/api/ranking"),
        ("get", f"/api/players/{uuid.uuid4()}"),
    ],
)
def test_endpoints_require_session(client, method, path):
    response = getattr(client, method)(path)
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "unauthorized"


# 2.1
def test_list_shows_only_available_challenges(client, engine):
    signup(client)
    make_challenge(engine, "Przyszłe", start="1 day", end="2 days")
    items = client.get("/api/challenges").json()["items"]
    names = {item["name"] for item in items}
    assert names == {"Pierwsze kroki", "Łowca klejnotów", "Mistrz czasu"}
    first = next(item for item in items if item["name"] == "Pierwsze kroki")
    assert first["difficulty"] == "łatwy"
    assert first["reward"] == {"type": "klejnoty", "gems": 50, "element_name": None, "booster_type": None}
    assert first["participation_status"] is None


def test_list_shows_element_reward_name(client):
    signup(client)
    items = client.get("/api/challenges").json()["items"]
    reward = next(item for item in items if item["name"] == "Mistrz czasu")["reward"]
    assert reward["type"] == "skórka" and reward["element_name"] == "Złoty biegacz"


def test_a3_list_marks_accepted_only_for_owner(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    client.post(f"/api/challenges/{wid}/accept")
    status = {i["id"]: i["participation_status"] for i in client.get("/api/challenges").json()["items"]}
    assert status[wid] == "Aktywne"
    other = other_client()
    signup(other, "Basia")
    status = {i["id"]: i["participation_status"] for i in other.get("/api/challenges").json()["items"]}
    assert status[wid] is None


# 2.6
def test_details(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    body = client.get(f"/api/challenges/{wid}").json()
    assert body["description"] == "Ukończ pierwszy poziom."
    assert body["level"] == "Poziom 1"
    assert body["completion_conditions"] == {"ukoncz_poziom": True}
    assert body["participation"] is None


@pytest.mark.parametrize("name", ["Akrobata", "Wyzwanie testowe"])
def test_a1_details_unavailable_for_expired_or_disabled(client, engine, name):
    signup(client)
    response = client.get(f"/api/challenges/{challenge_id(engine, name)}")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "challenge_unavailable"


def test_a1_details_unavailable_when_missing(client):
    signup(client)
    assert client.get("/api/challenges/999999").json()["error"]["code"] == "challenge_unavailable"


def test_a2_details_show_progress_after_accept(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    client.post(f"/api/challenges/{wid}/accept")
    assert client.get(f"/api/challenges/{wid}").json()["participation"] == {"status": "Aktywne", "progress_percent": 0}


# 2.2
def test_accept_returns_conditions(client, engine):
    signup(client)
    response = client.post(f"/api/challenges/{challenge_id(engine, 'Pierwsze kroki')}/accept")
    assert response.status_code == 201
    assert response.json()["status"] == "Aktywne"
    assert response.json()["completion_conditions"] == {"ukoncz_poziom": True}


def test_a1_accept_twice_keeps_one_participation(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    first = client.post(f"/api/challenges/{wid}/accept")
    second = client.post(f"/api/challenges/{wid}/accept")
    assert second.status_code == 200
    assert second.json()["accepted_at"] == first.json()["accepted_at"]
    assert execute(engine, "SELECT count(*) FROM uczestnictwo_w_wyzwaniu").scalar() == 1


@pytest.mark.parametrize("name", ["Akrobata", "Wyzwanie testowe"])
def test_a2_accept_unavailable_challenge(client, engine, name):
    signup(client)
    response = client.post(f"/api/challenges/{challenge_id(engine, name)}/accept")
    assert response.status_code == 404
    assert response.json()["error"]["code"] == "challenge_unavailable"
    assert execute(engine, "SELECT count(*) FROM uczestnictwo_w_wyzwaniu").scalar() == 0


def test_a3_accept_requires_unlocked_level(client, engine):
    gracz = signup(client)
    execute(
        engine,
        """INSERT INTO poziom (nazwa, kolejnosc, warunek_odblokowania, punkt_startowy)
           VALUES ('Poziom 2', 2, '{"poziom": 1}', '{}') ON CONFLICT (kolejnosc) DO NOTHING""",
    )
    wid = make_challenge(engine, "Wymagające", requirements='{"poziom_odblokowany": 2}')
    response = client.post(f"/api/challenges/{wid}/accept")
    assert response.status_code == 409
    error = response.json()["error"]
    assert error["code"] == "participation_requirements_not_met"
    assert error["details"] == {"poziom_odblokowany": 2}

    execute(
        engine,
        """INSERT INTO postep_poziomu (gracz_id, poziom_id, czy_odblokowany)
           SELECT :g, id, TRUE FROM poziom WHERE kolejnosc = 2""",
        g=gracz,
    )
    assert client.post(f"/api/challenges/{wid}/accept").status_code == 201


def test_a3_unknown_requirement_is_rejected(client, engine):
    signup(client)
    wid = make_challenge(engine, "Dziwne", requirements='{"cos_nowego": 1}')
    assert client.post(f"/api/challenges/{wid}/accept").status_code == 409


