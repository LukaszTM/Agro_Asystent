# Etap 1 zamknięty — podsumowanie

16 października 2026 r.

Aplikacja prowadzi dokumentację gospodarstwa w całości offline, na jednym
telefonie, bez serwera i bez żadnej opłaty za to, czego wymagają przepisy.

## Dziesięć kroków z planu (pkt 4)

| Krok | Raport |
| --- | --- |
| 1. Działki i mapa | `etap1-krok1-dzialki-i-mapa.md` |
| 2. Import działek i upraw z PDF wniosku | `etap1-krok2-import-wniosku.md` |
| 3. Rejestr zabiegów z ewidencją oprysków | `etap1-krok3-rejestr-zabiegow.md` |
| 4. Dokumenty: podgląd, PDF, CSV/XLSX | `etap1-krok4-dokumenty.md` |
| 5. Terminy i przypomnienia | `etap1-krok5-terminy.md` |
| 6. Nawożenie: ewidencja, limit N, plan | `etap1-krok6-nawozenie.md` |
| 7. Odczyt zdjęć: etykieta, worek nawozu | `etap1-krok7-odczyt-zdjec.md` |
| 8. Karencja z bazy etykiet | `etap1-krok8-karencja.md` |
| 9. Zwierzęta: stado, terminy, DJP | `etap1-krok9-zwierzeta.md` |
| 10. Konta i kilka gospodarstw | `etap1-krok10-konta-i-gospodarstwa.md` |

## Domknięte po dziesiątym kroku

| Co | Dlaczego | Raport |
| --- | --- | --- |
| **Trzy rejestry** do podglądu, wydruku i eksportu | plan (pkt 8) obiecuje trzy, aplikacja drukowała dwa — i to ewidencję nawożenia pod inną podstawą prawną | `etap1-trzy-rejestry.md` |
| **Kopia danych do pliku** + usuwanie gospodarstwa | plan (pkt 8) obiecuje ją w wersji darmowej; bez niej zgubiony telefon = utrata dokumentacji | `etap1-kopia-danych.md` |
| **Współczynniki DJP** z obowiązującego rozporządzenia | dane z kroku 9 pochodziły z uchylonego aktu i trzy wartości były błędne | `djp-weryfikacja.md` |
| **Okresy nawożenia azotem** + wykazy gmin | terminów nie było w danych; dziś są sprawdzone w tabeli 2 rozporządzenia, z dokładną datą dla konkretnego pola | `terminy-nawozenia-azotem.md` |
| **Dane prawne z dwóch ustaw i dwóch załączników** (luka 1) | zakazy z ustawy o nawozach, próg planu z Prawa wodnego, uprawy intensywne, odległości od wód | `dane-prawne-uzupelnienie.md` |
| **Kody EPPO: tylko potwierdzone wchodzą do słownika** (luka 2) | propozycja nie może trafić na urzędowy wydruk jako pewny kod | dopisek w `P3-raport.md` |
| **Drugi wygląd telefonu „Nowoczesny"** + przełącznik (luka 6) | plan (pkt 5) obiecuje dwa wyglądy przełączane w ustawieniach | `etap1-wyglad-nowoczesny.md` |
| **Kody EPPO upraw konwencjonalnych** (luka 2) | ewidencja SOR wymaga kodu EPPO uprawy; automat z P3 dał 44,7% i miał pięć kodów gatunków dzikich | `kody-eppo-uprawy-polskie.md` |
| **Maksymalne dawki azotu dla 126 upraw** (luka 4) | tabela 14 programu azotanowego — ostrzeżenie pada przed zapisem dawki, a nie po kontroli | `maksymalne-dawki-azotu.md` |
| **Cztery ekrany formularzowe w wyglądzie nowoczesnym** (luka 9) | rolnik musiał przełączać wygląd, żeby dodać działkę, wczytać wniosek, dopisać nawóz albo poprawić dane gospodarstwa | `etap1-nowoczesny-ekrany-formularzowe.md` |
| **Podpis wydawniczy i instrukcja wydania** (luka 2) | wydanie podpisywało się kluczem debugowym: nowszy plik nie wgrywał się na wierzch, a Google Play takiego nie przyjmie | `docs/wydanie-android.md` |
| **Dołączanie danych z drugiego urządzenia** (luka 11, część) | plan (pkt 2) obiecuje synchronizację przez dysk użytkownika; dwa telefony nie dały się pogodzić | `etap1-synchronizacja-przez-plik.md` |

