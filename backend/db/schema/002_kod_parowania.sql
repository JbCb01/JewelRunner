-- Kody parowania gry z kontem (Sprint 3). Gracz generuje kod w portalu i wpisuje go w grze,
-- więc nie podaje hasła w kliencie gry. Kod jest jednorazowy i ważny kilka minut.
CREATE TABLE kod_parowania (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator kodu
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel konta
    skrot_kodu          TEXT NOT NULL UNIQUE, -- skrót kodu; sam kod nie jest przechowywany
    data_utworzenia     TIMESTAMPTZ NOT NULL DEFAULT now(), -- data wygenerowania w portalu
    data_wygasniecia    TIMESTAMPTZ NOT NULL, -- koniec ważności
    data_uzycia         TIMESTAMPTZ, -- data wymiany na sesję gry; kod nie działa drugi raz
    CHECK (data_wygasniecia > data_utworzenia)
);
CREATE INDEX ix_kod_parowania_gracz ON kod_parowania (gracz_id);
