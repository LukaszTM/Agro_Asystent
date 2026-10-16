# Cztery ekrany formularzowe w wyglądzie „Nowoczesny" — luka 9 zamknięta

16 października 2026 r.

Wygląd „Nowoczesny" powstał w pełnym zakresie zakładek, ale cztery ekrany
formularzowe miał tylko wygląd prosty. Rolnik, który wybrał nowoczesny,
nie mógł dodać działki ewidencyjnej, wczytać wniosku, dopisać nawozu ani
poprawić danych gospodarstwa — musiał przełączyć wygląd. Teraz ma
wszystko u siebie.

## Co doszło

| Ekran | Plik | Wejście |
| --- | --- | --- |
| Działki ewidencyjne + granice z ULDK | `wyglad/nowoczesny/pola/ekran_dzialki.dart` | zakładka „Pola" → „Działki" |
| Import wniosku z PDF | `wyglad/nowoczesny/pola/ekran_import_wniosku.dart` | zakładka „Pola" → „Z wniosku" |
| Nawożenie: limity, terminy, zestawienie | `wyglad/nowoczesny/nawozenie/ekran_nawozenie.dart` | karta azotu na ekranie startowym |
| Spis nawozów + nowy nawóz | `wyglad/nowoczesny/nawozenie/ekran_nawozy.dart` | ekran nawożenia → „Nawozy i zawartość azotu" |
| Dane gospodarstwa (nazwa, numer, usuwanie) | `wyglad/nowoczesny/ustawienia/ekran_dane_gospodarstwa.dart` | Ustawienia → karta gospodarstwa |

W ustawieniach doszły przy tym dwa braki, których wcześniej nie było
widać: **dodanie kolejnego gospodarstwa** i **konto** (imię i nazwisko
albo nazwa firmy, bez logowania i hasła).

## Co wyjęte, a nie przepisane

Karta „Do kiedy wolno nawozić" to 150 wierszy tekstu zbudowanego z danych
(terminy z tabeli 2, zakazy z ustawy, odstępstwa, odległości od wód,
wcześniejsza wiosna). Przepisywanie jej drugi raz znaczyłoby, że następna
poprawka przepisu wymaga dwóch zmian w dwóch plikach — i że jeden z nich
kiedyś zostanie zapomniany.

Dlatego karta trafiła do `lib/rdzen/wspolne/terminy_nawozenia.dart` jako
`KartaTerminowNawozenia`. Wygląd podaje jej dwie rzeczy:

- `StylKarty` — tło, obramowanie, zaokrąglenie i odstęp;
- funkcję budującą ostrzeżenie (`Ostrzezenie` albo `OstrzezenieNowoczesne`).

Treść jest wspólna, bo w obu wyglądach znaczy to samo. Ten sam wzorzec
stosuje już `MapaDzialek`, która bierze `barwy` z motywu wywołującego.
`lib/rdzen/` nadal nie importuje niczego z `lib/wyglad/` — pilnuje tego
test architektury.

Pozostałe ekrany są napisane w idiomie nowoczesnym, nie skopiowane:
numer działki wpisuje się w zwykłe pole (klawiatura wychodzi po
dotknięciu okienka), rodzaj nawozu wybiera się „pigułką", liczby stoją
na kartach. Układ prosty — wizard z wielkimi przyciskami — został po
stronie prostego.

## Usterka wyłapana przy okazji

Pigułki „Mineralny (z worka)" i „Naturalny (obornik, gnojowica)" nie
mieszczą się w jednym rzędzie na ekranie 420 px — `Wrap` przycinał drugą
o 59 px. Etykiety są teraz krótkie („Mineralny", „Naturalny"),
a objaśnienie stoi wierszem niżej. Testy mają osobną grupę, która
przewija każdy nowy ekran do końca: przycięcie układu zgłasza się
w teście jako wyjątek, więc samo dojście do dołu jest sprawdzeniem.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Pliki kodu w `lib/` | 108 | **113** |
| Pliki testów | 38 | **39** |
| Testy Flutter | 383 | **394** |
| Wiersze nowych ekranów | — | 1602 |
| Wiersze wyjęte do `rdzen/wspolne/` | — | 248 |
| `flutter analyze` | czysto | czysto |

## Czego nadal nie ma w nowoczesnym

Zwierzęta (rejestr stada) i kopia danych działają w ustawieniach, ale
rejestr stada ma pełny ekran tylko w wyglądzie prostym — produkcja
zwierzęca jest ścieżką rozwoju (ADR-0007), więc to nie blokuje etapu 1.
