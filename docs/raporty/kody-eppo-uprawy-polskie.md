# Kody EPPO upraw: domknięcie luki 2

Data: 16.10.2026. Gałąź: `claude/eloquent-hopper-etevk6`.
Narzędzie: `tools/p3_slownik_upraw/uprawy_polskie.py`.

Zakres przyjęty na polecenie właściciela projektu: **uprawy konwencjonalne
w Polsce**. Rośliny ozdobne, leśne i tropikalne nie dostają kodu i nie
czekają na decyzję — aplikacja prowadzi dokumentację produkcji roślinnej.

## Czego brakowało

Ewidencja zabiegów środkami ochrony roślin ma kolumnę **„kod EPPO
uprawy"** (rozporządzenie wykonawcze UE 2023/564) — od 2027 r. dokument
ma być czytany maszynowo, więc puste pole przestanie wystarczać.

Zadanie P3 dopasowało kody automatem: nazwa uprawy z rejestru MRiRW
musiała zgadzać się **co do znaku** z polską nazwą rośliny w bazie EPPO.
Dało to 153 uprawy i **44,7%** zastosowań z rejestru. Baza EPPO ma jednak
polskie nazwy wyrywkowo — nie ma ich nawet dla „grusza", „sałata",
„burak ćwikłowy", „kapusta głowiasta" czy „pasternak". Największe dziury
po tym etapie:

| Uprawa | Zastosowań w rejestrze |
| --- | --- |
| grusza | 620 |
| sałata | 357 |
| ogórek | 347 |
| marchew | 344 |
| winorośl | 285 |
| śliwa | 282 |
| kapusta głowiasta | 278 |

## Jak uzupełniliśmy, nie zgadując

Dla każdej nazwy z rejestru podajemy **nazwę naukową** gatunku, który ta
nazwa oznacza w polskim rolnictwie — i to jest cała decyzja merytoryczna.
**Kod bierze baza EPPO po tej nazwie naukowej**; gdy nazwa naukowa nie ma
w bazie dokładnie jednego kodu, wiersz zostaje bez kodu i trafia do
raportu błędów. Nazwa naukowa stoi w pliku decyzji, więc każdą decyzję
da się sprawdzić bez czytania kodu skryptu.

Wynik zapisuje się w `assets/dane/kody_eppo_decyzje.csv`; decyzji już
`potwierdzonych` skrypt **nie nadpisuje** — przy rozbieżności wypisuje
spór i zostawia to, co w pliku.

## Polskie nazwy w EPPO są miejscami mylące

Na tym właśnie potknął się automat z P3. Nazwa naukowa jest wiążąca:

| Uprawa z rejestru | Automat (polska nazwa w EPPO) | Po sprawdzeniu nazwy naukowej |
| --- | --- | --- |
| porzeczka czerwona | `RIBSP` — *Ribes spicatum*, **gatunek dziki** | `RIBRU` — *Ribes rubrum* |
| pszenica płaskurka | `TRZMO` — EPPO nazywa tak *Triticum monococcum* (samopsza) | `TRZDI` — *Triticum dicoccon* |
| brokuł | `BRSOB` — EPPO daje tę nazwę kalafiorowi i brokułowi | `BRSOK` — *B. oleracea* var. *italica* |
| mięta pieprzowa | `MENPC` — *Mentha* × *piperita* var. *citrata* | `MENPI` — *Mentha* × *piperita* |
| peluszka | `PIBSX` — *Pisum sativum* | `PIBSA` — *P. sativum* subsp. *arvense* |
| koper włoski | `FOEVS` — *Foeniculum vulgare* subsp. *sativum* | zostaje `FOEVS` (automat był dokładniejszy) |

Pięć z tych kodów było **w pliku dołączanym do aplikacji** — plantacja
porzeczki czerwonej dostałaby na wydruku kod gatunku dzikiego.

Kontrola krzyżowa objęła wszystkie 73 uprawy, które miały już kod
z automatu: 67 zgodnych, 6 rozbieżnych (tabela powyżej).

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Uprawy z kodem w pliku aplikacji | 153 | **347** |
| Zastosowania z rejestru mające kod | 44,7% | **83,3%** |
| `potwierdzone` w pliku decyzji | 18 | 298 |
| `poza_zakresem` (ozdobne, leśne, tropikalne) | — | 135 |
| `nie_uprawa` (miejsca, przedmioty, produkty) | 11 | 71 |
| `grupa_upraw` (nazwy zbiorcze) | — | 31 |
| `rodzajowa` (pytanie o gatunek do rolnika) | 138 `do_decyzji` | **23** |

