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

-- ============================================================
-- KONTO
-- ============================================================

CREATE TABLE gracz (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- identyfikator gracza
    nazwa_uzytkownika   TEXT NOT NULL CHECK (length(nazwa_uzytkownika) BETWEEN 3 AND 32), -- nazwa widoczna dla innych
    email               TEXT NOT NULL, -- adres e-mail
    skrot_hasla         TEXT NOT NULL, -- skrót hasła (argon2id lub bcrypt), nigdy samo hasło
    status_konta        TEXT NOT NULL DEFAULT 'aktywne' CHECK (status_konta IN ('aktywne', 'zablokowane')), -- stan konta
    liczba_nieudanych_logowan INTEGER NOT NULL DEFAULT 0 CHECK (liczba_nieudanych_logowan >= 0), -- licznik do blokady po 5 próbach
    zablokowany_do      TIMESTAMPTZ, -- koniec czasowej blokady logowania
    data_rejestracji    TIMESTAMPTZ NOT NULL DEFAULT now(), -- data utworzenia konta
    data_ostatniego_logowania TIMESTAMPTZ, -- data ostatniego logowania
    data_ostatniej_synchronizacji TIMESTAMPTZ, -- data ostatniej synchronizacji z grą
    data_modyfikacji    TIMESTAMPTZ NOT NULL DEFAULT now() -- data ostatniej zmiany danych
);
CREATE UNIQUE INDEX ux_gracz_nazwa ON gracz (lower(nazwa_uzytkownika));
CREATE UNIQUE INDEX ux_gracz_email ON gracz (lower(email));

CREATE TABLE sesja_logowania (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(), -- identyfikator sesji
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel sesji
    skrot_tokenu        TEXT NOT NULL UNIQUE, -- skrót tokenu z cookie; token nie jest przechowywany
    urzadzenie          TEXT NOT NULL CHECK (urzadzenie IN ('gra', 'przeglądarka')), -- skąd zalogowano
    data_utworzenia     TIMESTAMPTZ NOT NULL DEFAULT now(), -- początek sesji
    data_wygasniecia    TIMESTAMPTZ NOT NULL, -- koniec ważności
    data_uniewaznienia  TIMESTAMPTZ -- data wylogowania lub unieważnienia
);
CREATE INDEX ix_sesja_gracz ON sesja_logowania (gracz_id);

CREATE TABLE token_resetu_hasla (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator tokenu
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel konta
    skrot_wartosci      TEXT NOT NULL UNIQUE, -- skrót tokenu wysłanego e-mailem
    data_utworzenia     TIMESTAMPTZ NOT NULL DEFAULT now(), -- data wysłania; służy też do limitu wysyłek
    data_waznosci       TIMESTAMPTZ NOT NULL, -- koniec ważności (30 minut)
    czy_uzyty           BOOLEAN NOT NULL DEFAULT FALSE -- czy token wykorzystano
);
CREATE INDEX ix_token_resetu_gracz ON token_resetu_hasla (gracz_id, data_utworzenia);

CREATE TABLE token_zmiany_emaila (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator tokenu
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel konta
    nowy_email          TEXT NOT NULL, -- adres czekający na potwierdzenie
    skrot_wartosci      TEXT NOT NULL UNIQUE, -- skrót tokenu z linku potwierdzającego
    data_utworzenia     TIMESTAMPTZ NOT NULL DEFAULT now(), -- data wysłania linku
    data_waznosci       TIMESTAMPTZ NOT NULL, -- koniec ważności linku
    czy_uzyty           BOOLEAN NOT NULL DEFAULT FALSE -- czy link wykorzystano
);
CREATE INDEX ix_token_emaila_gracz ON token_zmiany_emaila (gracz_id);

CREATE TABLE ustawienia_gracza (
    gracz_id            UUID PRIMARY KEY REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel ustawień
    glosnosc_muzyki     INTEGER NOT NULL DEFAULT 100 CHECK (glosnosc_muzyki BETWEEN 0 AND 100), -- głośność muzyki w procentach
    glosnosc_efektow    INTEGER NOT NULL DEFAULT 100 CHECK (glosnosc_efektow BETWEEN 0 AND 100), -- głośność efektów w procentach
    rozdzielczosc       TEXT, -- rozdzielczość ekranu
    jakosc_tekstur      TEXT, -- jakość tekstur
    poziom_efektow      TEXT, -- poziom efektów graficznych
    profil_graficzny    TEXT CHECK (profil_graficzny IN ('Niski', 'Średni', 'Wysoki')), -- wybrany profil graficzny
    jezyk               TEXT NOT NULL DEFAULT 'pl', -- język interfejsu
    domyslny_filtr_rankingu TEXT NOT NULL DEFAULT 'ogółem', -- ostatnio wybrany filtr rankingu
    data_modyfikacji    TIMESTAMPTZ NOT NULL DEFAULT now() -- data ostatniej zmiany
);

