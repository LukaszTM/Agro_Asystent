# Synchronizacja przez dysk użytkownika — luka 11 (część pierwsza)

16 października 2026 r.

Plan (pkt 2) obiecuje synchronizację **przez dysk użytkownika**, bez
własnego serwera. Aplikacja miała dotąd tylko kopię do pliku i wczytanie
jej do **pustej** instalacji; dwa urządzenia tego samego gospodarstwa nie
dały się pogodzić — wczytanie kopii na telefonie z wpisami kończyło się
odmową „w telefonie są już wpisy".

Teraz jest druga droga: **„Dołącz dane z drugiego urządzenia"**. Ten sam
plik, ta sama droga (pendrive, dysk w telefonie, mail do siebie), ale
dane z pliku **dołączają się** do tego, co już jest.

## Zasada, którą da się powiedzieć jednym zdaniem

> **Nowszy wpis wygrywa, starszy zostaje w dzienniku zmian.**

To nie jest wygodny skrót — to warunek z CLAUDE.md („wpisy są dopisywane,
nie nadpisywane"). Scalanie nie usuwa dokumentacji:

| Sytuacja | Co robi aplikacja |
| --- | --- |
| Wpis jest tylko w pliku | dopisuje go |
| Wpis jest tylko w telefonie | nie rusza go |
| Ten sam wpis, identyczny | nic |
| W pliku nowszy | zastępuje lokalny, **poprzednia wersja idzie do dziennika zmian** |
| W pliku starszy | zostawia lokalny, ale **wersję z pliku zapisuje w dzienniku** (`pominieto_z_pliku`) |
| Ustawienia telefonu (wygląd, przypomnienia) | zostają jego własne |

Dzięki temu kontrola i rolnik widzą obie wersje wpisu — z czasem i nazwą
urządzenia, które je zrobiło.

## Czego pilnuje kod

Tabele bez własnego czasu zmiany (powiązania pól z zabiegiem, szczegóły
oprysku i nawożenia) idą **razem z rodzicem**. Inaczej dałoby się scalić
zabieg z pliku ze szczegółami z telefonu i wyszłaby ewidencja zabiegu,
którego nikt nie wykonał. Reguła dla każdej tabeli stoi w jednym miejscu
(`regulyScalania`), nie rozsypana po kodzie.

Dziennik zmian scala się po **treści**, nie po numerze wpisu: numer jest
lokalny dla każdego telefonu, więc po numerze wpisy by się dublowały.
Scalanie tego samego pliku dwa razy nie zmienia niczego — ta właściwość
ma osobny test, bo rolnik naciśnie przycisk drugi raz, gdy nie będzie
pewien, czy pierwszy raz się udało.

Poprzednią wersję wpisu zapisujemy do dziennika tylko tam, gdzie nie robi
tego wyzwalacz bazy (zabiegi, szczegóły oprysku, uprawa pola mają własne).
Które tabele mają wyzwalacz, kod sprawdza **w bazie** (`sqlite_master`),
a nie na liście w kodzie — wyzwalacze dochodzą z migracjami.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 394 | **407** |
| Pliki testów | 39 | **40** |
| Nowy kod | — | `lib/rdzen/uslugi/kopia/scalanie.dart` (404 w.) |
| `flutter analyze` | czysto | czysto |

Testy scalania (10) sprawdzają m.in.: zabieg z drugiego urządzenia
dochodzi razem ze szczegółami i powiązaniem z polem; dwukrotne scalanie
nie dubluje; nowsza poprawka z pliku wygrywa, a starsza zostaje
w dzienniku; starsza wersja z pliku nie przepada bez śladu; ustawienia
telefonu zostają; obcy plik i plik z nowszego schematu są odrzucone.
Trzy testy ekranowe sprawdzają, co z tego widzi rolnik.

## Czego nadal brakuje do zamknięcia luki 11

- **Program na Windows** nie był budowany ani raz — katalog `windows/`
  jest z szablonu Fluttera, a w kontenerze sesji nie ma Windows ani
  możliwości jego zbudowania. To zostaje do zrobienia na komputerze.
- **Automatyczne wykrywanie pliku** („zobacz, czy na dysku jest nowsza
  kopia") — dziś rolnik wskazuje plik sam. Przy jednym gospodarstwie
  i dwóch urządzeniach to wystarcza.
- Scalanie nie rozpoznaje **usunięcia** wpisu na drugim urządzeniu jako
  czegoś innego niż zmiana: wpis oznaczony jako usunięty (`usuniety = 1`)
  jest zwykłym nowszym wpisem i wygrywa po czasie. To zachowanie jest
  zgodne z zasadą, ale warto je sprawdzić z rolnikiem, gdy aplikacja
  trafi na dwa prawdziwe telefony.
