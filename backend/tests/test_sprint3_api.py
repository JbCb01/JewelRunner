"""Ranking z filtrami i znajomi, statystyki i historia, ustawienia, personalizacja, odzyskiwanie hasła
oraz test integracyjny całej ścieżki portal ↔ API ↔ gra."""
import os
import re
import time

import pytest
from sqlalchemy import text

from app.services import mailer, pairing

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
PASSWORD = "Tajne1234"
_counter = iter(range(1000, 10000))


def scalar(engine, sql, **params):
    with engine.connect() as connection:
        return connection.scalar(text(sql), params)


def execute(engine, sql, **params):
    with engine.begin() as connection:
        connection.execute(text(sql), params)


@pytest.fixture(autouse=True)
def cleanup(engine):
    pairing.failures.reset()
    yield
    execute(engine, "DELETE FROM gracz")
    execute(engine, "DELETE FROM element_personalizacji WHERE NOT czy_domyslny AND nazwa LIKE 'Test %'")


def register(client, username="Kubas", email="kubas@example.com"):
    response = client.post("/api/auth/register", json={"username": username, "email": email, "password": PASSWORD})
    assert response.status_code == 201
    return response.json()["id"]


def login(client, email="kubas@example.com", password=PASSWORD):
    return client.post("/api/auth/login", json={"email": email, "password": password})


def switch(client, username, email):
    client.post("/api/auth/logout")
    return register(client, username, email)


def run(client, level=1, completed=True, score=300, time_s=45.0, gems=6, enemies=1, headers=None):
    body = {"session_id": f"SES-1763600000-{next(_counter)}", "level": level, "completed": completed,
            "score": score, "time_s": time_s, "gems": gems, "enemies_defeated": enemies}
    response = client.post("/api/game/runs", json=body, headers=headers or {})
    assert response.status_code == 200, response.text
    return response.json()


# ====================================================================== ranking i znajomi


def test_ranking_default_period_is_overall(client):
    register(client)
    body = client.get("/api/ranking").json()
    assert body["period"] == "ogółem"
    assert body["items"] == []
    assert body["empty_reason"] == "no_results"


@pytest.mark.parametrize("period", ["tydzień", "miesiąc", "ogółem", "week", "month"])
def test_ranking_periods_contain_fresh_score(client, period):
    register(client)
    run(client, score=300)
    body = client.get("/api/ranking", params={"period": period}).json()
    assert body["items"][0]["score"] == 300
    assert body["me"] == {"position": 1, "score": 300}
    assert (body["period_start"] is None) == (body["period"] == "ogółem")


def test_old_weekly_scores_are_not_in_this_week(client, engine):
    register(client)
    execute(
        engine,
        "INSERT INTO wpis_rankingu (gracz_id, okres, poczatek_okresu, wynik, data_uzyskania_wyniku)"
        " SELECT id, 'tydzień', DATE '2020-01-06', 900, now() FROM gracz",
    )
    assert client.get("/api/ranking?period=tydzień").json()["empty_reason"] == "no_results"


def test_ranking_filter_is_remembered(client, engine):
    register(client)
    client.get("/api/ranking?period=miesiąc")
    assert client.get("/api/ranking").json()["period"] == "miesiąc"
    assert scalar(engine, "SELECT domyslny_filtr_rankingu FROM ustawienia_gracza") == "miesiąc"
    assert client.get("/api/me/settings").json()["ranking_filter"] == "miesiąc"


def test_invalid_period(client):
    register(client)
    assert client.get("/api/ranking?period=rok").json()["error"]["code"] == "invalid_period"


def test_friends_ranking_without_friends(client):
    register(client)
    run(client)
    assert client.get("/api/ranking?period=znajomi").json()["empty_reason"] == "no_friends"


def test_friends_ranking_shows_only_friends_with_own_positions(client):
    register(client, "Ania", "ania@example.com")
    run(client, score=900)
    switch(client, "Basia", "basia@example.com")
    run(client, score=500)
    switch(client, "Kubas", "kubas@example.com")
    run(client, score=300)
    assert client.post("/api/me/friends", json={"username": "basia"}).status_code == 201
    body = client.get("/api/ranking?period=znajomi").json()
    assert [(i["username"], i["position"]) for i in body["items"]] == [("Basia", 1), ("Kubas", 2)]
    assert body["me"] == {"position": 2, "score": 300}
    assert body["empty_reason"] is None


