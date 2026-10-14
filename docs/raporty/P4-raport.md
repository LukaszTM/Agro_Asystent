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

## Czego ten raport **nie** dowodzi

Czytnik sprawdzono **wyłącznie na wzorcu, który sam wytworzyłem** według opisu
z planu. To dowodzi, że radzi sobie z opisanymi pułapkami — nie dowodzi, że
poradzi sobie z prawdziwym plikiem z eWniosekPlus. Prawdziwy wniosek może mieć
inne nazwy kolumn, dodatkowe sekcje między tabelami albo inne łamanie wierszy.

**Potrzebny jest jeden prawdziwy wniosek do sprawdzenia** — wystarczy
jednorazowo, na komputerze, bez wgrywania do repozytorium:

```bash
python3 tools/p4_wniosek/czytnik.py /ścieżka/do/wniosku.pdf
```

Wynik (same liczby, bez danych osobowych) wystarczy, żeby ocenić, co poprawić.
Plan przewiduje też próbę na wniosku z ekoschematami i długimi tabelami.

## Następny krok

**P5. Prototyp ULDK** — pobranie granic działek po identyfikatorze TERYT, zapis
lokalny i wyświetlenie na mapie offline. Identyfikatory z wniosku (tabela X)
są już odczytywane w postaci, której ULDK oczekuje.
