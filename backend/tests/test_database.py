"""Testy na prawdziwym PostgreSQL. Baza z TEST_DATABASE_URL jest czyszczona, więc jej nazwa musi zawierać „test”."""
import os
import subprocess
import sys
from pathlib import Path

import pytest
from sqlalchemy import create_engine, inspect, text

URL = os.environ.get("TEST_DATABASE_URL")
pytestmark = pytest.mark.skipif(not URL, reason="brak TEST_DATABASE_URL")
ROOT = Path(__file__).resolve().parents[1]


def run(*args: str) -> subprocess.CompletedProcess:
    env = {**os.environ, "DATABASE_URL": URL}
    return subprocess.run([sys.executable, "-m", *args], cwd=ROOT, env=env, capture_output=True, text=True)


@pytest.fixture(scope="module")
def engine():
    assert "test" in URL.rsplit("/", 1)[-1], "nazwa testowej bazy musi zawierać „test”"
    engine = create_engine(URL)
    with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
        connection.execute(text("DROP SCHEMA public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))
    result = run("alembic", "upgrade", "head")
    assert result.returncode == 0, result.stderr
    yield engine
    engine.dispose()


def test_upgrade_creates_all_tables_and_view(engine):
    inspector = inspect(engine)
    tables = set(inspector.get_table_names()) - {"alembic_version"}
    assert len(tables) == 30
    assert "v_ranking" in inspector.get_view_names()


def test_seed_loads_once(engine):
    first = run("scripts.seed")
    assert first.returncode == 0, first.stderr
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM wyzwanie")) == 5
    assert run("scripts.seed").returncode != 0
    with engine.connect() as connection:
        assert connection.scalar(text("SELECT count(*) FROM wyzwanie")) == 5


def test_health_with_database(engine, monkeypatch):
    from fastapi.testclient import TestClient

    from app.core.config import get_settings
    from app.db.session import get_engine
    from app.main import create_app

    monkeypatch.setenv("DATABASE_URL", URL)
    get_settings.cache_clear()
    get_engine.cache_clear()
    response = TestClient(create_app()).get("/api/health")
    get_settings.cache_clear()
    get_engine.cache_clear()
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "ok"}


def test_downgrade_and_upgrade_again(engine):
    down = run("alembic", "downgrade", "base")
    assert down.returncode == 0, down.stderr
    assert set(inspect(engine).get_table_names()) <= {"alembic_version"}
    up = run("alembic", "upgrade", "head")
    assert up.returncode == 0, up.stderr
    assert len(set(inspect(engine).get_table_names()) - {"alembic_version"}) == 30
