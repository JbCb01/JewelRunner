# JewelRunner: backend

REST API systemu Jewel Runner: FastAPI, SQLAlchemy, Alembic i PostgreSQL. Zawiera endpointy Sprintu 2: konto i sesję, wyzwania, moje wyzwania, ranking, profil publiczny i zmianę danych.

## Uruchomienie lokalne (WSL)

**1. Środowisko Pythona** (u Kubasia już istnieje, wystarczy aktywować):

    source ~/.venvs/jewelrunner-backend/bin/activate

Nowa instalacja: `python3 -m venv ~/.venvs/jewelrunner-backend`, aktywacja, potem `pip install -r requirements-dev.txt`.

**2. Baza danych.** Wymyśl hasło i wpisz je w miejsce `HASLO`:

    sudo -u postgres psql -c "CREATE ROLE jewelrunner LOGIN PASSWORD 'HASLO';"
    sudo -u postgres psql -c "CREATE DATABASE jewelrunner OWNER jewelrunner;"

**3. Konfiguracja:**

    cp .env.example .env

W pliku `.env` wpisz to samo hasło.

**4. Migracje i dane startowe:**

    alembic upgrade head
    python -m scripts.seed
    python -m scripts.seed_dev   # opcjonalnie: dane przykładowe i konto demo@example.com / Demo12345

**5. Serwer:**

    uvicorn app.main:app --reload

- Sprawdzenie działania: http://localhost:8000/api/health
- Dokumentacja endpointów: http://localhost:8000/api/docs

## Testy

    pytest

Bez `TEST_DATABASE_URL` testy z bazą są pomijane. Aby je uruchomić, utwórz osobną bazę z „test” w nazwie (test ją czyści):

    sudo -u postgres psql -c "CREATE DATABASE jewelrunner_test OWNER jewelrunner;"
    TEST_DATABASE_URL="postgresql+psycopg://jewelrunner:HASLO@localhost:5432/jewelrunner_test" pytest

## Wdrożenie na Azure

Instrukcja jest w `deploy/AZURE.md`.

## Struktura

- `app/main.py`: tworzenie aplikacji, CORS, routery
- `app/core/`: konfiguracja i wspólny format błędów
- `app/db/session.py`: połączenie z bazą
- `app/api/`: endpointy
- `alembic/versions/`: migracje; `0001` wykonuje `db/schema/001_schema.sql`
- `db/seeds/`: dane startowe
- `docs/API_KONTRAKT.md`: kontrakt API dla frontendu

Nowe zmiany w bazie dodajemy jako kolejne migracje Alembica. Nie edytujemy `001_schema.sql` po wdrożeniu.
