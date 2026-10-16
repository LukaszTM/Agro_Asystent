# Okresy nawożenia azotem — weryfikacja i wejście do aplikacji

16 października 2026 r. Zamyka otwartą sprawę z planu (pkt 3) i z kroku 6:
„Terminy nawożenia pochodzą ze strony ARiMR z 2019 r. — do sprawdzenia
w aktualnym rozporządzeniu".

Dotąd tych terminów **w ogóle nie było w danych** — stały tylko jako uwaga
przy obowiązku `program_azotanowy_ewidencja`. Teraz są, sprawdzone w samym
rozporządzeniu, razem z czymś, czego plan nie przewidywał: **wykazami gmin**,
które dają dokładną datę dla konkretnego pola.

## Źródło

**Dz.U. 2023 poz. 244** — rozporządzenie Rady Ministrów z dnia 31 stycznia
2023 r. w sprawie „Programu działań mających na celu zmniejszenie
zanieczyszczenia wód azotanami pochodzącymi ze źródeł rolniczych oraz
zapobieganie dalszemu zanieczyszczeniu". Pełny tekst (130 stron) z Dziennika
Ustaw, załączniki osobno ze strony ARiMR „Program azotanowy".

Weryfikacja szła w dwóch podejściach. Najpierw, przy zablokowanym dostępie
do Dziennika Ustaw, daty wzięliśmy z komunikatu Ministerstwa Rolnictwa
i oznaczyliśmy jako `ze_strony_ministerstwa` — aplikacja mówiła wtedy „daty
ze streszczenia, potwierdź u doradcy". Po udostępnieniu
`dziennikustaw.gov.pl` przeczytaliśmy tabelę 2 i rozdział 1.3 w oryginale.
**Wszystkie cztery daty się potwierdziły**, więc status to dziś
`potwierdzone`. Pełny tekst pokazał jednak cztery rzeczy, których
w streszczeniu nie było — opisane niżej.

## Co wie teraz aplikacja

Tabela 2 podaje **okresy**, nie same daty graniczne:

| Nawóz | Grunty orne | Uprawy trwałe, wieloletnie, TUZ |
| --- | --- | --- |
| Azotowe mineralne i naturalne płynne | 1 marca – **20 października** | 1 marca – **31 października** |
| Naturalne stałe (obornik, pomiot ptasi) | 1 marca – **31 października** | 1 marca – **30 listopada** |

Dla gruntów ornych tabela 2 ma dodatkowo dwa wiersze gminne: 1 marca –
**15 października** dla gmin z załącznika nr 2 i 1 marca –
**25 października** dla gmin z załącznika nr 3.

W słowniku zapisujemy datę graniczną **i** początek okresu (`okres_od`).
Kalendarz pokazuje jeden dzień, bo trwający pół roku okres zapchałby grupę
„dziś"; karta na ekranie nawożenia pokazuje oba końce („do 31 października,
wolno od 1 marca").

## Cztery rzeczy, których nie było w streszczeniu

1. **Odstępstwa dotyczą tylko gruntów ornych.** Rozdział 1.3 ust. 8 i 9
   wymienia wyłącznie grunty orne (w tym gminne). Wcześniej traktowaliśmy je
   jako ogólne.
2. **Odstępstwo „uprawa po późno zbieranych" nie ma daty granicznej.**
   Przepis znosi terminy z tabeli 2 i nie podaje nowej daty; komunikat
   ministerstwa mówił o końcu listopada. Dane mają więc `do_dnia: null`,
   a ekran pisze „termin z tabeli nie obowiązuje" plus uwagę o końcu
   listopada do potwierdzenia. **Nie wymyślamy daty, której w przepisie nie ma.**
3. **Zakaz nawożenia gruntów odłogowanych** (ust. 11) — nowy wpis, razem
   z wyjątkiem: przed planowanym zakończeniem odłogowania wolno zastosować
   nawozy jesienią.
