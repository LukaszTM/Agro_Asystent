# Raport etap 1, krok 4 — dokumenty: podgląd, wydruk, eksport

15 października 2026 r. Zadanie z planu (pkt 4, krok 4):
„Dokumenty: podgląd, wydruk PDF, eksport CSV/XLSX".

## Co rolnik może zrobić

Ekran główny → **Dokumenty** → **Wydruk i eksport**. Wybiera dokument
(ewidencja środków ochrony roślin albo rejestr ekoschematów) i okres
(wszystkie lata albo konkretny rok), widzi podgląd: tytuł, gospodarstwo,
liczbę wpisów, liczbę kolumn wymaganych przepisem, podstawę prawną i wersję
słownika reguł. Potem jeden z czterech przycisków:

| Przycisk | Co robi |
| --- | --- |
| **Wydrukuj** | otwiera okno wydruku systemu — drukarka albo „zapisz jako PDF" |
| **Plik PDF** | oddaje gotowy PDF do wysłania albo zapisania |
| **Plik CSV** | plik dla Excela i Arkuszy Google |
| **Plik XLSX** | arkusz kalkulacyjny |

Jeśli któryś wpis nie ma kompletu danych, widać to **przed** wydrukiem,
a na dokumencie brakujące pole wychodzi jako „brak" — nigdy jako pusta kratka
udająca porządek.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/dokumenty/dokument_ewidencji.dart` | dokument z kolumnami wziętymi ze słownika reguł |
| `lib/funkcje/dokumenty/eksport_csv.dart` | CSV ze średnikiem, BOM i CRLF |
| `lib/funkcje/dokumenty/eksport_xlsx.dart` | XLSX składany z plików XML i pakowany ZIP-em |
| `lib/funkcje/dokumenty/wydruk_pdf.dart` | wydruk A4 poziomo z osadzoną czcionką |
| `lib/funkcje/dokumenty/usluga_dokumentow.dart` | złożenie wszystkiego, nazwy plików, typy MIME |
| `lib/funkcje/dokumenty/wyjscie_dokumentu.dart` | granica: wydruk i oddanie pliku |
| `lib/app/wyjscie_dokumentu_urzadzenia.dart` | okno wydruku (`printing`) i udostępniania (`share_plus`) |
| `lib/wyglad/prosty/dokumenty/ekran_dokumenty.dart` | wybór dokumentu i okresu, podgląd, cztery przyciski |
| `tools/zbuduj_czcionki.py` | przycięcie DejaVu Sans do znaków z dokumentów |
| `tool/proba_wydruku.dart` | narzędzie dewelopera: przykładowy PDF, CSV i XLSX do obejrzenia |

Decyzje i odrzucone warianty: `docs/decyzje/ADR-0006-dokumenty.md`.

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 8 (+2 narzędzia) |
| Nowe pliki testów | 2 |
| Testy dodane w tym kroku | 21 |
| Testy w całym projekcie | 155 (było 134) |
| Kolumny ewidencji środków na wydruku | 12 (ze słownika reguł) |
| Czcionka wydruku | 36 kB (z 1,5 MB po przycięciu) |
| Nowe zależności | `pdf`, `printing` (Apache-2.0), `share_plus` (BSD), `archive` (MIT) |
| `flutter analyze` | bez ostrzeżeń |

## Sprawdzenie poza testami Dart

- **XLSX otwarty `openpyxl`** (ten sam czytnik, którego używaliśmy w P1):
  arkusz „Ewidencja", zakres A1:L11, nagłówki i wartości na swoich miejscach.
- **CSV wczytany modułem `csv`** z kodowaniem `utf-8-sig` i średnikiem —
  kolumny rozdzielone poprawnie, polskie znaki w całości.
- **PDF odczytany naszym własnym czytnikiem z kroku 2** — ten sam kod, którym
  czytamy wniosek. Jeśli dokument da się odczytać maszynowo u nas, odczyta go
  też urząd.

## Czego pilnują testy

- Kolumny dokumentu **są dokładnie** listą `wymagane_pola` ze słownika reguł
  — gdyby ktoś wpisał kolumny w kodzie, test to wyłapie.
- Wiersze mają wartości w kolejności kolumn, a braki są wymienione z nazwy.
- Rok zawęża dokument, a wpisy idą **od najstarszego** — tak czyta je kontrola.
- CSV: BOM na początku bajtów, średniki, cudzysłowy przy wartości ze
  średnikiem, „brak" zamiast pustego pola.
- XLSX: komplet plików w ZIP-ie, wartości w arkuszu, znaki `& < >` nie psują XML-a.
- PDF: da się odczytać, zawiera tytuł, gospodarstwo, okres, podstawę prawną,
  wersję słownika i polskie znaki; pusty okres daje zdanie „nie ma żadnego
  wpisu", a nie pustą kartkę.
- Ekran: trzy formaty dają trzy pliki z właściwymi rozszerzeniami i typami MIME,
  „Wydrukuj" idzie do wydruku, a nie do zapisu pliku.

## Rzeczy świadomie odłożone

- **Format urzędowy „do odczytu maszynowego"** wymagany od 1.01.2027 r. nie
  jest znany; CSV i XLSX spełniają wymóg co do istoty, ale gdy ministerstwo
  ogłosi schemat, dojdzie trzeci eksport.
- **Podgląd strona po stronie** (miniatura wydruku w aplikacji) — dziś podgląd
  jest opisowy: tytuł, okres, liczba wpisów i kolumn.
- **Rejestr nawożenia** da się już wydrukować, ale wpisy nawożenia powstaną
  dopiero w kroku 6.
- **Własne logo na wydruku** — wydruk jest celowo urzędowy; znak aplikacji
  zostaje w aplikacji.