## Liczby

| Miara | Wartość |
| --- | --- |
| Pliki kodu w `lib/` | 114 |
| Pliki testów | 40 |
| Testy | **407** |
| `flutter analyze` | bez ostrzeżeń |
| `dart format` | bez zmian |
| Migracje bazy | 4 |
| Wersja słownika reguł | 2026.10.16.5 |
| Gminy w wykazach terminów | 2158 |
| Grupy DJP | 93 |

## Zasady, które przetrwały cały etap

- **Żadnej liczby z przepisu w kodzie Dart.** Progi, limity, terminy,
  przeliczniki DJP i kolumny rejestrów są danymi ze słownika; pilnuje tego
  test architektury.
- **Niczego nie zgadujemy.** Nieznana karencja, nawóz bez składu, grupa DJP
  bez przypisania, data przyorania, gmina nierozczytana z identyfikatora —
  wszystko to zostaje pustym polem z adnotacją, nie liczbą „na oko".
- **Dokumentacji nie zamykamy za opłatą.** Wpisy, trzy rejestry, wydruk,
  eksport, kalendarz, ewidencja nawożenia, rejestr stada i kopia danych są
  darmowe; premium otwiera tylko oszczędzanie czasu.
- **Wpisy są dopisywane, nie nadpisywane.** Dziennik zmian przetrwał nawet
  wczytanie kopii — z pierwotnymi czasami.
- **Dane prawne mają źródło i status.** Każda wartość wie, z jakiego aktu
  pochodzi i czy została sprawdzona; niesprawdzona mówi o tym na ekranie.

## Luki do uzupełnienia

Stan na 16.10.2026, wieczór. Zamknięte zostawiam przekreślone, żeby było
widać, co już nie wraca.

### Zanim aplikacja trafi na telefon

1. **Aplikacja nie była ani raz uruchomiona na prawdziwym telefonie.**
   Cała weryfikacja to 407 testów i analizator — w kontenerze sesji nie ma
   Android SDK. Pierwsze uruchomienie może pokazać rzeczy, których test nie
   widzi: wielkość tekstu w ręce, zachowanie klawiatury, czas startu,
   uprawnienia do aparatu i powiadomień.
2. ~~**Podpis wydawniczy**~~ — strona kodu gotowa: Gradle bierze klucz
   z `android/key.properties` albo z sekretów repozytorium, a bez klucza
   podpisuje kluczem debugowym i mówi o tym w logu
   (`docs/wydanie-android.md`). **Zostaje do zrobienia przez właściciela:**
   wygenerowanie pliku `.jks` (`keytool`, potrzebny komputer) i dodanie
   czterech sekretów. Klucza nie generuję i nie mam go widzieć — jego
   utrata zamyka drogę do aktualizacji w Google Play.
3. ~~**Przepływ „Zbuduj APK" nie został przetestowany**~~ — trzeci
   przebieg przeszedł: plik `agro-asystent-0.1.0+1.apk` (94 MB) leży
   w wydaniu `apk-test`. Dwie poprawki po drodze: `setup-android`
   instalował nieistniejący pakiet „tools", a R8 przerywał budowanie
   wydania na klasach rozpoznawania pisma, których nie dołączamy
   (reguły w `android/app/proguard-rules.pro` — to była prawdziwa
   usterka wydania, nie usterka CI).

### Prawo i dane

