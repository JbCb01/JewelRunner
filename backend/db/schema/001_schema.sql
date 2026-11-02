-- JewelRunner: schemat bazy danych, wersja 1
-- Silnik: PostgreSQL 13 lub nowszy
-- Tabele powiązane z graczem mają ON DELETE CASCADE. Dane katalogowe (poziomy, wyzwania,
-- elementy) nie są usuwane, gdy ktoś z nich korzysta: wyzwanie wyłącza się statusem.


-- ============================================================
-- KATALOGI
-- ============================================================

CREATE TABLE poziom (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator poziomu
    nazwa               TEXT NOT NULL, -- nazwa wyświetlana graczowi
    kolejnosc           INTEGER NOT NULL UNIQUE CHECK (kolejnosc > 0), -- kolejność poziomów; następny poziom to kolejna wartość
    pozycja_mapy_x      INTEGER, -- pozycja na mapie świata, oś X
    pozycja_mapy_y      INTEGER, -- pozycja na mapie świata, oś Y
    warunek_odblokowania JSONB, -- warunek odblokowania; NULL oznacza poziom dostępny od początku
    punkt_startowy      JSONB NOT NULL, -- współrzędne startu postaci
    punkty_kontrolne    JSONB NOT NULL DEFAULT '[]' -- lista punktów kontrolnych
);

CREATE TABLE element_personalizacji (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator elementu
    typ                 TEXT NOT NULL CHECK (typ IN ('skórka', 'kolor', 'akcesorium')), -- rodzaj elementu
    nazwa               TEXT NOT NULL, -- nazwa wyświetlana graczowi
    zasob_graficzny     TEXT, -- ścieżka do pliku w Azure Blob Storage; sama grafika nie jest w bazie
    wartosc_koloru      TEXT CHECK (wartosc_koloru ~ '^#[0-9A-Fa-f]{6}$'), -- kolor w formacie HEX, tylko dla typu kolor
    punkt_mocowania     TEXT, -- miejsce na postaci, tylko dla typu akcesorium
    warunek_typ         TEXT CHECK (warunek_typ IN ('wynik w poziomie', 'liczba klejnotów', 'wyzwanie')), -- rodzaj warunku odblokowania
    warunek_wartosc     INTEGER CHECK (warunek_wartosc >= 0), -- wartość progowa warunku
    czy_domyslny        BOOLEAN NOT NULL DEFAULT FALSE, -- element przypisywany przy rejestracji
    UNIQUE (typ, nazwa),
    CHECK ((typ = 'kolor') = (wartosc_koloru IS NOT NULL)),
    CHECK ((typ = 'akcesorium') = (punkt_mocowania IS NOT NULL)),
    CHECK ((warunek_typ IS NULL) = (warunek_wartosc IS NULL))
);
CREATE UNIQUE INDEX ux_element_domyslny ON element_personalizacji (typ) WHERE czy_domyslny;

CREATE TABLE wzmocnienie (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator wzmocnienia
    typ                 TEXT NOT NULL UNIQUE CHECK (typ IN ('tarcza', 'podwójne punkty', 'dodatkowe życie', 'magnes')), -- rodzaj wzmocnienia
    efekt               TEXT NOT NULL, -- opis działania
    czas_trwania_s      INTEGER CHECK (czas_trwania_s > 0) -- czas działania w sekundach; NULL, gdy działanie jest jednorazowe
);

CREATE TABLE oferta_sklepu (
    wzmocnienie_id      BIGINT PRIMARY KEY REFERENCES wzmocnienie (id), -- oferowane wzmocnienie
    cena_w_klejnotach   INTEGER NOT NULL CHECK (cena_w_klejnotach > 0), -- cena zakupu
    dostepnosc          BOOLEAN NOT NULL DEFAULT TRUE -- czy można je teraz kupić
);

CREATE TABLE specjalny_klejnot (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator klejnotu
    nazwa               TEXT NOT NULL UNIQUE, -- nazwa klejnotu
    rzadkosc            TEXT NOT NULL, -- rzadkość klejnotu
    poziom_id           BIGINT NOT NULL REFERENCES poziom (id), -- poziom, w którym występuje
    pozycja_x           INTEGER, -- pozycja w poziomie, oś X
    pozycja_y           INTEGER, -- pozycja w poziomie, oś Y
    tresc_edukacyjna    TEXT -- treść przekazywana przez mówiący klejnot; NULL dla pozostałych
);

CREATE TABLE nagroda (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator nagrody
    typ                 TEXT NOT NULL CHECK (typ IN ('klejnoty', 'skórka', 'akcesorium', 'kolor', 'wzmocnienie')), -- rodzaj nagrody
    liczba_klejnotow    INTEGER CHECK (liczba_klejnotow > 0), -- wartość nagrody typu klejnoty
    element_id          BIGINT REFERENCES element_personalizacji (id), -- element dla nagród typu skórka, akcesorium i kolor
    wzmocnienie_id      BIGINT REFERENCES wzmocnienie (id), -- wzmocnienie dla nagrody typu wzmocnienie
    CHECK (
        (typ = 'klejnoty' AND liczba_klejnotow IS NOT NULL AND element_id IS NULL AND wzmocnienie_id IS NULL)
        OR (typ IN ('skórka', 'akcesorium', 'kolor') AND element_id IS NOT NULL AND liczba_klejnotow IS NULL AND wzmocnienie_id IS NULL)
        OR (typ = 'wzmocnienie' AND wzmocnienie_id IS NOT NULL AND liczba_klejnotow IS NULL AND element_id IS NULL)
    )
);

CREATE TABLE wyzwanie (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator wyzwania
    nazwa               TEXT NOT NULL UNIQUE, -- nazwa wyzwania
    opis                TEXT NOT NULL, -- opis dla gracza
    poziom_trudnosci    TEXT NOT NULL CHECK (poziom_trudnosci IN ('łatwy', 'średni', 'trudny')), -- trudność wyzwania
    poziom_id           BIGINT NOT NULL REFERENCES poziom (id), -- poziom gry powiązany z wyzwaniem
    warunki_udzialu     JSONB NOT NULL DEFAULT '{}', -- warunki sprawdzane przy przyjęciu wyzwania
    warunki_ukonczenia  JSONB NOT NULL, -- warunki zaliczenia wyzwania
    nagroda_id          BIGINT NOT NULL REFERENCES nagroda (id), -- nagroda za ukończenie
    data_rozpoczecia    TIMESTAMPTZ NOT NULL, -- początek dostępności
    data_zakonczenia    TIMESTAMPTZ NOT NULL, -- koniec dostępności
    status              TEXT NOT NULL DEFAULT 'Aktywne' CHECK (status IN ('Aktywne', 'Wygasłe', 'Wyłączone')), -- stan wyzwania
    CHECK (data_zakonczenia > data_rozpoczecia)
);
CREATE INDEX ix_wyzwanie_status ON wyzwanie (status, data_zakonczenia);

CREATE TABLE autor (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator wpisu
    imie_i_nazwisko     TEXT NOT NULL, -- imię i nazwisko autora
    rola                TEXT NOT NULL, -- rola w projekcie
    kolejnosc           INTEGER NOT NULL UNIQUE -- kolejność na liście autorów
);

