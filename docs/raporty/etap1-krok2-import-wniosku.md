# Raport etap 1, krok 2 — import działek i upraw z PDF wniosku

15 października 2026 r. Zadanie z planu (pkt 4, krok 2):
„Import działek i upraw z PDF wniosku".

## Co rolnik może zrobić

Od ekranu głównego: **Pola → Wczytaj wniosek z PDF → Wybierz plik wniosku**
(okno systemowe) **→ Zapisz do gospodarstwa**. Cztery dotknięcia i całe
gospodarstwo jest w aplikacji: działki ewidencyjne z powierzchniami, pola
z uprawami i powiązania „które pole leży na której działce".

Przed zapisem widać podsumowanie odczytu (ile działek, ile pól, ile hektarów,
na jaki rok) i wynik kontroli. Zapis następuje dopiero po potwierdzeniu.
Plik zostaje na telefonie — nic nie jest nigdzie wysyłane.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/rdzen/uslugi/pdf/skladnia_pdf.dart` | składnia obiektów PDF, filtry Flate / ASCII85 / ASCIIHex |
| `lib/rdzen/uslugi/pdf/dokument_pdf.dart` | obiekty, drzewo stron, czcionki i tablice znaków `/ToUnicode` |
| `lib/rdzen/uslugi/pdf/tekst_pdf.dart` | operatory tekstu → słowa z położeniem i wiersze |
| `lib/funkcje/dzialki/czytnik_wniosku.dart` | tabele X i XI wniosku (przeniesienie czytnika z P4 do aplikacji) |
| `lib/funkcje/dzialki/import_wniosku.dart` | zapis do bazy: działki, pola, części pól, kody EPPO |
| `lib/funkcje/dzialki/zrodlo_pliku.dart` | skąd bierzemy plik (logika nie zna okna systemowego) |
| `lib/app/zrodlo_pliku_urzadzenia.dart` | okno wyboru pliku na Androidzie i Windows (`file_selector`) |
| `lib/wyglad/prosty/dzialki/ekran_import_wniosku.dart` | ekran: wybór pliku, podsumowanie, zapis |
| `tool/odczyt_wniosku.dart` | narzędzie dewelopera do porównania z czytnikiem w Pythonie |

Decyzja o własnym czytniku PDF i odrzucone warianty:
`docs/decyzje/ADR-0005-odczyt-pdf.md`.

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 8 (+1 narzędzie) |
| Nowe pliki testów | 4 |
| Testy dodane w tym kroku | 37 |
| Testy w całym projekcie | 113 (było 76) |
| `flutter analyze` | bez ostrzeżeń |
| Nowe zależności | `file_selector` 1.1.0 (BSD, autorzy Fluttera) |

Odczyt prawdziwego wniosku (31 stron, 5,0 MB) — wynik czytnika w Darcie
i czytnika w Pythonie z P4, oba na tym samym pliku:

| Miara | Dart (aplikacja) | Python (P4) |
| --- | --- | --- |
| Działki referencyjne | 20 (33,04 ha) | 20 (33,04 ha) |
| Pola (działki rolne) | 34 | 34 |
| Powierzchnia zadeklarowana | 28,91 ha | 28,91 ha |
| Różnych upraw | 10 | 10 |
| Pominięte wiersze | 0 | 0 |
| Kontrola wewnętrzna | zgodna | zgodna |

Czas odczytu na komputerze: około 1 sekundy. Dlatego odczyt idzie w osobnym
wątku — ekran się nie zatrzymuje.

## Czego pilnują testy

- **Składnia PDF**: nazwy, liczby, odwołania `12 0 R`, słowniki, ciągi
  zwykłe i szesnastkowe, ASCII85; nieznany filtr to błąd, nie puste dane.
- **Plik, który nie jest PDF-em** (i plik pusty) kończy się komunikatem, a nie
  wyjątkiem w połowie ekranu.
- **Polskie znaki** pochodzą z tablicy `/ToUnicode` zapisanej w pliku —
  nazwa „pszenica zwyczajna ozima" wraca w całości.
- **Pułapki układu wniosku z P4**, każda osobnym testem: numer działki rozbity
  na dwa wiersze, nazwa uprawy w dwóch wierszach, jedno pole na kilku
  działkach, kody płatności z prawej strony, wiersz przed numeracją kolumn,
  odsyłacz „_" przy nazwie uprawy.
- **Kontrola, a nie cicha poprawka**: gdy części pola nie sumują się do jego
  powierzchni, odczyt zgłasza ostrzeżenie i rolnik je widzi.
- **Import nie kasuje granic z ULDK** — wniosek dopisuje opis i powierzchnię,
  granice zostają.
- **Powtórny import nie mnoży wierszy** i **nie zmienia nazwy pola nadanej
  przez rolnika**.
- **Kod EPPO tylko ze słownika**: brakujące uprawy są wymienione na ekranie
  („nie wpisujemy niczego na domysł"), a nie dopasowywane na siłę.

## Rzeczy świadomie odłożone

- **PDF ze skanu** (same obrazy) nie zadziała — potrzeba rozpoznawania pisma,
  a to krok 7 etapu 1.
- **Pobranie granic dla zaimportowanych działek jednym ruchem** („pobierz
  granice wszystkich") — na razie rolnik dodaje granice z ekranu działek.
- **Ręczna poprawa odczytu** (edycja pola po imporcie) czeka na ekran edycji
  pola; dziś można zaimportować wniosek ponownie.
- **Wniosek z ekoschematami i bardzo długimi tabelami** wciąż nie był
  sprawdzony — tak jak w P4, to otwarta sprawa z planu (pkt 6.2).