CREATE TABLE przypisanie_klawisza (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel przypisania
    akcja_sterowania    TEXT NOT NULL, -- nazwa akcji w grze
    klawisz             TEXT NOT NULL, -- przypisany klawisz
    PRIMARY KEY (gracz_id, akcja_sterowania),
    UNIQUE (gracz_id, klawisz)
);

CREATE TABLE znajomy (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    znajomy_id          UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- dodany znajomy
    data_dodania        TIMESTAMPTZ NOT NULL DEFAULT now(), -- data dodania
    PRIMARY KEY (gracz_id, znajomy_id),
    CHECK (gracz_id <> znajomy_id)
);
CREATE INDEX ix_znajomy_znajomy ON znajomy (znajomy_id);

-- ============================================================
-- PROFIL
-- ============================================================

CREATE TABLE statystyki_gracza (
    gracz_id            UUID PRIMARY KEY REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel statystyk
    laczny_czas_gry_s   BIGINT NOT NULL DEFAULT 0 CHECK (laczny_czas_gry_s >= 0), -- łączny czas gry w sekundach
    liczba_ukonczonych_poziomow INTEGER NOT NULL DEFAULT 0 CHECK (liczba_ukonczonych_poziomow >= 0), -- ukończone poziomy
    liczba_pokonanych_wrogow INTEGER NOT NULL DEFAULT 0 CHECK (liczba_pokonanych_wrogow >= 0), -- pokonani wrogowie
    liczba_porazek      INTEGER NOT NULL DEFAULT 0 CHECK (liczba_porazek >= 0), -- liczba porażek
    najdluzsze_combo    INTEGER NOT NULL DEFAULT 0 CHECK (najdluzsze_combo >= 0), -- najdłuższe combo
    czy_samouczek_ukonczony BOOLEAN NOT NULL DEFAULT FALSE -- czy samouczek został ukończony
);

CREATE TABLE portfel_gracza (
    gracz_id            UUID PRIMARY KEY REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel portfela
    liczba_klejnotow    INTEGER NOT NULL DEFAULT 0 CHECK (liczba_klejnotow >= 0), -- saldo klejnotów
    liczba_specjalnych_klejnotow INTEGER NOT NULL DEFAULT 0 CHECK (liczba_specjalnych_klejnotow >= 0) -- saldo specjalnych klejnotów
);

CREATE TABLE posiadany_element (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel
    element_id          BIGINT NOT NULL REFERENCES element_personalizacji (id), -- posiadany element
    data_odblokowania   TIMESTAMPTZ NOT NULL DEFAULT now(), -- data odblokowania
    czy_nowy            BOOLEAN NOT NULL DEFAULT TRUE, -- oznaczenie „nowy” w menu
    PRIMARY KEY (gracz_id, element_id)
);

CREATE TABLE wyglad_postaci (
    gracz_id            UUID PRIMARY KEY REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel
    skorka_id           BIGINT NOT NULL REFERENCES element_personalizacji (id), -- aktywna skórka
    kolor_id            BIGINT NOT NULL REFERENCES element_personalizacji (id), -- aktywny kolor postaci
    data_modyfikacji    TIMESTAMPTZ NOT NULL DEFAULT now() -- data ostatniej zmiany
);

CREATE TABLE wyglad_akcesorium (
    gracz_id            UUID NOT NULL REFERENCES wyglad_postaci (gracz_id) ON DELETE CASCADE, -- właściciel
    punkt_mocowania     TEXT NOT NULL, -- miejsce na postaci; maksymalnie jedno akcesorium
    akcesorium_id       BIGINT NOT NULL REFERENCES element_personalizacji (id), -- założone akcesorium
    kolor_id            BIGINT REFERENCES element_personalizacji (id), -- kolor akcesorium
    PRIMARY KEY (gracz_id, punkt_mocowania)
);

-- ============================================================
-- ROZGRYWKA
-- ============================================================

CREATE TABLE postep_poziomu (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    poziom_id           BIGINT NOT NULL REFERENCES poziom (id), -- poziom
    czy_odblokowany     BOOLEAN NOT NULL DEFAULT FALSE, -- czy gracz może uruchomić poziom
    najlepszy_wynik     INTEGER CHECK (najlepszy_wynik >= 0), -- najlepszy wynik; NULL przed ukończeniem
    najlepszy_czas_s    NUMERIC(8,1) CHECK (najlepszy_czas_s >= 0), -- najlepszy czas w sekundach
    liczba_prob         INTEGER NOT NULL DEFAULT 0 CHECK (liczba_prob >= 0), -- liczba prób
    PRIMARY KEY (gracz_id, poziom_id)
);

