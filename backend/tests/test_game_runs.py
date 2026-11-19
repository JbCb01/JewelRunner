"""Wyniki z gry: POST /api/game/runs (postęp, statystyki, ranking, wyzwania, historia)."""
import os
from concurrent.futures import ThreadPoolExecutor

import pytest
from sqlalchemy import text

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
def clean_extra_levels(engine):
    yield
    execute(engine, "DELETE FROM gracz")  # razem z wynikami i postępem na dodatkowych poziomach
    execute(engine, "DELETE FROM poziom WHERE kolejnosc > 1")


def register(client, username="Kubas", email="kubas@example.com"):
    response = client.post("/api/auth/register", json={"username": username, "email": email, "password": PASSWORD})
    assert response.status_code == 201


def run(client, session_id=None, level=1, completed=True, score=300, time_s=45.5, gems=6, enemies=2):
    body = {
        "session_id": session_id or f"SES-1763500000-{next(_counter)}",
        "level": level, "completed": completed, "score": score,
        "time_s": time_s, "gems": gems, "enemies_defeated": enemies,
    }
    return client.post("/api/game/runs", json=body)


def accept(client, engine, name):
    challenge_id = scalar(engine, "SELECT id FROM wyzwanie WHERE nazwa = :n", n=name)
    assert client.post(f"/api/challenges/{challenge_id}/accept").status_code in (200, 201)
    return challenge_id


def add_level_2(engine, condition='{"min_wynik": 100}'):
    execute(
        engine,
        "INSERT INTO poziom (nazwa, kolejnosc, warunek_odblokowania, punkt_startowy) VALUES ('Poziom 2', 2, CAST(:c AS jsonb), '{}')",
        c=condition,
    )


# ---------- podstawy


def test_requires_login(client):
    assert run(client).status_code == 401


def test_completed_run_updates_progress_and_stats(client, engine):
    register(client)
    response = run(client, score=300, time_s=45.5, gems=6, enemies=2)
    assert response.status_code == 200
    body = response.json()
    assert body["duplicate"] is False
    assert body["completed"] is True
    assert body["best_score"] == 300
    assert body["best_time_s"] == 45.5
    assert body["attempts"] == 1
    assert body["new_best"] is True
    assert scalar(engine, "SELECT liczba_ukonczonych_poziomow FROM statystyki_gracza") == 1
    assert scalar(engine, "SELECT liczba_pokonanych_wrogow FROM statystyki_gracza") == 2
    assert scalar(engine, "SELECT laczny_czas_gry_s FROM statystyki_gracza") == 46
    assert scalar(engine, "SELECT data_ostatniej_synchronizacji IS NOT NULL FROM gracz")


def test_best_score_and_time_are_kept(client):
    register(client)
    run(client, score=300, time_s=50)
    body = run(client, score=200, time_s=40).json()
    assert body["best_score"] == 300
    assert body["best_time_s"] == 40
    assert body["attempts"] == 2
    assert body["new_best"] is False
    assert run(client, score=500, time_s=60).json()["new_best"] is True


def test_level_counted_once_in_completed_levels(client, engine):
    register(client)
    run(client)
    run(client)
    assert scalar(engine, "SELECT liczba_ukonczonych_poziomow FROM statystyki_gracza") == 1


def test_failure_counts_attempt_and_defeat_but_not_best(client, engine):
    register(client)
    body = run(client, completed=False, score=120, time_s=30).json()
    assert body["best_score"] is None
    assert body["attempts"] == 1
    assert body["ranking"]["ogółem"] is None
    assert scalar(engine, "SELECT liczba_porazek FROM statystyki_gracza") == 1
    assert scalar(engine, "SELECT liczba_ukonczonych_poziomow FROM statystyki_gracza") == 0
    assert scalar(engine, "SELECT czy_ukonczony FROM ukonczenie_poziomu") is False


def test_same_session_sent_twice_is_counted_once(client, engine):
    register(client)
    first = run(client, session_id="SES-1763500000-0001").json()
    again = run(client, session_id="SES-1763500000-0001").json()
    assert again["duplicate"] is True
    assert again["best_score"] == first["best_score"]
    assert again["attempts"] == 1
    assert scalar(engine, "SELECT count(*) FROM ukonczenie_poziomu") == 1
    assert scalar(engine, "SELECT laczny_czas_gry_s FROM statystyki_gracza") == 46


def test_concurrent_resend_is_counted_once(client, engine):
    register(client)
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(lambda _: run(client, session_id="SES-1763500000-0002").json(), range(4)))
    assert sorted(r["duplicate"] for r in results) == [False, True, True, True]
    assert scalar(engine, "SELECT liczba_prob FROM postep_poziomu") == 1


@pytest.mark.parametrize(
    "change",
    [{"session_id": "abc"}, {"score": -1}, {"time_s": -1}, {"gems": 10_001}, {"level": 0}, {"completed": None}],
)
def test_invalid_run(client, change):
    register(client)
    body = {"session_id": "SES-1-0001", "level": 1, "completed": True, "score": 1, "time_s": 1, "gems": 0}
    assert client.post("/api/game/runs", json={**body, **change}).status_code == 422


def test_unknown_level(client):
    register(client)
    assert run(client, level=99).json()["error"]["code"] == "unknown_level"


# ---------- odblokowywanie poziomów


