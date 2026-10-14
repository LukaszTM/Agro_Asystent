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

## Kody EPPO — zablokowane

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
