# Raport P3 — słownik upraw

14 października 2026 r. Zadanie: „P3. Słownik upraw" z planu (pkt 9):
zestawić nazwy upraw z wniosku z nazwami z rejestru i kodami EPPO, a niepewne
dopasowania wypisać do ręcznej decyzji.

## Stan zadania

| Strona słownika | Stan |
| --- | --- |
| Rejestr środków ochrony roślin (1052 nazwy urzędowe) | **gotowe** — podstawa słownika |
| Etykiety (nazwy z karencji) | **gotowe** — 112 nazw, wszystkie dopasowane |
| Rejestr: nazwy spoza słownika urzędowego | **gotowe** — 67 nazw przerobionych |
| Wniosek z eWniosekPlus | **czeka na P4** — nie mamy jeszcze czytnika wniosku |
| Kody EPPO | **zablokowane** — brak dostępu do źródła, patrz niżej |

Mechanizm jest gotowy na obie brakujące strony: skrypt przyjmuje nazwy z wniosku
(`--wniosek plik.csv`) i kody EPPO (`--kody-eppo plik.csv`) i wpisuje je do tych
samych tabel.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/wspolne/tekst.py` | postać porównawcza nazw (bez wielkości liter, ogonków, nawiasów i słowa „uprawa") |
| `tools/p3_slownik_upraw/slownik.py` | dopasowanie wariantów do nazw urzędowych, zapis do bazy i do dwóch plików CSV |
| `tools/p3_slownik_upraw/test_slownik.py` | 12 testów |
| `dane/wynik/slownik_upraw.csv` | pełny wykaz dopasowań |
| `dane/wynik/uprawy_do_decyzji.csv` | lista do ręcznego rozstrzygnięcia |

## Wynik

179 wariantów nazw (112 z etykiet, 67 z rejestru):

| Sposób dopasowania | Ile | Udział | Czy wymaga człowieka |
| --- | --- | --- | --- |
| dokładne | 112 | 62,6% | nie |
| zbliżone (różnica w zapisie) | 4 | 2,2% | nie |
| podobieństwo (propozycja) | 39 | 21,8% | **tak** |
| brak propozycji | 24 | 13,4% | **tak** |

**Wszystkie 112 nazw upraw z etykiet dopasowały się dokładnie** do nazw
urzędowych z rejestru. To ważne, bo właśnie na tym styku powstaje ostrzeżenie
o karencji: karencja z etykiety trafia do tej samej uprawy, dla której rejestr
podaje dawkę.

## Lista do ręcznej decyzji (63 pozycje)

**39 z propozycją** — zapisy z dopiskiem, dla których skrypt podpowiada uprawę
nadrzędną, ale nie przesądza:

| Zapis w rejestrze | Propozycja |
| --- | --- |
| cebula uprawiana na zielony szczypior | cebula |
| cebula z siewu | cebula |
| cukinia uprawa pod osłonami | cukinia |
| dynia plantacje nasienne | dynia |
| groch jadalny na suche nasiona | groch jadalny |

Dopisek bywa istotny: cebula na szczypior to inne przeznaczenie niż cebula na
zbiór, a wraz z nim może iść inna dawka i karencja. Dlatego **propozycja nie jest
zatwierdzana automatycznie** (`zatwierdzone = 0` w bazie).

**24 bez propozycji** — i tu wyszła rzecz, której plan nie przewidywał.
Dzielą się na trzy grupy:

1. **Rośliny, których nie ma w słowniku urzędowym** (6): babka zwyczajna,
   pokrzywa zwyczajna, kocimiętka właściwa, borówka, jagoda, topola. Słownik
   pochodzi z wydania kwartalnego starszego o dwa tygodnie niż rejestr.
2. **Przedmioty i miejsca, nie uprawy** (16): doniczki, noże, sekatory, stoły,
   worki, skrzynie do przechowywania, nasypy, miejsca wzdłuż ogrodzeń i płotów,
   powierzchnie i urządzenia do uprawy i magazynowania, wokół wiat i szklarni.
   To zabiegi odkażania sprzętu i powierzchni — **kolumna „uprawa" w rejestrze
   bywa miejscem stosowania, nie rośliną**.
3. **Terminy, nie uprawy** (2): siew jesienny, siew wiosenny.

Wniosek dla aplikacji: wybór uprawy na ekranie wpisu zabiegu nie może brać
wszystkiego z kolumny „uprawa". Potrzebna jest druga kategoria — „miejsce
stosowania" — żeby rolnik szukający pszenicy nie przewijał listy noży i doniczek.

## Błąd w rejestrze wykryty przy okazji

W jednym wierszu rejestru kolumny są przesunięte: w `uprawa` stoją nazwy chorób,
a w `agrofag` opis dawki. Identycznie w pliku MRiRW i w wydaniu z dane.gov.pl,
więc to błąd w źródle. Import oznacza taki wiersz i nie rozbija jego „upraw"
(szczegóły w raporcie P1).

Przy tej okazji poprawił się też odczyt etykiet z P2: nazwy upraw w karencjach
są teraz sprawdzane ze słownikiem urzędowym. Wcześniej do bazy trafiały
fragmenty zdań („Etykieta środka ochrony roślin ATRIUM -X" jako uprawa).
Po poprawce różnych upraw w karencjach jest 112 zamiast 163, a 11 pozycji
trafiło do ręcznego sprawdzenia, zamiast udawać dane.

## Kody EPPO — odblokowane 15.10.2026

Użytkownik pobrał z EPPO Global Database bazę `eppocodes_all.sqlite` (48 MB)
i przekazał ją do pracy. Powstał `tools/p3_slownik_upraw/eppo.py`, który wiąże
nazwy upraw z kodami **wyłącznie przez polskie nazwy zapisane w tej bazie** —
żadnego kodu nie dopisujemy z pamięci.

| | |
| --- | --- |
| Polskich nazw roślin w bazie EPPO | 4 444 |
| Nazw upraw z rejestru MRiRW | 1 052 |
| **Nazwa polska zgodna co do znaku** | **169 (16,1%)** |
| Nazwa EPPO z dopowiedzeniem („jabłoń" → „jabłoń domowa") — do potwierdzenia | 32 (3,0%) |
| Kilku kandydatów — do wyboru | 112 (10,6%) |
| Brak polskiej nazwy w EPPO | 739 (70,2%) |

Licząc wagą użycia (ile razy uprawa występuje w rejestrze zastosowań), gotowy
kod ma **22,5% zastosowań**.

### Dlaczego tak mało

Baza EPPO **nie zawiera polskich nazw dla najważniejszych polskich upraw**.
Pszenica zwyczajna (TRZAX) nie ma w niej żadnej nazwy polskiej — jest tylko
łacińska. Do tego rozróżnienia „ozima/jara" są polską praktyką agrotechniczną,
a nie odrębnymi gatunkami, więc EPPO ich nie zna.

Najważniejsze uprawy czekające na decyzję (według liczby zastosowań w rejestrze):
pszenica ozima (1 515), rzepak ozimy (1 165), pszenżyto ozime (948),
jęczmień ozimy (819), jęczmień jary (807), pszenica jara (698).

### Pierwsze decyzje — 15.10.2026

Użytkownik podał sześć kodów dla najważniejszych upraw. **Każdy sprawdziłem
w bazie EPPO**: wszystkie istnieją i są aktualne.

| Uprawa | Kod | Nazwa w EPPO | Zastosowań w rejestrze |
| --- | --- | --- | --- |
| pszenica ozima | TRZAW | soft wheat (winter) | 1 515 |
| rzepak ozimy | BRSNW | rape (winter) | 1 165 |
| pszenżyto ozime | TTLWI | triticale (winter) | 948 |
| jęczmień ozimy | HORVW | barley (winter) | 819 |
| pszenica jara | TRZAS | soft wheat (spring) | 698 |
| pszenica zwyczajna | TRZAX | Triticum aestivum | — |

Przy okazji wyszło, **dlaczego moje szukanie ich nie znalazło**: formy ozime
i jare mają w EPPO typ `NTX` („non taxonomic"), który odfiltrowałem jako
„nie-roślina". I słusznie co do zasady — to nie są gatunki, tylko formy
uprawne — ale to właśnie ich wymaga ewidencja. Dodatkowo **spośród 640 kodów
NTX tylko 5 ma polską nazwę**, więc automatyczne dopasowanie po polsku było
z góry skazane.

Po wpisaniu tych sześciu kodów udział zastosowań z gotowym kodem wzrósł
z 22,5% do **36,0%**.

Baza zawiera komplet form ozimych i jarych (HORVS, SECCW, SECCS, BRSNS, TTLSO,
AVESP, AVESW, TRZDW, TRZDS), więc resztę dobrałem **z tej samej listy** jako
propozycje do potwierdzenia — razem z jabłonią (MABSD, Malus domestica).
Użytkownik potwierdził je 15.10.2026 — pokrycie wynosi dziś **44,8%**
zastosowań, a plik decyzji liczy 18 pozycji.

Decyzje i propozycje leżą w `assets/dane/kody_eppo_decyzje.csv` —
w repozytorium, bo to słownik aplikacji, a nie dane gospodarstwa. Kolumna
`stan` odróżnia „potwierdzone" od „propozycja".

### Co z tym zrobić

`dane/wynik/uprawy_eppo_do_decyzji.csv` jest ułożony **od upraw najczęściej
występujących w rejestrze** i ma kolumny: liczba zastosowań, propozycja,
kandydaci oraz „inne gatunki tego rodzaju" (sam trop, nie propozycja — dla
„pszenica ozima" pokazuje np. „pszenica płaskurka=TRZMO", czyli inny gatunek).
Rozstrzygnięcie pierwszych kilkudziesięciu pozycji przez doradcę pokryje
większość realnych zastosowań.

Kodów dla tych upraw **nie wpiszę sam**: błędny kod EPPO to błąd w dokumencie
urzędowym, który od 2027 r. ma być czytany maszynowo.

## Kody EPPO — stan przed 15.10.2026 (nieaktualne)

Kodów **nie ma w żadnym dostępnym źródle**:

- baza EPPO (`gd.eppo.int`, `data.eppo.int`) jest poza dozwolonymi domenami
  tego środowiska,
- w portalu dane.gov.pl nie ma zbioru z kodami EPPO (0 trafień),
- urzędowy słownik upraw MRiRW zawiera same nazwy, bez kodów.

**Kodów nie wpisujemy z pamięci.** Błędny kod EPPO w ewidencji zabiegów to błąd
w dokumencie urzędowym, a od 2027 r. ewidencja ma być czytana maszynowo.

Do rozstrzygnięcia przez Ciebie, dwie drogi:

1. Dodać `gd.eppo.int` i `data.eppo.int` do dozwolonych domen środowiska —
   wtedy pobiorę kody i uzupełnię słownik (baza EPPO udostępnia wykazy
   bezpłatnie, część po darmowej rejestracji).
2. Zapytać ministerstwo albo PIORiN o wykaz „uprawa → kod EPPO" w jednym pliku
   — przy okazji pytania o zbiorczą paczkę etykiet z P2.

Do tego czasu kolumna `kod_eppo` zostaje pusta, a skrypt jest gotowy ją wypełnić
z pliku.

## Następny krok

**P4. Czytnik wniosku PDF** — parser tabel X i XI z zanonimizowanego wzorca.
Dostarczy trzecią stronę słownika: nazwy upraw używane przez ARiMR we wniosku.
Potrzebny będzie zanonimizowany wzorzec wniosku (prawdziwy nie może trafić do
repozytorium).
