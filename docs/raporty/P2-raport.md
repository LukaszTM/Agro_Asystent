# Raport P2 — próba bazy etykiet (karencja)

14 października 2026 r. Zadanie: „P2. Próba bazy etykiet na podstronie A–B"
z planu (pkt 9). Próba objęła jedną podstronę alfabetyczną, zgodnie z planem.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/wspolne/pobieranie.py` | grzeczne pobieranie wspólne dla P1 i P2: `robots.txt`, uczciwy User-Agent, przerwy, `If-Modified-Since`, ponawianie prób |
| `tools/p2_etykiety/spis.py` | spis „środek → najnowsza etykieta" z podstrony alfabetycznej |
| `tools/p2_etykiety/odczyt.py` | odczyt karencji, okresu prewencji i liczby zabiegów |
| `tools/p2_etykiety/proba.py` | całość: spis → pobranie → odczyt → zapis do tabel `etykieta` i `karencja` |
| `tools/p2_etykiety/test_odczyt.py` | 17 testów na fragmentach prawdziwych etykiet |

## Czy wolno pobierać

`https://www.gov.pl/robots.txt` sprawdzony u źródła:

```
User-Agent: *
Allow: /
```

Brak jakichkolwiek ograniczeń dla automatów. Skrypt mimo to czyta `robots.txt`
przy każdym uruchomieniu i przerywa pracę, gdyby reguły się zmieniły.
Pobieranie: jedno żądanie na 2 sekundy, z pamięcią podręczną.

## Co jest na podstronie A–B

| Rodzaj dokumentu | Ile |
| --- | --- |
| **Etykiety** | **271** |
| Zezwolenia i pozwolenia | 104 |
| Decyzje, odnowienia, postanowienia | 129 |
| Pozostałe | 7 |
| Razem | 511 |

**Najważniejsze odkrycie: etykieta jest tylko dla części środków.** Rejestr ma
dla liter A–B **380 środków**, a etykiet jest **246** (**64,7%**). Dla pozostałych
134 strona udostępnia wyłącznie zezwolenie albo decyzję — bez etykiety, czyli
bez karencji. To przesądza o tym, że ręczny wpis karencji musi zostać na stałe
w wersji darmowej, a nie być „awaryjnym" rozwiązaniem.

## Pobieranie

| | |
| --- | --- |
| Pobranych plików | 271 (100%) |
| Rozmiar | 118 MB |
| Błędy pobrania | 0 (jedno zerwane połączenie, ponowienie się powiodło) |
| **Skany bez warstwy tekstowej** | **0** — wszystkie etykiety są plikami tekstowymi |
| Czas | ok. 15 minut przy przerwie 2 s |

## Odczyt

| Stan etykiety | Ile | Udział |
| --- | --- | --- |
| odczytana (karencja + liczba zabiegów) | 229 | **84,5%** |
| częściowa (jedno z dwojga) | 39 | 14,4% |
| do sprawdzenia | 3 | 1,1% |

| Pozycje karencji | Ile |
| --- | --- |
| z liczbą dni | 137 |
| bez karencji („nie dotyczy", „nie wymagany") | 120 |
| do sprawdzenia | 10 |
| **razem pozycji** | **267** |

Po rozbiciu na uprawy daje to **657 wierszy karencji dla 163 różnych upraw**.
**132 etykiety podają karencję osobno dla różnych upraw** — czyli karencja jest
cechą pary „środek + uprawa", nie samego środka. Model danych z planu (pkt 7)
to przewidywał i został potwierdzony.

Pozostałe pola: liczba zabiegów odczytana dla 243 etykiet, okres prewencji dla
261. Karencja waha się od 1 do 180 dni, najczęstsza to 35 dni.

## Typowe odstępstwa (to, co sprawiało kłopot)

1. **Karencja dla pasz tuż obok karencji do zbioru.** Dwa podobnie brzmiące
   zdania po sobie; wzięcie złej liczby dałoby rolnikowi błędny termin zbioru.
   Parser bierze wyłącznie zdanie o zbiorze rośliny uprawnej.
2. **Trzy sposoby zapisania braku karencji**: „nie dotyczy", „nie wymagany",
   „niewymagany”. Przed uwzględnieniem dwóch ostatnich odczyt kończył się
   wynikiem 78,2%; po poprawce 84,5%.
3. **Listy upraw łamane do nowej linii** — „pszenica ozima, jęczmień ozimy,
   żyto ozime\n– 42 dni” rozpadało się na dwie bezużyteczne części.
4. **Zdanie o karencji przechodzące w kolejną sekcję** (nagłówek wersalikami
   albo lista numerowana z zaleceniami) — trzeba je uciąć we właściwym miejscu.
5. **Różna liczba zabiegów dla różnych upraw w jednej etykiecie — 83 przypadki.**
   Baza oznacza to osobnym polem, bo podanie jednej liczby jako obowiązującej
   byłoby wprowadzaniem rolnika w błąd.

Dziesięć pozycji zostało jako „do sprawdzenia" i **nie są zgadywane**. To zapisy
opisowe, nie liczbowe, na przykład:

- „nie stosować środka w dniu zbioru owoców”,
- „termin ostatniego zabiegu wyznacza okres karencji”,
- „zawiera się w czasie od ostatniego zastosowania środka (BBCH 39) do zbioru”.

W dziewięciu etykietach w ogóle nie ma zdania o karencji.

## Powiązanie z rejestrem

**248 z 271 etykiet** udało się powiązać ze środkiem z rejestru po nazwie (91,5%).
Pozostałe 23 to etykiety środków, których nie ma w aktualnym rejestrze zastosowań
(wycofane albo o zmienionej nazwie).

## Wniosek dla aplikacji

Próba wypadła **pomyślnie** — warunek z planu („karencja z bazy etykiet, jeśli
próba z zadania P2 wypadnie dobrze”) jest spełniony, ale z dwoma zastrzeżeniami:

1. Karencja automatyczna będzie dostępna dla ok. **65% środków**; dla reszty
   rolnik wpisuje ją ręcznie — i to musi być wygodne, nie karne.
2. Aplikacja zawsze pokazuje **datę etykiety i jej źródło**, bo opakowanie
   kupione dawniej może mieć starszą wersję. Rolnik potwierdza karencję.

## Skala całości (oszacowanie)

Dla wszystkich 12 podstron alfabetycznych: ok. **2 000 etykiet, ok. 900 MB,
ok. 2 godziny pobierania** przy obecnej przerwie 2 s. Przed takim pobraniem warto
zapytać ministerstwo o udostępnienie etykiet w jednej paczce — to samo pytanie,
które plan stawia w pkt 10.

## Następny krok

**P3. Słownik upraw**: zestawić nazwy upraw z wniosku z nazwami z rejestru
i kodami EPPO. Mamy już urzędowy słownik 1052 upraw (P1) oraz 163 nazwy upraw
występujące w karencjach — to one są najpilniejsze, bo od nich zależy ostrzeżenie
o terminie zbioru.
