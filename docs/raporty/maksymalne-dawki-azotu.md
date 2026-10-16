# Maksymalne dawki azotu dla upraw (tabela 14) — luka 4 zamknięta

16 października 2026 r.

Ostatnia pozycja z luki „dane prawne": **tabela 14 z załącznika nr 9** do
programu azotanowego — maksymalne ilości azotu działającego ze wszystkich
źródeł, osobno dla każdej uprawy w plonie głównym.

Źródło: rozporządzenie Rady Ministrów z 31 stycznia 2023 r. (Dz.U. 2023
poz. 244), załącznik nr 9, tabela 14 — strony 122–127 pliku z sejmowego
serwera (9,6 MB, 130 stron).

## Co weszło do słownika

| Miara | Wartość |
| --- | --- |
| Upraw w tabeli | **126** |
| Najniższy limit | 60 kg N/ha (truskawka, bób, fasola, piwonia) |
| Najwyższy limit | 350 kg N/ha (kalafior, chmiel) |
| Uprawy bobowate | 8 (limit w innej postaci) |
| Obniżki dla gleb słabszych | 2 (bardzo lekkie −20%, lekkie −10%) |
| Wersja słownika reguł | 2026.10.16.4 → **2026.10.16.5** |

Rozkład po grupach z tabeli:

| Grupa | Upraw |
| --- | --- |
| Zboża | 13 |
| Bobowate | 8 |
| Oleiste | 5 |
| Okopowe | 5 |
| Pastewne | 17 |
| Inne, w tym uprawy trwałe | 9 |
| Rośliny energetyczne | 3 |
| Warzywa wieloletnie | 4 |
| Warzywa polowe | 38 |
| Rośliny sadownicze | 3 |
| Uprawy szkółkarskie | 7 |
| Rośliny ozdobne | 14 |

## Skrypt, nie przepisywanie ręką

`tools/azotany/maksymalne_dawki.py` czyta tabelę z PDF (pdfplumber)
i dopisuje blok `maksymalne_dawki_azotu` do `assets/dane/reguly_prawne.json`.
Uruchamiany **na komputerze dewelopera** — telefon niczego nie pobiera
(CLAUDE.md, reguła 3).

Warstwa tekstowa Dziennika Ustaw gubi polskie znaki: „Jęczmieo",
„dwikłowy", „mieszaocowe". Poprawki są wypisane w skrypcie, a każda linia
z liczbą, której skrypt nie rozpoznaje, **przerywa zapis** — nie chcemy
tabeli z dziurą po cichu.

Trzy pułapki układu tabeli, które trzeba było rozwiązać:

1. **Limit bobowatych podany słownie**, raz dla całej grupy, rozbity na
   dwie linie: „Bobik 30 kg z nawozów azotowych mineralnych" / „Grochy
   lub" / „Lędźwian 50 kg z nawozów naturalnych". Prawa kolumna wchodziła
   w nazwy upraw.
2. **Zawinięta lista w jednej komórce**: „Warzywa: rabarbar, szczaw,
   chrzan, szparag" — cztery uprawy z czterema różnymi limitami, pisane
   z małej litery w kolejnych wierszach.
3. **Ta sama nazwa w dwóch grupach**: rzepak ma 240 kg jako roślina
   oleista i 200 kg jako pastewna. Kontrole negatywne są więc kluczowane
   parą (grupa, uprawa), nie samą nazwą.

Kontrole negatywne (`--sprawdz-tylko`): dziewięć wartości sprawdzonych
wobec rozporządzenia, pełna lista bobowatych, limit bobowatych równy
dokładnie [30, 50], brak linii nieprzeczytanych, brak nazw z resztką
układu tabeli, co najmniej 100 wierszy. Osiem testów w
`tools/azotany/test_maksymalne_dawki.py` (działają bez PDF).

## Jak to widzi rolnik

Ostrzeżenie pada **przed zapisem**, przy wpisie dawki — wtedy, kiedy można
ją jeszcze zmienić:

> Na polu Za stodołą wyjdzie 254 kg azotu na hektar, a dla uprawy
> kukurydza na ziarno wolno dać najwyżej 240 kg.
> **Zmniejsz dawkę — do limitu zostało 36 kg azotu na hektar.**

Gdy dawka jest w granicach, ekran mówi tylko jedno zdanie bez straszenia:
„Za stodołą: razem 34 z 200 kg azotu na hektar." Zestawienie azotu
(wygląd prosty) pokazuje limit przy każdym polu i oznacza pola „ponad
limit".

**Wpisu nie blokujemy.** Rolnik mógł nawóz już wysiać i musi móc to
zapisać — dokumentacja ma być prawdziwa, a nie zgodna.

## Czego nie zgadujemy

| Sytuacja | Co robi aplikacja |
| --- | --- |
| Uprawa, której nie ma w tabeli (także wpisana ręcznie) | nic nie liczy i nie ostrzega — `StanMaksymalnejDawki.brak` |
| Nazwa pasuje do dwóch grup o różnych limitach (rzepak) | pokazuje oba („240 kg: oleiste, 200 kg: pastewne") i prosi o sprawdzenie grupy; nie wybiera za rolnika |
| Uprawa bobowata | mówi, że limit to 30 kg N z nawozów mineralnych albo 50 kg z naturalnych — nie udaje liczby „ze wszystkich źródeł" |
| Wiersz zbiorczy („Inne oleiste") | wybiera go tylko rolnik wprost; słowo „inne" w nazwie pola nie łapie limitu |
| Gleba bardzo lekka lub lekka | aplikacja nie zna rodzaju gleby, więc nie obniża limitu sama — mówi, że na glebach lekkich limit jest niższy, i odsyła do doradcy |

Dopasowanie nazw idzie po nazwie znormalizowanej (bez ogonków, bez
wielkich liter) i bierze **najdłuższą** pasującą nazwę z tabeli, żeby
„burak cukrowy" nie trafił w „burak pastewny", a „ziemniak późny"
w „ziemniak wczesny".

## Dotknięte pliki

| Plik | Co |
| --- | --- |
| `tools/azotany/maksymalne_dawki.py` | odczyt tabeli 14 z PDF |
| `tools/azotany/test_maksymalne_dawki.py` | 8 testów skryptu |
| `assets/dane/reguly_prawne.json` | blok `maksymalne_dawki_azotu`, wersja 2026.10.16.5 |
| `lib/rdzen/reguly/regula_prawna.dart` | `MaksymalneDawkiAzotu`, `LimitAzotuDlaUprawy`, dopasowanie uprawy |
| `lib/funkcje/nawozenie/plan_nawozenia.dart` | `SkutekDlaMaksymalnejDawki`, limit przy każdym polu w zestawieniu |
| `lib/wyglad/prosty/nawozenie/ekran_dawka_nawozu.dart` | ostrzeżenie przy dawce |
| `lib/wyglad/prosty/nawozenie/ekran_nawozenie.dart` | limit i „ponad limit" w zestawieniu |
| `lib/wyglad/nowoczesny/wpis/ekran_wpis.dart` | to samo w wyglądzie nowoczesnym |

## Liczby po zmianie

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 361 | **383** |
| Testy skryptów | 112 | **120** |
| `flutter analyze` | czysto | czysto |
| `dart format` | bez zmian | bez zmian |
