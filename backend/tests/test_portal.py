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


# 2.4
def test_my_challenges_are_private(client, engine):
    signup(client)
    client.post(f"/api/challenges/{challenge_id(engine, 'Pierwsze kroki')}/accept")
    item = client.get("/api/me/challenges").json()["items"][0]
    assert item["name"] == "Pierwsze kroki" and item["status"] == "Aktywne" and item["progress_percent"] == 0
    other = other_client()
    signup(other, "Basia")
    assert other.get("/api/me/challenges").json()["items"] == []


def test_a2_expired_participation_is_marked(client, engine):
    signup(client)
    wid = make_challenge(engine, "Krótkie")
    client.post(f"/api/challenges/{wid}/accept")
    execute(engine, "UPDATE wyzwanie SET data_zakonczenia = now() - interval '1 minute' WHERE id = :i", i=wid)
    assert client.get("/api/me/challenges").json()["items"][0]["status"] == "Wygasłe"
    assert execute(engine, "SELECT status FROM uczestnictwo_w_wyzwaniu").scalar() == "Wygasłe"


def test_a3_completed_stays_completed_after_end_date(client, engine):
    signup(client)
    wid = make_challenge(engine, "Ukończone")
    client.post(f"/api/challenges/{wid}/accept")
    execute(engine, "UPDATE uczestnictwo_w_wyzwaniu SET status = 'Ukończone', postep_procent = 100")
    execute(engine, "UPDATE wyzwanie SET data_zakonczenia = now() - interval '1 minute' WHERE id = :i", i=wid)
    assert client.get("/api/me/challenges").json()["items"][0]["status"] == "Ukończone"