def test_friends_crud_and_errors(client):
    basia_id = register(client, "Basia", "basia@example.com")
    switch(client, "Kubas", "kubas@example.com")
    assert client.post("/api/me/friends", json={"username": "Basia"}).json()["player_id"] == basia_id
    assert client.post("/api/me/friends", json={"username": "BASIA"}).json()["error"]["code"] == "already_friend"
    assert client.post("/api/me/friends", json={"username": "Kubas"}).json()["error"]["code"] == "cannot_add_self"
    assert client.post("/api/me/friends", json={"username": "Nikt"}).json()["error"]["code"] == "player_not_found"
    assert [f["username"] for f in client.get("/api/me/friends").json()["items"]] == ["Basia"]
    assert client.delete(f"/api/me/friends/{basia_id}").status_code == 204
    assert client.delete(f"/api/me/friends/{basia_id}").status_code == 404
    assert client.get("/api/me/friends").json()["items"] == []


def test_player_search(client):
    register(client, "Basia", "basia@example.com")
    register_two = switch(client, "Bartek", "bartek@example.com")
    assert register_two
    switch(client, "Kubas", "kubas@example.com")
    client.post("/api/me/friends", json={"username": "Basia"})
    items = client.get("/api/players", params={"search": "ba"}).json()["items"]
    assert [(i["username"], i["is_friend"]) for i in items] == [("Bartek", False), ("Basia", True)]
    assert client.get("/api/players", params={"search": "%_"}).json()["items"] == []
    assert client.get("/api/players", params={"search": "k"}).status_code == 422


# ====================================================================== statystyki i historia


def test_stats_zero_state(client):
    register(client)
    body = client.get("/api/me/stats").json()
    assert body["has_played"] is False
    assert body["overall"]["runs"] == 0
    assert body["overall"]["play_time_s"] == 0
    level = body["levels"][0]
    assert level["level"] == 1 and level["unlocked"] is True and level["best_score"] is None and level["attempts"] == 0


def test_stats_after_runs(client):
    register(client)
    run(client, score=300, time_s=40, gems=6, enemies=2)
    run(client, completed=False, score=50, time_s=20, gems=1, enemies=1)
    body = client.get("/api/me/stats").json()
    assert body["has_played"] is True
    assert body["overall"] == {
        "play_time_s": 60, "levels_completed": 1, "enemies_defeated": 3, "defeats": 1, "runs": 2,
        "gems_collected": 7, "gems_balance": 0, "tutorial_completed": False,
    }
    assert body["levels"][0]["best_score"] == 300
    assert body["levels"][0]["best_time_s"] == 40.0
    assert body["levels"][0]["attempts"] == 2
    assert body["last_synced_at"] is not None


def test_history_newest_first_with_paging(client):
    register(client)
    for score in (10, 20, 30):
        run(client, score=score)
    run(client, completed=False, score=5)
    first = client.get("/api/me/runs?limit=3").json()
    assert [i["score"] for i in first["items"]] == [5, 30, 20]
    assert first["items"][0]["completed"] is False
    second = client.get(f"/api/me/runs?limit=3&before_id={first['next_before_id']}").json()
    assert [i["score"] for i in second["items"]] == [10]
    assert second["next_before_id"] is None


def test_history_is_private(client):
    register(client)
    run(client)
    switch(client, "Basia", "basia@example.com")
    assert client.get("/api/me/runs").json()["items"] == []


# ====================================================================== ustawienia


def test_settings_defaults(client):
    register(client)
    body = client.get("/api/me/settings").json()
    assert body["music_volume"] == 100
    assert body["language"] == "pl"
    assert body["keybindings"] == {}
    assert body["updated_at"] is None


def test_settings_partial_update_and_game_state(client):
    register(client)
    body = client.patch("/api/me/settings", json={"music_volume": 40, "level_music_volume": 70, "resolution": "1920x1080",
                                                 "graphics_profile": "Średni", "keybindings": {"jump": "W", "dash": "Shift"}}).json()
    assert body["music_volume"] == 40 and body["sfx_volume"] == 100
    again = client.patch("/api/me/settings", json={"sfx_volume": 10}).json()
    assert again["music_volume"] == 40 and again["sfx_volume"] == 10
    assert again["keybindings"] == {"dash": "Shift", "jump": "W"}
    state = client.get("/api/me/game-state").json()["settings"]
    assert state["music_volume"] == 40 and state["level_music_volume"] == 70 and state["resolution"] == "1920x1080"
    assert "texture_quality" not in state  # nieustawione pola nie nadpisują domyślnych w grze


