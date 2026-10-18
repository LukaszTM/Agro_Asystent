# CLAUDE.md — zasady pracy nad Agro Asystentem

Aplikacja mobilna (Android, potem Windows) prowadząca dokumentację gospodarstwa wymaganą
przez ARiMR i inspekcje. Pełny plan: `docs/PLAN.md` — ten plik jest jego skrótem
operacyjnym dla pracy w kodzie. **Przy rozbieżności obowiązuje `docs/PLAN.md`.**

## Technologia (potwierdzona w P0)

- Flutter 3.47.7 / Dart 3.13.5, jeden kod na Android i Windows.
- Lokalna baza SQLite (`sqflite` na Androidzie, `sqflite_common_ffi` na Windows).
- Skrypty przygotowania danych: Python 3.13 w `tools/` — uruchamiane **na komputerze
  dewelopera**, nigdy z telefonu użytkownika.
- Uzasadnienie i odrzucone warianty: `docs/decyzje/ADR-0001-technologia.md`.
- Każda nowa zależność musi być darmowa i mieć licencję pozwalającą na użycie komercyjne
  (budżet = 0). Przed dodaniem paczki sprawdź licencję i wpisz ją do ADR, jeśli jest istotna.

## Czego nie robić (plan, pkt 11) — twarde reguły

1. **Żadnych progów, dat, stawek i limitów na stałe w kodzie.** 10 ha, 100 ha, 170 kg N/ha,
   15.10, 15.04–31.07, 7 dni na zgłoszenie cielęcia, ceny premium — to **dane** w słowniku
   z numerem wersji (`assets/dane/reguly_prawne.json` + tabele w SQLite), nie stałe w Dart.
   Jeśli piszesz liczbę z przepisu w kodzie Dart, robisz to źle.
2. **Żadnych danych osobowych w repozytorium.** Wnioski z eWniosekPlus, numery działek
   realnych gospodarstw, nazwiska — nigdy. Do testów służą zanonimizowane wzorce
   w `test/dane/`. `.gitignore` to blokuje, ale sprawdzaj przed `git add`.
3. **Nie pobieramy stron ministerstwa z urządzenia użytkownika.** Dane przygotowuje skrypt
   z `tools/`, wynik trafia do aplikacji jako gotowy plik (asset lub paczka aktualizacji).
4. **Nie blokujemy dokumentacji użytkownika za brak płatności.** Wpisy, trzy rejestry,
   wydruk PDF i eksport CSV/XLSX są zawsze darmowe i działają bez żadnej opłaty.
5. **Nie zgadujemy karencji ani dawek.** Gdy odczyt jest niepewny — pole zostaje puste,
   oznaczone jako „do potwierdzenia", a rolnik potwierdza ręcznie. Nigdy nie wstawiamy
   wartości „przybliżonej".

## Reguły architektury

- **Offline-first.** Każda funkcja musi działać bez internetu. Sieć jest wyłącznie
  opcjonalnym dodatkiem (ULDK, synchronizacja przez dysk użytkownika). Brak własnego serwera.
