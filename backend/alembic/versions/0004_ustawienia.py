"""Ustawienia: osobna głośność muzyki w poziomie.

Revision ID: 0004
Revises: 0003
"""
from pathlib import Path

from alembic import op

revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "004_ustawienia.sql"


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute("ALTER TABLE ustawienia_gracza DROP COLUMN glosnosc_muzyki_poziomu")
