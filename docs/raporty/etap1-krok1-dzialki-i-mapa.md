# Raport etap 1, krok 1 — działki i mapa

15 października 2026 r. Zadanie z planu (pkt 4, krok 1):
„Działki i mapa (dodawanie po numerze ewidencyjnym, granice z ULDK,
praca offline)".

## Co rolnik może zrobić

Od ekranu głównego do zapisanej działki z granicami:

1. **Pola**
2. **Działki i mapa**
3. **Dodaj działkę po numerze**
4. numer dużą klawiaturą (cyfry oraz `_`, `.`, `/` — bez klawiatury systemowej)
5. **Znajdź działkę**
6. **Tak, to moja działka**

Potwierdzenie na mapie jest obowiązkowe, bo nazwy obrębów powtarzają się w
kraju i sam numer nie wystarczy (plan, pkt 6.1). Po zapisie mapa rysuje się
z granic leżących na urządzeniu — bez internetu i bez serwera kafelków
(ADR-0003).

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/rdzen/uslugi/geometria.dart` | odczyt WKT/EWKT, zasięg, środek, przybliżona powierzchnia |
| `lib/funkcje/dzialki/klient_uldk.dart` | zapytanie do ULDK, odczyt odpowiedzi, komunikaty dla rolnika |
| `lib/funkcje/dzialki/repozytorium_dzialek.dart` | zapis działki z granicami, układem, źródłem i datą pobrania |
| `lib/wyglad/prosty/dzialki/mapa_dzialek.dart` | mapa z granic lokalnych (`CustomPainter`), poprawka zbieżności południków |
| `lib/wyglad/prosty/dzialki/ekran_dzialki.dart` | lista działek + mapa + wejście do dodawania |
| `lib/wyglad/prosty/dzialki/ekran_dodaj_dzialke.dart` | numer → granice → potwierdzenie → zapis |
| `lib/wyglad/prosty/widgety/klawiatura_numeru.dart` | duża klawiatura numeru (14 klawiszy, cel dotyku ≥ 48 px) |

Zmiany w istniejących plikach: `lib/app/uslugi.dart` i `lib/app/start.dart`
(dochodzi repozytorium działek i klient ULDK), `lib/wyglad/prosty/ekran_pola.dart`
(przycisk „Działki i mapa").

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 7 |
| Nowe pliki testów | 4 |
| Testy dodane w tym kroku | 30 |
| Testy w całym projekcie | 76 (było 46) |
| `flutter analyze` | bez ostrzeżeń |
| Zapytania do sieci przy rysowaniu mapy z bazy | 0 (pilnuje tego test) |

## Czego pilnują testy

- **EWKT, nie WKT.** ULDK zwraca `SRID=4326;POLYGON(...)` — przedrostek jest
  odczytywany, a nie wycinany na oślep (lekcja z P5).
- **Kolejność pól odpowiedzi** idzie za parametrem `result`, a `region` to
  obręb, nie województwo (druga lekcja z P5).
- **Nieznany rodzaj geometrii to błąd**, nie puste granice — zgodnie z zasadą
  „nie zgadujemy" wolimy komunikat niż narysowanie czegoś przypadkowego.
- **Każdy błąd to jedno zdanie i co zrobić**: brak sieci, awaria usługi, zły
  numer, działka już dodana.
- **Praca offline**: mapa z działką zapisaną wcześniej rysuje się przy kliencie
  HTTP, który zlicza zapytania — licznik zostaje na zerze.
- **Powtórny zapis** tej samej działki nie tworzy drugiego wiersza.

## Rzeczy świadomie odłożone

- **Powierzchnia z granic jest przybliżona** (rachunek na płaszczyźnie,
  błąd rzędu procenta) i w interfejsie zawsze poprzedza ją słowo „około".
  Do dokumentów idzie powierzchnia z wniosku — to krok 2 etapu 1.
- **Powiązanie działki ewidencyjnej z polem** (`dzialka_rolna_dzialka`)
  wypełni import z wniosku w kroku 2; teraz obie listy są osobne.
- **Podkład zdjęciowy i rysowanie granic palcem** — poza etapem 1 (ADR-0003).
- Mapa nie obsługuje przesuwania ani powiększania; przy jednym gospodarstwie
  cały zasięg mieści się na ekranie, a wyróżnienie działki następuje po
  dotknięciu jej na liście.
