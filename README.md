<img src="assets/logo/moj_lan.png" alt="Mój Łan" width="120" align="right" />

# Mój Łan

Aplikacja na telefon (Android) i komputer (Windows) prowadząca dokumentację gospodarstwa
wymaganą przez ARiMR i inspekcje. Rdzeniem jest jeden rejestr zabiegów przypisanych
do działek — z jednego wpisu powstają wszystkie wymagane dokumenty. Aplikacja działa
bez internetu; synchronizacja z komputerem tylko wtedy, gdy rolnik tego chce.

Pełny plan: [`docs/PLAN.md`](docs/PLAN.md). Zasady pracy w kodzie: [`CLAUDE.md`](CLAUDE.md).
Identyfikacja wizualna: [`docs/identyfikacja-wizualna.md`](docs/identyfikacja-wizualna.md).

> Zestawienie przepisów w tym repozytorium służy do zaplanowania aplikacji
> i nie jest poradą prawną.

## Stan prac

| Etap | Stan |
| --- | --- |
| Etap 1. Dokumentacja gospodarstwa na Androidzie (10 kroków) | **zamknięty 16.10.2026** — [podsumowanie](docs/raporty/etap1-podsumowanie.md) |
| Etap 2. Warunkowość i magazyn (7 kroków) | **zamknięty 17.10.2026** — [podsumowanie](docs/raporty/etap2-podsumowanie.md) |
| Etap 3. Program na komputer: pulpit, pola, pogoda, rynek (7 kroków) | **gotowe 18.10.2026**, poza notowaniami cen skupu — [raport](docs/raporty/etap3-pulpit-i-dane-z-sieci.md) |
| Zgłoszenia z testów z 19.10.2026 | **do zrobienia** — [plan, pkt 12](docs/PLAN.md) |

Aplikacja działa na Androidzie i na Windows, w całości bez internetu. Co już robi:

- **Pola i działki**: import z PDF wniosku z eWniosekPlus, granice z ULDK, mapa offline.
- **Rejestr zabiegów**: **wpis oprysku w pięciu dotknięciach**, bez klawiatury, na danych
  z rejestru środków ochrony roślin (2 967 środków, 18 632 zastosowania), z karencją
  z etykiet i ostrzeżeniem o dawce.
- **Nawożenie**: ewidencja, limit azotu, terminy stosowania dla konkretnego pola.
- **Warunkowość**: cztery z dziewięciu norm GAEC (4, 6, 7 i 8) z wydrukiem na kontrolę.
- **Dokumenty**: trzy rejestry do podglądu, wydruku PDF i eksportu CSV/XLSX.
- **Terminy i przypomnienia**, **magazyn** środków i nawozów, **kopia danych** do pliku.
- **Program na komputer**: pulpit z zasiewami i mapką pól, pogoda, kalendarz
  biodynamiczny, wiadomości rolnicze.

Zadania przygotowawcze, od których zaczął się projekt:

| Zadanie | Stan |
| --- | --- |
| P0. Repozytorium, struktura, zasady, wybór technologii | **gotowe** — [raport](docs/raporty/P0-raport.md) |
| P1. Import pliku zastosowań środków (XLSX → SQLite) | **gotowe** — [raport](docs/raporty/P1-raport.md) |
| P2. Próba bazy etykiet (karencja) | **gotowe** — [raport](docs/raporty/P2-raport.md) |
| P3. Słownik upraw (wniosek ↔ rejestr ↔ EPPO) | **gotowe** — [raport](docs/raporty/P3-raport.md): kody EPPO wymagają decyzji doradcy |
| P4. Czytnik wniosku PDF z eWniosekPlus | **gotowe** — [raport](docs/raporty/P4-raport.md): sprawdzone na prawdziwym wniosku |
| P5. Prototyp ULDK (granice działek, mapa offline) | **gotowe** — [raport](docs/raporty/P5-raport.md): 20 z 20 działek pobranych |
| P6. Model danych SQLite z migracjami | **gotowe** — [raport](docs/raporty/P6-raport.md) |
| P7. Pierwszy ekran: ścieżka wpisu oprysku | **gotowe** — [raport](docs/raporty/P7-raport.md) |

## Technologia

Flutter 3.47.7 / Dart 3.13.5, lokalna baza SQLite, skrypty danych w Pythonie 3.13.
Uzasadnienie i odrzucone warianty: [`docs/decyzje/ADR-0001-technologia.md`](docs/decyzje/ADR-0001-technologia.md).

## Uruchomienie

```bash
flutter pub get
flutter test                 # testy jednostkowe i widgetów
flutter analyze              # musi być bez ostrzeżeń
flutter run -d android       # telefon lub emulator
flutter run -d windows       # program na PC (wymaga Visual Studio)
```

Skrypty przygotowania danych (uruchamiane na komputerze, nie na telefonie):

```bash
python3 -m venv .venv && . .venv/bin/activate
pip install -r tools/requirements.txt
```

## Układ repozytorium

```
lib/rdzen/      baza, modele, reguły prawne, dostęp do premium, usługi
lib/funkcje/    moduły dziedzinowe (dane i logika, bez ekranów)
lib/wyglad/     dwa wyglądy telefonu: prosty i nowoczesny
assets/dane/    progi, terminy i stawki jako dane z numerem wersji
tools/          skrypty przygotowania danych (Python)
docs/           plan, decyzje techniczne, raporty z zadań
dane/           katalog roboczy skryptów — poza repozytorium
```

## Czego w tym repozytorium nie ma i nie będzie

Wniosków z eWniosekPlus ani żadnych danych osobowych rolnika — do testów służą
zanonimizowane wzorce w `test/dane/`. Progi, daty i stawki z przepisów nie są
wpisane w kod; są danymi w `assets/dane/`.
