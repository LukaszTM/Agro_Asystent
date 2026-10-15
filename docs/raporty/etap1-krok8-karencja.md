# Raport etap 1, krok 8 — karencja z bazy etykiet

15 października 2026 r. Zadanie z planu (pkt 4, krok 8):
„Karencja z bazy etykiet (jeśli próba z zadania P2 wypadnie dobrze)".

Próba z P2 wypadła dobrze: **84,5% etykiet** dało się odczytać, a wynik
ma przy sobie datę etykiety i źródło. Dlatego krok wchodzi w całości.

## Jak karencja działa teraz

| Sytuacja | Co widzi rolnik |
| --- | --- |
| Baza etykiet zna karencję | „Karencja: 42 dni. Zbiór najwcześniej 21.06.2026" wraz z datą etykiety i uwagą „Twoje opakowanie mogło być wydane wcześniej" |
| Etykieta mówi „karencja nie dotyczy" | jedno zdanie, bez liczenia dnia zbioru |
| Karencji nie ma w bazie | „Karencji nie znamy dla tego środka" + przycisk **„Wpisz karencję z opakowania"** |

Po każdym wpisie oprysku jest przycisk **„Sprawdź karencję na opakowaniu"**
(albo „Wpisz…", gdy jej nie znamy). Rolnik widzi liczbę dni, zmienia ją
przyciskami „+" i „−" i od razu dzień zbioru. Po zatwierdzeniu wpis mówi,
skąd karencja pochodzi:

- `etykieta MRiRW, potwierdzona przez rolnika`,
- `opakowanie, wpisane przez rolnika`,
- `etykieta MRiRW` + „do potwierdzenia", dopóki nikt jej nie sprawdził.

To samo widać w rejestrze (**Dokumenty → wpis**), razem z przyciskiem
potwierdzenia. Zmiana karencji zostawia ślad w dzienniku zmian, bo zmienia
dzień zbioru — a to jest informacja, którą kontrola porównuje z datą zbioru.

## Dlaczego nie czytamy karencji ze zdjęcia

Zdjęcie etykiety (krok 7) rozpoznaje nazwę i numer zezwolenia — rzeczy, które
da się sprawdzić w rejestrze. Karencja to liczba, od której zależy legalność
zbioru; jeśli rozpoznawanie pisma pomyli „7" z „1", rolnik zbierze plon za
wcześnie. Dlatego karencja pochodzi albo ze sprawdzonej bazy z P2 (z datą
etykiety), albo od rolnika, który ma opakowanie w ręku.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/wyglad/prosty/wpis/ekran_karencja.dart` | potwierdzenie albo wpis karencji, opis źródła dla rejestru |
| `lib/funkcje/zabiegi/repozytorium_zabiegow.dart` | `zapiszKarencje()` — zapis w jednej transakcji ze śladem w dzienniku |
| `lib/wyglad/prosty/wpis/ekran_zapisano.dart` | przycisk karencji zaraz po zapisie |
| `lib/wyglad/prosty/rejestr/ekran_wpis_rejestru.dart` | karencja ze źródłem i potwierdzeniem w podglądzie wpisu |

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 1 (+ zmiany w trzech) |
| Nowe pliki testów | 1 |
| Testy dodane w tym kroku | 5 |
| Testy w całym projekcie | 221 (było 216) |
| Odczyt karencji z P2 | 84,5% etykiet |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Karencja z bazy etykiet jest **do potwierdzenia**, dopóki rolnik jej nie
  zatwierdzi.
- Potwierdzenie zapisuje źródło i zostawia ślad w dzienniku zmian.
- Brak karencji w bazie → rolnik wpisuje ją z opakowania, a dzień zbioru
  liczy się od daty zabiegu.
- Zero dni znaczy „karencja nie obowiązuje" i tak jest opisane.
- Poprawiona karencja zmienia dzień zbioru w rejestrze i w kalendarzu
  terminów.

## Rzeczy świadomie odłożone

- **Prewencja** (okres, przez który nie wolno wchodzić na pole) jest
  odczytana w bazie z P2, ale nie ma jeszcze miejsca w ewidencji — dojdzie
  razem z ewidencją zabiegów dla pracowników.
- **Automatyczne odświeżanie bazy etykiet** — dziś słownik wchodzi z nową
  wersją aplikacji; paczka aktualizacji danych to temat etapu 2.
