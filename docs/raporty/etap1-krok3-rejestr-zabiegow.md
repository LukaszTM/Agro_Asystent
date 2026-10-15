# Raport etap 1, krok 3 — rejestr zabiegów z ewidencją oprysków

15 października 2026 r. Zadanie z planu (pkt 4, krok 3):
„Rejestr zabiegów z ewidencją oprysków (słownik środków, szukanie po nazwie)".

## Co rolnik może zrobić

Ekran główny → **Dokumenty** otwiera **rejestr zabiegów**: wszystkie wpisy od
najnowszego, z szukaniem po nazwie środka, pola albo uprawy i z przełącznikiem
„Wszystkie / Oprysk / Nawożenie". Nad listą stoi jedno zdanie: ile jest wpisów
i ile z nich **nie ma pełnych danych do ewidencji**.

Dotknięcie wpisu pokazuje go w całości, tak jak ma go zobaczyć kontrola:
nazwa środka, numer zezwolenia, data i godzina, dawka, powierzchnia, uprawa,
kod EPPO, faza BBCH, przyczyna zabiegu, rodzaj zastosowania i **numery działek
referencyjnych z wniosku**. Przy każdym polu widać, czy jest wypełnione.
Na dole: karencja z dniem zbioru, przyciski **„Popraw wpis"** (dawka i godzina
przyciskami „+" i „−") oraz **„Cofnij wpis"** z pytaniem o potwierdzenie.

## Skąd się bierze lista pól ewidencji

Pola wymagane przepisem są **danymi**, nie kodem: doszły do
`assets/dane/reguly_prawne.json` (wersja **2026.10.15**) jako `wymagane_pola`
obowiązków `ewidencja_sor` (12 pól, rozp. UE 2023/564) i `ekoschematy_rejestr`
(5 pól). Gdy przepis doda pole, wystarczy podmienić plik danych — kod się nie
zmienia (CLAUDE.md, reguła 1).

Jeśli słownik wymaga pola, którego ta wersja aplikacji nie umie wypełnić,
wpis **nie jest** uznawany za kompletny: rolnik widzi „tego pola ta wersja
aplikacji nie zna — sprawdź sam". Nie zgadujemy i nie milczymy.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/zabiegi/rejestr_zabiegow.dart` | odczyt wpisów z polami, uprawami i działkami referencyjnymi; filtry i szukanie |
| `lib/funkcje/zabiegi/kompletnosc_ewidencji.dart` | sprawdzenie wpisu pod kątem pól wymaganych przez przepis |
| `lib/wyglad/prosty/rejestr/ekran_rejestr.dart` | lista wpisów, szukanie, przełącznik rodzaju, podsumowanie braków |
| `lib/wyglad/prosty/rejestr/ekran_wpis_rejestru.dart` | wpis w całości, karencja, cofnięcie wpisu |
| `lib/wyglad/prosty/rejestr/ekran_popraw_wpis.dart` | poprawka dawki i godziny bez klawiatury |
| `assets/dane/reguly_prawne.json` | nowe `wymagane_pola` (12 + 5), wersja 2026.10.15 |
| `lib/rdzen/baza/migracje.dart` | migracja 2: dziennik zmian dla szczegółów oprysku |
| `lib/funkcje/zabiegi/repozytorium_zabiegow.dart` | `popraw()` — poprawka wpisu w jednej transakcji |

Przy okazji: wpis oprysku zapisuje teraz `rodzaj_zastosowania = „opryskiwanie"`
(rolnik wybrał „Oprysk", więc to jego wybór, nie domysł), a kafelek
„Dokumenty" prowadzi do rejestru — wydruk PDF i eksport dojdą w kroku 4.

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 5 |
| Nowe pliki testów | 3 |
| Testy dodane w tym kroku | 21 |
| Testy w całym projekcie | 134 (było 113) |
| Pól ewidencji środków ochrony roślin w słowniku | 12 |
| Pól rejestru ekoschematów w słowniku | 5 |
| Wersja schematu bazy | 2 (było 1) |
| `flutter analyze` | bez ostrzeżeń |
| Nowe zależności | brak |

## Czego pilnują testy

- **Wpis wraca w całości**: pole, uprawa, kod EPPO, powierzchnia, numery
  działek referencyjnych z importu wniosku (krok 2).
- **Kolejność i filtry**: najnowsze na górze, filtr rodzaju i roku, lista lat
  z wpisami.
- **Szukanie** znajduje po nazwie środka, nazwie pola i nazwie uprawy.
- **Karencja** liczy dzień zbioru od daty zabiegu (42 dni → 21.06.2026) i wie,
  czy jeszcze trwa.
- **Poprawka zostawia ślad**: po zmianie dawki z 0,75 na 0,50 poprzednia
  wartość jest w `historia_zmian` (nowy wyzwalacz z migracji 2 — wcześniej
  poprawka dawki przepadałaby bez śladu).
- **Cofnięty wpis** znika z rejestru, ale zostaje w dzienniku zmian wraz
  z operacjami „dodanie" i „usuniecie".
- **Braki są wymienione**: wpis bez godziny, kodu EPPO i rodzaju zastosowania
  pokazuje trzy braki i zdanie „W ewidencji brakuje 3 rzeczy: …".
- **Słownik nowszy niż aplikacja** → pole „nie wiadomo", wpis niekompletny.
- Ekrany: pusty rejestr podpowiada, co zrobić; poprawka godziny o kwadrans
  wraca do podglądu z nową wartością; cofnięcie pyta przed usunięciem.

## Rzeczy świadomie odłożone

- **Wydruk PDF i eksport CSV/XLSX** — to krok 4; rejestr jest już ich źródłem.
- **Poprawka pola i daty zabiegu** — na razie poprawiamy dawkę i godzinę;
  zmiana pola oznacza inny zabieg, więc lepiej wpisać go od nowa i cofnąć stary.
- **Faza BBCH** pochodzi z okna stosowania z etykiety, a nie z obserwacji
  rolnika. W ewidencji widać ją jako „BBCH 29–59"; ręczne podanie fazy
  z pola dojdzie razem z odczytem etykiet (krok 8).
- **Ewidencja nawożenia** ma w słowniku własny zestaw pól (rejestr
  ekoschematów), ale wpis nawożenia powstanie w kroku 6.
- **Eksport do odczytu maszynowego** wymagany od 1.01.2027 r. — format
  wyjściowy wybierzemy w kroku 4.
