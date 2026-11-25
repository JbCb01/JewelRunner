"""Migracja 0007: pięć wyzwań na poziomie 1 (10/30/wszystkie klejnoty, czas < 1 min, 10 tricków)."""
import os
from pathlib import Path

import pytest
from sqlalchemy import text

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
SQL = (Path(__file__).resolve().parents[1] / "db" / "schema" / "007_latwe_wyzwania.sql").read_text(encoding="utf-8")
NAMES = {"Garść klejnotów", "Poszukiwacz klejnotów", "Pełna kolekcja", "Sprinter", "Mistrz akrobacji"}
PASSWORD = "Tajne1234"


def apply(engine):
    with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
        connection.exec_driver_sql(SQL)


def count(engine):
    with engine.connect() as connection:
        return connection.scalar(text("SELECT count(*) FROM wyzwanie WHERE nazwa = ANY(:n)"), {"n": list(NAMES)})


def test_migration_adds_five_active_challenges_once(engine):
    apply(engine)
    apply(engine)
    assert count(engine) == 5
    with engine.connect() as connection:
        rows = connection.execute(
            text(
                """SELECT w.nazwa, w.poziom_trudnosci, w.status, n.typ, n.liczba_klejnotow, e.nazwa AS element
                   FROM wyzwanie w JOIN nagroda n ON n.id = w.nagroda_id
                   LEFT JOIN element_personalizacji e ON e.id = n.element_id
                   WHERE w.nazwa = ANY(:n)"""
            ),
            {"n": list(NAMES)},
        ).all()
    by_name = {r.nazwa: r for r in rows}
    assert by_name["Garść klejnotów"].poziom_trudnosci == "łatwy"
    assert by_name["Poszukiwacz klejnotów"].poziom_trudnosci == "średni"
    assert by_name["Pełna kolekcja"].poziom_trudnosci == "trudny"
    assert by_name["Sprinter"].poziom_trudnosci == "średni"
    assert by_name["Mistrz akrobacji"].poziom_trudnosci == "średni"
    assert {r.status for r in rows} == {"Aktywne"}
    assert {r.typ for r in rows} == {"klejnoty", "wzmocnienie"}
    assert all(r.element is None for r in rows)


def test_run_completes_all_five_challenges(client, engine):
    apply(engine)
    client.post("/api/auth/register", json={"username": "Kubas", "email": "kubas@example.com", "password": PASSWORD})
    available = {c["name"]: c["id"] for c in client.get("/api/challenges").json()["items"]}
    assert NAMES <= set(available)
    for name in NAMES:
        assert client.post(f"/api/challenges/{available[name]}/accept").status_code == 201

    run = {
        "session_id": "SES-1764100000-0001",
        "level": 1,
        "completed": True,
        "score": 5000,
        "time_s": 55.0,
        "gems": 49,
        "enemies_defeated": 2,
    }
    result = client.post("/api/game/runs", json=run).json()
    passed = {c["name"] for c in result["challenges"] if c["passed"]}
    assert NAMES <= passed

    mine = {c["name"]: c for c in client.get("/api/me/challenges").json()["items"]}
    assert all(mine[name]["reward_status"] == "Do odebrania" for name in NAMES)
    claim = client.post(f"/api/me/challenges/{available['Mistrz akrobacji']}/claim").json()
    assert claim["reward"]["type"] == "wzmocnienie"
    assert claim["reward"]["booster_type"] == "dodatkowe życie"
