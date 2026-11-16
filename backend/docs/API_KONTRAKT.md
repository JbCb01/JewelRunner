# Kontrakt API JewelRunner: Sprint 2 i 3

Wersja robocza do uzgodnienia z frontendem. Wszystkie endpointy poniżej są zaimplementowane lokalnie. Ścieżki nieokreślone w planie sprintu są oznaczone „propozycja”.

## Zasady

- Adres bazowy: `/api`. Dane w JSON, daty w ISO 8601 UTC.
- Klucze JSON po angielsku w `snake_case`. Wartości statusów bez zmian z bazy, np. `Aktywne`. Etykietę `Przyjęte` wyświetla portal.
- Sesja: cookie `jr_session` (HttpOnly, Secure, SameSite). Frontend wysyła zapytania z `credentials: "include"` i nie ma dostępu do tokenu.
- Gra (Sprint 3): ten sam token sesji w nagłówku `Authorization: Bearer <token>`. Token gra dostaje z `POST /auth/pair`. Nagłówek ma pierwszeństwo przed cookie.
- Lista zwraca `{"items": [...]}`.
- Bez sesji lub po jej wygaśnięciu: `401 unauthorized`. Dotyczy wszystkich endpointów poza rejestracją, logowaniem, parowaniem gry, wylogowaniem i `health`.

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
| 400 | `invalid_pairing_code` | kod parowania błędny, wygasły lub już użyty |
| 429 | `pairing_locked` | zbyt wiele błędnych kodów parowania na serwerze; spróbować po minucie |
| 409 | `daily_reward_claimed` | nagroda dzienna już dziś odebrana |
| 409 | `save_conflict` | na serwerze jest nowszy zapis gry; `details.server_save` to ten zapis |
| 422 | `corrupted_save` | suma kontrolna zapisu się nie zgadza |
| 422 | `unknown_level`, `invalid_save_time` | nieznany poziom lub data zapisu z przyszłości |
| 422 | `too_many_gems`, `duplicate_operation` | operacje salda poza limitem lub powtórzone w jednym żądaniu |
| 429 | `daily_gem_limit` | z gry dopisano już 10 000 klejnotów w ciągu doby |
| 409 | `level_locked` | wynik z poziomu, którego gracz nie ma odblokowanego |
| 422 | `invalid_period` | nieznany okres rankingu |
| 404/409/422 | `player_not_found`, `already_friend`, `cannot_add_self`, `too_many_friends` | znajomi |
| 409 | `settings_conflict`, `appearance_conflict` | na serwerze jest nowsza zmiana; `details` zawiera aktualne dane |
| 422 | `element_not_owned`, `slot_taken` | personalizacja: element zablokowany lub dwa akcesoria w jednym miejscu |
| 400 | `invalid_token` | link resetu hasła lub potwierdzenia e-maila wygasł albo został użyty |
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

### POST /auth/forgot (8.5, Sprint 3)
Wejście: `{"email"}`. Zawsze `202`: `{"status": "sent_if_exists", "message": "Jeśli konto istnieje, wysłaliśmy link do ustawienia nowego hasła."}` (8.5 A1). Link `<PORTAL_URL>/nowe-haslo?token=...` jest ważny 30 minut; nowy link unieważnia poprzednie; maks. 3 wiadomości na godzinę (A4).

### POST /auth/reset (8.5, Sprint 3)
Wejście: `{"token", "new_password"}`. `204`: hasło zmienione, wszystkie sesje (portal i gra) wylogowane, blokada logowania zdjęta.
Błędy: `400 invalid_token` → „Link wygasł” z opcją wysłania nowego (A2), `422 weak_password` (A3).

### POST /auth/logout
`204`, cookie usunięte. Działa także bez ważnej sesji.

### GET /me (propozycja)
Sprawdza stan zalogowania po odświeżeniu strony.
`200`: `{"id", "username", "email"}`.
Odpowiedź zawiera też `game_linked` (czy gra jest sparowana, czyli ma ważną sesję gry) i `last_synced_at` (kiedy gra ostatnio pobrała `/me/game-state`, albo `null`). Portal pokazuje z nich status „Połączone” w sekcji „Połącz z grą”.

## Parowanie gry z kontem (Sprint 3, integracja gry z portalem)

Gracz loguje się w portalu, generuje kod i wpisuje go w grze. Gra nie prosi o hasło.

### POST /me/pairing-code
Wymaga sesji portalu. Bez treści.
`201`: `{"code": "K7P2QX", "expires_at": "..."}`. Kod ma 6 znaków z alfabetu `A-Z` i `2-9` bez `I`, `L`, `O`, jest ważny 5 minut i działa raz. Nowy kod unieważnia poprzedni. W bazie zapisany jest tylko skrót kodu.

