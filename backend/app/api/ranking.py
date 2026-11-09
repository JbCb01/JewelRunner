from datetime import UTC, datetime

from fastapi import APIRouter
from sqlalchemy import text

from app.api.deps import CurrentPlayer, DbSession

router = APIRouter(prefix="/ranking", tags=["ranking"])

OVERALL = "okres = 'ogółem'"


@router.get("")
def read_ranking(gracz: CurrentPlayer, db: DbSession) -> dict:
    top = db.execute(
        text(f"SELECT pozycja, gracz_id, nazwa_uzytkownika, wynik FROM v_ranking WHERE {OVERALL} ORDER BY pozycja LIMIT 100")
    ).all()
    mine = db.execute(
        text(f"SELECT pozycja, wynik FROM v_ranking WHERE {OVERALL} AND gracz_id = :gracz"), {"gracz": gracz.id}
    ).first()
    return {
        "items": [
            {"position": row.pozycja, "player_id": row.gracz_id, "username": row.nazwa_uzytkownika, "score": row.wynik}
            for row in top
        ],
        "me": mine and {"position": mine.pozycja, "score": mine.wynik},
        "generated_at": datetime.now(UTC),
    }