def test_keybindings_reset_to_defaults(client):
    register(client)
    client.patch("/api/me/settings", json={"keybindings": {"jump": "W"}})
    assert client.patch("/api/me/settings", json={"keybindings": {}}).json()["keybindings"] == {}


@pytest.mark.parametrize(
    "body",
    [{"music_volume": 101}, {"resolution": "duzo"}, {"graphics_profile": "Ultra"}, {"language": "de"},
     {"keybindings": {"jump": "Escape"}}, {"keybindings": {"jump": "W", "dash": "w"}}, {"ranking_filter": "rok"}],
)
def test_invalid_settings(client, body):
    register(client)
    assert client.patch("/api/me/settings", json=body).status_code == 422


def test_settings_conflict_newer_wins(client):
    register(client)
    client.patch("/api/me/settings", json={"music_volume": 40})
    old = client.patch("/api/me/settings", json={"music_volume": 10, "changed_at": int(time.time()) - 3600})
    assert old.status_code == 409
    assert old.json()["error"]["details"]["server_settings"]["music_volume"] == 40
    newer = client.patch("/api/me/settings", json={"music_volume": 10, "changed_at": int(time.time()) + 1})
    assert newer.status_code == 200


def test_first_settings_sync_with_old_change_is_accepted(client):
    """Zmiana zrobiona offline przed pierwszym zapisem na serwerze nie jest konfliktem."""
    register(client)
    assert client.patch("/api/me/settings", json={"music_volume": 5, "changed_at": int(time.time()) - 3600}).status_code == 200


# ====================================================================== personalizacja


def add_element(engine, name, kind="skórka", condition=None, value=None, slot=None, hex_value=None):
    execute(
        engine,
        "INSERT INTO element_personalizacji (typ, nazwa, punkt_mocowania, wartosc_koloru, warunek_typ, warunek_wartosc)"
        " VALUES (:t, :n, :s, :h, :c, :v)",
        t=kind, n=name, s=slot, h=hex_value, c=condition, v=value,
    )
    return scalar(engine, "SELECT id FROM element_personalizacji WHERE nazwa = :n", n=name)


def catalog_item(body, element_id):
    return next(item for item in body["catalog"] if item["id"] == element_id)


def test_catalog_shows_owned_and_locked(client, engine):
    register(client)
    locked = add_element(engine, "Test Rycerz", condition="wynik w poziomie", value=1000)
    body = client.get("/api/me/appearance").json()
    assert body["current"]["skin"]["name"] == "Skórka podstawowa"
    item = catalog_item(body, locked)
    assert item["owned"] is False
    assert item["unlock_condition"] == {"type": "wynik w poziomie", "value": 1000, "challenge_name": None}
    assert any(i["owned"] and i["name"] == "Fioletowy" for i in body["catalog"])


def test_unlock_by_score_after_run_once(client, engine):
    register(client)
    skin = add_element(engine, "Test Rycerz", condition="wynik w poziomie", value=500)
    assert run(client, score=300)["unlocked_items"] == []
    assert [i["id"] for i in run(client, score=600)["unlocked_items"]] == [skin]
    assert run(client, score=700)["unlocked_items"] == []
    body = client.get("/api/me/appearance").json()
    assert catalog_item(body, skin)["owned"] is True and catalog_item(body, skin)["is_new"] is True
    assert body["new_count"] == 1


def test_unlock_by_gems_and_by_challenge_several_at_once(client, engine):
    register(client)
    challenge_id = scalar(engine, "SELECT id FROM wyzwanie WHERE nazwa = 'Pierwsze kroki'")
    client.post(f"/api/challenges/{challenge_id}/accept")
    gem_skin = add_element(engine, "Test Zbieracz", condition="liczba klejnotów", value=5)
    challenge_color = add_element(engine, "Test Złoty", kind="kolor", condition="wyzwanie", value=challenge_id,
                                  hex_value="#FFD700")
    unlocked = run(client, gems=6)["unlocked_items"]
    assert sorted(i["id"] for i in unlocked) == sorted([gem_skin, challenge_color])


