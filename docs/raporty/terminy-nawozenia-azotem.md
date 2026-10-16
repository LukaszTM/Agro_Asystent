# Terminy stosowania nawozów azotowych — weryfikacja i wejście do aplikacji

16 października 2026 r. Zamyka (częściowo) otwartą sprawę z planu (pkt 3)
i z kroku 6: „Terminy nawożenia pochodzą ze strony ARiMR z 2019 r. — do
sprawdzenia w aktualnym rozporządzeniu".

Dotąd tych terminów **w ogóle nie było w danych** — stały tylko jako uwaga
przy obowiązku `program_azotanowy_ewidencja`. Teraz są, razem z czymś, czego
nie było w planie: **wykazami gmin**, które dają dokładną datę dla
konkretnego pola.

## Źródła i poziom pewności

| Co | Skąd | Status w słowniku |
| --- | --- | --- |
| Wykazy gmin (15 X i 25 X) | **Dz.U. 2023 poz. 244**, załączniki nr 2 i 3 (tabele 4 i 5) — PDF-y ze strony ARiMR | `potwierdzone` |
| Same daty graniczne (31 X, 30 XI, 20 X, 31 X) | komunikat MRiRW „Zasady i terminy stosowania jesienią nawozów zawierających azot" (22.10.2024) | **`ze_strony_ministerstwa`** |
| Odstępstwa, zakazy, wyłączenia | ten sam komunikat | **`ze_strony_ministerstwa`** |

Różnica jest celowa. Wykazy gmin przeczytaliśmy w samym rozporządzeniu.
Dat **nie** — tabela 2 z rozdziału 1.3 programu jest w treści
rozporządzenia, a `dziennikustaw.gov.pl` i `isap.sejm.gov.pl` są
zablokowane przez politykę sieci środowiska, w którym pracujemy (403 na
CONNECT). Komunikat ministerstwa jest źródłem urzędowym, ale
**streszczeniem**, więc zgodnie z regułą 5 z CLAUDE.md aplikacja mówi
wprost: „Daty pochodzą ze streszczenia ministerstwa — potwierdź u doradcy".
Gdy tabela 2 będzie dostępna, wystarczy sprawdzić wartości i zmienić
`status_weryfikacji`. Kod się nie zmieni.

## Co wie teraz aplikacja

Cztery terminy graniczne — bo przepis daje inną datę dla obornika i dla
gnojowicy, a inną dla gruntów ornych i dla łąk:

| Nawóz | Grunty orne | Łąki, pastwiska, uprawy wieloletnie i trwałe |
| --- | --- | --- |
| Naturalne stałe (obornik, pomiot ptasi) | 31 października | 30 listopada |
| Azotowe mineralne i naturalne płynne (saletra, gnojowica, gnojówka) | **20 października, a w wykazanych gminach 15 albo 25 października** | 31 października |

Odstępstwa (rozdział 1.3 programu), też jako dane:

- **Niekorzystne warunki pogodowe** (nadmierne uwilgotnienie, susza) — do
  30 listopada, bez osobnych zapisów; rolnik sam ocenia warunki.
- **Uprawa zakładana jesienią po późno zbieranych** (burak cukrowy,
  kukurydza, przedplony, późne warzywa) — do 30 listopada, ale najwyżej
  **30 kg N/ha** z wieloskładnikowych nawozów mineralnych i z obowiązkiem
  zapisania pięciu rzeczy: termin zbioru przedplonu, data stosowania,
  zastosowane nawozy, dawka, termin siewu.

Zakaz niezależny od terminu: gleba zamarznięta, zalana, nasycona wodą albo
pod śniegiem. Terminy nie dotyczą upraw pod osłonami i kontenerowych.

## Wykazy gmin: dokładna data dla konkretnego pola

To największa praktyczna zmiana. Załączniki podają gminy z **kodami
TERYT**, a identyfikator działki ewidencyjnej, który aplikacja i tak ma
(`061506_2.0007.138`), zawiera kod gminy w pierwszych siedmiu cyfrach
(`0615062`). Aplikacja dopasowuje więc termin bez pytania rolnika o cokolwiek.

| Wykaz | Gmin | Termin na gruntach ornych |
| --- | --- | --- |
| Załącznik nr 2 (tabela 4) | **171** w 6 województwach | do 15 października |
| Załącznik nr 3 (tabela 5) | **1987** w 16 województwach | do 25 października |
| Poza wykazami | pozostałe | do 20 października (domyślny) |

Gdy działki leżą w gminach o różnych terminach, ekran pokazuje
**najwcześniejszy** i mówi, że pola różnią się między sobą — bo to ten
wcześniejszy wiąże, jeśli rolnik nie pilnuje każdego pola osobno. Działki
o nierozczytanym identyfikatorze są policzone i wymienione, nie przemilczane.