CREATE TABLE ukonczenie_poziomu (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator ukończenia
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    poziom_id           BIGINT NOT NULL REFERENCES poziom (id), -- ukończony poziom
    identyfikator_sesji_gry TEXT NOT NULL CHECK (identyfikator_sesji_gry ~ '^SES-[0-9]+-[0-9]{4}$'), -- ID sesji wygenerowane przez grę
    wynik               INTEGER NOT NULL CHECK (wynik >= 0), -- wynik punktowy
    czas_s              NUMERIC(8,1) NOT NULL CHECK (czas_s >= 0), -- czas przejścia w sekundach
    liczba_klejnotow    INTEGER NOT NULL DEFAULT 0 CHECK (liczba_klejnotow >= 0), -- zebrane klejnoty
    data_ukonczenia     TIMESTAMPTZ NOT NULL DEFAULT now(), -- data ukończenia
    UNIQUE (gracz_id, identyfikator_sesji_gry)
);
CREATE INDEX ix_ukonczenie_gracz_poziom ON ukonczenie_poziomu (gracz_id, poziom_id, data_ukonczenia DESC);

CREATE TABLE zapis_gry (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator zapisu
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    poziom_id           BIGINT NOT NULL REFERENCES poziom (id), -- zapisany poziom
    punkt_kontrolny     TEXT, -- ostatni punkt kontrolny
    zebrane_klejnoty    INTEGER NOT NULL DEFAULT 0 CHECK (zebrane_klejnoty >= 0), -- klejnoty w zapisie
    data_zapisu         TIMESTAMPTZ NOT NULL DEFAULT now(), -- data zapisu; wygrywa późniejsza
    wersja_gry          TEXT NOT NULL, -- wersja gry
    suma_kontrolna      TEXT NOT NULL -- suma kontrolna do wykrycia uszkodzenia
);
CREATE INDEX ix_zapis_gracz_data ON zapis_gry (gracz_id, data_zapisu DESC);

CREATE TABLE kolekcja_gracza (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel
    specjalny_klejnot_id BIGINT NOT NULL REFERENCES specjalny_klejnot (id), -- zdobyty klejnot
    data_zdobycia       TIMESTAMPTZ NOT NULL DEFAULT now(), -- data zdobycia
    PRIMARY KEY (gracz_id, specjalny_klejnot_id)
);

-- ============================================================
-- WYZWANIA
-- ============================================================

CREATE TABLE uczestnictwo_w_wyzwaniu (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator uczestnictwa
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    wyzwanie_id         BIGINT NOT NULL REFERENCES wyzwanie (id), -- wyzwanie
    status              TEXT NOT NULL DEFAULT 'Aktywne' CHECK (status IN ('Aktywne', 'Ukończone', 'Wygasłe')), -- stan uczestnictwa
    postep_procent      INTEGER NOT NULL DEFAULT 0 CHECK (postep_procent BETWEEN 0 AND 100), -- postęp w procentach
    najlepszy_wynik     INTEGER CHECK (najlepszy_wynik >= 0), -- najlepszy wynik w wyzwaniu
    data_przyjecia      TIMESTAMPTZ NOT NULL DEFAULT now(), -- data przyjęcia
    status_nagrody      TEXT CHECK (status_nagrody IN ('Do odebrania', 'Odebrana')), -- stan nagrody; NULL przed ukończeniem
    data_odebrania_nagrody TIMESTAMPTZ, -- data odebrania nagrody
    UNIQUE (gracz_id, wyzwanie_id),
    CHECK ((status_nagrody IS NULL) OR (status = 'Ukończone')),
    CHECK ((status_nagrody IS NOT DISTINCT FROM 'Odebrana') = (data_odebrania_nagrody IS NOT NULL))
);
CREATE INDEX ix_uczestnictwo_wyzwanie ON uczestnictwo_w_wyzwaniu (wyzwanie_id);
CREATE INDEX ix_uczestnictwo_gracz_status ON uczestnictwo_w_wyzwaniu (gracz_id, status);