4. **Wcześniejsze nawożenie w lutym** (ust. 4–7) — wolno przed terminem
   z tabeli 2, gdy średnia dobowa temperatura przejdzie przez próg **3°C**
   (rośliny zasiane jesienią, uprawy trwałe, wieloletnie, TUZ) albo **5°C**
   (pozostałe uprawy); przejściem jest **5 dni z rzędu** powyżej progu na
   **95%** powierzchni powiatu, a daty ogłasza IMGW-PIB codziennie w lutym.

Przy okazji poprawione: zakaz dla gleb zamarzniętych, zalanych, nasyconych
wodą i pod śniegiem jest w Programie tylko **odesłaniem** do art. 20 ustawy
o nawozach i nawożeniu. Treści tego artykułu nie czytaliśmy, więc ten jeden
wpis ma `do_weryfikacji`, a ekran pisze przy nim „do sprawdzenia". To
jedyne ostrzeżenie, jakie karta dziś pokazuje.

## Co jeszcze potwierdził pełny tekst

- **Limit 170 kg N/ha** z nawozów naturalnych — rozdział 1.5 ust. 1,
  dosłownie. Limit miał status `potwierdzone` od czasów planu; teraz ma przy
  sobie dokładną sygnaturę.
- **Progi obowiązku: ≥ 10 ha UR albo ≥ 10 DJP** (stan średnioroczny) —
  rozdział 1.6 ust. 2. Dokładnie to, co było w słowniku.
- **Przechowywanie dokumentów 3 lata** — ust. 2 pkt 3.
- **Wzór ewidencji nawożenia azotem** — tabela 15 (załącznik nr 10):
  dziewięć kolumn, od daty zastosowania po dawkę azotu na zastosowaną
  powierzchnię, plus datę przyorania na terenie o dużym nachyleniu. Wpisane
  do `wymagane_pola` obowiązku.
- **Wyłączenia**: terminy nie dotyczą upraw pod osłonami (szklarnie,
  inspekty, namioty foliowe) ani upraw kontenerowych z zamkniętym obiegiem
  nawozów i wody.

## Wykazy gmin: dokładna data dla konkretnego pola

Załączniki podają gminy z **kodami TERYT**, a identyfikator działki
ewidencyjnej, który aplikacja i tak ma (`061506_2.0007.138`), zawiera kod
gminy w pierwszych siedmiu cyfrach (`0615062`). Aplikacja dopasowuje więc
termin bez pytania rolnika o cokolwiek.

| Wykaz | Gmin | Termin na gruntach ornych |
| --- | --- | --- |
| Załącznik nr 2 (tabela 4) | **171** w 6 województwach | do 15 października |
| Załącznik nr 3 (tabela 5) | **1987** w 16 województwach | do 25 października |
| Poza wykazami | pozostałe | do 20 października |

Gdy działki leżą w gminach o różnych terminach, ekran pokazuje
**najwcześniejszy** i mówi, że pola różnią się między sobą — bo to ten
wcześniejszy wiąże, jeśli rolnik nie pilnuje każdego pola osobno. Działki
o nierozczytanym identyfikatorze są policzone i wymienione, nie przemilczane.

## Jak sprawdza to skrypt

`tools/azotany/terminy_nawozenia.py` (Python, `pdfplumber`), uruchamiany
**na komputerze dewelopera** (CLAUDE.md, reguła 3). Dostaje pełny tekst
rozporządzenia i oba wykazy, a potem:

1. Szuka w tekście **16 wzorców** — całych wierszy tabeli 2, zdań
   z odstępstwami, limitu azotu, progów obowiązku, trzyletniego
   przechowywania i tytułu tabeli 15.
2. Sprawdza **9 kolumn** wzoru ewidencji po słowach wypisanych wprost przy
   każdej kolumnie (nagłówki w tabeli są łamane i poprzeplatane, więc całych
   zdań tam nie ma).
3. Czyta wykazy gmin i pilnuje, by **żadna pominięta linia nie zawierała
   kodu gminy**, by kody się nie powtarzały i by gmina nie była w dwóch
   wykazach naraz.