def test_save_appearance_with_owned_items(client, engine):
    register(client)
    skin = add_element(engine, "Test Rycerz", condition="wynik w poziomie", value=1)
    hat = add_element(engine, "Test Kapelusz", kind="akcesorium", slot="głowa", condition="wynik w poziomie", value=1)
    run(client, score=10)
    color = scalar(engine, "SELECT id FROM element_personalizacji WHERE nazwa = 'Fioletowy'")
    body = client.put("/api/me/appearance", json={"skin_id": skin, "color_id": color,
                                                  "accessories": [{"accessory_id": hat, "color_id": color}]}).json()
    assert body["skin"]["name"] == "Test Rycerz"
    assert body["accessories"][0]["slot"] == "głowa"
    assert body["accessories"][0]["color"]["hex"] == "#6A3FB5"
    gs = client.get("/api/me/game-state").json()["appearance"]
    assert gs["active_skin"] == "Test Rycerz"
    assert gs["active_skin_id"] == skin
    assert gs["active_color_hex"] == "#6A3FB5"
    assert gs["active_color_id"] == color
    assert gs["equipped_accessories"] == {"głowa": "Test Kapelusz"}
    assert gs["equipped_accessories_detail"] == [
        {"slot": "głowa", "accessory_id": hat, "name": "Test Kapelusz", "color_id": color}
    ]
    assert any(item["id"] == skin for item in gs["owned_items"])


def test_a1_locked_or_wrong_type_element_is_rejected(client, engine):
    register(client)
    locked = add_element(engine, "Test Rycerz", condition="wynik w poziomie", value=1000)
    color = scalar(engine, "SELECT id FROM element_personalizacji WHERE nazwa = 'Fioletowy'")
    response = client.put("/api/me/appearance", json={"skin_id": locked, "color_id": color})
    assert response.json()["error"]["code"] == "element_not_owned"
    response = client.put("/api/me/appearance", json={"skin_id": color, "color_id": color})
    assert response.json()["error"]["code"] == "element_not_owned"


def test_one_accessory_per_slot(client, engine):
    register(client)
    a = add_element(engine, "Test Czapka 1", kind="akcesorium", slot="głowa", condition="wynik w poziomie", value=1)
    b = add_element(engine, "Test Czapka 2", kind="akcesorium", slot="głowa", condition="wynik w poziomie", value=1)
    run(client, score=10)
    look = client.get("/api/me/appearance").json()["current"]
    body = {"skin_id": look["skin"]["id"], "color_id": look["color"]["id"],
            "accessories": [{"accessory_id": a}, {"accessory_id": b}]}
    assert client.put("/api/me/appearance", json=body).json()["error"]["code"] == "slot_taken"


def test_a3_appearance_conflict(client):
    register(client)
    look = client.get("/api/me/appearance").json()["current"]
    body = {"skin_id": look["skin"]["id"], "color_id": look["color"]["id"], "changed_at": int(time.time()) - 3600}
    assert client.put("/api/me/appearance", json=body).json()["error"]["code"] == "appearance_conflict"


def test_mark_new_items_seen(client, engine):
    register(client)
    add_element(engine, "Test Rycerz", condition="wynik w poziomie", value=1)
    run(client, score=10)
    assert client.post("/api/me/appearance/seen", json={}).status_code == 200
    assert client.get("/api/me/appearance").json()["new_count"] == 0


# ====================================================================== odzyskiwanie hasła


@pytest.fixture
def mailbox(monkeypatch):
    sent = []
    monkeypatch.setattr(mailer, "send_email", lambda to, subject, body: sent.append((to, body)))
    return sent


def reset_token(mailbox):
    return re.search(r"nowe-haslo\?token=(\S+)", mailbox[-1][1])[1]


def test_forgot_same_answer_for_unknown_email(client, mailbox):
    register(client)
    known = client.post("/api/auth/forgot", json={"email": "KUBAS@example.com"})
    unknown = client.post("/api/auth/forgot", json={"email": "nikt@example.com"})
    assert known.status_code == unknown.status_code == 202
    assert known.json() == unknown.json()
    assert [to for to, _ in mailbox] == ["kubas@example.com"]


def test_reset_password_logs_out_everywhere(client, engine, mailbox):
    register(client)
    game_code = client.post("/api/me/pairing-code").json()["code"]
    portal_cookie = client.cookies.get("jr_session")
    client.cookies.clear()
    game_token = client.post("/api/auth/pair", json={"code": game_code}).json()["token"]
    client.post("/api/auth/forgot", json={"email": "kubas@example.com"})
    token = reset_token(mailbox)
    assert client.post("/api/auth/reset", json={"token": token, "new_password": "Nowe12345"}).status_code == 204
    assert client.get("/api/me", headers={"Authorization": f"Bearer {game_token}"}).status_code == 401
    client.cookies.set("jr_session", portal_cookie)
    assert client.get("/api/me").status_code == 401
    assert login(client).status_code == 401
    assert login(client, password="Nowe12345").status_code == 200
    # A2: link działa tylko raz
    again = client.post("/api/auth/reset", json={"token": token, "new_password": "Inne12345"})
    assert again.json()["error"]["code"] == "invalid_token"