### POST /auth/pair
Wywołuje gra, bez sesji. Wejście: `{"code": "K7P2QX"}`; wielkość liter, spacje i myślniki nie mają znaczenia.
`200`: `{"token": "...", "expires_at": "...", "player": {"id", "username", "email"}}`. Tworzy sesję z urządzeniem `gra`; cookie nie jest ustawiane. Gra zapisuje token lokalnie i wysyła go w `Authorization: Bearer`.
Błędy: `400 invalid_pairing_code`, `403 account_blocked`, `429 pairing_locked` (30 błędnych kodów na minutę dla całego serwera).

### POST /auth/logout z grą
Gra wylogowuje się tym samym endpointem, wysyłając nagłówek `Authorization: Bearer <token>`. Sesja jest unieważniana na serwerze.

## Nagroda dzienna (7.5, Sprint 3)

Dzień ustala serwer według strefy `GAME_TIMEZONE` (domyślnie `Europe/Warsaw`), a nie zegar gracza. Tabela nagród: dzień 1 – 10, 2 – 15, 3 – 20, 4 – 25, 5 – 30, 6 – 40, 7 – 100 klejnotów (nagroda specjalna). Po dniu 7 seria zaczyna się od nowa, a przerwa dłuższa niż jeden dzień resetuje ją do dnia 1.

### GET /me/daily-reward
`200`: `{"today": "2026-11-14", "available": true, "streak_day": 3, "gems": 20, "special": false, "last_claimed": "2026-11-13", "rewards": [{"day": 1, "gems": 10, "special": false}, ...]}`.
`available: true` oznacza, że gra lub portal pokazuje powiadomienie; `streak_day` i `gems` to wtedy nagroda do odebrania. Przy `available: false` to nagroda już odebrana dziś. Odczyt niczego nie zapisuje, więc zamknięte powiadomienie można otworzyć ponownie do końca dnia.

### POST /me/daily-reward/claim
Bez treści. `200`: to samo co `GET` plus `"balance"` (nowe saldo klejnotów). Dodaje klejnoty do portfela, zapisuje datę i serię oraz transakcję typu `zmiana stanu konta`.
Błędy: `409 daily_reward_claimed`. Równoczesne kliknięcia dają jedną wypłatę.

## Wyniki z gry (4.3, 2.3, 2.4, 8.4, Sprint 3)

### POST /game/runs
Gra wysyła wynik po każdym rozegraniu poziomu: po mecie i po porażce. Wymaga tokenu gry (`Authorization: Bearer`).

Wejście:
```json
{"session_id": "SES-1763500000-1234", "level": 1, "completed": true, "score": 300, "time_s": 45.5, "gems": 6, "enemies_defeated": 2}
```
- `session_id`: ID sesji z `Events.generate_session_id()`; ten sam wynik wysłany ponownie nie liczy się drugi raz (`duplicate: true`).
- `level`: numer poziomu (`kolejnosc` w bazie). `completed: false` oznacza porażkę.

W jednej transakcji serwer: zapisuje rozegranie (historia gier), aktualizuje postęp poziomu (liczba prób, najlepszy wynik i czas), po ukończeniu odblokowuje następny poziom (warunek `{"min_wynik": N}` wymaga wyniku N), aktualizuje statystyki (czas gry, ukończone poziomy, pokonani wrogowie, porażki), przelicza ranking i zapisuje próbę w aktywnych wyzwaniach tego poziomu.

Ranking: wynik to suma najlepszych wyników ze wszystkich poziomów, osobno za bieżący tydzień (od poniedziałku), miesiąc i ogółem (strefa `GAME_TIMEZONE`). Wynik w rankingu nigdy nie spada.

Wyzwania: próba zalicza wyzwanie, gdy poziom jest ukończony i spełnione są wszystkie warunki (`ukoncz_poziom`, `min_klejnotow`, `min_wynik`, `max_czas_s`). Wtedy status `Ukończone` i nagroda `Do odebrania`. Niezaliczona próba podnosi postęp do części spełnionych warunków (maks. 99%).

`200`:
```json
{"duplicate": false, "level": 1, "completed": true, "best_score": 300, "best_time_s": 45.5, "attempts": 1,
 "new_best": true, "unlocked_levels": [2],
 "ranking": {"tydzień": {"position": 3, "score": 300}, "miesiąc": {"position": 5, "score": 300}, "ogółem": {"position": 12, "score": 300}},
 "challenges": [{"challenge_id": 1, "name": "Pierwsze kroki", "passed": true, "progress_percent": 100, "status": "Ukończone", "reward_status": "Do odebrania"}]}
```
`ranking.<okres>` jest `null`, gdy gracz nie ma jeszcze wyniku w tym okresie. W odpowiedzi na duplikat `passed` jest `null`.
Błędy: `422 unknown_level`, `409 level_locked`, `422 validation_error`.

