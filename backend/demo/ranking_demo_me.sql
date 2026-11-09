-- Dodaje wynik do rankingu dla Twojego konta (musi być zarejestrowane w portalu).
-- Użycie: psql ... -v mail='twoj@email' -v score=4000 -f ranking_demo_me.sql
INSERT INTO wpis_rankingu (gracz_id, okres, wynik, data_uzyskania_wyniku)
SELECT id, 'ogółem', :score, now() FROM gracz WHERE lower(email) = lower(:'mail')
ON CONFLICT (gracz_id, okres, poczatek_okresu)
DO UPDATE SET wynik = EXCLUDED.wynik, data_uzyskania_wyniku = EXCLUDED.data_uzyskania_wyniku;

SELECT pozycja, nazwa_uzytkownika, wynik FROM v_ranking WHERE okres = 'ogółem' AND lower(nazwa_uzytkownika) IN (SELECT lower(nazwa_uzytkownika) FROM gracz WHERE lower(email) = lower(:'mail'));