Rozkład wszystkich 38 359 zastosowań z rejestru po zmianie:
82,6% uprawa z kodem, 6,2% poza zakresem, 5,9% nie-uprawa,
1,8% nazwa rodzajowa (gatunek wybiera rolnik), 1,6% nazwa zbiorcza,
1,9% bez decyzji
(ogon 400 nazw, każda poniżej 15 zastosowań).

## 23 nazwy rodzajowe: pyta o nie rolnik, nie my

Rejestr mówi np. „łubin", a gatunki mają różne kody (biały `LUPAL`, żółty
`LUPLU`, wąskolistny `LUPAN`). Rozstrzygnięcie właściciela projektu
z 16.10.2026: **kodu rodzaju nie wpisujemy na wydruk** — aplikacja
pokazuje rolnikowi gatunki do wyboru, a gdy jego uprawy nie ma na liście,
rolnik wpisuje własną nazwę i kolumna kodu zostaje pusta.

Dlatego nazwy rodzajowe mają w danych stan `rodzajowa`, pytanie do
rolnika („Jaki łubin?") i listę gatunków — każdy z gotowym kodem
(pilnuje tego test). Przykłady:

| Nazwa z rejestru | Pytanie | Gatunki do wyboru |
| --- | --- | --- |
| łubin | Jaki łubin? | biały, żółty, wąskolistny |
| gorczyca | Jaka gorczyca? | biała, sarepska, czarna |
| dynia | Jaka dynia? | zwyczajna, olbrzymia, piżmowa |
| kapusta | Jaka kapusta? | głowiasta biała i czerwona, włoska, pekińska, chińska, brukselka, jarmuż, kalarepa, kalafior, brokuł |
| porzeczka | Jaka porzeczka? | czarna, czerwona, biała |
| wierzba energetyczna | Jaka wierzba? | wiciowa, purpurowa |

Dwie nazwy — „topola energetyczna" i „róża uprawiana na jadalne owoce" —
nie mają gatunku w słowniku; tam rolnik wpisze własną nazwę.

## Ekran wyboru uprawy (oba wyglądy)

Uprawę pola wybiera się z listy, nie z klawiatury (reguły interfejsu).
Lista idzie **od upraw najczęstszych w rejestrze**, więc pszenica ozima,
rzepak ozimy i pszenżyto są na górze; wyszukiwarka jest dodatkiem, nie
wymogiem.

- Uprawa z kodem → od razu wybrana, pod nazwą stoi `kod EPPO: TRZAW`.
- Nazwa rodzajowa → drugi ekran z pytaniem i gatunkami; po wyborze
  gatunku oba ekrany zamykają się jednym dotknięciem.
- „Nie ma mojej uprawy" → rolnik wpisuje nazwę i widzi, co traci:
  „nie podpowiemy środków z rejestru ani kodu EPPO", a w ewidencji
  zostanie „brak".
- Nazwy zbiorcze („zboża"), miejsca stosowania („uprawa w szklarni")
  i rośliny spoza zakresu („róża") na listę nie wchodzą.

Słownik aplikacji nosi teraz przy każdej uprawie stan, gatunki do wyboru,
pytanie i liczbę zastosowań w rejestrze (`tools/zbuduj_slowniki.py`),
więc kolejność listy i pytania są **danymi**, nie kodem ekranu.

## Wyszukiwarka upraw (16.10.2026)

Do wyboru jest **621 upraw** — przewijaniem nie da się znaleźć konkretnej,
więc wyszukiwarka jest w ekranie wyboru uprawy obowiązkowa, a nie dodatkowa:

- **Bez ogonków i bez wielkich liter.** Słownik trzyma przy każdej nazwie
  postać znormalizowaną (kolumna `szukanie`: małe litery, `ł` → `l`,
  bez ogonków). „lubin" znajduje „łubin", „ZYTO" — „żyto".
  Tę samą normalizację robi `Tekst.znormalizuj` w `lib/rdzen/wspolne/`,
  więc wpisany tekst i dane liczą się tak samo.
- **Kilka słów, dowolna kolejność.** „ozim psz" znajduje „pszenicę ozimą" —
  każde słowo musi wystąpić w nazwie, kolejność nie ma znaczenia.
- **Widać, ile pasuje.** Nad listą stoi „Znaleziono 7 upraw"; gdy pasuje
  więcej, niż się pokazuje, ekran mówi wprost: „Pasuje 231 upraw,
  pokazujemy 60 — wpisz więcej liter".
- **Klawiatura wychodzi po dotknięciu okienka**, nie od razu po wejściu na
  ekran (decyzja z 16.10.2026): najpierw widać listę najczęstszych upraw,
  a klawiatura nie zasłania ekranu temu, kto chce tylko przewinąć.

## Zmiana uprawy pola

Uprawa zmienia się co sezon, a wpisy zabiegów zostają przy tym samym polu.
Wcześniej uprawę można było ustawić tylko przy zakładaniu pola — teraz:

- wygląd prosty: lista pól → pole → „Zmień uprawę",
- wygląd nowoczesny: karta wybranego pola → „Zmień uprawę",
- oba ekrany prowadzą do tej samej wyszukiwarki upraw.

Poprzednią uprawę i kod EPPO zapisuje **wyzwalacz bazy** (migracja 4,
`historia_dzialka_rolna_zmiana`), więc kontrola widzi, co rosło wcześniej —
tak jak przy poprawce wpisu (CLAUDE.md: wpisy są dopisywane, nie
nadpisywane). Zapis tej samej uprawy nie dopisuje nic do dziennika.

To zamyka też lukę z importu wniosku: uprawę wczytaną z PDF, której słownik
nie rozpoznał, rolnik poprawia na ekranie pola.

## Dziura w zabezpieczeniu, znaleziona przy okazji

`tools/zbuduj_slowniki.py` brał z wyniku P3 **każdy wiersz z kodem**, nie
patrząc na kolumnę `stan`. Gdyby `eppo.py` zapisał tam kod ze stanem
`propozycja`, trafiłby do pliku aplikacji jako kod pewny — ten sam rodzaj
błędu, który wcześniej naprawiliśmy w `slownik.py`. Teraz wchodzą tylko
stany `kod` i `potwierdzone`.

## Testy

`tools/p3_slownik_upraw/test_uprawy_polskie.py` — 18 testów:

- każda nazwa naukowa z tabeli daje w bazie EPPO dokładnie jeden kod,
- wymyślona nazwa naukowa nie daje żadnego kodu,
- kody ważnych upraw (ziemniak, grusza, marchew, burak ćwikłowy,
  porzeczka czerwona, płaskurka, samopsza, brokuł, kalafior) są sprawdzane
  wprost — to one chronią przed powrotem błędów z tabeli wyżej,
- wiersze `poza_zakresem`, `grupa_upraw`, `nie_uprawa` i `do_decyzji`
  nigdy nie mają kodu,
- nazwa trafia do dokładnie jednej tabeli, a alias wskazuje uprawę z kodem,
- scalanie nie nadpisuje decyzji `potwierdzonej` (i mówi o sporze),
  a wiersz `do_decyzji` wolno poprawić.

Po stronie aplikacji doszły testy wyboru uprawy:
`test/funkcje/dzialki/slownik_upraw_test.dart` (9 testów: kolejność listy,
odrzucone nazwy zbiorcze i miejsca, gatunki w kolejności z danych, własna
nazwa bez kodu) oraz `test/wyglad/wybor_uprawy_test.dart` i trzy testy
w `test/wyglad/nowoczesny_test.dart` — ta sama ścieżka w obu wyglądach.

Wyszukiwarkę i zmianę uprawy pilnują kolejne testy: szukanie bez ogonków
i wielkimi literami, dwa słowa w dowolnej kolejności, uprawa z końca listy
(1 zastosowanie w rejestrze) znaleziona po fragmencie nazwy, ucięta lista
podająca liczbę pasujących, zmiana uprawy pola w obu wyglądach i wpis
w dzienniku zmian (plus kontrola, że zapis tej samej uprawy nic nie
dopisuje).

Razem: `python3 -m pytest tools` → 112 testów, `flutter test` → 361 testów.

## Jak powtórzyć

```bash
python3 tools/p3_slownik_upraw/uprawy_polskie.py      # decyzje + pokrycie
python3 tools/p3_slownik_upraw/eppo.py                # dane/wynik/uprawy_eppo.csv
python3 tools/zbuduj_slowniki.py                      # asset dla aplikacji
```
