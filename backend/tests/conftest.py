import os

# Testy bez bazy nie łączą się z tym adresem. Testy z bazą używają TEST_DATABASE_URL.
os.environ.setdefault("DATABASE_URL", "postgresql+psycopg://test:test@127.0.0.1:1/test")
os.environ.setdefault("CORS_ORIGINS", "http://localhost:5173")

from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, text

from app.core.config import get_settings
from app.db.session import get_engine
from app.main import create_app

URL = os.environ.get("TEST_DATABASE_URL")
ROOT = Path(__file__).resolve().parents[1]


def clear_caches():
    get_settings.cache_clear()
    get_engine.cache_clear()


@pytest.fixture(scope="module")
def engine():
    """Czysta baza ze schematem i danymi startowymi dla każdego modułu testów."""
    assert "test" in URL.rsplit("/", 1)[-1], "nazwa testowej bazy musi zawierać „test”"
    engine = create_engine(URL)
    with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
        connection.execute(text("DROP SCHEMA public CASCADE"))
        connection.execute(text("CREATE SCHEMA public"))
        connection.exec_driver_sql((ROOT / "db/schema/001_schema.sql").read_text(encoding="utf-8"))
        connection.exec_driver_sql((ROOT / "db/seeds/001_dane_startowe.sql").read_text(encoding="utf-8"))
    yield engine
    engine.dispose()


@pytest.fixture
def client(engine, monkeypatch):
    monkeypatch.setenv("DATABASE_URL", URL)
    clear_caches()
    with engine.begin() as connection:
        connection.execute(text("DELETE FROM gracz"))
    yield TestClient(create_app())
    clear_caches()