## Zapis gry w chmurze (8.2, Sprint 3)

Gra wysyła zapis z tokenem `Authorization: Bearer`. Poziom to jego numer (`kolejnosc` w bazie), a czas to sekundy od 1970-01-01 UTC.

Suma kontrolna: SHA-256 (hex) z tekstu `level|checkpoint|gems|saved_at|game_version`; brak punktu kontrolnego to pusty tekst. W Godocie: `("%d|%s|%d|%d|%s" % [level, checkpoint, gems, saved_at, version]).sha256_text()`.

### GET /me/save
`200`: `{"save": {"level": 1, "level_name": "Poziom 1", "checkpoint": "cp-2", "gems": 12, "saved_at": 1763460000, "saved_at_iso": "...", "game_version": "0.3.0", "checksum": "..."}}` albo `{"save": null}`. Zwraca najnowszy zapis z poprawną sumą kontrolną; uszkodzony jest pomijany i gra dostaje poprzedni poprawny (A3).

### PUT /me/save
Wejście: `{"level", "checkpoint", "gems", "saved_at", "game_version", "checksum"}`. `200`: zapisany zapis (jak w `GET`).
- Starszy zapis niż ten na serwerze: `409 save_conflict` z `details.server_save` (A2). Gra pyta gracza: wczytać zapis z serwera albo zachować swój, wtedy wysyła ponownie z `?force=true` i bieżącą datą.
- Błędna suma kontrolna: `422 corrupted_save`, nic nie jest zapisywane (A3).
- Ten sam zapis wysłany drugi raz nie tworzy duplikatu. Serwer przechowuje 5 ostatnich zapisów gracza.

## Saldo klejnotów z gry (7.1, Sprint 3)

Gra zbiera klejnoty także bez internetu i trzyma je w lokalnej kolejce (`scripts/core/wallet_sync.gd`, plik `user://wallet_queue.json`). Kolejkę wysyła, gdy ma połączenie.

### GET /me/wallet
`200`: `{"gems": 120}`.

### POST /me/wallet/sync
Wejście: `{"operations": [{"id": "SES-1763460000-1234", "gems": 15, "reason": "poziom"}]}`. `id`: 8–64 znaki `A-Z a-z 0-9 _ . : -`, stały dla danej operacji (gra używa ID sesji poziomu). `gems`: 1–500.
`200`: `{"gems": 135, "applied": ["..."], "duplicates": ["..."]}`. Operacja wysłana ponownie trafia do `duplicates` i nie jest liczona drugi raz; gra usuwa z kolejki oba rodzaje.
Limity: 50 operacji i 2000 klejnotów w żądaniu (`422`), 10 000 klejnotów z gry na dobę (`429 daily_gem_limit`). Każda operacja to transakcja `zmiana stanu konta`.

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

## Ranking (2.3, 2.7)

### GET /ranking?period=tydzień|miesiąc|ogółem|znajomi
Działają też `week`, `month`, `overall`, `friends`. Bez `period` serwer zwraca ostatnio wybrany filtr gracza (domyślnie `ogółem`); podany `period` jest zapamiętywany w ustawieniach (`ranking_filter`).
`200`: `{"period": "tydzień", "period_start": "2026-11-16", "items": [{"position", "player_id", "username", "score"}], "me": {"position", "score"} | null, "empty_reason": null | "no_results" | "no_friends", "generated_at"}`.
- Wynik to suma najlepszych wyników z poziomów w okresie; tydzień liczony od poniedziałku, `period_start` jest `null` dla `ogółem`.
- `znajomi`: gracz i jego znajomi z rankingu ogółem, pozycje liczone tylko wśród nich.
- `empty_reason`: `no_results` → „Brak wyników w tym okresie” (2.7 A1), `no_friends` → „Dodaj znajomych” (2.7 A2).
- `items` to najwyżej 100 graczy; `me` pozwala pokazać wiersz gracza poza setką, `null` → „Ukończ poziom, aby pojawić się w rankingu”.
Błąd: `422 invalid_period`.

### GET /players?search=ba
Gracze, których nazwa zaczyna się od podanego tekstu (min. 2 znaki, maks. 10 wyników, bez siebie). `200`: `{"items": [{"player_id", "username", "is_friend"}]}`.

### GET /players/{id}
`200`: `{"id", "username", "statistics": {"play_time_seconds", "levels_completed", "enemies_defeated", "defeats", "longest_combo"}}`.
Błąd: `404 not_found`.

## Znajomi (2.7, Sprint 3)

Lista jest jednostronna (jak obserwowanie), maks. 100 osób.

### GET /me/friends
`200`: `{"items": [{"player_id", "username", "added_at", "score"}]}`; `score` to wynik ogółem albo `null`.