4. ~~**Dane prawne**~~ — zrobione w całości, razem z **tabelą 14**
   (maksymalne ilości azotu działającego dla 126 upraw, załącznik nr 9):
   ostrzeżenie pada przy wpisie dawki, `maksymalne-dawki-azotu.md`.
   Wszystkie pozycje słownika reguł są sprawdzone w aktach — zero wpisów
   `do_weryfikacji`.
5. ~~**Kody EPPO bez decyzji**~~ — 347 upraw z kodem, **83,3%** zastosowań
   z rejestru (było 44,7%). Zostaje ogon: **253 nazwy** do wyboru bez kodu
   (każda poniżej 15 zastosowań, np. „kapusta choy-sum") — rolnik je wybierze,
   ale w ewidencji wyjdzie „brak". 23 nazwy rodzajowe są obsłużone pytaniem
   o gatunek.
6. **Karencja znana dla 84,5% środków** (zadanie P2). Dla reszty rolnik
   przepisuje liczbę z opakowania — aplikacja o to prosi i zapisuje, że to
   jego źródło. Luka jest w danych MRiRW, nie w kodzie.
7. **Pytanie do ministerstwa** o hurtowy dostęp do etykiet (P2) — bez
   odpowiedzi.
8. **Format „maszynowo odczytywalny"** wymagany od 1.01.2027 — nieogłoszony.
   Decyzja: dodajemy po 1.01.2027; eksport CSV/XLSX i kody EPPO już teraz
   zbierają wszystkie wymagane pola.

### Funkcje w aplikacji

9. ~~**Wygląd „Nowoczesny"**~~ — zrobiony razem z przełącznikiem
   i z czterema brakującymi ekranami formularzowymi (działki z ULDK,
   import wniosku, nawozy i zestawienie azotu, dane gospodarstwa):
   `etap1-nowoczesny-ekrany-formularzowe.md`. Wspólna karta terminów
   nawożenia stoi w `lib/rdzen/wspolne/`, nie w dwóch kopiach. Pełnego
   ekranu rejestru stada nowoczesny nadal nie ma — produkcja zwierzęca
   jest ścieżką rozwoju (ADR-0007).
10. **Nie da się kupić premium** — `lib/rdzen/dostep/` rozstrzyga dostęp, ale
    nie ma płatności (brak zależności do Google Play Billing). Wszystko,
    czego wymaga prawo, jest darmowe, więc to nie blokuje rolnika; blokuje
    przychód.
11. **Program na Windows** — katalog `windows/` istnieje z szablonu, ale
    program nie był budowany ani raz (w kontenerze sesji nie ma Windows).
    Synchronizacja przez dysk użytkownika **jest zrobiona**: „Dołącz dane
    z drugiego urządzenia" scala plik kopii z tym, co w telefonie —
    nowszy wpis wygrywa, starszy zostaje w dzienniku zmian
    (`etap1-synchronizacja-przez-plik.md`). Nie ma jeszcze automatycznego
    wykrywania nowszego pliku na dysku — rolnik wskazuje go sam.
12. **Rejestr stada do wydruku** — wymaga urzędowego układu kolumn IRZplus;
    dotyczy ścieżki rozwoju (produkcja zwierzęca poza zakresem, ADR-0007).

### Poza kodem

13. **Próba z rolnikami 60+** (plan, pkt 10) — nikt poza nami nie dotknął
    tych ekranów. To jedyny sposób sprawdzenia miary z planu: wpis zabiegu
    w pięciu dotknięciach.
14. **Regulamin, polityka prywatności, zastrzeżenie o braku gwarancji
    zgodności** — do pokazania prawnikowi przed publikacją.
15. **Konto w Google Play, prowizja, VAT, rozliczenie przychodu** oraz
    coroczny przegląd progów i terminów przez doradcę (plan, pkt 10).

Dalej według planu: program na Windows i synchronizacja, potem etap 2
(kontrola warunkowości, magazyn) i etap 3 (API IRZplus, koszty
i przychody, iPhone).
