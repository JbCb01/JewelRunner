"""Testy backendu dla sklepu (8), wzmocnień w grze (10), odbioru nagród (11),
sesji i odłączania gry (13), samouczka (14) oraz katalogu skórek (15)."""
import os
import uuid

import pytest
from sqlalchemy import text
from sqlalchemy.exc import OperationalError

from app.db.models import PortfelGracza

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
PASSWORD = "Tajne1234"


def scalar(engine, sql, **params):
    with engine.connect() as connection:
        return connection.scalar(text(sql), params)


def execute(engine, sql, **params):
    with engine.begin() as connection:
        connection.execute(text(sql), params)


@pytest.fixture(autouse=True)
def cleanup(engine):
    yield
    execute(engine, "DELETE FROM gracz")
    execute(engine, "UPDATE oferta_sklepu SET dostepnosc = TRUE")


def register(client, username="Kubas", email="kubas@example.com"):
    response = client.post("/api/auth/register", json={"username": username, "email": email, "password": PASSWORD})
    assert response.status_code == 201, response.text
    return response.json()["id"]


def set_gems(engine, player_id, gems):
    execute(engine, "UPDATE portfel_gracza SET liczba_klejnotow = :g WHERE gracz_id = :id", g=gems, id=player_id)


# ====================================================================== 8. Sklep


def test_shop_list_returns_offers_balance_and_owned(client, engine):
    player_id = register(client)
    set_gems(engine, player_id, 250)
    body = client.get("/api/shop").json()
    assert body["balance"] == 250
    assert [item["type"] for item in body["items"]] == ["tarcza", "podwójne punkty", "dodatkowe życie", "magnes"]
    assert all(item["owned"] == 0 for item in body["items"])

    # Niedostępna oferta nie jest zwracana.
    execute(engine, "UPDATE oferta_sklepu SET dostepnosc = FALSE WHERE wzmocnienie_id = (SELECT id FROM wzmocnienie WHERE typ = 'magnes')")
    types = [item["type"] for item in client.get("/api/shop").json()["items"]]
    assert "magnes" not in types


def test_shop_purchase_atomic_and_updates_wallet_owned_and_transaction(client, engine):
    player_id = register(client)
    set_gems(engine, player_id, 250)
    shield_id = scalar(engine, "SELECT id FROM wzmocnienie WHERE typ = 'tarcza'")

    res = client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-shield-0001"})
    assert res.status_code == 200, res.text
    body = res.json()
    assert body == {
        "booster_id": shield_id,
        "type": "tarcza",
        "price": 100,
        "balance": 150,
        "owned": 1,
        "duplicate": False,
    }
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza WHERE gracz_id = :id", id=player_id) == 150
    assert scalar(engine, "SELECT liczba FROM posiadane_wzmocnienie WHERE gracz_id = :id AND wzmocnienie_id = :b", id=player_id, b=shield_id) == 1
    assert scalar(engine, "SELECT kwota_klejnotow FROM transakcja WHERE gracz_id = :id AND typ = 'zakup w sklepie'", id=player_id) == -100


def test_shop_a1_insufficient_gems_reports_missing_amount(client, engine):
    player_id = register(client)
    set_gems(engine, player_id, 40)
    shield_id = scalar(engine, "SELECT id FROM wzmocnienie WHERE typ = 'tarcza'")

    res = client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-poor-0001"})
    assert res.status_code == 409
    err = res.json()["error"]
    assert err["code"] == "insufficient_gems"
    assert err["details"]["missing_gems"] == 60
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza WHERE gracz_id = :id", id=player_id) == 40
    assert scalar(engine, "SELECT count(*) FROM posiadane_wzmocnienie WHERE gracz_id = :id", id=player_id) == 0
    assert scalar(engine, "SELECT count(*) FROM transakcja WHERE gracz_id = :id", id=player_id) == 0


def test_shop_a2_db_failure_rolls_back_everything(client, engine, monkeypatch):
    player_id = register(client)
    set_gems(engine, player_id, 250)
    shield_id = scalar(engine, "SELECT id FROM wzmocnienie WHERE typ = 'tarcza'")

    from sqlalchemy.orm import Session

    original_commit = Session.commit

    def fail_commit(self):
        raise OperationalError("COMMIT", {}, Exception("simulated db error"))

    monkeypatch.setattr(Session, "commit", fail_commit)
    res = client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-fail-0001"})
    monkeypatch.setattr(Session, "commit", original_commit)

    assert res.status_code == 503
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza WHERE gracz_id = :id", id=player_id) == 250
    assert scalar(engine, "SELECT count(*) FROM posiadane_wzmocnienie WHERE gracz_id = :id", id=player_id) == 0
    assert scalar(engine, "SELECT count(*) FROM transakcja WHERE gracz_id = :id", id=player_id) == 0


