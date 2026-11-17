"""Katalog skórek i kolorów postaci z grafik zespołu.

Revision ID: 0005
Revises: 0004
"""
from pathlib import Path

from alembic import op

revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "005_katalog_skorek.sql"


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    op.execute(
        """
        DELETE FROM element_personalizacji
        WHERE (typ = 'skórka' AND nazwa IN ('Noir Stelly', 'Office Stelly', '2077 Stelly', 'Promissed Stelly', 'Retro Stelly'))
           OR (typ = 'kolor' AND nazwa IN ('Monochrom', 'Granatowy', 'Cyjan', 'Morski', 'Bursztynowy'))
        """
    )
