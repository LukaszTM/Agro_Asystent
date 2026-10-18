# Raport P5 — granice działek z ULDK i mapa offline

15 października 2026 r. Zadanie: „P5. Prototyp ULDK" z planu (pkt 9):
pobranie granic po identyfikatorze, zapis lokalny, wyświetlenie na mapie offline.

## Stan zadania

| Część | Stan |
| --- | --- |
| Klient usługi ULDK (budowa zapytania, odczyt odpowiedzi, pamięć podręczna) | **gotowe i sprawdzone na żywej usłudze** |
| Zapis granic do bazy lokalnej | **gotowe** |
| Rysowanie granic bez internetu | **gotowe** |
| Decyzja o podkładzie mapy | **gotowe** — `docs/decyzje/ADR-0003-mapa-offline.md` |
| Sprawdzenie na prawdziwych działkach | **gotowe** — 20 z 20 działek z prawdziwego wniosku |

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/p5_uldk/klient.py` | pobiera granice działek z ULDK i zapisuje do `dane/wynik/dzialki.sqlite` |
| `tools/p5_uldk/mapa.py` | zamienia geometrię WKT na rysunek SVG — bez żadnego serwera kafelków |
| `tools/p5_uldk/test_uldk.py` | 13 testów (bez łączenia się z siecią) |

Klient korzysta ze wspólnego pobieracza z P1/P2: sprawdza `robots.txt`,
przedstawia się nagłówkiem User-Agent, robi przerwy między żądaniami, nie
pobiera ponownie tego, co już ma, i ponawia próbę przy zerwanym połączeniu.
Granice pobiera się **raz na działkę** — potem wszystko dzieje się offline.

## Sprawdzenie na prawdziwej usłudze

Po dodaniu `uldk.gugik.gov.pl` do dozwolonych domen klient pobrał granice
**20 z 20 działek** z prawdziwego wniosku (identyfikatory odczytane przez
czytnik z P4). Pliki zostały w katalogu roboczym poza repozytorium.

Pierwsze uruchomienie zwróciło jednak **20 błędów „w odpowiedzi nie ma
geometrii"** — znów rozbieżność między dokumentacją a rzeczywistością:

| Zakładałem | Jak jest naprawdę |
| --- | --- |
| Geometria jako czyste WKT: `POLYGON((…))` | **EWKT z przedrostkiem układu**: `SRID=4326;POLYGON((…))` |
| Pola odpowiedzi w stałym układzie | Pola wracają **w kolejności, w jakiej je zamówiono** w parametrze `result` |
| `region` to województwo | `region` to **obręb ewidencyjny**; województwo to `voivodeship` |

Po poprawce wszystkie 20 działek odczytuje się poprawnie, razem z nazwą
województwa, powiatu, gminy i obrębu. Format EWKT i przypisanie pól są objęte
testami na prawdziwej treści odpowiedzi.

### Kontrola krzyżowa powierzchni

Powierzchnia policzona z geometrii ULDK: **32,78 ha**. Powierzchnia z tabeli X
wniosku: **33,04 ha**. Różnica **0,26 ha (0,8%)** bierze się z przybliżenia
przy liczeniu pola na współrzędnych geograficznych — dla kontroli „czy to na
pewno te działki" w zupełności wystarcza. Gdyby aplikacja miała podawać
powierzchnię do dokumentów, trzeba będzie liczyć pole w układzie metrycznym
(EPSG:2180, który ULDK zwraca na żądanie).

### Identyfikatory: skąd je brać

Przy okazji wyszła pułapka: **tabela X wniosku podaje numer obrębu bez kodu
gminy** (`0007.138`), więc nie nadaje się dla ULDK. Pełne identyfikatory
(`061506_2.0007.138`) są w tabeli XI i stamtąd czytnik z P4 je teraz eksportuje.

## Mapa bez internetu — sprawdzona

Na zmyślonej geometrii (9 działek) rysunek powstaje poprawnie: obrysy, numery
działek, kolory z makiety aplikacji, poprawka na zbieżność południków, żeby
działki nie wyglądały na rozciągnięte. Rysunek nie wymaga żadnego połączenia.

Decyzja o podkładzie: **etap 1 bez zdjęcia lotniczego** (ADR-0003). Publiczne
serwery OpenStreetMap zabraniają masowego pobierania kafelków, a warunki
trzymania ortofotomapy z Geoportalu offline nadal nie są potwierdzone. Dla
wyboru pola wystarczy obrys, numer działki i własna nazwa pola.

## Następny krok

**P6. Model danych** — schemat SQLite z migracjami według punktu 7 planu.
Wszystkie cztery źródła danych są już rozpoznane: rejestr środków (P1),
etykiety i karencja (P2), słownik upraw i kody EPPO (P3), wniosek (P4),
granice działek (P5). Teraz trzeba je złożyć w jedną bazę aplikacji.

## Uzupełnienie (2026-10-18): czego ULDK nie umie

Specyfikacja (`https://uldk.gugik.gov.pl/opis.html`) nie przewiduje żadnego
zapytania o **listę** jednostek. Są tylko `Get…ById` / `Get…ByXY` dla działki,
budynku, obrębu, gminy, powiatu i województwa oraz `GetParcelByIdOrNr`.
Pierwsza wersja wyboru działki „z list" (`GetVoivodeships`, `GetCounties`,
`GetCommunes`, `GetRegions`) zakładała zapytania, których usługa nie ma —
wyszło to w teście na telefonie i zostało zastąpione:

- lista 16 województw jedzie z aplikacją jako dane
  (`assets/dane/wojewodztwa.json`, buduje `tools/dzialki/wojewodztwa.py`
  z `GetVoivodeshipById` dla kodów 02–32);
- działkę spoza wniosku szuka się przez `GetParcelByIdOrNr` zapisem
  „nazwa obrębu numer"; usługa oddaje **wszystkie** pasujące działki w kraju
  (pierwszy wiersz to liczba wyników, nie status; brak wyników to
  `-1 brak wyników`), każdą z województwem, powiatem i gminą. Wybór
  województwa zawęża listę po pierwszych dwóch cyfrach identyfikatora,
  a gminę wskazuje rolnik.

Sprawdzone na żywo 2026-10-18: „Krzewina 134" → 1 działka, „Dąbrowa 12" →
61 działek, „Stara Wieś 756" → 8, „Krzewina 134/2" → 2; brak numeru daje
`-1 brak wyników - nie podano numeru działki`.
