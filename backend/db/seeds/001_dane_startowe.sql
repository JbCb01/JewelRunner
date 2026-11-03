-- JewelRunner: dane startowe i przykładowe wyzwania (ST-19)
-- Uruchamiać raz, po migracji 001_schema.sql, na pustej bazie.
-- Ceny, nagrody i warunki są przykładowe. Dane graczy i wyników należą do ST-35.

BEGIN;

INSERT INTO poziom (nazwa, kolejnosc, punkt_startowy, punkty_kontrolne)
VALUES ('Poziom 1', 1, '{"x": 0, "y": 0}', '[]');

-- Elementy przypisywane przy rejestracji
INSERT INTO element_personalizacji (typ, nazwa, wartosc_koloru, punkt_mocowania, czy_domyslny) VALUES
    ('skórka', 'Skórka podstawowa', NULL, NULL, TRUE),
    ('kolor', 'Fioletowy', '#6A3FB5', NULL, TRUE),
    ('skórka', 'Złoty biegacz', NULL, NULL, FALSE),
    ('akcesorium', 'Czapka', NULL, 'głowa', FALSE);

INSERT INTO wzmocnienie (typ, efekt, czas_trwania_s) VALUES
    ('tarcza', 'Chroni przed jednym trafieniem', 30),
    ('podwójne punkty', 'Podwaja zdobywane punkty', 20),
    ('dodatkowe życie', 'Dodaje jedno życie', NULL),
    ('magnes', 'Przyciąga pobliskie klejnoty', 15);

INSERT INTO oferta_sklepu (wzmocnienie_id, cena_w_klejnotach)
SELECT id, CASE typ WHEN 'tarcza' THEN 100 WHEN 'podwójne punkty' THEN 150 WHEN 'dodatkowe życie' THEN 200 ELSE 80 END
FROM wzmocnienie;

INSERT INTO nagroda (typ, liczba_klejnotow) VALUES ('klejnoty', 50), ('klejnoty', 200);
INSERT INTO nagroda (typ, element_id)
SELECT 'skórka', id FROM element_personalizacji WHERE nazwa = 'Złoty biegacz';
INSERT INTO nagroda (typ, wzmocnienie_id)
SELECT 'wzmocnienie', id FROM wzmocnienie WHERE typ = 'tarcza';

-- Różne statusy i terminy pozwalają testować scenariusze 2.1, 2.2 i 2.6
INSERT INTO wyzwanie (nazwa, opis, poziom_trudnosci, poziom_id, warunki_udzialu, warunki_ukonczenia, nagroda_id, data_rozpoczecia, data_zakonczenia, status)
SELECT w.nazwa, w.opis, w.trudnosc, p.id, w.udzial::jsonb, w.ukonczenie::jsonb, n.id, now() + w.start, now() + w.koniec, w.status
FROM (VALUES
    ('Pierwsze kroki', 'Ukończ pierwszy poziom.', 'łatwy', '{}', '{"ukoncz_poziom": true}', 'klejnoty', 50, INTERVAL '-1 day', INTERVAL '30 days', 'Aktywne'),
    ('Łowca klejnotów', 'Zbierz wszystkie klejnoty w jednym przejściu.', 'średni', '{}', '{"min_klejnotow": 5}', 'klejnoty', 200, INTERVAL '-1 day', INTERVAL '14 days', 'Aktywne'),
    ('Mistrz czasu', 'Ukończ poziom poniżej 60 sekund.', 'trudny', '{"poziom_odblokowany": 1}', '{"max_czas_s": 60}', 'skórka', NULL, INTERVAL '-1 day', INTERVAL '7 days', 'Aktywne'),
    ('Akrobata', 'Zdobądź 500 punktów w jednym przejściu.', 'średni', '{}', '{"min_wynik": 500}', 'wzmocnienie', NULL, INTERVAL '-30 days', INTERVAL '-1 day', 'Wygasłe'),
    ('Wyzwanie testowe', 'Wyzwanie wyłączone przez administratora.', 'łatwy', '{}', '{"ukoncz_poziom": true}', 'klejnoty', 50, INTERVAL '-5 days', INTERVAL '5 days', 'Wyłączone')
) AS w (nazwa, opis, trudnosc, udzial, ukonczenie, nagroda_typ, nagroda_klejnoty, start, koniec, status)
CROSS JOIN LATERAL (SELECT id FROM poziom WHERE kolejnosc = 1) p
CROSS JOIN LATERAL (
    SELECT id FROM nagroda
    WHERE typ = w.nagroda_typ AND (w.nagroda_klejnoty IS NULL OR liczba_klejnotow = w.nagroda_klejnoty)
    LIMIT 1
) n;

COMMIT;
