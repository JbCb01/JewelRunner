"""Tabela kod_parowania: łączenie gry z kontem kodem z portalu.

Revision ID: 0002
Revises: 0001
"""
from pathlib import Path

from alembic import op

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "002_kod_parowania.sql"


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute("DROP TABLE kod_parowania")