def test_attempts_and_best_score(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    client.post(f"/api/challenges/{wid}/accept")
    assert client.get(f"/api/me/challenges/{wid}/attempts").json() == {"best_score": None, "items": []}
    execute(engine, "UPDATE uczestnictwo_w_wyzwaniu SET najlepszy_wynik = 90")
    for score, when in ((50, "2026-01-01"), (90, "2026-01-02")):
        execute(
            engine,
            """INSERT INTO proba_wyzwania (uczestnictwo_id, wynik, data_proby, czy_zaliczona)
               SELECT id, :s, CAST(:d AS timestamptz), :s > 80 FROM uczestnictwo_w_wyzwaniu""",
            s=score, d=when,
        )
    body = client.get(f"/api/me/challenges/{wid}/attempts").json()
    assert body["best_score"] == 90
    assert [(i["score"], i["passed"]) for i in body["items"]] == [(90, True), (50, False)]


def test_attempts_of_another_player_are_hidden(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    client.post(f"/api/challenges/{wid}/accept")
    other = other_client()
    signup(other, "Basia")
    assert other.get(f"/api/me/challenges/{wid}/attempts").status_code == 404


# 2.3
def add_score(engine, gracz, score, when):
    execute(
        engine,
        "INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku) VALUES (:g, 'ogółem', :w, CAST(:d AS timestamptz))",
        g=gracz, w=score, d=when,
    )


def test_ranking_order_and_tie_break(client, engine):
    kubas = signup(client)
    other = other_client()
    basia = signup(other, "Basia")
    add_score(engine, kubas, 500, "2026-11-02")
    add_score(engine, basia, 500, "2026-11-01")
    body = client.get("/api/ranking").json()
    assert [(i["position"], i["username"]) for i in body["items"]] == [(1, "Basia"), (2, "Kubas")]
    assert body["me"] == {"position": 2, "score": 500}


def test_a2_ranking_me_is_null_without_score(client):
    signup(client)
    assert client.get("/api/ranking").json()["me"] is None


def test_a1_ranking_limits_to_100_and_reports_me_outside(client, engine):
    kubas = signup(client)
    execute(
        engine,
        """WITH nowi AS (
             INSERT INTO gracz (nazwa_uzytkownika, email, skrot_hasla)
             SELECT 'gracz' || n, 'g' || n || '@example.com', 'x' FROM generate_series(1, 120) n RETURNING id)
           INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku)
           SELECT id, 'ogółem', 1000, now() FROM nowi""",
    )
    add_score(engine, kubas, 1, "2026-11-01")
    body = client.get("/api/ranking").json()
    assert len(body["items"]) == 100
    assert kubas not in {i["player_id"] for i in body["items"]}
    assert body["me"] == {"position": 121, "score": 1}


# Profil publiczny
def test_public_profile_hides_private_data(client):
    signup(client)
    other = other_client()
    basia = signup(other, "Basia")
    response = client.get(f"/api/players/{basia}")
    assert response.status_code == 200
    assert response.json()["username"] == "Basia"
    assert response.json()["statistics"]["levels_completed"] == 0
    assert "email" not in response.text and "skrot" not in response.text


def test_public_profile_missing_or_malformed(client):
    signup(client)
    assert client.get(f"/api/players/{uuid.uuid4()}").status_code == 404
    assert client.get("/api/players/nie-uuid").status_code == 422


# 8.6
def test_change_username_visible_in_ranking(client, engine):
    kubas = signup(client)
    add_score(engine, kubas, 10, "2026-11-01")
    response = client.patch("/api/me", json={"username": "NowaNazwa"})
    assert response.status_code == 200 and response.json()["username"] == "NowaNazwa"
    assert client.get("/api/ranking").json()["items"][0]["username"] == "NowaNazwa"
    assert client.get("/api/me").json()["username"] == "NowaNazwa"


@pytest.mark.parametrize("name,status,code", [("BASIA", 409, "username_taken"), ("ab", 422, "validation_error")])
def test_a1_change_username_rejected(client, engine, name, status, code):
    signup(client)
    other = other_client()
    signup(other, "Basia")
    response = client.patch("/api/me", json={"username": name})
    assert response.status_code == status
    assert response.json()["error"]["code"] == code
    assert client.get("/api/me").json()["username"] == "Kubas"


def test_keep_own_username_is_allowed(client):
    signup(client)
    assert client.patch("/api/me", json={"username": "kubas"}).status_code == 200


def test_a4_expired_session_cannot_change_data(client, engine):
    signup(client)
    execute(engine, "UPDATE sesja_logowania SET data_wygasniecia = now() - interval '1 second'")
    assert client.patch("/api/me", json={"username": "Nowa"}).status_code == 401
    assert execute(engine, "SELECT nazwa_uzytkownika FROM gracz").scalar() == "Kubas"


@pytest.fixture
def sent(monkeypatch):
    messages = []
    monkeypatch.setattr(mailer, "send_email", lambda to, subject, body: messages.append((to, body)))
    return messages


def token_from(messages):
    return re.search(r"token=(\S+)", messages[-1][1]).group(1)


def request_email(client, email="nowy@example.com", password=PASSWORD):
    return client.post("/api/me/email", json={"new_email": email, "current_password": password})


def test_a2_change_email_after_confirmation(client, engine, sent):
    signup(client)
    assert request_email(client).status_code == 202
    assert sent[0][0] == "nowy@example.com"
    assert client.get("/api/me").json()["email"] == "kubas@example.com"
    token = token_from(sent)
    assert execute(engine, "SELECT skrot_wartosci FROM token_zmiany_emaila").scalar() != token
    response = client.post("/api/me/email/confirm", json={"token": token})
    assert response.status_code == 200 and response.json()["email"] == "nowy@example.com"
    client.post("/api/auth/logout")
    assert client.post("/api/auth/login", json={"email": "nowy@example.com", "password": PASSWORD}).status_code == 200


def test_change_email_wrong_password(client, sent):
    signup(client)
    response = request_email(client, password="Zle12345")
    assert response.status_code == 403
    assert response.json()["error"]["code"] == "invalid_password"
    assert sent == []


def test_change_email_taken(client, sent):
    signup(client)
    other = other_client()
    signup(other, "Basia")
    assert request_email(client, "BASIA@example.com").json()["error"]["code"] == "email_taken"


def test_email_token_single_use_and_latest_only(client, sent):
    signup(client)
    request_email(client, "pierwszy@example.com")
    old = token_from(sent)
    request_email(client, "drugi@example.com")
    new = token_from(sent)
    assert client.post("/api/me/email/confirm", json={"token": old}).status_code == 400
    assert client.post("/api/me/email/confirm", json={"token": new}).json()["email"] == "drugi@example.com"
    assert client.post("/api/me/email/confirm", json={"token": new}).json()["error"]["code"] == "invalid_token"


def test_email_token_expired(client, engine, sent):
    signup(client)
    request_email(client)
    execute(engine, "UPDATE token_zmiany_emaila SET data_waznosci = now() - interval '1 second'")
    assert client.post("/api/me/email/confirm", json={"token": token_from(sent)}).status_code == 400


def test_email_token_of_another_player(client, sent):
    signup(client)
    request_email(client)
    other = other_client()
    signup(other, "Basia")
    assert other.post("/api/me/email/confirm", json={"token": token_from(sent)}).status_code == 400


def test_email_confirm_conflict_when_address_was_taken_meanwhile(client, sent):
    signup(client)
    request_email(client, "wspolny@example.com")
    other = other_client()
    other.post("/api/auth/register", json={"username": "Basia", "email": "wspolny@example.com", "password": PASSWORD})
    response = client.post("/api/me/email/confirm", json={"token": token_from(sent)})
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_taken"
    assert client.get("/api/me").json()["email"] == "kubas@example.com"


def test_email_failure_returns_503_and_keeps_old_link(client, engine, monkeypatch):
    signup(client)
    monkeypatch.setenv("EMAIL_BACKEND", "none")
    from app.core.config import get_settings

    get_settings.cache_clear()
    response = request_email(client)
    assert response.status_code == 503
    assert response.json()["error"]["code"] == "email_unavailable"
    assert execute(engine, "SELECT count(*) FROM token_zmiany_emaila").scalar() == 0


def test_change_password(client):
    signup(client)
    payload = {"current_password": PASSWORD, "new_password": "NoweHaslo99"}
    assert client.post("/api/me/password", json=payload).status_code == 204
    client.post("/api/auth/logout")
    assert client.post("/api/auth/login", json={"email": "kubas@example.com", "password": PASSWORD}).status_code == 401
    assert client.post("/api/auth/login", json={"email": "kubas@example.com", "password": "NoweHaslo99"}).status_code == 200


@pytest.mark.parametrize(
    "payload,status,code",
    [
        ({"current_password": "Zle12345", "new_password": "NoweHaslo99"}, 403, "invalid_password"),
        ({"current_password": PASSWORD, "new_password": "krotkie"}, 422, "weak_password"),
    ],
)
def test_change_password_rejected(client, payload, status, code):
    signup(client)
    response = client.post("/api/me/password", json=payload)
    assert response.status_code == status
    assert response.json()["error"]["code"] == code


# Przegląd bezpieczeństwa
@pytest.mark.parametrize("path", ["/api/challenges/99999999999999999999", "/api/challenges/0", "/api/me/challenges/99999999999999999999/attempts"])
def test_out_of_range_id_returns_validation_error(client, path):
    signup(client)
    response = client.get(path)
    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


@pytest.mark.parametrize("name", ["ab\x00cd", "ab\ncd"])
def test_control_characters_in_username_are_rejected(client, name):
    response = client.post(
        "/api/auth/register", json={"username": name, "email": "a@example.com", "password": PASSWORD}
    )
    assert response.status_code == 422
    signup(client)
    assert client.patch("/api/me", json={"username": name}).status_code == 422


def test_dates_are_returned_in_utc(client, engine):
    signup(client)
    wid = challenge_id(engine, "Pierwsze kroki")
    assert client.get(f"/api/challenges/{wid}").json()["ends_at"].endswith(("Z", "+00:00"))


def test_portal_origin_can_post(client):
    response = client.post("/api/auth/logout", headers={"Origin": "http://localhost:5173"})
    assert response.status_code == 204


def test_password_change_attempts_are_limited(client, engine):
    signup(client)
    bad = {"current_password": "Zle12345", "new_password": "NoweHaslo99"}
    for _ in range(5):
        assert client.post("/api/me/password", json=bad).status_code == 403
    good = {"current_password": PASSWORD, "new_password": "NoweHaslo99"}
    response = client.post("/api/me/password", json=good)
    assert response.status_code == 429
    assert response.json()["error"]["code"] == "login_locked"
    execute(engine, "UPDATE gracz SET zablokowany_do = now() - interval '1 second'")
    assert client.post("/api/me/password", json=good).status_code == 204


def test_correct_password_resets_counter_on_email_change(client, engine, sent):
    signup(client)
    request_email(client, password="Zle12345")
    assert execute(engine, "SELECT liczba_nieudanych_logowan FROM gracz").scalar() == 1
    assert request_email(client).status_code == 202
    assert execute(engine, "SELECT liczba_nieudanych_logowan FROM gracz").scalar() == 0
