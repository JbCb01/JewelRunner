"""Wczytuje dane przykładowe do pracy lokalnej (ST-35). Wymaga wcześniejszego `python -m scripts.seed`."""
from pathlib import Path

from sqlalchemy import create_engine, text

from app.core.config import get_settings

SEED = Path(__file__).resolve().parents[1] / "db" / "seeds" / "002_dane_przykladowe.sql"


def main() -> None:
    settings = get_settings()
    if settings.environment != "development":
        raise SystemExit("Dane przykładowe zawierają konta ze znanym hasłem. Działają tylko w środowisku development.")
    engine = create_engine(settings.database_url)
    with engine.connect() as connection:
        if not connection.scalar(text("SELECT count(*) FROM poziom")):
            raise SystemExit("Najpierw uruchom: python -m scripts.seed")
        if connection.scalar(text("SELECT count(*) FROM gracz WHERE email = 'demo@example.com'")):
            raise SystemExit("Dane przykładowe są już w bazie. Nic nie zmieniono.")
    with engine.connect().execution_options(isolation_level="AUTOCOMMIT") as connection:
        connection.exec_driver_sql(SEED.read_text(encoding="utf-8"))
    print("Wczytano dane przykładowe. Konto: demo@example.com / Demo12345")


if __name__ == "__main__":
    main()
