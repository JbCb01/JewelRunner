"""Dodanie poziomów gry 2–4 (Ascent, Momentum, Szachownica AI).

Revision ID: 0006
Revises: 0005
"""
from pathlib import Path

from alembic import op

revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "006_poziomy_gry.sql"


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute("DELETE FROM poziom WHERE kolejnosc IN (2, 3, 4)")
