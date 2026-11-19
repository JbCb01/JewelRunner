-- Poziomy 2–4 odpowiadające profilom w grze (Ascent, Momentum, Szachownica AI).
-- Migracja jest idempotentna; warunek_odblokowania = NULL, bo gra pozwala wybrać dowolny profil od startu.
INSERT INTO poziom (nazwa, kolejnosc, warunek_odblokowania, punkt_startowy, punkty_kontrolne)
VALUES
    ('Poziom 2', 2, NULL, '{"x": 0, "y": 0}', '[]'),
    ('Poziom 3', 3, NULL, '{"x": 0, "y": 0}', '[]'),
    ('Szachownica AI', 4, NULL, '{"x": 0, "y": 0}', '[]')
ON CONFLICT (kolejnosc) DO NOTHING;