- **Logika nie zależy od wyglądu.** Baza, reguły prawne, dokumenty i eksport są wspólne
  (`lib/rdzen/`, `lib/funkcje/`). Trzy warstwy ekranów — dwa wyglądy telefonu („Prosty",
  „Nowoczesny") i program na komputer — leżą w `lib/wyglad/prosty/`,
  `lib/wyglad/nowoczesny/` i `lib/wyglad/komputer/`. Żadna z nich nie importuje innej;
  wspólne widgety idą do `lib/rdzen/wspolne/`.
  Kod w `lib/rdzen/` i `lib/funkcje/` **nie może importować niczego z `lib/wyglad/`**.
- **Jedno miejsce decydujące o premium**: `lib/rdzen/dostep/`. Nigdzie w kodzie nie ma
  warunku „czy użytkownik kupił" poza tym katalogiem.
- **Wpisy są dopisywane, nie nadpisywane** (`historia_zmian`): starsze wersje zostają —
  wymaga tego kontrola, cofanie zmian i synchronizacja.
- **Reguły prawne jako dane z wersją.** Silnik w `lib/rdzen/reguly/` czyta słownik
  i sam włącza obowiązki na podstawie powierzchni, upraw i liczby DJP.

## Reguły interfejsu (użytkownicy 60+)

Miara powodzenia: **wpis zabiegu w najwyżej pięciu dotknięciach, bez klawiatury.**

- Tekst min. 18 px (wygląd Prosty), cele dotyku min. 48 px, wysoki kontrast.
- Wybór z listy zamiast pisania; liczby przyciskami „+" i „−" albo dużą klawiaturą numeryczną.
- Język rolnika („oprysk"); nazwy urzędowe („zabieg środkiem ochrony roślin") tylko na wydrukach.
- Ostrzeżenie = jedno zdanie + co zrobić. Każdy wpis da się cofnąć i poprawić.
- Data, godzina, powierzchnia i faza wzrostu uzupełniają się same.
- Podczas wpisu zabiegu **żadnych okien z ofertą premium**.
- Kolory i kroje pisma: wyłącznie z `lib/wyglad/*/motyw.dart`. Nie wpisuj kodów kolorów
  w ekranach.
- **Identyfikacja wizualna**: logo i kolory marki tylko z `lib/rdzen/marka/marka.dart`,
  pliki wariantów wytwarza `tools/zbuduj_ikony.py` z jednego źródła
  (`assets/logo/agro_asystent.png`). Nie rysuj wariantów logo ręcznie i nie myl
  kolorów marki z kolorami ekranów — zasady w `docs/identyfikacja-wizualna.md`.

## Nazewnictwo

Pojęcia dziedzinowe po polsku, zgodnie z planem i przepisami (`DzialkaEwidencyjna`,
`DzialkaRolna`, `Zabieg`, `SrodekOchrony`, `Karencja`, `Nawoz`, `SlownikUpraw`, `Termin`).
Bez polskich znaków w identyfikatorach i nazwach plików (`dzialka_rolna.dart`).
Techniczne nazwy (klasy pomocnicze, repozytoria, testy) mogą być angielskie.
Komentarze, komunikaty i dokumentacja — po polsku.
Opis prac, raporty i rozmowa z użytkownikiem — zawsze po polsku.

## Struktura katalogów

```
lib/
  main.dart            punkt wejścia
  app/                 start aplikacji, trasy, wstrzykiwanie zależności
  rdzen/
    baza/              SQLite: schemat, migracje, dostęp
    modele/            encje domenowe (plan, pkt 7)
    reguly/            silnik reguł prawnych (progi i terminy jako dane)
    dostep/            jedyne miejsce decydujące o premium
    uslugi/            eksport CSV/XLSX, PDF, klient ULDK, pliki, kopia zapasowa
    wspolne/           formatowanie liczb i dat, wspólne widgety niezależne od wyglądu
  funkcje/             dane + logika modułów (bez ekranów)
    dzialki/ zabiegi/ dokumenty/ terminy/ nawozenie/ zwierzeta/ ustawienia/
  wyglad/
    prosty/            wygląd telefonu dla osób starszych (pierwszy w etapie 1)
    nowoczesny/        wygląd telefonu dla osób obytych ze smartfonem
    komputer/          program na Windows: jeden wygląd, wielkość tekstu z ustawień
test/
  dane/                zanonimizowane wzorce do testów
tools/                 skrypty Python przygotowujące dane (P1–P5)
dane/                  katalog roboczy skryptów — cały w .gitignore
docs/
  PLAN.md              plan projektu (źródło prawdy)
  decyzje/             ADR — decyzje techniczne
  raporty/             raporty z zadań przygotowawczych P0–P7
```

## Polecenia

```bash
flutter pub get
flutter analyze                 # musi być czysto przed commitem
dart format --set-exit-if-changed lib test
flutter test
flutter run -d android          # telefon / emulator
flutter run -d windows          # program na PC
```

Skrypty danych:

```bash
python3 -m venv .venv && . .venv/bin/activate && pip install -r tools/requirements.txt
python3 tools/<zadanie>/<skrypt>.py --help
```

## Praca krok po kroku

- Zadania przygotowawcze P0–P7 wykonujemy po kolei (plan, pkt 9). Po każdym — krótki raport
  z liczbami w `docs/raporty/`.
- Każdy krok etapu 1 ma dawać **działającą aplikację** (plan, pkt 4).
- `flutter analyze` bez ostrzeżeń i `flutter test` na zielono przed każdym commitem.
- Commity po polsku, w trybie rozkazującym: „Dodaj czytnik tabel wniosku".
- Gałąź roboczą i zasady wysyłania zmian podaje zadanie; nie wysyłaj na `main`.

## Założenia niepotwierdzone (nie opierać na nich projektu)

- Czy eksport z aplikacji wystarczy przy kontroli WIORiN i czy państwowa aplikacja PIORiN
  przyjmie dane z innych programów.
- Regulamin gov.pl a automatyczne pobieranie etykiet (sprawdzić przed P2 w całości).
- Terminy nawożenia z planu pochodzą ze strony ARiMR z 2019 r. — do sprawdzenia
  w aktualnym rozporządzeniu. Oznaczaj je w danych jako „do weryfikacji".
