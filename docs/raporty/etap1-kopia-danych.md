# Kopia danych do pliku — ostatnia obietnica wersji darmowej

16 października 2026 r. Plan (pkt 8) wymienia w kolumnie darmowej
„Urządzenia: telefon, **kopia do pliku**", a `DostepFunkcji` traktował
`kopiaDanychDoPliku` jako funkcję darmową — tylko że ekranu nie było.
Aplikacja obiecywała coś, czego nie umiała.

To ważna rzecz, nie ozdoba: dane są wyłącznie w telefonie (brak serwera —
plan, pkt 2), więc bez kopii zgubiony telefon znaczy utratę całej
dokumentacji, której wymaga ARiMR.

## Jak to działa

**Kopia** to jeden plik ZIP z jednym JSON-em — `agro-asystent-kopia-RRRRMMDD-GGMM.zip`.
Rolnik zapisuje go tam, gdzie chce: na dysku w chmurze, na karcie, mailem
do siebie. Format jest czytelny: plik otworzy się na komputerze, nawet
gdyby aplikacja zniknęła.

Kopiujemy **całą bazę**, nie pojedyncze gospodarstwo — tak jest jedna
odpowiedź na pytanie „czy mam wszystko": wszystkie gospodarstwa, działki,
pola, zabiegi, nawozy, zwierzęta, ustawienia i **dziennik zmian**.

**Wczytanie** działa tylko do pustej aplikacji. Gdy w telefonie są już
wpisy, odmawiamy i mówimy dlaczego: scalanie dwóch zbiorów danych to
synchronizacja (etap „Windows i synchronizacja"), a nie wczytanie kopii.
Ciche zdublowanie ewidencji byłoby gorsze niż odmowa.

Odmawiamy też, gdy kopia pochodzi z **nowszego schematu** bazy, niż ta
wersja aplikacji rozumie — nie zgadujemy, jak ją przerobić.

## Dziennik zmian wraca taki, jaki był

Wyzwalacze w bazie dopisują wiersze dziennika przy każdym zabiegu — także
wtedy, gdy wstawiamy wpisy z kopii. Dlatego po wczytaniu danych czyścimy
dziennik i wstawiamy ten z kopii. Inaczej kontrola zobaczyłaby zmiany
„wykonane" w dniu odzyskiwania telefonu, a nie w dniu zabiegu. Pilnuje
tego osobny test: czas pierwszego wpisu dziennika musi pochodzić z kopii.

## Usuwanie gospodarstwa

Krok 10 odłożył usuwanie gospodarstwa „do ekranu kopii danych" — i teraz
dochodzi. Przycisk stoi przy danych gospodarstwa, pyta o potwierdzenie
i przypomina o kopii. Wpisy **zostają w bazie** (`usuniety = 1`), bo
wymaga tego kontrola; z listy znika gospodarstwo, a aplikacja przełącza
się na to, które zostało. Ostatniego nie da się usunąć — ekran wyjaśnia,
że rolnik zostałby bez miejsca na dokumentację.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/rdzen/uslugi/kopia/kopia_danych.dart` | zbiera bazę do pliku i wczytuje z powrotem |
| `lib/wyglad/prosty/ustawienia/ekran_kopia.dart` | „Zrób kopię" i „Wczytaj kopię" |
| `lib/funkcje/dzialki/zrodlo_pliku.dart` | wybór pliku kopii obok wyboru wniosku PDF |
| `lib/wyglad/prosty/ustawienia/ekran_gospodarstwa.dart` | wejście na ekran kopii + usuwanie gospodarstwa |

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 2 (+ zmiany w pięciu) |
| Nowe pliki testów | 2 |
| Testy dodane | 11 (5 logiki kopii, 4 ekranu kopii, 2 usuwania) |
| Testy w całym projekcie | 295 (było 284) |
| Tabele w kopii | 16 |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Kopia mówi, co w niej jest (gospodarstwa, liczba pól, zabiegów, zwierząt),
  nie zmieniając bazy.
- Kopia wraca w całości do pustej bazy — razem z karencją w szczegółach
  oprysku i z dziennikiem zmian o pierwotnych czasach.
- Wczytania na istniejące dane odmawiamy, nic nie dublując.
- Obcy plik i kopia z nowszego schematu są odrzucane, a nie wczytywane
  połowicznie.
- Ekran zapisuje plik ZIP o nazwie z datą i mówi, że kopia jest darmowa.
- Ostatniego gospodarstwa nie można usunąć; usunięcie drugiego przełącza na
  to, które zostało, i zostawia wiersz w bazie.

## Czego kopia nie robi

- **Nie scala** danych z dwóch telefonów — to synchronizacja z późniejszego
  etapu.
- **Nie wysyła** się sama nigdzie: nie ma serwera ani automatycznej kopii
  w chmurze (automatyczna kopia jest w planie po stronie premium).
- **Nie szyfruje** pliku. Plik zawiera dane gospodarstwa, więc rolnik ma go
  trzymać tam, gdzie trzyma inne dokumenty gospodarstwa.
