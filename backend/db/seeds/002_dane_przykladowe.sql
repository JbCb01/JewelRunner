-- JewelRunner: dane przykładowe tylko do pracy lokalnej i testów (ST-35).
-- Do czasu połączenia gry z serwerem zapełniają ranking, uczestnictwa i próby.
-- Konta: demo@example.com i demo2@example.com, hasło Demo12345. Nie uruchamiać na produkcji.

BEGIN;

CREATE TEMP TABLE _hash ON COMMIT DROP AS SELECT '$argon2id$v=19$m=65536,t=3,p=4$mvb3NGMWDLJnwmagu9ataQ$kohZgIX/1QfDTlLxFHsmy9zcD5cSHqIasm4w0/h7/ns'::text AS h;

INSERT INTO gracz (nazwa_uzytkownika, email, skrot_hasla)
SELECT 'gracz' || lpad(n::text, 3, '0'), 'gracz' || lpad(n::text, 3, '0') || '@example.com', (SELECT h FROM _hash)
FROM generate_series(1, 120) AS n;

INSERT INTO gracz (nazwa_uzytkownika, email, skrot_hasla)
SELECT nazwa, email, (SELECT h FROM _hash)
FROM (VALUES ('Demo', 'demo@example.com'), ('Demo2', 'demo2@example.com')) AS d (nazwa, email);

INSERT INTO statystyki_gracza (gracz_id, laczny_czas_gry_s, liczba_ukonczonych_poziomow, liczba_pokonanych_wrogow, liczba_porazek, najdluzsze_combo)
SELECT id, 3600 + (row_number() OVER (ORDER BY nazwa_uzytkownika)) * 60, 1, 10, 3, 5 FROM gracz;

INSERT INTO portfel_gracza (gracz_id, liczba_klejnotow) SELECT id, 250 FROM gracz;

INSERT INTO wyglad_postaci (gracz_id, skorka_id, kolor_id)
SELECT g.id,
       (SELECT id FROM element_personalizacji WHERE typ = 'skórka' AND czy_domyslny),
       (SELECT id FROM element_personalizacji WHERE typ = 'kolor' AND czy_domyslny)
FROM gracz g;

INSERT INTO posiadany_element (gracz_id, element_id)
SELECT g.id, e.id FROM gracz g CROSS JOIN element_personalizacji e WHERE e.czy_domyslny;

-- Ranking ogólny: 120 graczy, co dziesiąty ma remis z poprzednim.
INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku)
SELECT g.id, 'ogółem',
       5000 - (s.n - (CASE WHEN mod(s.n, 10) = 0 THEN 1 ELSE 0 END)) * 10,
       TIMESTAMPTZ '2026-10-01 12:00+00' + s.n * INTERVAL '1 hour'
FROM generate_series(1, 120) AS s (n)
JOIN gracz g ON g.nazwa_uzytkownika = 'gracz' || lpad(s.n::text, 3, '0');

-- Demo: remis z gracz050, ale późniejszy wynik, więc tuż za nim. Demo2: poza pierwszą setką.
INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku)
SELECT g.id, 'ogółem', w.wynik, TIMESTAMPTZ '2026-11-01 12:00+00'
FROM (VALUES ('Demo', 4500), ('Demo2', 5)) AS w (nazwa, wynik)
JOIN gracz g ON g.nazwa_uzytkownika = w.nazwa;

INSERT INTO ukonczenie_poziomu (gracz_id, poziom_id, identyfikator_sesji_gry, wynik, czas_s, liczba_klejnotow)
SELECT g.id, (SELECT id FROM poziom WHERE kolejnosc = 1), 'SES-1793224991-3268', 4500, 62.4, 5
FROM gracz g WHERE g.nazwa_uzytkownika = 'Demo';

-- Uczestnictwa konta Demo w każdym statusie.
INSERT INTO uczestnictwo_w_wyzwaniu (gracz_id, wyzwanie_id, status, postep_procent, najlepszy_wynik, status_nagrody)
SELECT g.id, w.id, d.status, d.postep, d.wynik, d.nagroda
FROM (VALUES
    ('Pierwsze kroki', 'Aktywne', 40, 120, NULL),
    ('Łowca klejnotów', 'Ukończone', 100, 900, 'Do odebrania'),
    ('Akrobata', 'Wygasłe', 20, 100, NULL)
) AS d (wyzwanie, status, postep, wynik, nagroda)
JOIN wyzwanie w ON w.nazwa = d.wyzwanie
CROSS JOIN gracz g
WHERE g.nazwa_uzytkownika = 'Demo';

INSERT INTO proba_wyzwania (uczestnictwo_id, wynik, data_proby, czy_zaliczona)
SELECT u.id, p.wynik, p.data::timestamptz, p.zaliczona
FROM (VALUES
    ('Pierwsze kroki', 80, '2026-11-01 10:00+00', FALSE),
    ('Pierwsze kroki', 120, '2026-11-02 10:00+00', FALSE),
    ('Łowca klejnotów', 900, '2026-11-03 10:00+00', TRUE)
) AS p (wyzwanie, wynik, data, zaliczona)
JOIN wyzwanie w ON w.nazwa = p.wyzwanie
JOIN uczestnictwo_w_wyzwaniu u ON u.wyzwanie_id = w.id
JOIN gracz g ON g.id = u.gracz_id AND g.nazwa_uzytkownika = 'Demo';

COMMIT;
