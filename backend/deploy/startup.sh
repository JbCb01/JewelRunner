#!/usr/bin/env bash
# Polecenie startowe App Service: migracje, dane startowe przy pierwszym uruchomieniu, serwer.
set -euo pipefail

python -m alembic upgrade head
# Skrypt kończy się kodem błędu także wtedy, gdy dane już są; serwer ma wtedy normalnie wystartować.
python -m scripts.seed || echo "Dane startowe nie zostały wczytane (powód powyżej)."
exec python -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
