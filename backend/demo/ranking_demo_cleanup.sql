-- Usuwa graczy-widmo z demo/ranking_demo.sql razem z ich wynikami i statystykami (kaskadowo).
DELETE FROM gracz WHERE email LIKE '%@ranking.invalid';
SELECT count(*) AS pozostalo_w_rankingu FROM wpis_rankingu;
