-- Przykładowy ranking na pokaz (sprint review). Gra nie wysyła jeszcze wyników, więc ranking jest pusty.
-- Dodaje 18 graczy-widmo: nie da się na nich zalogować (hasło jest nieprawidłowym skrótem), mają adres w domenie .invalid.
-- Można uruchomić ponownie, nie duplikuje danych. Usuwanie: demo/ranking_demo_cleanup.sql.

BEGIN;

CREATE TEMP TABLE _demo (nazwa text, wynik int, kiedy timestamptz, czas_gry int, wrogowie int, porazki int, combo int) ON COMMIT DROP;
INSERT INTO _demo VALUES
    ('Skoczek_91',   4820, '2026-11-02 18:20+00', 14400, 210,  9, 14),
    ('DashQueen',    4710, '2026-11-03 09:05+00', 12600, 188,  7, 12),
    ('KlejnotMistrz',4505, '2026-11-01 20:40+00', 21600, 240, 15, 11),
    ('Wspinacz',     4390, '2026-11-04 16:10+00',  9000, 120, 11,  9),
    ('NocnyBiegacz', 4250, '2026-11-05 22:30+00', 18000, 165, 20, 10),
    ('Trickster',    4120, '2026-11-02 12:00+00', 10800,  98,  8, 17),
    ('PixelRunner',  3990, '2026-11-06 08:15+00',  7200,  80,  6,  8),
    ('SzybkaStopa',  3900, '2026-11-03 19:00+00',  8400,  90, 12,  9),
    ('Gemma',        3900, '2026-11-05 10:00+00',  9600, 101, 10,  7),
    ('Jewelka',      3770, '2026-11-04 11:45+00', 15000, 130, 18,  6),
    ('Odbijacz',     3640, '2026-11-06 14:20+00',  6000,  70,  9,  8),
    ('CichyBiegacz', 3500, '2026-11-01 07:30+00',  5400,  64, 14,  5),
    ('Stellyt',      3310, '2026-11-07 17:00+00', 12000,  95, 22,  7),
    ('Zawisly',      3150, '2026-11-02 21:10+00',  4800,  55, 13,  4),
    ('MalyKlejnot',  2980, '2026-11-05 13:35+00',  3600,  40, 11,  5),
    ('Rozbieg',      2760, '2026-11-06 19:50+00',  3000,  33, 16,  3),
    ('PierwszyKrok', 2400, '2026-11-07 09:25+00',  1800,  20, 19,  2),
    ('Nowicjusz',    1950, '2026-11-08 15:00+00',  1200,  12, 25,  1);

INSERT INTO gracz (nazwa_uzytkownika, email, skrot_hasla)
SELECT nazwa, lower(nazwa) || '@ranking.invalid', '!'
FROM _demo
ON CONFLICT DO NOTHING;

INSERT INTO statystyki_gracza (gracz_id, laczny_czas_gry_s, liczba_ukonczonych_poziomow, liczba_pokonanych_wrogow, liczba_porazek, najdluzsze_combo)
SELECT g.id, d.czas_gry, 1, d.wrogowie, d.porazki, d.combo
FROM _demo d JOIN gracz g ON g.email = lower(d.nazwa) || '@ranking.invalid'
ON CONFLICT DO NOTHING;

INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku)
SELECT g.id, 'ogółem', d.wynik, d.kiedy
FROM _demo d JOIN gracz g ON g.email = lower(d.nazwa) || '@ranking.invalid'
ON CONFLICT DO NOTHING;

COMMIT;

SELECT count(*) AS graczy_w_rankingu FROM v_ranking WHERE okres = 'ogółem';
