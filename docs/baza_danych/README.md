# JewelRunner: model bazy danych

Dokumentacja i kopia skryptów bazy danych systemu Jewel Runner. Źródłem prawdy jest folder `backend`: schemat w `backend/db/schema/001_schema.sql`, migracje w `backend/alembic/versions`. Ten folder zawiera kopię pierwszej wersji schematu i dokument opisujący model. Przy każdej zmianie schematu zaktualizuj oba miejsca.

| Plik | Zawartość |
|---|---|
| `Model_bazy_danych_JewelRunner.docx` | diagramy ERD, opis 30 tabel i widoku `v_ranking`, stan użycia tabel w aplikacji, decyzje projektowe |
| `erd.mmd` | pełny diagram w Mermaid |
| `migrations/001_schema.sql` | schemat: 30 tabel i widok rankingu (PostgreSQL 13 lub nowszy) |
| `seeds/001_dane_startowe.sql` | dane startowe wczytywane także na Azure |
| `seeds/002_dane_przykladowe.sql` | dane przykładowe (122 graczy, ranking, uczestnictwa); tylko praca lokalna i testy |

## Stan na 11.11.2026
- Baza działa na Azure Database for PostgreSQL (Flexible Server, B1ms, PostgreSQL 18, Norway East).
- Działające API korzysta z 16 tabel i widoku `v_ranking`. Pozostałe 14 tabel czeka na kod w kolejnych sprintach (lista w rozdziale 4 dokumentu).