## Jak sprawdzaliśmy wykazy

Skrypt `tools/azotany/terminy_nawozenia.py` (Python, `pdfplumber`),
uruchamiany **na komputerze dewelopera** (CLAUDE.md, reguła 3):

1. Każdy wiersz wykazu musi mieć kształt „województwo — siedmiocyfrowy kod
   — nazwa", a województwo musi być jednym z szesnastu.
2. **Najważniejsza kontrola**: żadna pominięta linia nie może zawierać
   siedmiocyfrowego kodu. Inaczej zgubiliśmy wiersz.
3. Kody nie mogą się powtarzać w jednym wykazie ani występować w obu —
   termin byłby niejednoznaczny.
4. Dopiero wtedy skrypt zapisuje pliki.

Kontrola z punktu 2 od razu się przydała: warstwa tekstowa załączników
gubi „ń" („warmiosko-mazurskie" zamiast „warmińsko-mazurskie"), tak samo
jak w załączniku nr 1 („afrykaoskie"). Bez wypisanej wprost poprawki
z wykazów wypadłoby **72 gminy warmińsko-mazurskie** — po cichu, bo
wiersze wyglądałyby jak nagłówki stron.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `assets/dane/gminy_terminy_azotowe.json` | wykazy gmin (same kody TERYT, 42 kB) |
| `assets/dane/reguly_prawne.json` | 4 terminy graniczne + dział `zasady_nawozenia_azotem` |
| `tools/azotany/terminy_nawozenia.py` | odczyt i sprawdzenie wykazów, zapis danych |
| `lib/rdzen/reguly/gminy_terminy.dart` | słownik wykazów + kod gminy z identyfikatora działki |
| `lib/funkcje/nawozenie/terminy_azotowe.dart` | termin dla gospodarstwa z działek |
| `lib/rdzen/reguly/regula_prawna.dart` | `Termin` wie o rodzaju nawozu i gruntu; `ZasadyNawozeniaAzotem` |
| `lib/wyglad/prosty/nawozenie/ekran_nawozenie.dart` | karta „Do kiedy wolno nawozić" |

Terminy wchodzą też do kalendarza obowiązków bez żadnej zmiany w kodzie
kalendarza — to zwykłe terminy roczne ze słownika, a oznaczenie „do
sprawdzenia" obsługiwał już krok 5.

## Liczby

| Miara | Wartość |
| --- | --- |
| Terminy graniczne w słowniku | 4 |
| Odstępstwa / zakazy | 2 / 1 |
| Gminy w wykazach | 171 + 1987 = **2158** |
| Gmin zgubionych bez poprawki „ń" | 72 (wyłapane przez kontrolę) |
| Nowe pliki kodu | 2 (+ zmiany w pięciu) |
| Nowe pliki testów | 1 |
| Testy dodane | 14 (12 logiki, 2 ekranu) |
| Testy w całym projekcie | 275 (było 261) |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Cztery terminy mają właściwe daty dla obu rodzajów nawozu i obu rodzajów
  gruntu.
- Daty są oznaczone jako wymagające sprawdzenia, wykazy gmin jako
  potwierdzone.
- Kod gminy wyciąga się z identyfikatora działki; dziwnego identyfikatora
  nie zgadujemy.
- Gmina z załącznika nr 2 dostaje 15 X, z nr 3 — 25 X, poza wykazami — 20 X.
- Działki w różnych gminach dają najwcześniejszy termin.
- Karta na ekranie pokazuje daty po rolniczemu („do 31 października"),
  zakaz, oba odstępstwa z limitem 30 kg N/ha i ostrzeżenie o źródle dat.

## Co zostaje otwarte

1. **Tabela 2 z rozdziału 1.3 programu** — potrzebna, żeby daty przestały
   być „ze strony ministerstwa". Wymaga dostępu do pełnego tekstu
   rozporządzenia (`dziennikustaw.gov.pl` albo `isap.sejm.gov.pl`).
2. **Wcześniejsze nawożenie wiosną** — przepis dopuszcza start przed datą
   z tabeli 2 po przejściu średniej temperatury dobowej przez próg; tego
   nie wpisujemy, dopóki nie przeczytamy warunku w rozporządzeniu.
3. **Limit 170 kg N/ha i progi planu nawożenia** mają w słowniku status
   `potwierdzone` z czasów planu — warto je potwierdzić w tym samym
   dokumencie, przy okazji tabeli 2.
4. **Odłogi** — materiały wspominają o zakazie nawożenia gruntów
   odłogowanych z wyjątkiem przed zakończeniem odłogowania; nie ma tego
   w komunikacie ministerstwa, więc nie wpisujemy.
