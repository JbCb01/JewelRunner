-- Ustawienia (Sprint 3): gra ma osobny suwak muzyki w menu i w poziomie.
ALTER TABLE ustawienia_gracza
    ADD COLUMN glosnosc_muzyki_poziomu INTEGER NOT NULL DEFAULT 100
        CHECK (glosnosc_muzyki_poziomu BETWEEN 0 AND 100); -- głośność muzyki w poziomie; glosnosc_muzyki dotyczy menu
