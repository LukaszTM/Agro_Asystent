# Plan testów — komputer (Windows)

**Tester:** …………………………… **Windows:** 10 / 11 **Wersja programu**
(Ustawienia → O programie): …………… **Data:** ……………

Jak zakreślać: **TAK** — stało się to, co w kolumnie „Co powinno się stać".
**NIE** — stało się coś innego; napisz co w „Uwagach". **–** — nie robiłem.
Punkty z gwiazdką ★ są najważniejsze.

## A. Uruchomienie

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| A1 ★ | Pobierz zip, rozpakuj cały folder, uruchom `agro_asystent.exe`, przy SmartScreen: Więcej informacji → Uruchom mimo to | Program wstaje, po lewej pasek zakładek, otwarta zakładka Pulpit | TAK / NIE | |
| A2 | Uruchom `agro_asystent.exe` prosto z wnętrza archiwum zip (bez rozpakowania) | Program nie wstaje albo wstaje i od razu gaśnie — to znany stan; zapisz, co zobaczyłeś | TAK / NIE | |
| A3 ★ | Ustawienia → Wielkość tekstu → wybierz inną | Tekst zmienia się od razu w całym programie | TAK / NIE | |
| A4 | Zwęź okno do połowy ekranu | Nic nie jest ucięte, da się dalej pracować | TAK / NIE | |

## B. Gospodarstwo i pola

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| B1 ★ | Ustawienia → Popraw dane gospodarstwa: nazwa, właściciel, numer producenta, powierzchnia, zwierzęta | Dane widać na karcie Gospodarstwo w Ustawieniach i w nagłówku programu | TAK / NIE | |
| B2 ★ | Pola → Dodaj pole: nazwa, uprawa z listy, powierzchnia np. 2,35 | Pole na liście; wykres na Pulpicie zmienia się | TAK / NIE | |
| B3 | Dodaj pole z własną nazwą uprawy spoza listy | Program mówi, że kodu EPPO nie ma; na wydruku „brak" | TAK / NIE | |
| B4 | Pola → wybierz pole → ikona zmiany nazwy → nowa nazwa → Zapisz nazwę | Nowa nazwa na liście; przy polu z wniosku zostaje też oznaczenie „we wniosku: …" | TAK / NIE | |
| B5 | Pola → wybierz pole → rodzaj użytku i woda przy polu | Wybór zapisuje się od razu | TAK / NIE | |

## C. Działki i wniosek

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| C1 ★ | Pola → Działka po numerze → Wpisz pełny numer → numer z wypisu → Znajdź | Działka z granicą do potwierdzenia; po potwierdzeniu widać ją na mapie Pulpitu | TAK / NIE | |
| C2 ★ | Pola → Działka po numerze → Po miejscowości: województwo, nazwa wsi, numer | Jedna działka → potwierdzenie; kilka gmin → lista do wyboru; po wyborze potwierdzenie | TAK / NIE | |
| C3 | Odłącz internet i spróbuj C2 | Jedno zdanie o braku połączenia i rada; program działa dalej | TAK / NIE | |
| C4 ★ | Pola → Wczytaj wniosek z PDF → własny plik wniosku (na próbę) | Program pokazuje, ile działek i pól wczyta; po potwierdzeniu są na listach i na mapie | TAK / NIE | |
| C5 | Wczytaj ten sam wniosek drugi raz | Nic się nie dubluje; program mówi, że już to ma | TAK / NIE | |
| C6 | Wskaż zamiast wniosku inny plik PDF | Program mówi, że to nie wniosek; nic nie zapisuje | TAK / NIE | |

## D. Pulpit

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| D1 ★ | Po dodaniu kilku pól otwórz Pulpit | Wykres „Co rośnie" zgadza się z listą pól (pole bez uprawy ma osobny szary wycinek); mapa pokazuje działki; terminy najbliższe | TAK / NIE | |
| D2 | Z internetem — karta pogody | Prognoza na co najmniej 3 dni dla położenia gospodarstwa (z działek); bez działek — zdanie, że nie wiadomo, gdzie jest gospodarstwo | TAK / NIE | |
| D3 | Bez internetu — karty pogody i wiadomości | Każda mówi jednym zdaniem o braku sieci; ostatnia pobrana prognoza zostaje | TAK / NIE | |
| D4 | Karta cen skupu | Mówi wprost, że notowań nie ma w tej wersji — nie pokazuje żadnej ceny | TAK / NIE | |
| D5 | Kalendarz biodynamiczny → rozwiń tydzień do miesiąca | Przy każdym dniu rączka siewna (jedna — dobry dzień, dwie — bardzo dobry, przekreślona — zły, w dzień nowiu, kwadry albo pełni) i ikona: liść, owoc, korzeń albo szpadel (prace w glebie); widoczne zastrzeżenie, że to tradycja, nie przepis | TAK / NIE | |

## E. Dane z telefonu, rejestr, wydruk

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| E1 ★ | Na telefonie Zrób kopię, prześlij plik na komputer, Ustawienia → Dołącz dane z telefonu | Wpisy z telefonu są w Rejestrze zabiegów; program mówi, ile doszło; nic nie znika | TAK / NIE | |
| E2 | Dołącz ten sam plik drugi raz | Program mówi, że plik nie wnosi nic nowego | TAK / NIE | |
| E3 ★ | Dokumenty → przy rejestrze zabiegów Zapisz PDF, Zapisz CSV, Zapisz XLSX | Pliki powstają; PDF z polskimi znakami, nagłówek z danymi gospodarstwa; CSV/XLSX otwierają się w arkuszu | TAK / NIE | |
| E4 | Dokumenty → Wydrukuj | Otwiera się okno drukowania systemu | TAK / NIE | |
| E5 | Warunkowość → przejrzyj normy → Zapisz PDF | Każda norma ma stan; „do sprawdzenia" tam, gdzie program nie umie policzyć; PDF powstaje | TAK / NIE | |
| E6 | Terminy | Lista obowiązków odpowiada danym gospodarstwa; karencje z zabiegów (po E1) na liście | TAK / NIE | |
| E7 | Magazyn → dodaj zakup środka | Stan widoczny; po dołączeniu wpisów z telefonu zużycie zdjęte | TAK / NIE | |
| E8 ★ | Ustawienia → Zrób kopię → wskaż miejsce | Plik powstaje; po skasowaniu danych i wczytaniu go na telefonie wszystko wraca | TAK / NIE | |

## Na koniec — dwa pytania

1. Czego brakuje na komputerze, żebyś prowadził tu dokumentację? ……………………
2. Co było niejasne? ……………………