def test_shop_a3_double_click_same_key_charges_once(client, engine):
    player_id = register(client)
    set_gems(engine, player_id, 250)
    shield_id = scalar(engine, "SELECT id FROM wzmocnienie WHERE typ = 'tarcza'")

    first = client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-dup-0001"})
    second = client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-dup-0001"})
    assert first.status_code == 200 and first.json()["duplicate"] is False
    assert second.status_code == 200 and second.json()["duplicate"] is True
    assert second.json()["balance"] == 150
    assert second.json()["owned"] == 1
    assert scalar(engine, "SELECT count(*) FROM transakcja WHERE gracz_id = :id AND typ = 'zakup w sklepie'", id=player_id) == 1


def test_shop_unavailable_offer_returns_404(client, engine):
    player_id = register(client)
    set_gems(engine, player_id, 500)
    magnet_id = scalar(engine, "SELECT id FROM wzmocnienie WHERE typ = 'magnes'")
    execute(engine, "UPDATE oferta_sklepu SET dostepnosc = FALSE WHERE wzmocnienie_id = :id", id=magnet_id)
    res = client.post("/api/shop/purchase", json={"booster_id": magnet_id, "idempotency_key": "buy-off-0001"})
    assert res.status_code == 404
    assert res.json()["error"]["code"] == "offer_unavailable"


# ====================================================================== 10. Wzmocnienia w grze


def test_game_state_returns_owned_boosters_and_use_is_idempotent(client, engine):
    player_id = register(client)
    set_gems(engine, player_id, 300)
    shield_id = scalar(engine, "SELECT id FROM wzmocnienie WHERE typ = 'tarcza'")
    client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-gs-0001"})
    client.post("/api/shop/purchase", json={"booster_id": shield_id, "idempotency_key": "buy-gs-0002"})

    state = client.get("/api/me/game-state").json()
    assert state["boosters"]["tarcza"] == 2
    assert state["boosters"]["magnes"] == 0

    first = client.post("/api/me/boosters/use", json={"operation_id": "USE-1763600000-0001", "booster_type": "tarcza"})
    assert first.status_code == 200
    assert first.json() == {"booster_type": "tarcza", "remaining": 1, "duplicate": False}

    # Powtórzone żądanie nie odejmuje drugi raz.
    retry = client.post("/api/me/boosters/use", json={"operation_id": "USE-1763600000-0001", "booster_type": "tarcza"})
    assert retry.status_code == 200
    assert retry.json() == {"booster_type": "tarcza", "remaining": 1, "duplicate": True}

    # Zużycie drugiej sztuki i próba użycia, gdy brak.
    second = client.post("/api/me/boosters/use", json={"operation_id": "USE-1763600000-0002", "booster_type": "tarcza"})
    assert second.json()["remaining"] == 0
    empty = client.post("/api/me/boosters/use", json={"operation_id": "USE-1763600000-0003", "booster_type": "tarcza"})
    assert empty.status_code == 409
    assert empty.json()["error"]["code"] == "booster_not_owned"

    unknown = client.post("/api/me/boosters/use", json={"operation_id": "USE-1763600000-0004", "booster_type": "laser"})
    assert unknown.status_code == 422
    assert unknown.json()["error"]["code"] == "unknown_booster"


# ====================================================================== 11. Odbiór nagrody za wyzwanie


def _complete_challenge(engine, player_id, challenge_name):
    cid = scalar(engine, "SELECT id FROM wyzwanie WHERE nazwa = :n", n=challenge_name)
    execute(
        engine,
        """INSERT INTO uczestnictwo_w_wyzwaniu (gracz_id, wyzwanie_id, status, postep_procent, najlepszy_wynik, status_nagrody)
           VALUES (:g, :c, 'Ukończone', 100, 500, 'Do odebrania')""",
        g=player_id, c=cid,
    )
    return cid


def test_claim_gems_reward_once_and_records_transaction(client, engine):
    player_id = register(client)
    cid = _complete_challenge(engine, player_id, "Pierwsze kroki")

    mine = client.get("/api/me/challenges").json()["items"][0]
    assert mine["reward_status"] == "Do odebrania"
    details = client.get(f"/api/challenges/{cid}").json()
    assert details["reward_status"] == "Do odebrania"

    res = client.post(f"/api/me/challenges/{cid}/claim")
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["reward_status"] == "Odebrana"
    assert body["gems_awarded"] == 50
    assert body["balance"] == 50
    assert body["converted_to_gems"] is False

    # Ponowny odbiór zablokowany.
    again = client.post(f"/api/me/challenges/{cid}/claim")
    assert again.status_code == 409
    assert again.json()["error"]["code"] == "reward_already_claimed"
    assert scalar(engine, "SELECT liczba_klejnotow FROM portfel_gracza WHERE gracz_id = :id", id=player_id) == 50
    assert scalar(engine, "SELECT count(*) FROM transakcja WHERE gracz_id = :id AND typ = 'odbiór nagrody'", id=player_id) == 1


