# ADR-0006. Wydruk PDF i eksport CSV/XLSX na urządzeniu

- Stan: **przyjęte** (15 października 2026 r., etap 1 krok 4)
- Dotyczy: plan, pkt 4 krok 4 („Dokumenty: podgląd, wydruk PDF, eksport CSV/XLSX")
  oraz pkt 8 (dokumentacja zawsze darmowa)

## Problem

Rolnik ma pokazać kontroli ewidencję i wysłać ją doradcy. Wszystko musi
powstawać **na telefonie**, bez internetu i bez naszego serwera, a dokument
ma zawierać dokładnie te pola, których żąda przepis — razem z brakami,
zamiast pustych kratek.

## Decyzje

### 1. Kolumny dokumentu pochodzą ze słownika reguł

Wydruk i eksport biorą kolumny z `wymagane_pola` obowiązku
(`assets/dane/reguly_prawne.json`), tak samo jak kontrola kompletności
z kroku 3. Dzięki temu dokument, ekran i ostrzeżenia nigdy się nie rozjeżdżają,
a zmiana przepisu to podmiana pliku danych.

### 2. PDF: pakiet `pdf` + `printing`

| Droga | Ocena |
| --- | --- |
| **`pdf` (Apache-2.0)** | czysty Dart, składa dokument i osadza czcionkę; testowalny bez urządzenia — wybrane |
| **`printing` (Apache-2.0)** | okno wydruku systemu (drukarka albo „zapisz jako PDF"), Android i Windows — wybrane |
| Własny generator PDF | pisanie osadzania czcionek i podziału tabel na strony to tygodnie pracy; czytnik z kroku 2 był prostszy, bo czytał, a nie składał |
| Wysyłka do usługi w sieci | łamie „brak własnego serwera" i wysyła dane osobowe — odpada |

### 3. XLSX składamy sami, z pakietem `archive`

XLSX to ZIP z kilkoma plikami XML. Zamiast biblioteki do arkuszy (kolejna
zależność, własne błędy) piszemy sześć plików XML i pakujemy je pakietem
`archive` (MIT). Wynik otwiera Excel, LibreOffice i Arkusze Google —
sprawdzone odczytem przez `openpyxl`.

### 4. CSV ze średnikiem i znacznikiem BOM

Polski Excel dzieli kolumny średnikiem, a bez znacznika BOM pokazuje
„krzaki" zamiast polskich znaków. Plik ma więc średniki, BOM i końce wierszy
CRLF — otwiera się dwuklikiem, bez kreatora importu.

### 5. Czcionka: fragment DejaVu Sans

Wbudowane czcionki pakietu `pdf` nie mają polskich znaków. Osadzamy DejaVu Sans
(licencja Bitstream Vera — wolno używać, zmieniać i sprzedawać z dołączoną
treścią licencji), przyciętą skryptem `tools/zbuduj_czcionki.py` do znaków,
które pojawiają się na dokumentach: **1,5 MB → 36 kB**.

### 6. Wyjście pliku przez `share_plus`

Na Androidzie katalog aplikacji jest niedostępny dla rolnika, a okno „zapisz
jako" nie obsługuje tej platformy. Plik oddajemy przez okno udostępniania
(`share_plus`, licencja BSD): poczta, dysk, menedżer plików, przeniesienie na
komputer. Logika modułów go nie zna — korzysta z `WyjscieDokumentu`,
więc w testach pliki trafiają do pamięci.

## Skutki

- Wydruk i eksport działają bez internetu i są **zawsze darmowe** (plan, pkt 8).
- Gotowy PDF czytamy własnym czytnikiem z kroku 2 — test sprawdza, że dokument
  da się odczytać maszynowo i że polskie znaki wyszły w całości.
- Doszły cztery zależności: `pdf`, `printing` (Apache-2.0), `share_plus` (BSD),
  `archive` (MIT) — wszystkie darmowe i dopuszczające użycie komercyjne.
- Wymóg „eksportu w formacie do odczytu maszynowego" od 1.01.2027 r. jest
  spełniony co do istoty (CSV i XLSX), ale **format urzędowy nie jest znany** —
  zostaje w otwartych sprawach planu.