def test_a2_expired_link(client, engine, mailbox):
    register(client)
    client.post("/api/auth/forgot", json={"email": "kubas@example.com"})
    execute(engine, "UPDATE token_resetu_hasla SET data_waznosci = now() - interval '1 minute'")
    response = client.post("/api/auth/reset", json={"token": reset_token(mailbox), "new_password": "Nowe12345"})
    assert response.json()["error"]["code"] == "invalid_token"


def test_a3_weak_new_password(client, mailbox):
    register(client)
    client.post("/api/auth/forgot", json={"email": "kubas@example.com"})
    response = client.post("/api/auth/reset", json={"token": reset_token(mailbox), "new_password": "krotkie"})
    assert response.json()["error"]["code"] == "weak_password"


def test_a4_three_emails_per_hour_and_only_last_link_works(client, mailbox):
    register(client)
    for _ in range(5):
        assert client.post("/api/auth/forgot", json={"email": "kubas@example.com"}).status_code == 202
    assert len(mailbox) == 3
    first = re.search(r"token=(\S+)", mailbox[0][1])[1]
    assert client.post("/api/auth/reset", json={"token": first, "new_password": "Nowe12345"}).status_code == 400
    assert client.post("/api/auth/reset", json={"token": reset_token(mailbox), "new_password": "Nowe12345"}).status_code == 204


def test_reset_unlocks_locked_account(client, engine, mailbox):
    register(client)
    for _ in range(5):
        login(client, password="Zle12345")
    client.post("/api/auth/forgot", json={"email": "kubas@example.com"})
    client.post("/api/auth/reset", json={"token": reset_token(mailbox), "new_password": "Nowe12345"})
    assert login(client, password="Nowe12345").status_code == 200


# ====================================================================== cała ścieżka portal ↔ API ↔ gra


def test_full_path_portal_game_portal(client, engine):
    """Portal: konto, wyzwanie, kod → gra: parowanie, wynik, klejnoty, zapis → portal widzi wszystko."""
    register(client)
    challenge_id = scalar(engine, "SELECT id FROM wyzwanie WHERE nazwa = 'Pierwsze kroki'")
    assert client.post(f"/api/challenges/{challenge_id}/accept").status_code == 201
    code = client.post("/api/me/pairing-code").json()["code"]
    portal_cookie = client.cookies.get("jr_session")

    # --- gra (bez cookie, z tokenem)
    client.cookies.clear()
    token = client.post("/api/auth/pair", json={"code": code}).json()["token"]
    game = {"Authorization": f"Bearer {token}"}
    state = client.get("/api/me/game-state", headers=game).json()
    assert [c["challenge_id"] for c in state["challenges"]] == [challenge_id]
    result = run(client, score=420, gems=7, headers=game)
    assert result["challenges"][0]["passed"] is True
    sync = client.post("/api/me/wallet/sync", headers=game,
                       json={"operations": [{"id": "SES-1763600000-9999", "gems": 7, "reason": "poziom"}]})
    assert sync.json()["gems"] == 7

    # --- portal widzi efekty
    client.cookies.set("jr_session", portal_cookie)
    me = client.get("/api/me").json()
    assert me["game_linked"] is True and me["last_synced_at"] is not None
    assert client.get("/api/ranking").json()["me"] == {"position": 1, "score": 420}
    mine = client.get("/api/me/challenges").json()["items"][0]
    assert mine["status"] == "Ukończone" and mine["progress_percent"] == 100
    stats = client.get("/api/me/stats").json()
    assert stats["overall"]["levels_completed"] == 1 and stats["overall"]["gems_balance"] == 7
    assert client.get("/api/me/runs").json()["items"][0]["score"] == 420


def test_levels_2_to_4_accept_runs(client):
    register(client)
    for lvl in (2, 3, 4):
        res = run(client, level=lvl, score=150 * lvl, gems=3, enemies=1)
        assert res["level"] == lvl
        assert res["completed"] is True
    stats = client.get("/api/me/stats").json()
    assert stats["overall"]["levels_completed"] == 3
    assert len([lvl for lvl in stats["levels"] if lvl["level"] in (2, 3, 4) and lvl["completed"]]) == 3
