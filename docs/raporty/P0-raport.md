# Raport P0 — repozytorium

12 października 2026 r. Zadanie: „P0. Repozytorium" z planu (pkt 9).

## Co zrobiono

| Element | Stan |
| --- | --- |
| Projekt Flutter, cele `android` i `windows` | Flutter 3.47.7, Dart 3.13.5, nazwa pakietu `pl.agroasystent.agro_asystent` |
| Struktura katalogów | `lib/rdzen`, `lib/funkcje` (7 modułów), `lib/wyglad/{prosty,nowoczesny}`, `assets/dane`, `tools`, `docs`, `dane` |
| `tools/` na skrypty danych | README z układem zadań P1–P5 i `requirements.txt` (Python 3.13) |
| `.gitignore` | 76 wierszy: wnioski PDF i dane osobowe, pliki pobrane, bazy wynikowe, wytwory Fluttera, Pythona i narzędzi |
| `CLAUDE.md` | zasady z planu: 5 twardych reguł „czego nie robić", reguły architektury, interfejsu i nazewnictwa |
| Potwierdzenie technologii | `docs/decyzje/ADR-0001-technologia.md` — Flutter + SQLite przyjęte, 5 wariantów odrzuconych z uzasadnieniem |

Dodatkowo, bo plan wymaga tego „od początku":

- **Jedno miejsce decydujące o premium** (`lib/rdzen/dostep/`) — 24 funkcje
  podzielone według tabeli z planu (pkt 8); 9 z nich oznaczono jako wymagane
  przepisami, czyli darmowe zawsze i bezwarunkowo.
- **Progi i terminy jako dane** (`assets/dane/reguly_prawne.json`, wersja
  `2026.10.12`) — 7 obowiązków, 4 terminy, 2 parametry warunkowości, każdy
  z podstawą prawną i statusem weryfikacji. Do tego czytnik słownika
  (`lib/rdzen/reguly/`), który na nieznanej mierze zwraca „nie wiadomo",
  a nie domysł.
- **Ekran główny wyglądu „Prosty"** — cztery duże przyciski, kolory i rozmiary
  wyłącznie z `lib/wyglad/prosty/motyw.dart`. Za przyciskami ekran mówiący
  wprost, co powstanie w kolejnych krokach.

## Liczby

- Kod aplikacji: 9 plików Dart, 836 wierszy.
- Testy: 4 pliki, 391 wierszy, **26 testów — wszystkie przechodzą**.
- `flutter analyze`: **0 ostrzeżeń** (reguły zaostrzone wobec `flutter_lints`).
- `dart format`: kod sformatowany, sprawdzane w CI.
- 17 plików README opisujących przeznaczenie katalogów.
- Zależności: 5 produkcyjnych (`sqflite`, `path`, `path_provider`, `intl`,
  `flutter_localizations`), 2 do testów. Wszystkie darmowe, licencje BSD/MIT/Apache 2.0.

## Testy pilnujące zasad z planu

`test/architektura_test.dart` sprawdza mechanicznie to, czego analizator nie widzi:

1. `lib/rdzen` i `lib/funkcje` nie importują niczego z `lib/wyglad` — logika nie
   może zależeć od wyglądu.
2. Wyglądy „prosty" i „nowoczesny" nie importują się wzajemnie.
3. Poza `lib/rdzen/dostep/` żaden plik nie pyta o samo posiadanie premium.
4. W kodzie Dart nie ma liczb z przepisów (170, 100, 60, 10 jako progi).

`test/wyglad/ekran_glowny_test.dart` pilnuje reguł interfejsu: cztery przyciski,
brak ukrytego menu, cele dotyku od 48 px, żaden napis mniejszy niż 18 px.

`test/rdzen/dostep/dostep_funkcji_test.dart` pilnuje obietnicy z planu: każda
funkcja wymagana przepisami działa w wersji darmowej, a nowa pozycja w liście
funkcji musi zostać świadomie przypisana do wersji darmowej albo premium.

## Czego nie udało się sprawdzić w tym środowisku

- **Budowa pliku APK** — brak Android SDK w kontenerze. Kod przechodzi analizę
  i testy; pierwsze `flutter build apk` trzeba wykonać na komputerze z Android
  Studio.
- **Budowa programu na Windows** — wymaga Visual Studio; katalog `windows/`
  jest przygotowany, ale nieprzetestowany.
- Oba sprawdzenia warto wykonać przed zadaniem P7.

## Sprawy otwarte po P0

1. Mapa offline: warunki pobierania ortofotomapy z Geoportalu (decyzja w P5).
2. Odczyt zdjęć na Windows — na Androidzie rozpoznawanie tekstu na urządzeniu
   jest darmowe, na PC trzeba będzie innego rozwiązania albo funkcji tylko
   na telefonie.
3. Regulamin gov.pl a automatyczne pobieranie etykiet — sprawdzić **przed** P2.
4. Terminy nawożenia ze strony ARiMR z 2019 r. — do potwierdzenia w aktualnym
   rozporządzeniu; w słowniku reguł będą oznaczone jako „do weryfikacji".

## Następny krok

**P1. Import pliku zastosowań**: skrypt XLSX → SQLite, rozbicie list upraw
na pojedyncze uprawy, wyciągnięcie dawki maksymalnej z jednostką, filtr po
terminie do stosowania. Raport ma podać, ile wierszy nie dało się odczytać i dlaczego.
