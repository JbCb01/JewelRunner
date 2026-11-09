"""Wczytuje dane startowe. Uruchamiać raz, po `alembic upgrade head`, na pustej bazie."""
from pathlib import Path

from sqlalchemy import create_engine, text

from app.core.config import get_settings

SEED = Path(__file__).resolve().parents[1] / "db" / "seeds" / "001_dane_startowe.sql"


def main() -> None:
    engine = create_engine(get_settings().database_url)
    with engine.connect() as connection:
        if connection.scalar(text("SELECT count(*) FROM poziom")):
            raise SystemExit("Dane startowe są już w bazie. Nic nie zmieniono.")
    with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
        connection.exec_driver_sql(SEED.read_text(encoding="utf-8"))
    print("Wczytano dane startowe.")


if __name__ == "__main__":
    main()
