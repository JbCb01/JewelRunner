-- Pięć łatwych wyzwań na poziomie 1, do zaliczenia w jednym krótkim przejściu.
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

    FOR w IN
        SELECT * FROM (VALUES
            ('Pierwszy klejnot', 'Ukończ poziom, zbierając co najmniej 1 klejnot.', '{"min_klejnotow": 1}', 15, NULL),
            ('Rozgrzewka', 'Ukończ poziom z wynikiem co najmniej 10 punktów.', '{"min_wynik": 10}', 20, NULL),
            ('Mały wynik', 'Ukończ poziom z wynikiem co najmniej 50 punktów.', '{"min_wynik": 50}', 25, NULL),
            ('Bez pośpiechu', 'Ukończ poziom w czasie do 5 minut.', '{"max_czas_s": 300}', 30, NULL),
            ('Zbieracz', 'Ukończ poziom, zbierając co najmniej 3 klejnoty.', '{"min_klejnotow": 3}', NULL, 'dodatkowe życie')
        ) AS t (nazwa, opis, ukonczenie, klejnoty, wzmocnienie)
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
        VALUES (w.nazwa, w.opis, 'łatwy', v_poziom, '{}', w.ukonczenie::jsonb,
                v_nagroda, now() - INTERVAL '1 day', now() + INTERVAL '180 days', 'Aktywne');
    END LOOP;
END $$;
