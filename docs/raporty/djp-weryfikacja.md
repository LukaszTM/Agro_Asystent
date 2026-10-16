# Weryfikacja współczynników DJP w rozporządzeniu

Zamyka otwartą sprawę z kroku 9 etapu 1 (`etap1-krok9-zwierzeta.md`).
Weryfikacja szła w dwóch podejściach i dopiero drugie jest wiążące.

## Co się stało

**15.10.2026** sprawdziliśmy tabelę 3 w załączniku nr 1 do programu działań
z **Dz.U. 2020 poz. 243** (PDF dostarczony przez właściciela projektu).
Poprawiło to trzy błędne wartości wpisane „na start" w kroku 9.

**16.10.2026**, przy okazji sprawdzania terminów nawożenia, strona
Ministerstwa Rolnictwa wskazała obowiązującą podstawę prawną:
**rozporządzenie Rady Ministrów z 31 stycznia 2023 r. (Dz.U. 2023 poz. 244)**.
Rozporządzenie z 2020 r. zostało zastąpione — a **tabela 3 się zmieniła**.
Dane z 15.10 pochodziły więc z uchylonego aktu.

Obowiązujący załącznik nr 1 pobraliśmy ze strony ARiMR „Program azotanowy"
(<https://www.gov.pl/web/arimr/program-azotanowy-2023>) i słownik stoi
teraz na nim.

## Co zmieniło rozporządzenie z 2023 r.

| Grupa | 2020 (Dz.U. poz. 243) | 2023 (Dz.U. poz. 244) |
| --- | --- | --- |
| Warchlaki | „Warchlaki od 2 miesiąca do 4 miesiąca" — 0,07 | „Warchlaki" — **0,04** |
| Prosięta | „Prosięta do 2 miesiąca" — 0,02 | „Prosięta" — **0,01** |
| Lamy | — | **nowy gatunek**: samice 0,20, samce 0,19, młode od ½ do 1 roku 0,12, cielęta/cria do ½ roku 0,05 |
| Alpaki | — | **nowy gatunek**: samice 0,11, samce 0,12, młode od ½ do 1 roku 0,05, cielęta/cria do ½ roku 0,03 |

Pozostałe 85 wierszy ma te same wartości co w 2020 r. Nazwy warchlaków
i prosiąt straciły przedziały wiekowe — w słowniku stoją dziś dosłownie
tak, jak w przepisie.

## Jak sprawdzaliśmy (metoda wiążąca)

Skrypt `tools/djp/wspolczynniki_djp.py` (Python, `pdfplumber`), uruchamiany
**na komputerze dewelopera** (CLAUDE.md, reguła 3). Pierwsza wersja
dopasowywała „liczbę blisko nazwy" w tekście strony. To **za słabe**:
załącznik ma skład dwukolumnowy, a lamy i alpaki stoją obok siebie
i mają **identyczne nazwy grup** („Samice powyżej 1 roku"). Takie
dopasowanie potwierdziłoby również przypisanie zamienione miejscami.

Dlatego skrypt czyta PDF **po współrzędnych**:

1. Kolumny ze współczynnikami są wyrównane do prawej (x₁ ≈ 295 i ≈ 516),
   więc liczba w nazwie („od 1 roku do **2** lat") nie zostanie wzięta za
   współczynnik.
2. Strona dzieli się na dwa strumienie wierszy — lewy i prawy. Tekst zbiera
   się od poprzedniej wartości do następnej i **przez wszystkie strony**,
   bo nazwa złamana na końcu strony kończy się na następnej.
3. Każdy strumień porównujemy z przepisaną tabelą **co do kolejności,
   nazwy i wartości**. Lamy są w lewym strumieniu, alpaki w prawym —
   pomyłka jest niemożliwa.
4. Wiersz „Inne zwierzęta o łącznej masie 500 kg" biegnie przez całą
   szerokość tabeli, więc sprawdzamy go w tekście strony.
5. Dopiero gdy wszystko się zgadza, skrypt zapisuje słownik.

Dwie rzeczy są wypisane wprost, żeby nie osłabiać kontroli po cichu:
warstwa tekstowa załącznika gubi „ń" w wyrazie „afrykańskie" (PDF ma
„afrykaoskie") — poprawka siedzi w `POPRAWKI_TEKSTU`; numer strony stoi
w kolumnie wartości i też jest wyrównany do prawej, więc stopkę odcinamy
po współrzędnej.

Wynik:

```
grup w tabeli: 93, gatunków: 24
kolumna lewa: 48 wierszy zgodnych co do kolejności, nazwy i wartości
kolumna prawa: 44 wierszy zgodnych co do kolejności, nazwy i wartości
zapisano 93 grup do assets/dane/reguly_prawne.json
```

Kontrola negatywna: ten sam skrypt uruchomiony na załączniku z 2020 r.
**odmawia zapisu**.

Kolejność gatunków w słowniku (a przez to na ekranie) to osobna lista
`KOLEJNOSC_NA_EKRANIE` — decyzja o wyglądzie, nie o treści przepisu.
Pierwsza wersja skryptu mieszała jedno z drugim i porównanie strumieniami
od razu to wyłapało.

## Co się zmieniło w słowniku

| Miara | Krok 9 | Po 15.10 (2020) | Teraz (2023) |
| --- | --- | --- | --- |
| Grupy zwierząt | 16 | 85 | **93** |
| Gatunki | 6 | 22 | **24** |
| `status_weryfikacji` | `do_weryfikacji` | `potwierdzone` | `potwierdzone` |
| `zrodlo` | „do sprawdzenia…" | Dz.U. 2020 poz. 243 | **Dz.U. 2023 poz. 244** |
| Wersja słownika | 2026.10.15 | 2026.10.15.2 | **2026.10.16** |

## Trzy wartości z kroku 9 były błędne

| Grupa z kroku 9 | Było | W rozporządzeniu z 2023 r. | Ocena |
| --- | --- | --- | --- |
| cielę do 6 miesięcy | 0,15 | Cielęta do 6 miesiąca — 0,15 | zgadza się |
| młodzież 6–12 miesięcy | 0,3 | Jałówki od 6 miesiąca do 1 roku — 0,3 | zgadza się |
| młodzież 12–18 miesięcy | 0,5 | — | **takiej grupy nie ma** |
| jałówka powyżej 18 miesięcy | 0,8 | Jałówki powyżej 1 roku — 0,8 | zgadza się |
| krowa | 1,0 | Krowy — 1 | zgadza się |
| buhaj | 1,4 | Buhaje — 1,4 | zgadza się |
| prosię do 2 miesięcy | 0,02 | Prosięta — 0,01 | **za dużo o połowę** |
| warchlak 2–4 miesiące | 0,07 | Warchlaki — 0,04 | **za dużo** |
| tucznik | 0,14 | Tuczniki, loszki i knurki hodowlane — 0,14 | zgadza się |
| locha | 0,35 | Lochy — 0,35 | zgadza się |
| jagnię | 0,05 | Jagnięta do 3,5 miesiąca — 0,05 | zgadza się |
| owca dorosła | 0,1 | Owce powyżej 1,5 roku — 0,1 | zgadza się |
| koza dorosła | 0,1 | Kozy matki — 0,15 / Pozostałe kozy — 0,1 | **za mało dla kozy matki** |
| koń dorosły | 1,2 | ras dużych — 1,2 / ras małych — 0,6 | zgadza się tylko dla ras dużych |
| kura nioska | 0,004 | Kury, kaczki — 0,004 | zgadza się |
| brojler | 0,0025 | Kurczęta brojlery — 0,0036 | **o blisko trzecią część za mało** |

Przy stadzie 10 000 brojlerów różnica 0,0025 → 0,0036 to **25 DJP zamiast
36**: po starych liczbach gospodarstwo mogło nie zobaczyć obowiązku, który
je dotyczy. Przy 1000 tuczników i prosiętach różnica idzie w drugą stronę —
stare liczby zawyżały. Dlatego wynik był oznaczony jako „do sprawdzenia"
i dlatego ta reguła z CLAUDE.md istnieje.

## Co to zmienia w aplikacji

- Karta DJP **nie pokazuje już ostrzeżenia** „Przeliczniki czekają na
  sprawdzenie w przepisie" — wynik jest pewny, dopóki każde zwierzę ma
  grupę.
- Ekran wyboru grupy pokazuje **pierwsze gatunki z listy** (bydło, świnie,
  drób, owce, kozy, konie ras dużych), a pozostałe 18 gatunków po
  naciśnięciu **„Więcej zwierząt (18)"**. Kolejność ustala słownik.
- Mechanizm ostrzegania został zachowany i objęty testem: gdy wejdzie nowa
  grupa ze statusem `do_weryfikacji`, aplikacja znowu oznaczy DJP jako
  niepewne.

## Liczby

| Miara | Wartość |
| --- | --- |
| Grup w słowniku | 93 (24 gatunki) |
| Wierszy sprawdzonych po współrzędnych | 92 w dwóch strumieniach + 1 wiersz zbiorczy |
| Błędne wartości z kroku 9 | 4 (plus 1 grupa zmyślona) |
| Wartości zmienione przez rozporządzenie z 2023 r. | 2 (+ 8 nowych wierszy: lamy, alpaki) |
| Skrypt | `tools/djp/wspolczynniki_djp.py` |
| Testy w całym projekcie | 261 |
| `flutter analyze` | bez ostrzeżeń |

## Nauka na przyszłość

Sprawdzanie danych z przepisu musi obejmować **pytanie, czy akt jeszcze
obowiązuje** — nie tylko czy liczby zgadzają się z dokumentem, który mamy
pod ręką. Dlatego w słowniku, obok `zrodlo` i `sprawdzono`, źródło zawiera
pełną sygnaturę aktu (`Dz.U. 2023 poz. 244`), a nie samą nazwę programu.
