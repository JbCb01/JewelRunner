"""Początkowy schemat bazy danych: 30 tabel i widok v_ranking.

Revision ID: 0001
Revises:
"""
from pathlib import Path

from alembic import op

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "001_schema.sql"

TABLES = [
    "nagroda_dzienna", "transakcja", "posiadane_wzmocnienie", "wpis_rankingu", "proba_wyzwania",
    "uczestnictwo_w_wyzwaniu", "kolekcja_gracza", "zapis_gry", "ukonczenie_poziomu", "postep_poziomu",
    "wyglad_akcesorium", "wyglad_postaci", "posiadany_element", "portfel_gracza", "statystyki_gracza",
    "znajomy", "przypisanie_klawisza", "ustawienia_gracza", "token_zmiany_emaila", "token_resetu_hasla",
    "sesja_logowania", "gracz", "autor", "wyzwanie", "nagroda", "specjalny_klejnot", "oferta_sklepu",
    "wzmocnienie", "element_personalizacji", "poziom",
]


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute("DROP VIEW v_ranking")
    for table in TABLES:
        op.execute(f"DROP TABLE {table}")
