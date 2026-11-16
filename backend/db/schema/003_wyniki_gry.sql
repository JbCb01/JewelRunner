-- Wyniki z gry (Sprint 3). Tabela ukonczenie_poziomu przechowuje odtąd każde rozegranie poziomu
-- wysłane przez grę, także porażki, więc służy też jako historia gier gracza.
ALTER TABLE ukonczenie_poziomu
    ADD COLUMN czy_ukonczony BOOLEAN NOT NULL DEFAULT TRUE, -- FALSE: porażka (utrata żyć, wyjście z poziomu)
    ADD COLUMN liczba_pokonanych_wrogow INTEGER NOT NULL DEFAULT 0 CHECK (liczba_pokonanych_wrogow >= 0); -- wrogowie pokonani w tej próbie
CREATE INDEX ix_ukonczenie_gracz_data ON ukonczenie_poziomu (gracz_id, data_ukonczenia DESC);