### POST /me/friends
Wejście: `{"username": "Basia"}` (wielkość liter bez znaczenia). `201`: `{"player_id", "username"}`.
Błędy: `404 player_not_found`, `409 already_friend`, `422 cannot_add_self`, `422 too_many_friends`.

### DELETE /me/friends/{player_id}
`204`. Błąd: `404 not_found`.

## Statystyki i historia gier (8.4, Sprint 3)

### GET /me/stats
`200`:
```json
{"has_played": true, "last_synced_at": "...",
 "overall": {"play_time_s": 60, "levels_completed": 1, "enemies_defeated": 3, "defeats": 1, "runs": 2,
             "gems_collected": 7, "gems_balance": 0, "tutorial_completed": false},
 "levels": [{"level": 1, "name": "Poziom 1", "unlocked": true, "unlock_condition": null, "best_score": 300,
             "best_time_s": 40.0, "attempts": 2, "completed": true}]}
```
`has_played: false` → stan zerowy z zachętą do gry (8.4 A1). `levels` zawiera wszystkie poziomy, także zablokowane.

### GET /me/runs?limit=20&before_id=123
Historia gier od najnowszych: `{"items": [{"id", "level", "level_name", "completed", "score", "time_s", "gems", "enemies_defeated", "played_at", "session_id"}], "next_before_id": 120 | null}`. Kolejna strona: `before_id = next_before_id`. `limit` 1–100.

## Ustawienia (3.2–3.5, Sprint 3)

### GET /me/settings
`200`: `{"music_volume": 100, "level_music_volume": 100, "sfx_volume": 100, "resolution": null, "texture_quality": null, "effects_level": null, "graphics_profile": null, "language": "pl", "ranking_filter": "ogółem", "keybindings": {"jump": "W"}, "updated_at": null}`.
`null` oznacza, że gracz tego nie ustawił (gra używa wtedy swoich domyślnych). `/me/game-state` zwraca te same ustawienia bez pól `null`.

### PATCH /me/settings
Zmienia tylko podane pola. Głośności 0–100; `resolution` np. `1920x1080`; `texture_quality`, `effects_level`, `graphics_profile`: `Niski` | `Średni` | `Wysoki`; `language`: `pl` | `en`; `ranking_filter` jak `period` rankingu.
`keybindings` zastępuje całą listę (`{}` przywraca domyślne). Ten sam klawisz nie może być przypisany dwa razy; zarezerwowane: Escape, F11, F12, PrintScreen.
Opcjonalnie `changed_at` (sekundy UTC): zmiana starsza niż zapisana na serwerze → `409 settings_conflict` z `details.server_settings` (wygrywa późniejsza).
`200`: aktualne ustawienia jak w `GET`. Błędy: `422 validation_error`, `409 settings_conflict`.

## Personalizacja (5.1–5.4, 5.8, Sprint 3)

### GET /me/appearance
`200`:
```json
{"current": {"skin": {"id", "name", "asset"}, "color": {"id", "name", "hex"},
             "accessories": [{"slot": "głowa", "accessory": {"id", "name"}, "color": {"id", "name", "hex"} | null}], "updated_at"},
 "catalog": [{"id", "type": "skórka|kolor|akcesorium", "name", "asset", "color_hex", "slot", "owned", "is_new",
              "unlock_condition": null | {"type": "wynik w poziomie|liczba klejnotów|wyzwanie", "value": 500, "challenge_name": null}}],
 "new_count": 1, "newly_unlocked": [{"id", "type", "name"}]}
```
Przed odpowiedzią serwer odblokowuje elementy, których warunek gracz już spełnia. Warunki: „wynik w poziomie” – najlepszy wynik na dowolnym poziomie ≥ wartość; „liczba klejnotów” – łącznie zebrane klejnoty ≥ wartość; „wyzwanie” – ukończone wyzwanie o id = wartość. Nieposiadany element bez warunku można zdobyć tylko jako nagrodę.
Odblokowanie sprawdza też `POST /game/runs` i zwraca nowe elementy w `unlocked_items`.

### PUT /me/appearance
Wejście: `{"skin_id": 3, "color_id": 2, "accessories": [{"accessory_id": 4, "color_id": 2}], "changed_at": 1763600000}` (`changed_at` opcjonalnie).
`200`: aktualny wygląd (jak `current`). Błędy: `422 element_not_owned` (zablokowany lub zły typ, 5.3 A1), `422 slot_taken` (dwa akcesoria w jednym miejscu), `409 appearance_conflict` z `details.server_appearance` (5.3 A3).

### POST /me/appearance/seen
Wejście: `{"element_ids": [3, 4]}` albo `{}` (wszystkie). Usuwa oznaczenie „nowy”. `200`: `{"updated": 2}`.

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
