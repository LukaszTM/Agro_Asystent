# ADR-0001. Flutter + SQLite jako podstawa aplikacji

- Stan: **przyjęte** (12 października 2026 r., zadanie P0)
- Dotyczy: plan, pkt 2 („Technologia — propozycja; do potwierdzenia na starcie")

## Czego potrzebujemy

1. Jeden kod na Android (pierwszy) i Windows; wersja Apple dopiero po testach.
2. Praca bez internetu w każdej funkcji; telefon i PC mają pełne, niezależne kopie danych.
3. Lokalna baza wytrzymująca słownik środków (ok. 18 800 zastosowań, 2 990 środków)
   i rosnącą ewidencję zabiegów.
4. Mapa z granicami działek działająca offline.
5. Wydruk PDF i eksport CSV/XLSX z konfigurowalnym układem kolumn.
6. Odczyt zdjęć etykiet i opakowań (premium, etap 1 pkt 7).
7. Dwa wyglądy telefonu na wspólnej logice; osobny wygląd na Windows.
8. Budżet zero, jeden deweloper, sklep Google Play.

## Decyzja

Potwierdzamy propozycję z planu:

- **Flutter 3.47.7 / Dart 3.13.5** — jeden kod, cele `android` i `windows`.
- **SQLite** — `sqflite` na Androidzie, `sqflite_common_ffi` na Windows i w testach
  na komputerze (ta sama droga dla obu: zapytania SQL, własne migracje).
- **Python 3.13** w `tools/` do przygotowania danych poza aplikacją.

Zależności dodane w P0: `sqflite`, `path`, `path_provider`, `intl`,
`flutter_localizations`; do testów `sqflite_common_ffi`, `flutter_lints`.
Wszystkie darmowe, na licencji BSD/MIT lub Apache 2.0.

## Dlaczego nie inaczej

| Wariant | Dlaczego odrzucony |
| --- | --- |
| **.NET MAUI** | Android i Windows z jednego kodu — realna alternatywa, ale słabsze darmowe biblioteki do mapy offline i wydruków; jeden deweloper nadrabiałby to ręcznie. |
| **React Native** | Windows jako osobny, mniej dopieszczony projekt; dwa łańcuchy narzędzi zamiast jednego. |
| **Kotlin Multiplatform + Compose** | Android bez zarzutu, ale Windows wymaga dystrybucji z maszyną JVM — gorsza instalacja dla rolnika i więcej pracy przy wydaniu. |
| **Aplikacja internetowa (PWA)** | Odpada praca offline z plikami i aparatem w takim zakresie, jak tu potrzebny, oraz płatności w Google Play. |
| **Osobno Kotlin (Android) i WinUI (Windows)** | Dwa razy tyle kodu reguł prawnych i dokumentów przy jednym deweloperze. |

## Następstwa

- Logika (baza, reguły, dokumenty) jest wspólna; wygląd to osobna warstwa
  (`lib/wyglad/`). Test `test/architektura_test.dart` pilnuje, że logika nie
  importuje wyglądu.
- Progi i terminy wchodzą do `assets/dane/reguly_prawne.json` z numerem wersji;
  aktualizacja danych nie wymaga nowego wydania aplikacji.
- Migracje bazy piszemy ręcznie w SQL (bez generatora kodu) — mniej magii,
  łatwiejsza synchronizacja dopisywanych wpisów.
- Instalator Windows i podpis aplikacji to osobne zadanie przed wydaniem na PC.

## Sprawy do rozstrzygnięcia w kolejnych zadaniach

- **Mapa offline**: `flutter_map` z plikami kafelków na urządzeniu wygląda
  najprościej, ale warunki pobierania ortofotomapy z Geoportalu do pracy offline
  trzeba sprawdzić (plan, pkt 6.1). Decyzja w zadaniu P5.
- **Odczyt zdjęć**: na Androidzie rozpoznawanie tekstu na urządzeniu (ML Kit)
  jest darmowe i działa bez internetu; na Windows trzeba będzie innego silnika
  albo funkcja zostanie tylko na telefonie. Decyzja przy etapie 1 pkt 7.
- **Krój Atkinson Hyperlegible** (licencja OFL, darmowy) dołączymy jako plik
  czcionki przy pierwszym ekranie produkcyjnym.
- **Synchronizacja** przez dysk użytkownika wymaga dopisywanego dziennika zmian
  i rozstrzygania konfliktów bez serwera — projekt w zadaniu P6.
