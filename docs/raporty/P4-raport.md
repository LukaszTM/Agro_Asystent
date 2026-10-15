# Raport P4 — czytnik wniosku o płatności (PDF)

14 października 2026 r. Zadanie: „P4. Czytnik wniosku PDF" z planu (pkt 9):
parser tabel X i XI z testami na zanonimizowanym wzorcu oraz kontrola sumy
powierzchni z podsumowaniem wniosku.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/p4_wniosek/wzorzec.py` | wytwarza zanonimizowany wzorzec wniosku (dane zmyślone) |
| `tools/p4_wniosek/czytnik.py` | czyta tabele X i XI, sprawdza sumę powierzchni |
| `tools/p4_wniosek/test_czytnik.py` | 14 testów |
| `test/dane/wzorzec_wniosku.pdf` | wzorzec do testów — jedyny wniosek w repozytorium |

## Zanonimizowany wzorzec

Prawdziwy wniosek zawiera dane osobowe i nie może trafić do repozytorium
(plan, pkt 11), więc wzorzec powstaje ze skryptu. Odwzorowuje liczby z planu
(pkt 6.2) i **wszystkie wymienione tam pułapki**:

| Cecha | We wzorcu |
| --- | --- |
| Działek ewidencyjnych (tabela X) | 20 |
| Działek rolnych (tabela XI) | 34 |
| Powierzchnia razem | 28,91 ha |
| Nazwa uprawy łamana na kilka wierszy | tak |
| Jedna działka rolna na kilku ewidencyjnych | 5 przypadków |
| Tabela przechodząca przez strony z powtórzonym nagłówkiem | tak |
| Oznaczenia dwuliterowe (AA, AB…) | tak |
| Nagłówek i stopka na każdej stronie | tak |

Każda strona wzorca jest podpisana „WZORZEC TESTOWY — DANE ZMYŚLONE, NIE
DOTYCZĄ ŻADNEGO GOSPODARSTWA", a test pilnuje, żeby ten podpis tam został.

## Wynik odczytu wzorca

```
Działki ewidencyjne: 20
Działki rolne:       34
Powierzchnia z odczytu:   28.91 ha
Powierzchnia z wniosku:   28.91 ha
Różnych upraw:       8
Pominięte wiersze (nagłówki i stopki stron): 1
Kontrola: zgodna
```

Kolumny rozpoznajemy po **położeniu nagłówka na stronie**, nie po liniach
siatki — wniosek jest składany tekstem, bez obramowań. Po przejściu na nową
stronę nagłówek jest odczytywany ponownie, więc przesunięcie kolumn na kolejnej
stronie niczego nie psuje.

## Kontrola sumy — i dlaczego jest ważniejsza niż sam odczyt

Czytnik porównuje sumę powierzchni działek rolnych z podsumowaniem wniosku
i liczbę działek z deklarowaną. Niezgodność kończy pracę **błędem** (kod wyjścia 1)
i wypisuje ostrzeżenie. To jedyna rzecz, która chroni przed cichym zgubieniem
wiersza: jeśli przy innym układzie wniosku parser przeoczy działkę, suma się nie
zgodzi i rolnik dostanie informację, zamiast niekompletnej ewidencji.

Dodatkowe ostrzeżenia: nierozpoznane kolumny tabeli, wiersz z brakującą
powierzchnią, brak podsumowania w pliku.

## Dwa błędy znalezione w trakcie

1. **Nagłówek strony sklejał się z nazwą uprawy** przy przejściu tabeli na nową
   stronę — powstawała uprawa „kukurydza na ziarno — DANE ZMYŚLONE…". Teraz
   wiersz, w którym w kolumnie oznaczenia stoi coś, co oznaczeniem nie jest,
   jest pomijany i liczony osobno.
2. **Cichy brak wyniku przy nierozpoznanych kolumnach**: gdy nagłówek tabeli
   skleił dwie kolumny, czytnik zwracał zero wierszy bez słowa wyjaśnienia.
   Teraz zgłasza, ile kolumn rozpoznał z ilu.

## Powiązanie z P3

Czytnik zapisuje nazwy upraw z wniosku (`--uprawy-csv`), a słownik z P3 je
przyjmuje (`--wniosek`). Na wzorcu daje to dokładnie rozbieżności, które plan
przewidywał (pkt 6.3):

| Nazwa z wniosku | Nazwa z rejestru | Sposób |
| --- | --- | --- |
| pszenica ozima | pszenica ozima | dokładne |
| jęczmień jary | jęczmień jary | dokładne |
| rzepak ozimy | rzepak ozimy | dokładne |
| ziemniak | ziemniak | dokładne |
| **owies zwyczajny** | owies | propozycja do zatwierdzenia |
| **kukurydza na ziarno** | kukurydza | propozycja do zatwierdzenia |
| **łąki trwałe** | łąki | propozycja do zatwierdzenia |
| mieszanka zbożowo-strączkowa na nasiona… | — | brak propozycji |

Czyli ta część słownika upraw działa — potrzebuje tylko prawdziwej listy nazw
używanych przez ARiMR.

## Sprawdzenie na prawdziwym wniosku (15.10.2026)

Użytkownik udostępnił swój wniosek za 2026 r. (31 stron, plik tekstowy).
**Plik został użyty wyłącznie w katalogu roboczym poza repozytorium
(`dane/prywatne/`, wykluczony w `.gitignore`) i nigdzie nie został zapisany
na stałe.** Pierwsze uruchomienie czytnika odczytało **zero wierszy** — mój
wzorzec, zbudowany z opisu w planie, różnił się od rzeczywistości w czterech
miejscach:

| Co zakładałem | Jak jest naprawdę |
| --- | --- |
| Strona pionowa, nagłówek tabeli w jednym wierszu | Strona **pozioma**, nagłówek rozbity na kilkanaście wierszy |
| Kolumny rozpoznawane po nazwach w nagłówku | Pod nagłówkiem jest **wiersz z numerami kolumn**, a wartości są wyśrodkowane |
| Identyfikator działki w jednym kawałku | Łamany na dwa wiersze: `140100_2.0001` + `.123/4` |
| Podsumowanie powierzchni na końcu tabeli | **Wniosek nie zawiera żadnego podsumowania** |

Po przebudowie czytnika wynik na prawdziwym pliku:

```
Działki ewidencyjne: 20  (33.04 ha)
Działki rolne:       34
Powierzchnia zadeklarowana: 28.91 ha
Różnych upraw:       10
Kontrola: zgodna
```

Liczby zgadzają się co do jednego z opisem w planie (pkt 6.2): 20 działek
ewidencyjnych, 34 działki rolne, 28,91 ha.

### Trzy błędy, które wyszły dopiero na prawdziwym pliku

1. **Działka rolna leżąca na trzech działkach ewidencyjnych.** Wiersze kolejnych
   części zaczynają się od identyfikatora, bez oznaczenia i bez powierzchni
   zadeklarowanej. Czytnik je gubił, a kody płatności z tych wierszy wsiąkały
   w nazwę uprawy („TUZ ONW, PWD ONW").
2. **Stopka strony** („…-PLA-26-0001 Status wniosku: Roboczy 5/9") dopisywała się
   do nazwy uprawy ostatniej działki na stronie. Teraz pas przy dolnej krawędzi
   strony jest odcinany.
3. **Brak podsumowania powierzchni** — kontrola, na której opierał się cały
   czytnik, nie miała się o co oprzeć.

### Kontrole wewnętrzne zamiast podsumowania

Skoro wniosek nie podaje sumy, czytnik sprawdza spójność samych danych:

- suma powierzchni części działki rolnej musi równać się jej powierzchni
  zadeklarowanej (łapie zgubiony wiersz części),
- każdy identyfikator z tabeli XI musi występować w tabeli X,
- oznaczenia działek rolnych nie mogą się powtarzać.

Na prawdziwym wniosku wszystkie trzy przechodzą. To one wyłapały błąd nr 1 —
zanim go poprawiłem, czytnik zgłaszał „działka AB: powierzchnia 0,51 ha,
a części dają 0,05 ha".

### Wzorzec przebudowany według rzeczywistości

`test/dane/wzorzec_wniosku.pdf` powstaje teraz według prawdziwego układu
(strona pozioma, wiersz numeracji kolumn, wyśrodkowane wartości, łamane
identyfikatory, wiersze części, stopka). Dane w nim pozostają zmyślone.
Czytnik daje na nim te same liczby co na prawdziwym pliku, a 21 testów pilnuje
każdej z wymienionych pułapek.

### Nazwy upraw z prawdziwego wniosku

Dziesięć nazw, z czego trzy trafiają dokładnie w rejestr (jęczmień ozimy,
pszenżyto ozime, ziemniak), cztery dostają propozycję do zatwierdzenia
(„pszenica zwyczajna ozima" → pszenica, „kukurydza na ziarno" → kukurydza,
„owies zwyczajny" → owies, „trawy wieloletnie na gruntach ornych" → trawy),
a trzy nie mają odpowiednika, bo to kategorie ARiMR, a nie uprawy w rozumieniu
rejestru: **TUZ**, **Sad**, **Uprawa mieszana**. Te trzy wymagają decyzji
w słowniku upraw (P3) — plan to przewidywał („łąki, pastwiska" wobec „TUZ").

### Czego nadal nie wiemy

Sprawdzenie objęło **jeden wniosek, w stanie roboczym**. Plan przewiduje jeszcze
próbę na wniosku z ekoschematami i długimi tabelami — tam mogą dojść kolumny,
których ten plik nie zawiera.

## Następny krok

**P5. Prototyp ULDK** — pobranie granic działek po identyfikatorze TERYT, zapis
lokalny i wyświetlenie na mapie offline. Identyfikatory z wniosku (tabela X)
są już odczytywane w postaci, której ULDK oczekuje.
