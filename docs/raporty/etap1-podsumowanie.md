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

## Liczby

| Miara | Wartość |
| --- | --- |
| Pliki kodu w `lib/` | 108 |
| Pliki testów | 37 |
| Testy | **360** |
| `flutter analyze` | bez ostrzeżeń |
| `dart format` | bez zmian |
| Migracje bazy | 4 |
| Wersja słownika reguł | 2026.10.16.4 |
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

1. ~~**Dane prawne**~~ — zrobione 16.10.2026 poza **tabelą 14** (maksymalne
   ilości azotu działającego, załącznik nr 9): wymaga własnego ekranu
   i ostrzeżenia, nie tylko wpisu w słowniku.
2. ~~**Kody EPPO bez decyzji**~~ — uzupełnione 16.10.2026 dla upraw
   konwencjonalnych w Polsce: 347 upraw z kodem, **83,3%** zastosowań
   z rejestru (było 44,7%). Przy 23 nazwach rodzajowych („łubin",
   „gorczyca", „dynia"…) rejestr nie podaje gatunku, więc **aplikacja pyta
   rolnika** i pokazuje gatunki do wyboru; gdy uprawy nie ma na liście,
   rolnik wpisuje własną nazwę i kod zostaje pusty.
   Raport `kody-eppo-uprawy-polskie.md`.
3. **Rejestr stada do wydruku** — wymaga urzędowego układu kolumn IRZplus;
   dotyczy ścieżki rozwoju (produkcja zwierzęca poza zakresem, ADR-0007).
4. **Pytanie do ministerstwa** o hurtowy dostęp do etykiet (P2) bez odpowiedzi.
5. **Format „maszynowo odczytywalny"** wymagany od 1.01.2027 — nieogłoszony.
   Decyzja z 16.10.2026: dodamy go po 1.01.2027, gdy będzie znany; do tego
   czasu eksport CSV/XLSX i kody EPPO w ewidencji przygotowują na niego grunt.
6. ~~**Wygląd „Nowoczesny"**~~ — zrobiony 16.10.2026 razem z przełącznikiem
   w obu wyglądach. Zostają w nim cztery ekrany formularzowe, które ma tylko
   wygląd prosty (działki z ULDK, import wniosku z PDF, nawozy i zestawienie
   azotu, dane gospodarstwa) — do wyjęcia do `lib/rdzen/wspolne/`, nie do
   przepisania drugi raz; szczegóły w `etap1-wyglad-nowoczesny.md`.

Dalej według planu: program na Windows i synchronizacja, potem etap 2
(kontrola warunkowości, magazyn) i etap 3 (API IRZplus, koszty
i przychody, iPhone).
