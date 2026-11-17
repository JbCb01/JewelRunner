-- Katalog skórek i kolorów z grafik zespołu (Sprint 3).
-- Migracja jest idempotentna, bo baza na Azure ma już dane startowe.
INSERT INTO element_personalizacji (
    typ, nazwa, zasob_graficzny, wartosc_koloru, punkt_mocowania, warunek_typ, warunek_wartosc, czy_domyslny
) VALUES
    ('skórka', 'Noir Stelly', 'noir_stelly', NULL, NULL, 'wynik w poziomie', 1000, FALSE),
    ('skórka', 'Office Stelly', 'office_stelly', NULL, NULL, 'liczba klejnotów', 50, FALSE),
    ('skórka', '2077 Stelly', '2077_stelly', NULL, NULL, 'wynik w poziomie', 2500, FALSE),
    ('skórka', 'Promissed Stelly', 'promissed_stelly', NULL, NULL, 'liczba klejnotów', 150, FALSE),
    ('skórka', 'Retro Stelly', 'retro_stelly', NULL, NULL, 'wyzwanie', 2, FALSE),
    ('kolor', 'Monochrom', NULL, '#505050', NULL, 'wynik w poziomie', 800, FALSE),
    ('kolor', 'Granatowy', NULL, '#2B3A4A', NULL, 'liczba klejnotów', 30, FALSE),
    ('kolor', 'Cyjan', NULL, '#2CE0D2', NULL, 'wynik w poziomie', 2000, FALSE),
    ('kolor', 'Morski', NULL, '#00B4D8', NULL, 'liczba klejnotów', 100, FALSE),
    ('kolor', 'Bursztynowy', NULL, '#F5A623', NULL, 'liczba klejnotów', 80, FALSE)
ON CONFLICT (typ, nazwa) DO NOTHING;
