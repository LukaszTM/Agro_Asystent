# ADR-0005. Odczyt PDF wniosku na urządzeniu rolnika

- Stan: **przyjęte** (15 października 2026 r., etap 1 krok 2)
- Dotyczy: plan, pkt 4 krok 2 („Import działek i upraw z PDF wniosku") i pkt 6.2

## Problem

Wniosek o płatności z eWniosekPlus to kilkudziesięciostronicowy PDF, który
rolnik ma na telefonie. Import musi przeczytać z niego tabele X i XI
**na urządzeniu**: plik zawiera dane osobowe, więc nie wolno go nigdzie
wysyłać, a aplikacja ma działać bez internetu (plan, pkt 2 i 6.2).

Czytnik z zadania P4 jest w Pythonie (`pdfplumber`) i działa na komputerze
dewelopera — na telefonie go nie uruchomimy.

## Rozważone drogi

| Droga | Ocena |
| --- | --- |
| **`syncfusion_flutter_pdf`** | licencja wspólnotowa z progami przychodu i liczby programistów — nie jest wolna do użycia komercyjnego bez warunków, odpada (CLAUDE.md: budżet 0 i licencja komercyjna) |
| **`pdfrx` / PDFium** | licencje w porządku (MIT + BSD), ale to wtyczka natywna: pobiera binaria przy budowaniu, waży kilka MB na APK i nie da się jej uruchomić w `flutter test` bez urządzenia |
| **Wysyłanie pliku do własnej usługi** | łamie „brak własnego serwera" i wysyła dane osobowe — odpada bez dyskusji |
| **Własny czytnik tekstu PDF w Darcie** | nic nie waży, działa w testach na komputerze, bez licencji i bez wtyczek; kosztuje około 1000 wierszy kodu i obsługuje tylko PDF-y tekstowe |

## Decyzja

Piszemy **własny czytnik tekstu PDF w Darcie** (`lib/rdzen/uslugi/pdf/`),
obejmujący dokładnie to, co jest potrzebne do odczytu wniosku:

- składnia obiektów PDF, strumienie, filtry `FlateDecode`, `ASCII85Decode`
  i `ASCIIHexDecode`;
- obiekty wyszukiwane przez przejrzenie pliku za zapisem „N 0 obj", a nie
  przez tablicę xref (wnioski bywają zapisywane przyrostowo);
- drzewo stron z dziedziczeniem `/Resources` i `/MediaBox`;
- czcionki: `Type0` z `Identity-H` (wniosek) i czcionki jednobajtowe
  (wzorzec testowy), znaki **wyłącznie** z tablicy `/ToUnicode` zapisanej
  w pliku, szerokości z `/W` albo `/Widths`;
- operatory tekstu `BT ET Tf Td TD Tm T* TL Tc Tw Tz Ts Tj TJ ' "` oraz
  przekształcenia `cm q Q`, czyli tyle, by znać położenie każdego słowa.

Grafika, obrazy, szyfrowanie i PDF-y ze skanów są **poza zakresem**. Gdy pliku
nie da się odczytać, rolnik dostaje jedno zdanie i podpowiedź, co zrobić —
nigdy pustego wyniku udającego poprawny odczyt.

## Czego nie zgadujemy

Znaki biorą się tylko z tablicy `/ToUnicode`. Jeśli czcionka złożona jej nie
ma, tekst z niej nie wychodzi wcale — zamiast podstawiać układ łaciński
i ryzykować, że „ł" zmieni się w inną literę w nazwie uprawy.

## Wybór pliku

Okno wyboru pliku bierzemy z pakietu `file_selector` (autorzy Fluttera,
licencja BSD) — Android i Windows. Logika importu go nie zna: korzysta
z `ZrodloPliku` z `lib/funkcje/dzialki/`, więc w testach plik pochodzi z dysku.

## Skutki

- Import działa bez internetu i bez wtyczek natywnych, a cały odczyt da się
  sprawdzić testami na komputerze (`flutter test`).
- Odczyt idzie w osobnym wątku (`compute`), bo prawdziwy wniosek ma 31 stron
  i 5 MB; na komputerze zajmuje to około sekundy.
- PDF ze skanu (same obrazy) nie zadziała i nie zadziała też w przyszłości bez
  rozpoznawania pisma — to osobny temat (plan, pkt 4 krok 7).
- Wynik czytnika w Darcie porównujemy z czytnikiem w Pythonie narzędziem
  `tool/odczyt_wniosku.dart` na prawdziwym wniosku, którego nie wolno trzymać
  w repozytorium.
