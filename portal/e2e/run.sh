#!/usr/bin/env bash
# Uruchamia testy E2E na tymczasowym PostgreSQL, prawdziwym API i portalu. Nie dotyka bazy projektu.
# Wymaga: PostgreSQL 18 w /usr/lib/postgresql/18/bin i środowiska Pythona backendu.
set -euo pipefail

PORTAL="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND="${BACKEND_DIR:-$PORTAL/../backend}"
VENV="${VENV_DIR:-$HOME/.venvs/jewelrunner-backend}"
PGBIN=/usr/lib/postgresql/18/bin
WORK="$(mktemp -d)"
PG_PORT=55434; API_PORT=8766; WEB_PORT=5174
PIDS=()

cleanup() {
  for pid in "${PIDS[@]:-}"; do kill "$pid" 2>/dev/null || true; done
  "$PGBIN/pg_ctl" -D "$WORK/pg" -m fast stop >/dev/null 2>&1 || true
  rm -rf "$WORK"
}
trap cleanup EXIT

"$PGBIN/initdb" -D "$WORK/pg" -A trust -U test -E UTF8 --locale=C.UTF-8 >/dev/null
"$PGBIN/pg_ctl" -D "$WORK/pg" -o "-p $PG_PORT -k $WORK -c listen_addresses=127.0.0.1" -l "$WORK/pg.log" -w start >/dev/null
"$PGBIN/createdb" -h 127.0.0.1 -p "$PG_PORT" -U test jewelrunner_e2e

export DATABASE_URL="postgresql+psycopg://test@127.0.0.1:$PG_PORT/jewelrunner_e2e"
export CORS_ORIGINS="http://localhost:$WEB_PORT" PORTAL_URL="http://localhost:$WEB_PORT" EMAIL_BACKEND=console ENVIRONMENT=development
export E2E_BACKEND_LOG="$WORK/api.log" E2E_BASE_URL="http://localhost:$WEB_PORT"

cd "$BACKEND"
"$VENV/bin/python" -m alembic upgrade head >/dev/null 2>&1
"$VENV/bin/python" -m scripts.seed
"$VENV/bin/python" -m scripts.seed_dev
"$VENV/bin/uvicorn" app.main:app --port "$API_PORT" >"$E2E_BACKEND_LOG" 2>&1 &
PIDS+=($!)

cd "$PORTAL"
VITE_API_PROXY="http://localhost:$API_PORT" npx vite --port "$WEB_PORT" --strictPort >"$WORK/web.log" 2>&1 &
PIDS+=($!)

for _ in $(seq 1 90); do
  curl -sf "http://localhost:$API_PORT/api/health" >/dev/null && curl -sf "http://localhost:$WEB_PORT" >/dev/null && break
  sleep 2
done

npx playwright test "$@"
