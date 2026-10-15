# Raport P7 — pierwszy ekran: ścieżka wpisu oprysku

15 października 2026 r. Zadanie: „P7. Pierwszy ekran" z planu (pkt 9):
ścieżka wpisu oprysku według punktu 5, na danych z zadania P1.

## Miara powodzenia z planu

> Wpis zabiegu w najwyżej pięciu dotknięciach, bez klawiatury.

**Osiągnięta i pilnowana testem.** Pięć dotknięć od ekranu głównego do zapisu:

1. **Dodaj zabieg**
2. **Za stodołą** (pole)
3. **Oprysk** (rodzaj zabiegu)
4. **Abydos 750 EC** (środek)
5. **Zapisz**

Data, godzina, powierzchnia, dawka, przyczyna i kod EPPO uzupełniają się same —
z pola, z rejestru środków i z zegara. Klawiatura nie jest potrzebna ani razu.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/zbuduj_slowniki.py` | składa `slowniki.sqlite` z wyników P1–P3 i pakuje do assetu |
| `lib/rdzen/baza/przygotowanie_slownikow.dart` | rozpakowuje słowniki przy pierwszym uruchomieniu |
| `lib/funkcje/zabiegi/slownik_srodkow.dart` | środki dopuszczone w danej uprawie, dawka, karencja |
| `lib/funkcje/dzialki/repozytorium_pol.dart` | pola gospodarstwa |
| `lib/wyglad/prosty/wpis/` | pięć ekranów ścieżki wpisu |
| `lib/wyglad/prosty/widgety/` | duży przycisk, pasek ostrzeżenia, wybór liczby „+/−" |
| `lib/app/start.dart`, `lib/app/uslugi.dart` | złożenie aplikacji przy starcie |
| `test/wyglad/wpis_zabiegu_test.dart` | 7 testów całej ścieżki |

## Słowniki w aplikacji

Plik `slowniki.sqlite` powstaje ze skryptu i waży **9,6 MB**; w aplikacji jedzie
spakowany — **1,9 MB** — i rozpakowuje się przy pierwszym uruchomieniu.

| | |
| --- | --- |
| Środki (bez wycofanych) | 2 967 |
| Zastosowania | 18 632 |
| Przypisania do upraw | 37 928 |
| Uprawy | 831 (153 z kodem EPPO) |
| Karencje z etykiet | 616 |

Środki po terminie stosowania **nie trafiają do aplikacji** — nie wolno ich
stosować, więc nie ma czym kusić na liście wyboru.

## Czego pilnują testy

| Test | Czego dowodzi |
| --- | --- |
| wpis w pięciu dotknięciach | miara powodzenia z planu |
| karencja i dzień zbioru po zapisie | rolnik od razu wie, kiedy wolno zbierać, i z jakiej etykiety to wiadomo |
| nieznana karencja powiedziana wprost | przy braku danych nie udajemy, że karencja to zero |
| zapis do bazy z dawką, karencją i kodem EPPO | ewidencja ma komplet wymaganych pól |
| dawka ponad dopuszczalną | ostrzeżenie zamiast cichego przyjęcia |
| lista środków zawężona do uprawy | rolnik nie przewija 2 967 środków |
| brak zachęty do premium podczas wpisu | obietnica z planu (pkt 8) |

## Decyzje podjęte przy pisaniu ekranów

- **Lista środków jest zawężona do uprawy pola** — z 2 967 środków zostaje
  kilkadziesiąt. Wyszukiwarka po nazwie jest dla tych, którzy wiedzą, czego
  szukają.
- **Dawka jest podpowiedziana z rejestru** i zmienia się przyciskami „+" i „−"
  co 0,05. Przekroczenie dawki maksymalnej daje ostrzeżenie, ale **nie blokuje
  zapisu** — rolnik odpowiada za swoje pole, aplikacja ma ostrzegać, nie zabraniać.
- **Gdy rejestr nie podaje dawki jednoznacznie** (3,7% zastosowań z P1), ekran
  pokazuje pełny tekst z rejestru i prosi o sprawdzenie etykiety — zamiast
  podstawiać liczbę.
- **Karencja zawsze z datą etykiety**, bo opakowanie kupione dawniej może mieć
  starszą wersję (ustalenie z P2).

## Stan

- **138 testów** (45 Fluttera, 93 skryptów danych), wszystkie przechodzą.
- `flutter analyze` bez ostrzeżeń, `dart format` zastosowany.

## Czego jeszcze nie ma w tej ścieżce

1. **Powtórzenia ostatniego zabiegu** i **zabiegu na kilku polach naraz**
   (to drugie jest funkcją premium — plan, pkt 8).
2. **Wyboru powodu zabiegu z listy** — teraz wpisuje się ten, który rejestr
   wiąże z wybranym zastosowaniem.
3. **Zdjęcia etykiety** jako sposobu wyboru środka (premium, etap 1 pkt 7).
4. **Mapy przy wyborze pola** — na razie lista; mapa dojdzie z granicami z P5.
5. **Dokumentów** — ekran po zapisie wymienia rejestry, do których wpis trafił,
   ale samych wydruków jeszcze nie ma (krok 4 etapu 1).

## Koniec prac przygotowawczych

Zadania P0–P7 z planu są zrobione. Dalej zaczyna się etap 1 właściwej budowy
(plan, pkt 4), gdzie kolejnym krokiem są **dokumenty**: podgląd, wydruk PDF
i eksport CSV/XLSX trzech rejestrów.