CREATE TABLE proba_wyzwania (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator próby
    uczestnictwo_id     BIGINT NOT NULL REFERENCES uczestnictwo_w_wyzwaniu (id) ON DELETE CASCADE, -- uczestnictwo
    wynik               INTEGER NOT NULL CHECK (wynik >= 0), -- wynik próby
    data_proby          TIMESTAMPTZ NOT NULL DEFAULT now(), -- data próby
    czy_zaliczona       BOOLEAN NOT NULL DEFAULT FALSE -- czy spełniła warunki wyzwania
);
CREATE INDEX ix_proba_uczestnictwo ON proba_wyzwania (uczestnictwo_id, data_proby DESC);

-- ============================================================
-- RANKING
-- ============================================================

CREATE TABLE wpis_rankingu (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    okres               TEXT NOT NULL CHECK (okres IN ('tydzień', 'miesiąc', 'ogółem')), -- rodzaj okresu
    poczatek_okresu     DATE NOT NULL DEFAULT DATE '1970-01-01', -- początek okresu; dla „ogółem” stała data
    wynik               INTEGER NOT NULL CHECK (wynik >= 0), -- wynik w okresie
    data_uzyskania_wyniku TIMESTAMPTZ NOT NULL, -- decyduje o kolejności przy remisie
    PRIMARY KEY (gracz_id, okres, poczatek_okresu),
    CHECK (okres <> 'ogółem' OR poczatek_okresu = DATE '1970-01-01')
);
CREATE INDEX ix_ranking_kolejnosc ON wpis_rankingu (okres, poczatek_okresu, wynik DESC, data_uzyskania_wyniku);

-- Pozycja jest wyliczana. Przy równym wyniku wyżej jest gracz, który uzyskał go wcześniej.
CREATE VIEW v_ranking AS
SELECT
    ROW_NUMBER() OVER (
        PARTITION BY w.okres, w.poczatek_okresu
        ORDER BY w.wynik DESC, w.data_uzyskania_wyniku ASC, w.gracz_id
    ) AS pozycja,
    w.okres,
    w.poczatek_okresu,
    w.gracz_id,
    g.nazwa_uzytkownika,
    w.wynik,
    w.data_uzyskania_wyniku
FROM wpis_rankingu w
JOIN gracz g ON g.id = w.gracz_id
WHERE g.status_konta = 'aktywne';

-- ============================================================
-- EKONOMIA
-- ============================================================

CREATE TABLE posiadane_wzmocnienie (
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- właściciel
    wzmocnienie_id      BIGINT NOT NULL REFERENCES wzmocnienie (id), -- wzmocnienie
    liczba              INTEGER NOT NULL DEFAULT 0 CHECK (liczba >= 0), -- posiadana liczba
    PRIMARY KEY (gracz_id, wzmocnienie_id)
);

CREATE TABLE transakcja (
    id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY, -- identyfikator transakcji
    gracz_id            UUID NOT NULL REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    typ                 TEXT NOT NULL CHECK (typ IN ('zakup w sklepie', 'odbiór nagrody', 'zmiana stanu konta')), -- rodzaj operacji
    kwota_klejnotow     INTEGER NOT NULL, -- zmiana salda: ujemna przy zakupie; 0, gdy nagroda to element
    wzmocnienie_id      BIGINT REFERENCES wzmocnienie (id), -- kupione wzmocnienie
    uczestnictwo_id     BIGINT REFERENCES uczestnictwo_w_wyzwaniu (id), -- uczestnictwo, za które odebrano nagrodę
    klucz_idempotencji  TEXT NOT NULL UNIQUE, -- chroni przed podwójnym rozliczeniem przy powtórzeniu żądania
    data_transakcji     TIMESTAMPTZ NOT NULL DEFAULT now(), -- data transakcji
    CHECK (typ <> 'zakup w sklepie' OR (wzmocnienie_id IS NOT NULL AND kwota_klejnotow < 0)),
    CHECK (typ <> 'odbiór nagrody' OR (uczestnictwo_id IS NOT NULL AND kwota_klejnotow >= 0))
);
CREATE INDEX ix_transakcja_gracz_data ON transakcja (gracz_id, data_transakcji DESC);
-- Nagroda za jedno uczestnictwo może zostać rozliczona tylko raz.
CREATE UNIQUE INDEX ux_transakcja_nagroda ON transakcja (uczestnictwo_id) WHERE typ = 'odbiór nagrody';

CREATE TABLE nagroda_dzienna (
    gracz_id            UUID PRIMARY KEY REFERENCES gracz (id) ON DELETE CASCADE, -- gracz
    data_ostatniej_nagrody DATE, -- data według czasu serwera
    dlugosc_serii       INTEGER NOT NULL DEFAULT 0 CHECK (dlugosc_serii BETWEEN 0 AND 7) -- dni z rzędu; po 7 seria zaczyna się od nowa
);