def test_claim_element_reward_and_duplicate_converts_to_gems(client, engine):
    player_id = register(client)
    cid = _complete_challenge(engine, player_id, "Mistrz czasu")

    res = client.post(f"/api/me/challenges/{cid}/claim")
    assert res.status_code == 200
    body = res.json()
    assert body["reward"]["type"] == "skórka"
    assert body["reward"]["element_name"] == "Złoty biegacz"
    assert body["converted_to_gems"] is False
    assert body["gems_awarded"] == 0
    assert any(i["name"] == "Złoty biegacz" and i["owned"] for i in client.get("/api/me/appearance").json()["catalog"])

    # Drugi gracz już ma skórkę przed odbiorem -> dostaje równowartość w klejnotach.
    client.post("/api/auth/logout")
    player2 = register(client, "Basia", "basia@example.com")
    skin_id = scalar(engine, "SELECT id FROM element_personalizacji WHERE nazwa = 'Złoty biegacz'")
    execute(engine, "INSERT INTO posiadany_element (gracz_id, element_id) VALUES (:g, :e)", g=player2, e=skin_id)
    cid2 = _complete_challenge(engine, player2, "Mistrz czasu")

    res2 = client.post(f"/api/me/challenges/{cid2}/claim")
    assert res2.status_code == 200
    body2 = res2.json()
    assert body2["converted_to_gems"] is True
    assert body2["gems_awarded"] == 100
    assert body2["balance"] == 100


def test_claim_booster_reward_adds_owned_booster(client, engine):
    player_id = register(client)
    cid = _complete_challenge(engine, player_id, "Akrobata")
    res = client.post(f"/api/me/challenges/{cid}/claim")
    assert res.status_code == 200
    assert res.json()["reward"]["type"] == "wzmocnienie"
    assert client.get("/api/me/game-state").json()["boosters"]["tarcza"] == 1


def test_claim_not_completed_challenge_returns_409(client, engine):
    register(client)
    cid = scalar(engine, "SELECT id FROM wyzwanie WHERE nazwa = 'Pierwsze kroki'")
    client.post(f"/api/challenges/{cid}/accept")
    res = client.post(f"/api/me/challenges/{cid}/claim")
    assert res.status_code == 409
    assert res.json()["error"]["code"] == "reward_not_available"


# ====================================================================== 13. Sesje i odłączanie gry


def test_list_and_revoke_game_session(client):
    register(client)
    code = client.post("/api/me/pairing-code").json()["code"]
    portal_cookie = client.cookies.get("jr_session")
    client.cookies.clear()
    game_token = client.post("/api/auth/pair", json={"code": code}).json()["token"]

    client.cookies.set("jr_session", portal_cookie)
    assert client.get("/api/me").json()["game_linked"] is True
    sessions = client.get("/api/me/sessions").json()["items"]
    assert len(sessions) == 2
    game_session = next(s for s in sessions if s["device"] == "gra")
    browser_session = next(s for s in sessions if s["device"] == "przeglądarka")
    assert game_session["is_current"] is False
    assert browser_session["is_current"] is True

    delete_res = client.delete(f"/api/me/sessions/{game_session['id']}")
    assert delete_res.status_code == 204
    assert client.get("/api/me").json()["game_linked"] is False
    assert client.delete(f"/api/me/sessions/{game_session['id']}").status_code == 404
    assert client.delete(f"/api/me/sessions/{uuid.uuid4()}").status_code == 404

    # Token gry przestał działać.
    client.cookies.clear()
    assert client.get("/api/me", headers={"Authorization": f"Bearer {game_token}"}).status_code == 401


# ====================================================================== 14. Samouczek


def test_complete_tutorial_updates_stats_and_is_idempotent(client):
    register(client)
    assert client.get("/api/me/stats").json()["overall"]["tutorial_completed"] is False
    res = client.post("/api/me/tutorial/complete")
    assert res.status_code == 200
    assert res.json() == {"tutorial_completed": True}
    assert client.get("/api/me/stats").json()["overall"]["tutorial_completed"] is True
    # Powtórne wywołanie nadal zwraca 200.
    assert client.post("/api/me/tutorial/complete").status_code == 200


# ====================================================================== 15. Katalog skórek


def test_skins_catalog_migration_populated_team_skins(client):
    register(client)
    catalog = client.get("/api/me/appearance").json()["catalog"]
    skin_names = {item["name"] for item in catalog if item["type"] == "skórka"}
    assert {"Skórka podstawowa", "Noir Stelly", "Office Stelly", "2077 Stelly", "Promissed Stelly", "Retro Stelly"} <= skin_names
    conditions = {item["unlock_condition"]["type"] for item in catalog if item["unlock_condition"]}
    assert {"wynik w poziomie", "liczba klejnotów", "wyzwanie"} <= conditions
