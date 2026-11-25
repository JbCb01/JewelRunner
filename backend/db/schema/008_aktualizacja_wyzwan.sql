-- Migracja 0008: podmiana tymczasowych 5 wyzwań z pierwszej wersji 0007 na docelowe 5 wyzwań.
-- Niezbędna na istniejącej bazie (Azure), gdzie migracja 0007 została już zapisana w alembic_version.
DO $$
DECLARE
    v_poziom BIGINT;
    v_nagroda BIGINT;
    v_row RECORD;
BEGIN
    SELECT id INTO v_poziom FROM poziom WHERE kolejnosc = 1;
    IF v_poziom IS NULL THEN
        RETURN;
    END IF;

    -- Usuń stare 5 wyzwań (jeśli nikt w nich nie uczestniczy); pozostałe wyłącz, żeby nie były aktywne.
    WITH usuniete AS (
        DELETE FROM wyzwanie wyz
        WHERE wyz.nazwa IN ('Pierwszy klejnot', 'Rozgrzewka', 'Mały wynik', 'Bez pośpiechu', 'Zbieracz')
          AND NOT EXISTS (SELECT 1 FROM uczestnictwo_w_wyzwaniu u WHERE u.wyzwanie_id = wyz.id)
        RETURNING wyz.nagroda_id
    )
    DELETE FROM nagroda n USING usuniete WHERE n.id = usuniete.nagroda_id;

    UPDATE wyzwanie
    SET status = 'Wyłączone'
    WHERE nazwa IN ('Pierwszy klejnot', 'Rozgrzewka', 'Mały wynik', 'Bez pośpiechu', 'Zbieracz')
      AND status <> 'Wyłączone';

    FOR v_row IN
        SELECT * FROM (VALUES
            ('Garść klejnotów', 'Zbierz co najmniej 10 klejnotów w jednym przejściu poziomu.', 'łatwy', '{"min_klejnotow": 10}', 50, NULL),
            ('Poszukiwacz klejnotów', 'Zbierz co najmniej 30 klejnotów w jednym przejściu poziomu.', 'średni', '{"min_klejnotow": 30}', 150, NULL),
            ('Pełna kolekcja', 'Zbierz wszystkie klejnoty na poziomie w jednym przejściu.', 'trudny', '{"min_klejnotow": 49}', 300, NULL),
            ('Sprinter', 'Ukończ poziom w mniej niż 1 minutę.', 'średni', '{"max_czas_s": 60}', NULL, 'podwójne punkty'),
            ('Mistrz akrobacji', 'Wykonaj 10 udanych tricków w jednym poziomie.', 'średni', '{"min_wynik": 500}', NULL, 'dodatkowe życie')
        ) AS t (nazwa, opis, trudnosc, ukonczenie, klejnoty, wzmocnienie)
    LOOP
        CONTINUE WHEN EXISTS (SELECT 1 FROM wyzwanie WHERE nazwa = v_row.nazwa);

        IF v_row.klejnoty IS NOT NULL THEN
            INSERT INTO nagroda (typ, liczba_klejnotow) VALUES ('klejnoty', v_row.klejnoty) RETURNING id INTO v_nagroda;
        ELSE
            INSERT INTO nagroda (typ, wzmocnienie_id)
            SELECT 'wzmocnienie', id FROM wzmocnienie WHERE typ = v_row.wzmocnienie
            RETURNING id INTO v_nagroda;
            CONTINUE WHEN v_nagroda IS NULL;
        END IF;

        INSERT INTO wyzwanie (nazwa, opis, poziom_trudnosci, poziom_id, warunki_udzialu, warunki_ukonczenia,
                              nagroda_id, data_rozpoczecia, data_zakonczenia, status)
        VALUES (v_row.nazwa, v_row.opis, v_row.trudnosc, v_poziom, '{}', v_row.ukonczenie::jsonb,
                v_nagroda, now() - INTERVAL '1 day', now() + INTERVAL '180 days', 'Aktywne');
    END LOOP;
END $$;

