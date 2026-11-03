# Kontrakt API JewelRunner: Sprint 2

Wersja robocza do uzgodnienia z frontendem. Wszystkie endpointy poniżej są zaimplementowane lokalnie. Ścieżki nieokreślone w planie sprintu są oznaczone „propozycja”.

## Zasady

- Adres bazowy: `/api`. Dane w JSON, daty w ISO 8601 UTC.
- Klucze JSON po angielsku w `snake_case`. Wartości statusów bez zmian z bazy, np. `Aktywne`. Etykietę `Przyjęte` wyświetla portal.
- Sesja: cookie `jr_session` (HttpOnly, Secure, SameSite). Frontend wysyła zapytania z `credentials: "include"` i nie ma dostępu do tokenu.
- Lista zwraca `{"items": [...]}`.
- Bez sesji lub po jej wygaśnięciu: `401 unauthorized`. Dotyczy wszystkich endpointów poza rejestracją, logowaniem, wylogowaniem i `health`.

## Błędy

Każdy błąd ma ten sam format. Portal wybiera komunikat na podstawie `code`.

```json
{"error": {"code": "email_taken", "message": "Tekst dla użytkownika", "details": null}}
```

| Status | Kod | Znaczenie |
|---|---|---|
| 401 | `unauthorized` | brak ważnej sesji |
| 404 | `not_found` | nieznany adres |
| 422 | `validation_error` | błędne dane; `details`: lista `{field, message}` |
| 403 | `forbidden` | operacja zmieniająca dane z niedozwolonego adresu (`Origin`) |
| 429 | `login_locked` | 5 błędnych haseł (także przy zmianie e-maila lub hasła); blokada na 15 minut |
| 500 | `internal_error` | błąd serwera |
| 503 | `database_unavailable` | baza niedostępna;; na stronie rankingu portal pokazuje zapamiętane dane (2.3 A3) |

## Konto (8.1)

### POST /auth/register
Wejście: `{"username", "email", "password"}`. Hasło: min. 8 znaków, litera i cyfra.
`201`: dane z `GET /me` oraz cookie sesji.
Błędy: `409 username_taken`, `409 email_taken`, `422 weak_password`.

### POST /auth/login
Wejście: `{"email", "password"}`.
`200`: dane z `GET /me` oraz cookie sesji.
Błędy: `401 invalid_credentials`, `403 account_blocked` (konto zablokowane przez administratora), `429 login_locked` (po 5 nieudanych próbach, na 15 minut).

### POST /auth/logout
`204`, cookie usunięte. Działa także bez ważnej sesji.

### GET /me (propozycja)
Sprawdza stan zalogowania po odświeżeniu strony.
`200`: `{"id", "username", "email"}`.

## Wyzwania (2.1, 2.6, 2.2)

### GET /challenges
`200`: `items`: `{"id", "name", "difficulty", "reward", "ends_at", "participation_status"}`.
`participation_status` to status uczestnictwa albo `null`, gdy gracz nie przyjął wyzwania. Pusta lista oznacza „Brak dostępnych wyzwań”.

`reward`: `{"type", "gems", "element_name", "booster_type"}`; wypełnione są tylko pola danego typu.

### GET /challenges/{id}
`200`: `{"id", "name", "description", "difficulty", "level", "completion_conditions", "reward", "starts_at", "ends_at", "participation": {"status", "progress_percent"} | null}`.
Błąd: `404 challenge_unavailable` (wyzwanie wygasłe, wyłączone lub usunięte).

### POST /challenges/{id}/accept
`201`: `{"status", "accepted_at", "completion_conditions"}`.
Gdy gracz już uczestniczy: `200` z tą samą treścią i bez nowego zapisu (2.2 A1).
Błędy: `404 challenge_unavailable`, `409 participation_requirements_not_met` (`details` podaje brakujący warunek).

## Moje wyzwania (2.4)

### GET /me/challenges
`200`: `items`: `{"challenge_id", "name", "status", "progress_percent", "ends_at", "best_score"}`.
Status: `Aktywne`, `Ukończone` lub `Wygasłe` (portal pokazuje „Zakończone – nieukończone”).

### GET /me/challenges/{id}/attempts
`{id}` to identyfikator wyzwania.
`200`: `{"best_score", "items": [{"score", "attempted_at", "passed"}]}`. Pusta lista oznacza „Brak prób”.
Błąd: `404 not_found`, także gdy to uczestnictwo innego gracza.

## Ranking (2.3)

### GET /ranking
`200`: `{"items": [{"position", "player_id", "username", "score"}], "me": {"position", "score"} | null, "generated_at"}`.
`items` to najwyżej 100 najlepszych graczy. `me` pozwala pokazać wiersz poza setką. `null` oznacza „Ukończ poziom, aby pojawić się w rankingu”.

### GET /players/{id}
`200`: `{"id", "username", "statistics": {"play_time_seconds", "levels_completed", "enemies_defeated", "defeats", "longest_combo"}}`.
Błąd: `404 not_found`.

## Profil (8.6)

### PATCH /me
Wejście: `{"username"}`. `200`: dane z `GET /me`.
Błędy: `409 username_taken`, `422 validation_error`.

### POST /me/email (propozycja)
Wejście: `{"new_email", "current_password"}`. `202`: link wysłany na nowy adres.
Błędy: `403 invalid_password`, `409 email_taken`, `503 email_unavailable`.

### POST /me/email/confirm (propozycja)
Wejście: `{"token"}` z linku. Wymaga zalogowania na to samo konto. `200`: dane z `GET /me`.
Błędy: `400 invalid_token`, `409 email_taken`.

### POST /me/password (propozycja)
Wejście: `{"current_password", "new_password"}`. `204`.
Błędy: `403 invalid_password`, `422 weak_password`.

## Do ustalenia

- Link z 8.1 A2 prowadzi do odzyskiwania hasła (8.5), które nie należy do sprintu.
- Link potwierdzający prowadzi do `PORTAL_URL/potwierdz-email?token=...`; taką stronę musi mieć portal.
- Adres docelowy portalu na Azure.
