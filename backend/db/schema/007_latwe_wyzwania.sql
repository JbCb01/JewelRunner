-- Pięć wyzwań na poziomie 1 (klejnoty: 10, 30, wszystkie; czas < 1 min; 10 udanych tricków).
-- Migracja jest idempotentna: pomija istniejące wyzwania, a na pustej bazie (bez poziomu 1
-- i wzmocnień z danych startowych) nic nie robi.
DO $$
DECLARE
    v_poziom BIGINT;
    v_nagroda BIGINT;
    w RECORD;
BEGIN
    SELECT id INTO v_poziom FROM poziom WHERE kolejnosc = 1;
    IF v_poziom IS NULL THEN
        RETURN;
    END IF;

    WITH usuniete AS (
        DELETE FROM wyzwanie w
        WHERE w.nazwa IN ('Pierwszy klejnot', 'Rozgrzewka', 'Mały wynik', 'Bez pośpiechu', 'Zbieracz')
          AND NOT EXISTS (SELECT 1 FROM uczestnictwo_w_wyzwaniu u WHERE u.wyzwanie_id = w.id)
        RETURNING w.nagroda_id
    )
    DELETE FROM nagroda n USING usuniete WHERE n.id = usuniete.nagroda_id;

    FOR w IN
        SELECT * FROM (VALUES
            ('Garść klejnotów', 'Zbierz co najmniej 10 klejnotów w jednym przejściu poziomu.', 'łatwy', '{"min_klejnotow": 10}', 50, NULL),
            ('Poszukiwacz klejnotów', 'Zbierz co najmniej 30 klejnotów w jednym przejściu poziomu.', 'średni', '{"min_klejnotow": 30}', 150, NULL),
            ('Pełna kolekcja', 'Zbierz wszystkie klejnoty na poziomie w jednym przejściu.', 'trudny', '{"min_klejnotow": 49}', 300, NULL),
            ('Sprinter', 'Ukończ poziom w mniej niż 1 minutę.', 'średni', '{"max_czas_s": 60}', NULL, 'podwójne punkty'),
            ('Mistrz akrobacji', 'Wykonaj 10 udanych tricków w jednym poziomie.', 'średni', '{"min_wynik": 500}', NULL, 'dodatkowe życie')
        ) AS t (nazwa, opis, trudnosc, ukonczenie, klejnoty, wzmocnienie)
    LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM wyzwanie WHERE nazwa = w.nazwa);

        IF w.klejnoty IS NOT NULL THEN
            INSERT INTO nagroda (typ, liczba_klejnotow) VALUES ('klejnoty', w.klejnoty) RETURNING id INTO v_nagroda;
        ELSE
            INSERT INTO nagroda (typ, wzmocnienie_id)
            SELECT 'wzmocnienie', id FROM wzmocnienie WHERE typ = w.wzmocnienie
            RETURNING id INTO v_nagroda;
            CONTINUE WHEN v_nagroda IS NULL;
        END IF;

        INSERT INTO wyzwanie (nazwa, opis, poziom_trudnosci, poziom_id, warunki_udzialu, warunki_ukonczenia,
                              nagroda_id, data_rozpoczecia, data_zakonczenia, status)
        VALUES (w.nazwa, w.opis, w.trudnosc, v_poziom, '{}', w.ukonczenie::jsonb,
                v_nagroda, now() - INTERVAL '1 day', now() + INTERVAL '180 days', 'Aktywne');
    END LOOP;
END $$;
