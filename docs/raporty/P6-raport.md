# Raport P6 — model danych (SQLite z migracjami)

15 października 2026 r. Zadanie: „P6. Model danych" z planu (pkt 9): schemat
SQLite z migracjami według punktu 7 planu.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/rdzen/baza/migracje.dart` | schemat: 16 tabel, 5 indeksów, 3 wyzwalacze |
| `lib/rdzen/baza/baza_gospodarstwa.dart` | otwieranie i migrowanie bazy rolnika |
| `lib/rdzen/baza/baza_slownikow.dart` | odczyt słowników dołączonych do aplikacji wraz z datą danych |
| `lib/rdzen/modele/zabieg.dart` | encje zabiegu i szczegółów oprysku |
| `lib/funkcje/zabiegi/repozytorium_zabiegow.dart` | zapis całego wpisu w jednej transakcji |
| `test/rdzen/baza/baza_gospodarstwa_test.dart` | 12 testów na prawdziwym SQLite |

Decyzje, na których to stoi: `docs/decyzje/ADR-0004-budowa-bazy.md`.

## Trzy rozstrzygnięcia

### Dwie bazy zamiast jednej

`gospodarstwo.sqlite` (dane rolnika) i `slowniki.sqlite` (środki, karencje,
uprawy, kody EPPO). Aktualizacja danych to **podmiana jednego pliku** — bez
dotykania wpisów rolnika i bez migrowania jego bazy. Kopia zapasowa
gospodarstwa nie wlecze za sobą 12 MB słowników.

### Identyfikatory tekstowe (UUID), nie liczniki

Telefon i komputer mają niezależne kopie danych i synchronizują się bez serwera.
Przy `AUTOINCREMENT` dwa urządzenia nadałyby ten sam numer dwóm różnym zabiegom.

### Wpisy są dopisywane, nie nadpisywane

Każda zmiana zabiegu trafia do `historia_zmian` — **wyzwalaczem w bazie**,
a nie dobrą wolą kodu. Usunięcie to `usuniety = 1`, wiersz zostaje.
Testy pilnują wszystkich trzech przypadków: dodania, poprawki (w dzienniku
zostaje poprzednia treść) i cofnięcia wpisu.

## Co model przenosi z zadań P1–P5

| Ustalenie | Gdzie w schemacie |
| --- | --- |
| Jedna działka rolna leży na kilku ewidencyjnych, z powierzchnią części (P4) | `dzialka_rolna_czesc` z `powierzchnia_ar` |
| Karencja jest cechą pary „środek + uprawa", nie samego środka (P2) | `zabieg_oprysk.karencja_dni` przepisywana przy wpisie |
| Niepewnej karencji nie podajemy jako pewnej (P2) | `karencja_potwierdzona` + `karencja_zrodlo` + `karencja_data_etykiety` |
| Kod EPPO wymagany w ewidencji od 2027 r. (P3) | `dzialka_rolna.kod_eppo` i `zabieg_oprysk.kod_eppo` |
| Granice działek z ULDK trzymane lokalnie (P5) | `dzialka_ewidencyjna.geometria_wkt` + `srid` + `zrodlo_geometrii` |
| Dane środka mogą się zmienić po aktualizacji słownika | szczegóły oprysku **kopiowane** do wpisu, nie wskazywane kluczem obcym |

Ostatni punkt jest najważniejszy dla kontroli: ewidencja pokazuje stan z dnia
zabiegu. Gdyby wpis wskazywał na wiersz w słowniku, po aktualizacji danych
rolnik zobaczyłby dzisiejszą dawkę przy zabiegu sprzed roku — albo pustkę,
gdyby środek wycofano.

## Liczby

- 16 tabel, 5 indeksów, 3 wyzwalacze dziennika zmian.
- 12 testów bazy na prawdziwym silniku SQLite (`sqflite_common_ffi`) — ten sam,
  który pojedzie na telefon.
- Razem w projekcie: **131 testów** (38 Fluttera, 93 skryptów danych), wszystkie
  przechodzą; `flutter analyze` bez ostrzeżeń.

## Czego jeszcze nie ma

- **Tabel ewidencji wyliczanej** (trzy rejestry, zestawienie do wniosku) — to
  widoki nad zabiegami, powstaną razem z dokumentami.
- **Synchronizacji** — schemat jest na nią przygotowany (UUID, `zmieniono`,
  `urzadzenie`, dziennik zmian), ale samo składanie dwóch kopii to osobne zadanie.
- **Wypełnienia słowników** — pliki z P1–P3 trzeba jeszcze złożyć w
  `slowniki.sqlite` i dołączyć do aplikacji; dziś baza słowników umie je czytać.

## Następny krok

**P7. Pierwszy ekran** — ścieżka wpisu oprysku według punktu 5 planu, na danych
z P1: pole → rodzaj zabiegu → środek → dawka i przyczyna → zapis, w pięciu
dotknięciach i bez klawiatury.