4. Dopiero wtedy zapisuje `reguly_prawne.json` i
   `gminy_terminy_azotowe.json`.

Dwie wady warstwy tekstowej Dziennika Ustaw są wypisane wprost, zamiast
osłabiać sprawdzanie po cichu:

- **„ć" czyta się jako „d"** („przekroczyd"), a **„ń" jako „o"** („dzieo",
  „warmiosko-mazurskie"). Wzorce dopuszczają w tych miejscach obie litery.
  Bez poprawki nazwy województwa z wykazów wypadłoby **72 gminy** —
  wyłapała to kontrola z punktu 3.
- **Strona z tabelą 15 ma tekst złożony wspak** („.51 alebaT" zamiast
  „Tabela 15."). Do przeszukiwania dokładamy każdą stronę także odwróconą;
  fałszywe trafienie jest niemożliwe, bo wzorce są długimi zdaniami.

Kontrola negatywna: po podmianie jednej daty we wzorcu (20 → 21
października) skrypt odmawia zapisu.

## Liczby

| Miara | Wartość |
| --- | --- |
| Wzorców sprawdzonych w rozporządzeniu | 16 |
| Kolumn wzoru ewidencji | 9 |
| Terminy graniczne | 4 (wszystkie `potwierdzone`) |
| Odstępstwa / zakazy | 2 / 2 |
| Gminy w wykazach | 171 + 1987 = **2158** |
| Gmin zgubionych bez poprawki „ń" | 72 (wyłapane przez kontrolę) |
| Nowe pliki kodu | 2 (+ zmiany w sześciu) |
| Nowe pliki testów | 1 |
| Testy dodane | 18 (16 logiki, 2 ekranu) |
| Testy w całym projekcie | 279 (było 261) |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Cztery terminy mają właściwe daty dla obu rodzajów nawozu i obu rodzajów
  gruntu, a okres zaczyna się 1 marca.
- Daty i zasady są `potwierdzone` i wskazują tabelę 2; zakaz z ustawy
  o nawozach — `do_weryfikacji`.
- Odstępstwa dotyczą gruntów ornych; to po późno zbieranych **nie ma** daty
  granicznej i mówi o tym wprost.
- Progi 3°C i 5°C, 5 dni, 95% powierzchni powiatu i nazwa instytutu są
  danymi ze słownika.
- Wzór ewidencji ma dziewięć kolumn z tabeli 15.
- Kod gminy wyciąga się z identyfikatora działki; dziwnego identyfikatora
  nie zgadujemy.
- Gmina z załącznika nr 2 dostaje 15 X, z nr 3 — 25 X, poza wykazami 20 X;
  działki w różnych gminach dają najwcześniejszy termin.

## Co zostaje otwarte

1. **Art. 20 ustawy o nawozach i nawożeniu** — treść zakazu dla gleb
   zamarzniętych, zalanych, nasyconych wodą i pod śniegiem. Program tylko
   do niego odsyła.
2. **Progi obowiązku planu nawożenia azotem** (> 100 ha UR, > 50 ha upraw
   intensywnych, > 60 DJP) są w ustawie – Prawo wodne, art. 105a ust. 1,
   a nie w Programie. Program podaje tylko listę upraw intensywnych
   (załącznik nr 7) — ta lista też czeka na wpisanie do danych.
3. **Tabela 14 (maksymalne ilości azotu działającego)** z załącznika nr 9 —
   dla gospodarstw bez obowiązku planu. Duża tabela, osobne zadanie.
4. **Tabela 1 (odległości od wód)** i tabela 9 (produkcja nawozów
   naturalnych i koncentracja azotu) — warto wciągnąć przy kolejnych krokach.
5. **Wzór ewidencji nawożenia a wydruk.** Kolumny z tabeli 15 są już
   w danych, ale dokument nawożenia nadal drukuje się po kolumnach
   ekoschematów (Plan Strategiczny WPR). Przełączenie wydruku na wzór
   urzędowy to osobny krok — wymaga mapowania wpisów na dziewięć kolumn
   i własnych testów.
