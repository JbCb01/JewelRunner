"""Wyniki z gry: porażki i pokonani wrogowie w ukonczenie_poziomu.

Revision ID: 0003
Revises: 0002
"""
from pathlib import Path

from alembic import op

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "003_wyniki_gry.sql"


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute("DROP INDEX ix_ukonczenie_gracz_data")
    op.execute("ALTER TABLE ukonczenie_poziomu DROP COLUMN liczba_pokonanych_wrogow, DROP COLUMN czy_ukonczony")