def test_completion_unlocks_next_level(client, engine):
    register(client)
    add_level_2(engine)
    assert run(client, level=2).json()["error"]["code"] == "level_locked"
    assert run(client, score=300).json()["unlocked_levels"] == [2]
    assert run(client, score=300).json()["unlocked_levels"] == []
    assert run(client, level=2).status_code == 200


def test_unlock_requires_minimum_score(client, engine):
    register(client)
    add_level_2(engine, '{"min_wynik": 1000}')
    assert run(client, score=300).json()["unlocked_levels"] == []
    assert run(client, score=1200).json()["unlocked_levels"] == [2]


def test_failure_does_not_unlock(client, engine):
    register(client)
    add_level_2(engine, "{}")
    assert run(client, completed=False).json()["unlocked_levels"] == []


# ---------- ranking


def test_ranking_entries_for_all_periods(client, engine):
    register(client)
    body = run(client, score=300).json()
    for period in ("tydzień", "miesiąc", "ogółem"):
        assert body["ranking"][period] == {"position": 1, "score": 300}
    assert scalar(engine, "SELECT count(*) FROM wpis_rankingu") == 3


def test_ranking_is_sum_of_best_scores_per_level(client, engine):
    register(client)
    add_level_2(engine, "{}")
    run(client, score=300)
    run(client, score=200)  # słabszy wynik na poziomie 1 nie zmienia sumy
    body = run(client, level=2, score=150).json()
    assert body["ranking"]["ogółem"]["score"] == 450
    assert client.get("/api/ranking").json()["me"]["score"] == 450


def test_ranking_position_against_other_player(client):
    register(client)
    run(client, score=300)
    client.post("/api/auth/logout")
    register(client, "Basia", "basia@example.com")
    body = run(client, score=500).json()
    assert body["ranking"]["ogółem"] == {"position": 1, "score": 500}
    items = client.get("/api/ranking").json()["items"]
    assert [i["username"] for i in items] == ["Basia", "Kubas"]


def test_ranking_never_goes_down(client, engine):
    register(client)
    execute(
        engine,
        "INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku) SELECT id, 'ogółem', 5000, now() FROM gracz",
    )
    assert run(client, score=300).json()["ranking"]["ogółem"]["score"] == 5000


# ---------- wyzwania


def test_challenge_completed_by_run(client, engine):
    register(client)
    challenge_id = accept(client, engine, "Pierwsze kroki")
    body = run(client).json()
    entry = next(c for c in body["challenges"] if c["challenge_id"] == challenge_id)
    assert entry == {
        "challenge_id": challenge_id, "name": "Pierwsze kroki", "passed": True,
        "progress_percent": 100, "status": "Ukończone", "reward_status": "Do odebrania",
    }
    mine = client.get("/api/me/challenges").json()["items"]
    assert mine[0]["status"] == "Ukończone"
    attempts = client.get(f"/api/me/challenges/{challenge_id}/attempts").json()
    assert attempts["items"][0]["passed"] is True


def test_challenge_not_met_records_failed_attempt(client, engine):
    register(client)
    challenge_id = accept(client, engine, "Łowca klejnotów")  # min 5 klejnotów
    body = run(client, gems=3).json()
    entry = next(c for c in body["challenges"] if c["challenge_id"] == challenge_id)
    assert entry["passed"] is False
    assert entry["status"] == "Aktywne"
    assert entry["reward_status"] is None
    assert scalar(engine, "SELECT count(*) FROM proba_wyzwania WHERE NOT czy_zaliczona") == 1
    assert run(client, gems=5).json()["challenges"][0]["passed"] is True


def test_failed_run_does_not_pass_challenge_but_counts_attempt(client, engine):
    register(client)
    accept(client, engine, "Łowca klejnotów")
    body = run(client, completed=False, gems=10).json()
    assert body["challenges"][0]["passed"] is False
    assert body["challenges"][0]["progress_percent"] == 99
    assert scalar(engine, "SELECT count(*) FROM proba_wyzwania") == 1


def test_time_challenge(client, engine):
    register(client)
    run(client)  # „Mistrz czasu” wymaga odblokowanego poziomu 1
    challenge_id = accept(client, engine, "Mistrz czasu")  # maks. 60 s
    slow = run(client, time_s=75).json()
    assert next(c for c in slow["challenges"] if c["challenge_id"] == challenge_id)["passed"] is False
    fast = run(client, time_s=59).json()
    assert next(c for c in fast["challenges"] if c["challenge_id"] == challenge_id)["passed"] is True


def test_completed_challenge_is_not_evaluated_again(client, engine):
    register(client)
    accept(client, engine, "Pierwsze kroki")
    run(client)
    run(client)
    assert scalar(engine, "SELECT count(*) FROM proba_wyzwania") == 1


def test_challenges_of_other_players_are_untouched(client, engine):
    register(client)
    accept(client, engine, "Pierwsze kroki")
    client.post("/api/auth/logout")
    register(client, "Basia", "basia@example.com")
    run(client)
    assert scalar(engine, "SELECT count(*) FROM proba_wyzwania") == 0


# ---------- gra z tokenem


def test_game_sends_run_with_bearer_token(client):
    register(client)
    code = client.post("/api/me/pairing-code").json()["code"]
    client.cookies.clear()
    token = client.post("/api/auth/pair", json={"code": code}).json()["token"]
    response = client.post(
        "/api/game/runs",
        json={"session_id": "SES-1763500000-0003", "level": 1, "completed": True, "score": 10, "time_s": 5, "gems": 1},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
