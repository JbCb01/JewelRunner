"""Pięć wyzwań na poziomie 1 (klejnoty 10/30/wszystkie, czas < 1 min, 10 tricków).

Revision ID: 0007
Revises: 0006
"""
from pathlib import Path

from alembic import op

revision = "0007"
down_revision = "0006"
branch_labels = None
depends_on = None

SCHEMA = Path(__file__).resolve().parents[2] / "db" / "schema" / "007_latwe_wyzwania.sql"
NAMES = "('Garść klejnotów', 'Poszukiwacz klejnotów', 'Pełna kolekcja', 'Sprinter', 'Mistrz akrobacji')"


def upgrade() -> None:
    op.get_bind().exec_driver_sql(SCHEMA.read_text(encoding="utf-8"))


def downgrade() -> None:
    # Usuwa tylko wyzwania, w których nikt nie uczestniczy, razem z ich nagrodami.
    op.execute(
        f"""
        WITH usuniete AS (
            DELETE FROM wyzwanie w
            WHERE w.nazwa IN {NAMES}
              AND NOT EXISTS (SELECT 1 FROM uczestnictwo_w_wyzwaniu u WHERE u.wyzwanie_id = w.id)
            RETURNING w.nagroda_id
        )
        DELETE FROM nagroda n USING usuniete WHERE n.id = usuniete.nagroda_id
        """
    )
