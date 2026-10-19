# Aplikacja do zarządzania gospodarstwem — plan dla Claude Code

Stan na 12 października 2026 r. Ten plik jest punktem wyjścia do prac przygotowawczych.
Zestawienie przepisów służy do zaplanowania aplikacji i nie jest poradą prawną.

## 1. Cel

Aplikacja na telefon dla rolników, także starszych, która prowadzi dokumentację wymaganą
przez ARiMR i inspekcje. Rdzeniem jest jeden rejestr zabiegów przypisanych do działek;
z jednego wpisu powstają wszystkie wymagane dokumenty. Aplikacja działa samodzielnie i bez
internetu, a z programem na PC synchronizuje się tylko wtedy, gdy użytkownik tego chce.

## 2. Decyzje (zamknięte)

| Temat | Decyzja |
| --- | --- |
| Odbiorca | Produkt dla wielu gospodarstw; jedno konto może prowadzić kilka gospodarstw |
| Profil | **Produkcja roślinna.** Produkcja zwierzęca wychodzi z zakresu aplikacji i czeka jako ścieżka rozwoju po jej ukończeniu (decyzja z 16.10.2026) |
| Platformy | Android (pierwszy) i Windows. Wersja Apple dopiero po pozytywnych testach na Androidzie |
| Technologia | Jeden kod: Flutter + lokalna baza SQLite (propozycja; do potwierdzenia na starcie) |
| Wygląd | Na telefonie dwa do wyboru (Prosty i Nowoczesny), przełączane w ustawieniach; na Windows jeden dla wszystkich |
| Tryb pracy | Offline-first. Telefon i PC mają pełne, niezależne kopie danych |
| Synchronizacja | Do wyboru w ustawieniach: internet z kopią zapasową albo samo domowe Wi-Fi |
| Serwer | Brak własnego serwera. Synchronizacja i kopia przez dysk użytkownika (Google Drive, OneDrive) |
| Budżet | Zero. Tylko darmowe narzędzia i dane; jedyna opłata na start to konto Google Play |
| Budowa | Jedna osoba z Claude Code |
| Nazwa | **Mój Łan** (od 19.10.2026; wcześniej „Agro Asystent" — kolizja z programem AgroAsystent firmy AgroPower, ADR-0009) |
| Import działek | Z pliku PDF wniosku pobranego z eWniosekPlus |
| Środki ochrony roślin | Lista z pliku ministerstwa, zawężona do uprawy na polu, szukanie po nazwie i po zdjęciu etykiety |
| Nawozy | Wprowadzane ręcznie albo ze zdjęcia opakowania (nazwa, skład NPK) |
| Karencja | Z bazy urzędowych etykiet; awaryjnie ze zdjęcia etykiety lub ręcznie. Rolnik zawsze potwierdza |
| Eksport ewidencji | CSV i XLSX; układ kolumn konfigurowalny bez przebudowy aplikacji |
| Model płatności | Darmowa wersja + premium kupowane raz; potem dobrowolna wpłata co 2 lata (min. 20 zł) za aktualizacje danych |

Założenie robocze (niepotwierdzone w inspekcji): eksport z aplikacji wystarczy przy kontroli,
a państwowa aplikacja PIORiN przyjmie dane z innych programów.

## 3. Wymogi prawne, które aplikacja pilnuje

Aplikacja sama włącza właściwe obowiązki na podstawie powierzchni, upraw i liczby zwierząt.
Progi i terminy muszą być aktualizowanym słownikiem (dane), nie stałymi w kodzie.

| Obowiązek | Kogo dotyczy | Co robi aplikacja |
| --- | --- | --- |
| Ewidencja zabiegów środkami ochrony roślin (rozp. UE 2023/564) | Każdy profesjonalny użytkownik | Zapisuje: środek, nr zezwolenia, datę i godzinę, dawkę, powierzchnię, uprawę z kodem EPPO, fazę BBCH, przyczynę zabiegu, rodzaj zastosowania, działkę z wniosku. Od 1.01.2027 r. tylko elektronicznie, w formacie do odczytu maszynowego |
| Program azotanowy: ewidencja nawożenia azotem | Od 10 ha UR lub od 10 DJP (DJP poza zakresem — patrz niżej) | Ewidencja, liczenie N/ha, limit 170 kg N/ha z nawozów naturalnych, terminy nawożenia. Przechowywanie 3 lata |
| Program azotanowy: plan nawożenia azotem | Powyżej 100 ha UR, 50 ha upraw intensywnych lub 60 DJP | Plan dla każdej działki; włącza się sam po przekroczeniu progu |
| Ekoschematy: rejestr zabiegów agrotechnicznych | Rolnicy z zadeklarowanym ekoschematem | Rejestr: nr działki ewidencyjnej, powierzchnia, data, uprawa, rodzaj zabiegu, nawóz i ilość |
| Warunkowość (GAEC, SMR) | Powyżej 10 ha (mniejsze zwolnione z kontroli i kar) | Kontrola zmianowania i dywersyfikacji (GAEC 7), okrywy 80% GO do 15.10 (GAEC 6), pasa 3 m od wód (GAEC 4), zakazu przycinania drzew 15.04–31.07 (GAEC 8) |
| Wniosek o płatności | Wszyscy | Zestawienie działek i upraw, przypomnienie o naborze. Wniosek składa się w eWniosekPlus |
| ~~IRZplus~~ | Posiadacze zwierząt | **Poza zakresem** (decyzja z 16.10.2026). Rejestr stada, terminy zgłoszeń i liczenie DJP są napisane i przetestowane, ale nie są dostępne z ekranów — wracają jako ścieżka rozwoju. Aplikacja pyta tylko, czy gospodarstwo ma zwierzęta: od tego zależy, czy obowiązki zależne od DJP oznaczyć jako „do sprawdzenia" |

Aplikacja nie zastępuje systemów urzędowych (eWniosekPlus, Mobilna ARiMR, IRZplus).
Terminy nawożenia pochodzą ze strony ARiMR z 2019 r.; trzeba je sprawdzić w aktualnym rozporządzeniu.

## 4. Zakres etapu 1 (Android)

Kolejność wewnątrz etapu; każdy krok ma dawać działającą aplikację:

1. Działki i mapa (dodawanie po numerze ewidencyjnym, granice z ULDK, praca offline).
2. Import działek i upraw z PDF wniosku.
3. Rejestr zabiegów z ewidencją oprysków (słownik środków, szukanie po nazwie).
4. Dokumenty: podgląd, wydruk PDF, eksport CSV/XLSX.
5. Terminy i przypomnienia.
6. Nawożenie: ewidencja, limit N, plan nawożenia azotem od progu.
7. Odczyt zdjęć: etykieta środka (rozpoznanie), opakowanie nawozu (nazwa, NPK).
8. Karencja z bazy etykiet (jeśli próba z zadania P2 wypadnie dobrze).
9. ~~Zwierzęta: rejestr stada, terminy, DJP.~~ Zrobione, potem **wyjęte
   z zakresu** (decyzja z 16.10.2026) — kod i testy zostają jako ścieżka
   rozwoju, ekrany nie są dostępne.
10. Konta i kilka gospodarstw.

Dodatkowo, poza dziesięcioma krokami: trzy rejestry do wydruku i eksportu (pkt 8),
kopia danych do pliku, **drugi wygląd telefonu („Nowoczesny") z przełącznikiem
w ustawieniach** (raport `docs/raporty/etap1-wyglad-nowoczesny.md`) oraz **wybór
uprawy z wyszukiwarką** (621 upraw, szukanie bez ogonków, pytanie o gatunek przy
nazwie rodzajowej, własna nazwa gdy uprawy nie ma w słowniku) razem ze **zmianą
uprawy pola na nowy sezon** zapisywaną w dzienniku zmian (raport
`docs/raporty/kody-eppo-uprawy-polskie.md`) — wszystko zrobione 16.10.2026.

Tego samego dnia domknięte jeszcze: **maksymalne dawki azotu dla 126 upraw**
(tabela 14 programu azotanowego, ostrzeżenie przy wpisie dawki — raport
`docs/raporty/maksymalne-dawki-azotu.md`), **cztery brakujące ekrany formularzowe
w wyglądzie nowoczesnym** (`docs/raporty/etap1-nowoczesny-ekrany-formularzowe.md`),
**dołączanie danych z drugiego urządzenia** — czyli obiecana w pkt 2 synchronizacja
przez dysk użytkownika (`docs/raporty/etap1-synchronizacja-przez-plik.md`),
**start aplikacji na komputerze** (baza z biblioteki dołączonej do programu,
`lib/app/platforma.dart`) i **podpis wydawniczy** gotowy do użycia
(`docs/wydanie-android.md`).

Później: zbudowanie programu na Windows (przepływ `windows.yml`, uruchamiany
ręcznie) i próba z rolnikami na prawdziwym telefonie; etap 3 — koszty
i przychody, wersja na iPhone'a.

## 4a. Zakres etapu 2 (warunkowość i magazyn)

Kolejność jak w etapie 1: każdy krok ma dawać działającą aplikację. Rozbicie
powstało 17.10.2026 z **tekstu jednolitego** rozporządzenia o normach
(Dz.U. z 2025 r. poz. 1674) — czyli z aktu w brzmieniu obowiązującym, a nie
z wersji z 2023 r., która w czterech miejscach jest już nieaktualna (między
innymi okrywa z § 4 i dywersyfikacja z § 5 ust. 4).

1. **Dane warunkowości.** Normy GAEC 1–9 jako dane z wersją: progi (10 ha,
   30 ha, 14 %, 80 %, 40 %, 75 %, 95 %), terminy (15.10, 1.11–15.02,
   15.04–31.07, 1.07–20.08), wyłączenia i zwolnienia. Skrypt czyta akt
   i odmawia zapisu, gdy którejkolwiek wartości nie ma w jego tekście.
2. **Rodzaj użytku i historia upraw pola.** Bez podziału na grunty orne,
   trwałe użytki zielone i uprawy trwałe nie da się policzyć żadnego progu
   GAEC 7, a bez uprawy w plonie głównym rok po roku (od 2023 r.) — reguły
   trzech lat. Nowa tabela upraw pola i możliwość dopisania lat wcześniejszych.
3. **GAEC 7: zmianowanie i dywersyfikacja.** Liczenie obu warunków
   z wyłączeniami z § 5 ust. 3 i 11 oraz ostrzeżenie przy zmianie uprawy
   („ta uprawa będzie tu czwarty rok").
4. **GAEC 6: okrywa ochronna gleby.** Udział 80 % gruntów ornych od zbioru
   do 15 października, z przerwą do 4 tygodni na siew ozimin; formy okrywy
   deklaruje rolnik — aplikacja podpowiada z wpisów, ale nie zgaduje.
5. **GAEC 4 i GAEC 8.** Pas 3 m od wód jako cecha pola i ostrzeżenie przy
   oprysku oraz nawożeniu; zakaz przycinania drzew i żywopłotów
   15.04–31.07 w kalendarzu i przy wpisie zabiegu.
6. **Ekran „Warunkowość"** w obu wyglądach: każda norma ze stanem
   (dotyczy / nie dotyczy / spełniona / do sprawdzenia), jedno zdanie co
   zrobić, wydruk na kontrolę.
7. **Magazyn** (premium, pkt 8): zakup i zużycie środków oraz nawozów, stan
   na dziś, zużycie liczone z wpisu zabiegu, ostrzeżenie o środku wycofanym.

Wszystkie siedem kroków zrobione 17.10.2026 — raporty w `docs/raporty/`
(`etap2-krok1-dane-warunkowosci.md` … `etap2-krok7-magazyn.md`).

Czego aplikacja nie policzy sama i co mówi wprost: GAEC 1 (udział TUZ w skali
kraju), GAEC 2 (wyznaczone torfowiska i obszary podmokłe — wykaz z Dz.U.
z 2025 r. poz. 307 jest po stronie IUNG-PIB i ARiMR), GAEC 5 (nachylenie
stoku) i GAEC 9 (TUZ cenne na Natura 2000). Tam rolnik dostaje treść normy
i informację, że dane o jego działkach ma urząd, nie telefon.

**Ścieżka rozwoju: produkcja zwierzęca.** Rejestr stada, liczenie DJP, terminy
zgłoszeń do IRZplus i później wysyłka przez API IRZplus. Moduł jest napisany
i przetestowany (krok 9), tylko odłączony od ekranów — wraca po ukończeniu
aplikacji dla produkcji roślinnej.

## 5. Zasady interfejsu (użytkownicy 60+)

Miara powodzenia: wpis zabiegu w najwyżej pięciu dotknięciach, bez klawiatury.

Wzorcowy wpis oprysku: pole (mapa lub lista) → rodzaj zabiegu (kafelki) → środek (ostatnio
używane / szukaj / zdjęcie) → powód (dawka już podpowiedziana, zmiana przyciskami + i −) → Zapisz.
Data, godzina, powierzchnia i faza wzrostu uzupełniają się same.

- Ekran główny: cztery duże przyciski — Pola, Dodaj zabieg, Terminy, Dokumenty. Bez ukrytego menu.
- Tekst co najmniej 18 px, wysoki kontrast, cele dotyku co najmniej 48 px, czytelność w słońcu.
- Wybór z listy zamiast pisania; liczby przyciskami + i − albo dużą klawiaturą numeryczną.
- „Powtórz ostatni zabieg" i ten sam zabieg na kilku polach.
- Język rolnika („oprysk"), nazwy urzędowe dopiero na wydrukach.
- Ostrzeżenia jednym zdaniem, z instrukcją, co zrobić.
- Każdy wpis da się cofnąć i poprawić. Logowanie raz; żadnych haseł w polu.
- Pola mają własne nazwy („Za stodołą"), numer ewidencyjny widoczny obok.
- Po zapisie: potwierdzenie, lista dokumentów, do których trafił wpis, informacja o karencji.

Wygląd z makiety: tło #F4F6F0, tekst #10230F, zieleń akcji #1E5B2E, powierzchnie #FFFFFF
i #E4EEDF, ostrzeżenia #FFF1D6 z obramowaniem #8A4B00, krój Atkinson Hyperlegible,
zaokrąglenia 14–18 px. Ekrany makiety: Ekran główny, Pola na mapie, Pole i rodzaj zabiegu,
Wybór środka, Dawka i przyczyna, Zapisano, Terminy, Dokumenty.

### Dwa wyglądy na telefonie

Rolnik wybiera wygląd przy pierwszym uruchomieniu i może go zmienić w ustawieniach. Oba
pokazują te same dane, dokumenty i funkcje. Różni się tylko warstwa ekranów; baza danych,
reguły i dokumenty są wspólne (logika nie może zależeć od wyglądu).

| | Prosty | Nowoczesny |
| --- | --- | --- |
| Dla kogo | Osoby starsze, duże przyciski | Osoby obyte ze smartfonem |
| Ekran główny | Cztery duże kafelki | Podsumowanie sezonu, ostatnie zabiegi, pasek azotu, dolny pasek nawigacji z przyciskiem „+" |
| Pola | Mapa + lista pól | Mapa na całą szerokość, wyszukiwarka, filtry upraw, karta wybranego pola |
| Wpis zabiegu | Krok po kroku, jedna decyzja na ekranie | Jeden ekran: rodzaj, kilka pól naraz, środek (szukaj / zdjęcie), dawka, powód |
| Tekst | Co najmniej 18 px, krój Atkinson Hyperlegible | 13–16 px, krój Manrope |

Nowoczesny: tło #F6F7F4, karty #FFFFFF z zaokrągleniem 18–20 px, tekst #0F1F12, tekst
pomocniczy #4F5F51, zieleń #1E5B2E, pasek nawigacji #0F1F12 z przyciskiem #B9E26A.
Kolejność: etap 1 zbudował najpierw wygląd prosty w całości, nowoczesny doszedł po nim
(16.10.2026). Wybór wyglądu zapisuje się w ustawieniach gospodarstwa i da się go zmienić
w każdej chwili — w obu wyglądach.
Program na Windows ma jeden wygląd, z ustawieniem wielkości tekstu.

## 6. Źródła danych i wyniki prób

### 6.1 Granice działek — ULDK (GUGiK)
- Opis: https://uldk.gugik.gov.pl/opis.html — bezpłatne, bez logowania, tylko GET.
- `GetParcelById&id=<TERYT>&result=geom_wkt,...&srid=4326`; identyfikator `WWPPGG_R.OOOO.[AR_NR.]NR_DZ`.
- `GetParcelByIdOrNr` przyjmuje też „nazwa obrębu + numer"; nazwy obrębów się powtarzają, więc
  użytkownik musi potwierdzić działkę na mapie.
- Domyślny układ EPSG:2180. Granice zapisywać lokalnie.
- Podkład mapy: ortofotomapa z Geoportalu — warunki pobierania do pracy offline do sprawdzenia.
  Publiczne serwery OpenStreetMap nie pozwalają na masowe pobieranie offline.

### 6.2 Wniosek o płatności — PDF z eWniosekPlus
Sprawdzone na jednym wniosku za 2026 r. (plik tekstowy, generator pdfmake):
- Tabela „X. OŚWIADCZENIE O DZIAŁKACH REFERENCYJNYCH": województwo, powiat, gmina, nazwa i nr
  obrębu, nr arkusza, nr działki, powierzchnia [ha].
- Tabela „XI. OŚWIADCZENIE O ZADEKLAROWANYCH POWIERZCHNIACH": oznaczenie (A, B, … AA), uprawa,
  powierzchnia (ha i a w osobnych kolumnach), pełny identyfikator działki, płatności.
- Próba: 20 działek ewidencyjnych, 34 działki rolne, suma 28,91 ha zgodna z podsumowaniem.
- Pułapki: nazwa uprawy i identyfikator działki łamią się na kilka wierszy; jedna działka rolna
  może leżeć na kilku działkach ewidencyjnych (kolejne wiersze bez oznaczenia); tabela przechodzi
  przez strony z powtórzonym nagłówkiem; mapy w załącznikach są obrazami (brak granic upraw).
- Do zrobienia: próba na wniosku z ekoschematami i długimi tabelami.
- Wniosek zawiera dane osobowe: nie umieszczać go w repozytorium; do testów zrobić zanonimizowany wzorzec.

### 6.3 Środki ochrony roślin — plik zastosowań MRiRW
- Strona: https://www.gov.pl/web/rolnictwo/wyszukiwarka-srodkow-ochrony-roslin (plik XLSX, ok. 1,7 MB).
- Arkusz `Rejestr_zastosowanie`, kolumny: nazwa, NrZezw, TerminZezw, TerminDoSprzedazy,
  TerminDoStosowania, Rodzaj, Substancja_czynna, uprawa, agrofag, dawka, termin, nazwa_grupy,
  maloobszarowe, metody_stosowania, laczne_stosowanie, zastosowanie/uzytkownik,
  srodek_mikrobiologiczny, stosowanie_agrolotnicze.
- Stan pliku z 25.09.2026: 18 785 zastosowań, 2 990 środków.
- Dawka z liczbą i jednostką w ok. 91% wierszy (tekst typu „Maksymalna/zalecana dawka dla
  jednorazowego zastosowania: 0,14 kg/ha.") — da się podpowiadać i pilnować maksimum.
- Karencja: tylko w 244 wierszach — nie brać z tego pliku.
- 24 środki po terminie stosowania nadal są w pliku — filtrować po `TerminDoStosowania`.
- Faza BBCH w kolumnie `termin` w ok. 2/3 wierszy.
- Kolumna `uprawa`: 2 189 różnych zapisów, 1 868 to listy kilku upraw w jednej komórce.
  Nazwy różnią się od wniosku („owies" vs „owies zwyczajny", „kukurydza" vs „kukurydza na ziarno",
  „łąki, pastwiska" vs „TUZ"). Potrzebny słownik odpowiedników: uprawa z wniosku → uprawa
  z rejestru → kod EPPO. To największa praca w tym module.

### 6.4 Etykiety środków — karencja
- Strona: https://www.gov.pl/web/rolnictwo/etykiety-srodkow-ochrony-roslin — dziesięć podstron
  alfabetycznych (np. /web/rolnictwo/a-b1), pliki PDF pod adresami bez nazwy środka, brak pliku zbiorczego.
- Przy środku jest kilka dokumentów (etykieta, zezwolenie, decyzje) — wybierać najnowszą etykietę.
- Sprawdzona jedna etykieta: PDF tekstowy, karencja w postaci „uprawa(y) – N dni;", obok okres
  prewencji, dawka, maksymalna liczba zabiegów.
- Urzędowa etykieta to wersja aktualna; opakowanie rolnika może mieć starszą — pokazywać datę etykiety.

### 6.5 Nawozy
- Wykaz MRiRW: https://www.gov.pl/web/rolnictwo/wykaz-nawozow-i-srodkow-wspomagajacych-uprawe-roslin
  (XLSX, aktualizowany mniej więcej co miesiąc). 830 nazw z producentem i numerem decyzji, bez składu
  i upraw; brak popularnych nawozów z oznakowaniem unijnym.
- Wniosek: nawozy wprowadza rolnik (ręcznie lub ze zdjęcia), aplikacja zapamiętuje nazwę i skład NPK.

### 6.6 Zwierzęta
- API IRZplus: https://www.gov.pl/web/arimr/api--portal-irzplus (etap 3).

## 7. Szkic modelu danych

- Gospodarstwo; Konto (opcjonalne) ↔ wiele gospodarstw.
- DzialkaEwidencyjna: identyfikator TERYT, obręb, numer, geometria, powierzchnia.
- DzialkaRolna (pole): nazwa własna, oznaczenie z wniosku, sezon, uprawa, powierzchnia.
- Relacja wiele-do-wielu DzialkaRolna ↔ DzialkaEwidencyjna z powierzchnią części.
- Zabieg: typ (oprysk, nawożenie, siew, zbiór, uprawa gleby), data, godzina, pola, powierzchnia.
  - szczegóły oprysku: środek, nr zezwolenia, dawka i jednostka, przyczyna, faza BBCH, kod EPPO, rodzaj zastosowania;
  - szczegóły nawożenia: nawóz, dawka, wyliczony N/ha.
- SrodekOchrony, Zastosowanie (środek × uprawa: dawka maks., termin, daty ważności), Karencja (środek × uprawa: dni, data etykiety, źródło).
- Nawoz (własny słownik użytkownika: nazwa, N, P, K, naturalny/mineralny).
- SlownikUpraw: nazwa z wniosku, nazwy z rejestru, kod EPPO.
- Stado / Zwierze, zdarzenia, współczynniki DJP.
- RegulaPrawna i Termin (progi, daty — jako dane z numerem wersji).
- Historia zmian wpisu (wpisy są dopisywane, starsze wersje zostają) — potrzebna też do synchronizacji.

## 8. Wersja darmowa i premium

Zasada: darmowa wystarcza do spełnienia obowiązków; premium oszczędza czas. Wpisy, wydruki
i eksport wymagany przepisami są zawsze darmowe. Podczas wpisu zabiegu żadnych okien z ofertą.

| Funkcja | Darmowa | Premium |
| --- | --- | --- |
| Pola i mapa | Dodawanie działek po numerze, bez limitu | Import z PDF wniosku |
| Wpis zabiegu | Pełny, lista dopuszczonych środków, szukanie po nazwie | Zdjęcie etykiety i opakowania; zabieg na wielu polach naraz |
| Karencja | Wpis ręczny | Automatycznie z bazy etykiet, z przypomnieniem |
| Dokumenty | Trzy rejestry: podgląd, wydruk, eksport | Zestawienie do wniosku, komplet na kontrolę jednym przyciskiem |
| Terminy | Kalendarz obowiązków | Ostrzeżenia przed błędem (azot, zmianowanie, okrywa) |
| Nawożenie | Ewidencja i limit 170 kg N/ha | Plan nawożenia azotem |
| Urządzenia | Telefon, kopia do pliku | Program na Windows, synchronizacja, automatyczna kopia |
| Zwierzęta | *(poza zakresem — ścieżka rozwoju)* | *(poza zakresem — ścieżka rozwoju)* |
| Dodatki | Jedno gospodarstwo | Kilka gospodarstw, magazyn, koszty i przychody |

Trzy pozycje z tabeli zostały 17.10.2026 **świadomie zostawione darmowe** przy
porządkowaniu dostępu (raport: `docs/raporty/premium-w-calej-aplikacji.md`) — do
decyzji właściciela: karencja z bazy etykiet (informacja o bezpieczeństwie
żywności), ostrzeżenia przed błędem (chronią przed karą, nie oszczędzają czasu)
i wczytanie kopii z pliku (bez niego rolnik nie odzyska dokumentacji po zmianie
telefonu). Reszta tabeli jest już pilnowana w kodzie.

Ceny (do potwierdzenia w rozmowach z rolnikami): cały 2027 r. premium za darmo dla wszystkich;
potem 49 zł jednorazowo dla użytkowników z pierwszego sezonu i 99 zł dla nowych. Aktualizacje
danych w cenie przez 2 lata od zakupu, potem dobrowolna wpłata co 2 lata (min. 20 zł; w sklepie
jako przyciski 20/30/50 zł). Bez wpłaty nic nie przestaje działać. Informacja o wycofaniu środka
trafia do wszystkich za darmo. Kod powinien mieć od początku jedno miejsce decydujące o dostępie
do funkcji premium.

## 9. Prace przygotowawcze dla Claude Code

Wykonywać po kolei; po każdym zadaniu krótki raport z wynikami i liczbami.

- **P0. Repozytorium.** Założyć projekt (Flutter, cele Android i Windows), strukturę katalogów,
  `tools/` na skrypty danych, `.gitignore` wykluczający dane osobowe i pobrane pliki, plik CLAUDE.md
  z zasadami z tego planu. Potwierdzić wybór technologii albo zaproponować inny z uzasadnieniem.
- **P1. Import pliku zastosowań.** Skrypt: XLSX → SQLite. Rozbicie list upraw na pojedyncze uprawy,
  wyciągnięcie dawki maksymalnej i jednostki, filtr po terminie stosowania. Raport: ile wierszy
  nie dało się odczytać i dlaczego.
- **P2. Próba bazy etykiet na podstronie A–B.** Zebrać spis „środek → najnowsza etykieta", pobrać
  pliki powoli (przerwy między żądaniami, pamięć podręczna, bez ponownego pobierania), odczytać
  karencję, okres prewencji i liczbę zabiegów. Raport: odsetek etykiet odczytanych, typowe
  odstępstwa, skany bez tekstu. Środków nieodczytanych nie zgadywać — oznaczać.
  Przed pobieraniem całości sprawdzić regulamin gov.pl.
- **P3. Słownik upraw.** Zestawić nazwy upraw z wniosku z nazwami z rejestru i kodami EPPO;
  zacząć od upraw rolniczych. Lista niepewnych dopasowań do ręcznej decyzji.
- **P4. Czytnik wniosku PDF.** Parser tabel X i XI z testami na zanonimizowanym wzorcu; kontrola
  sumy powierzchni z podsumowaniem wniosku.
- **P5. Prototyp ULDK.** Pobranie granic po identyfikatorze, zapis lokalny, wyświetlenie na mapie offline.
- **P6. Model danych.** Schemat SQLite z migracjami według punktu 7.
- **P7. Pierwszy ekran.** Ścieżka wpisu oprysku według punktu 5 na danych z P1.

## 10. Otwarte sprawy (poza kodem)

- Inspekcja ochrony roślin (WIORiN): czy eksport z własnego programu wystarczy przy kontroli, czy
  państwowa aplikacja przyjmie dane z innych programów, termin przenoszenia notatek dla zabiegów z 2027 r.
- Regulamin gov.pl a automatyczne pobieranie etykiet; pytanie do ministerstwa o dane zbiorcze.
- **Format „do odczytu maszynowego"** z rozp. UE 2023/564 nie został ogłoszony.
  Decyzja z 16.10.2026: dodajemy go po 1.01.2027, gdy będzie znany. Do tego czasu
  aplikacja zbiera wszystkie wymagane pola (razem z kodem EPPO uprawy) i eksportuje
  CSV/XLSX, więc dojdzie sam zapis, a nie zbieranie danych od nowa.
- Regulamin aplikacji, polityka prywatności, zastrzeżenie o braku gwarancji zgodności — do pokazania prawnikowi.
- Prowizja sklepu Google, VAT, rozliczenie przychodu.
- Próba makiety z 3–5 rolnikami 60+; pytanie o gotowość do zapłaty.
- Coroczny przegląd progów i terminów przez doradcę rolniczego przed naborem wniosków.

## 11. Czego nie robić

- Nie wpisywać progów, dat i stawek na stałe w kodzie.
- Nie umieszczać w repozytorium wniosków ani innych danych osobowych.
- Nie pobierać stron ministerstwa z telefonu użytkownika; dane przygotowuje skrypt na komputerze.
- Nie blokować dokumentacji użytkownika za brak płatności.
- Nie zgadywać karencji ani dawek, gdy odczyt jest niepewny.

## 12. Do zrobienia — zgłoszenia z testów (19.10.2026)

Kolejność do ustalenia; żadne nie zmienia decyzji z pkt 2 ani reguł z pkt 11.

1. **Numery działek przy polach.** Po wczytaniu wniosku każde pole ma w bazie
   swoje działki ewidencyjne (`dzialka_rolna_czesc`), ale lista pól na telefonie
   i tabela na komputerze pokazują tylko nazwę, uprawę i powierzchnię. Numery
   działek mają stać przy polu — na liście, w karcie pola i przy wyborze pola
   do zabiegu.
2. **Nowe pole = wybór działki z listy.** Przy ręcznym tworzeniu pola (telefon
   i komputer) wymagany wybór numeru działki ewidencyjnej z listy działek
   gospodarstwa, z wyszukiwaniem po numerze. Pole bez działki tylko wtedy, gdy
   gospodarstwo nie ma jeszcze żadnej działki — wtedy wyraźna podpowiedź, żeby
   najpierw dodać działkę (ULDK albo wniosek).
3. **Prace polowe z datą wstecz.** Przy siewie, zbiorze, uprawie gleby i innych
   pracach na telefonie: wybór rodzaju pracy z listy (jak dziś przy „Inny") oraz
   data z kalendarza wstecz od dnia bieżącego (bez dat z przyszłości) — rolnik
   wpisuje prace po fakcie. Na komputerze data z kalendarza już jest (okno
   „Dodaj zabieg").
4. **Notatki rolnika ze zdjęciem i przypomnieniem.** Osobny moduł
   (`lib/funkcje/notatki/`): notatka z datą zapisu, treścią i opcjonalnym
   zdjęciem (plik w katalogu danych aplikacji, w bazie tylko ścieżka — kopia
   danych musi go objąć), z możliwością ustawienia przypomnienia
   jednorazowego albo cyklicznego (co tydzień, co miesiąc, co rok) przez
   istniejącą `UslugaPrzypomnien`. Notatki są dopisywane jak wpisy
   (`historia_zmian`), eksport razem z kopią. Na komputerze podgląd i edycja
   tekstu; zdjęcie robi telefon. Nigdy za opłatą.
