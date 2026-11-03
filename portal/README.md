# JewelRunner: portal gracza

Aplikacja React (Vite, TypeScript) korzystająca z REST API z folderu `backend`. Portal jest przeznaczony na przeglądarki na komputerach.

## Uruchomienie

1. Uruchom backend zgodnie z `../backend/README.md` (adres `http://localhost:8000`).
2. W tym folderze:

       npm install
       npm run dev

3. Otwórz http://localhost:5173. Po załadowaniu danych przykładowych można zalogować się kontem `demo@example.com` / `Demo12345`.

Zapytania do `/api` przechodzą przez serwer Vite. Na innym adresie API ustaw `VITE_API_URL` przy budowaniu oraz `CORS_ORIGINS` i `SESSION_COOKIE_SAMESITE` w backendzie.

## Testy

    npm test            # testy jednostkowe
    ./e2e/run.sh        # testy E2E na tymczasowej bazie, prawdziwym API i przeglądarce

Pierwsze uruchomienie E2E wymaga `npx playwright install chromium`. Jeśli przeglądarce brakuje bibliotek systemowych, zainstaluj je poleceniem `sudo npx playwright install-deps chromium`.

Zrzuty ekranów w `docs/ekrany` powstają podczas testów E2E.
