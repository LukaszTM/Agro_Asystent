# Raport P1 — import pliku zastosowań (XLSX → SQLite)

14 października 2026 r. Zadanie: „P1. Import pliku zastosowań" z planu (pkt 9).

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/p1_zastosowania/pobierz.py` | pobieranie danych: sprawdza `robots.txt`, przedstawia się nagłówkiem User-Agent, robi 2-sekundowe przerwy, nie pobiera ponownie (`If-Modified-Since`), ponawia przy zerwanym połączeniu |
| `tools/p1_zastosowania/parsery.py` | odczyt dawki, fazy BBCH i rozbijanie list upraw — każda wartość ze znacznikiem pewności |
| `tools/p1_zastosowania/importuj.py` | budowa bazy SQLite i raport z liczbami |
| `tools/p1_zastosowania/test_parsery.py` | 20 testów parserów |
| `dane/wynik/srodki_ochrony.sqlite` | wynik (12 MB, poza repozytorium) |

Źródła i uzasadnienie ich wyboru: `docs/decyzje/ADR-0002-zrodlo-danych-o-srodkach.md`.

## Liczby

Dane: rejestr zastosowań MRiRW z **12.10.2026** + wydanie kwartalne z dane.gov.pl
z **30.09.2026** (licencja CC0 1.0).

| | |
| --- | --- |
| Wierszy w pliku | 18 785 |
| Środków (nazwa + nr zezwolenia) | 2 991 |
| Zastosowań | 18 785 |
| Środków po terminie stosowania | **24** (oznaczone `wycofany = 1`, nie usunięte) |
| Środków czynnych | 2 967 |
| Uzupełniono producenta | 2 971 |
| Uzupełniono adres etykiety | 2 964 |
| Różnych upraw w bazie | 902 |

### Odczyt dawki

| Pewność | Wierszy | Udział |
| --- | --- | --- |
| odczytana | 18 012 | 95,9% |
| zakres (wzięta górna granica) | 75 | 0,4% |
| **do sprawdzenia** | 698 | 3,7% |

Razem z wartością liczbową: **18 087 zastosowań (96,3%)**. Plan szacował ok. 91%
— wyszło lepiej, bo parser radzi sobie też ze stężeniami procentowymi,
dawkami na wielokrotność jednostki („20 g/10 m²") i na masę ziarna.

Z 698 nieodczytanych **295 to wiersze, w których rejestr w ogóle nie podaje
dawki**. Pozostałe 403 to opisy słowne (np. „ml środka z dodatkiem wody na
100 kg ziarna" w rozbudowanych wariantach). Żadnej z nich nie zgadujemy —
w bazie zostaje pełny tekst opisu i znacznik `do_sprawdzenia`, a rolnik
potwierdza dawkę ręcznie.

### Pozostałe pola

| | |
| --- | --- |
| Faza BBCH odczytana | 12 050 (64,1%) — zgodnie z szacunkiem planu (ok. 2/3) |
| Pozycje upraw rozpoznane słownikiem | 38 151 (**99,4%**) |
| Pozycje upraw do sprawdzenia | 212 (71 różnych nazw) |

Nazwy spoza słownika to głównie zioła (babka zwyczajna, estragon, rozmaryn)
i miejsca niebędące uprawą (nasypy, stoły, maty podsiąkowe) — słownik pochodzi
z wydania o dwa tygodnie starszego niż rejestr. Wszystkie są zapisane
z `pewnosc = 'do_sprawdzenia'` i trafią do ręcznej decyzji w P3.

## Ważna poprawka w odczycie dawki

Komórki Excela zawierają artefakty `_x000D_` po znakach końca wiersza. Przed
ich usunięciem parser przeskakiwał dawkę **maksymalną** i trafiał na podany
dalej zakres **zalecany** — czyli zwracał wartość niższą niż dopuszczalna.
Po poprawce zwraca dawkę maksymalną. Przypadek jest zabezpieczony testem
`test_dawka_maksymalna_wazniejsza_niz_zalecana`.

## Błąd w samym rejestrze (znaleziony przy P3)

W jednym wierszu rejestru **kolumny są przesunięte**: w kolumnie `uprawa` stoją
nazwy chorób („mączniak prawdziwy zbóż i traw, brunatna plamistość liści…"),
a w kolumnie `agrofag` — opis dawki. Tak samo wygląda to w pliku ze strony
MRiRW i w wydaniu z dane.gov.pl, więc to błąd w źródle, nie w odczycie.
Import oznacza taki wiersz (`uklad_podejrzany = 1`) i nie rozbija jego
„upraw", żeby do bazy nie trafiły choroby udające uprawy.

## Czy baza nadaje się dla aplikacji

Zapytanie, które zada ekran wyboru środka („co wolno na pszenicę ozimą?"),
zwraca 1 515 zastosowań w **4 ms**:

```
3C-750          R-16/2024 h.r.   2.0 l/ha   BBCH 30-31  wyleganie
Abran 250       R-148/2024       0.8 l/ha   BBCH 30-69  septorioza paskowana liści, rdza brunatna
Abydos 750 EC   R-14/2025 h.r.   0.75 l/ha  BBCH 29-59  mączniak prawdziwy zbóż i traw
```

Baza ma 12 MB. Przed dołączeniem do aplikacji warto sprawdzić, czy da się ją
zmniejszyć (najwięcej miejsca zajmują pełne teksty opisów dawki i terminu).

## Co zostaje otwarte

1. **403 opisy dawek** wymagające ręcznego spojrzenia albo dopisania wzorców.
2. **71 nazw upraw** spoza słownika — do rozstrzygnięcia w P3 razem z kodami EPPO.
3. **Karencji w tym pliku nie ma** (plan: tylko 244 wiersze) — pozostaje P2
   i baza etykiet. Adres etykiety mamy już dla 2 964 środków, co skraca pracę.
4. Rozmiar bazy dołączanej do aplikacji.

## Następny krok

**P2. Próba bazy etykiet na podstronie A–B**: zebrać spis „środek → najnowsza
etykieta", pobierać powoli z pamięcią podręczną, odczytać karencję, okres
prewencji i liczbę zabiegów. Mamy już adresy podstron przy niemal każdym środku.
