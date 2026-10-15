# Raport etap 1, krok 5 — terminy i przypomnienia

15 października 2026 r. Zadanie z planu (pkt 4, krok 5):
„Terminy i przypomnienia".

## Co rolnik może zrobić

Ekran główny → **Terminy**. Widzi kalendarz obowiązków pogrupowany po
pilności: „Termin już minął", „Dziś", „W tym tygodniu", „W tym miesiącu",
„Później". Każda pozycja mówi, **kiedy** („za 12 dni, 27.10.2026", „trwa do
31.07.2026") i **co zrobić** jednym zdaniem. Pilne i przegapione są w ramce
ostrzeżenia.

Nad listą stoi przełącznik **„Przypominaj o terminach"**. Po włączeniu telefon
odzywa się rano — trzy dni przed terminem i w dniu terminu.

## Skąd biorą się terminy

| Źródło | Co daje |
| --- | --- |
| Słownik reguł `assets/dane/reguly_prawne.json` | daty roczne (okrywa do 15.10), okresy (zakaz przycinania drzew 15.04–31.07), terminy jednorazowe (ewidencja wyłącznie elektronicznie od 1.01.2027) |
| Rejestr zabiegów | koniec karencji po każdym opryskuie — „nie zbieraj plonu do…" |

**Żadnej daty nie ma w kodzie Dart.** Terminy przeliczamy ze słownika na
konkretne dni: data roczna przechodzi na następny rok, gdy już minęła, okres
pokazuje się jako trwający, a termin liczony od zdarzenia (7 dni na zgłoszenie
cielęcia) czeka na zwierzęta z kroku 9 — nie udajemy, że umiemy go policzyć.

Które obowiązki w ogóle się włączają, decyduje **profil gospodarstwa** liczony
z bazy: powierzchnia pól bieżącego sezonu. Gospodarstwo poniżej progu nie
dostaje terminów warunkowości; obowiązek, którego aplikacja nie umie ocenić,
dostaje adnotację „sprawdź u doradcy", zamiast zniknąć.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/terminy/kalendarz_terminow.dart` | przeliczenie terminów ze słownika, karencje z rejestru, profil gospodarstwa z bazy |
| `lib/funkcje/terminy/przypomnienia.dart` | układanie przypomnień (logika osobno od systemu) i granica `UslugaPrzypomnien` |
| `lib/funkcje/terminy/ustawienia_przypomnien.dart` | zapamiętanie wyboru rolnika w tabeli `ustawienia` |
| `lib/app/przypomnienia_urzadzenia.dart` | powiadomienia systemowe (`flutter_local_notifications`) |
| `lib/wyglad/prosty/terminy/ekran_terminy.dart` | kalendarz z grupowaniem i przełącznikiem przypomnień |

Zmiany natywne: w `android/app/build.gradle.kts` doszło **odcukrzanie**
(`coreLibraryDesugaring`) wymagane przez wtyczkę powiadomień, a w manifeście
zgoda `RECEIVE_BOOT_COMPLETED`, żeby przypomnienia przeżyły ponowne
uruchomienie telefonu.

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 5 |
| Nowe pliki testów | 3 |
| Testy dodane w tym kroku | 26 |
| Testy w całym projekcie | 181 (było 155) |
| Terminy w słowniku reguł | 4 (2 roczne, 1 okres, 1 jednorazowy) |
| Nowe zależności | `flutter_local_notifications` (BSD), `timezone` (BSD), `flutter_timezone` (Apache-2.0) |
| `flutter analyze` | bez ostrzeżeń |

## Decyzje warte zapamiętania

- **Przypomnienia niedokładne.** Planujemy je w trybie
  `inexactAllowWhileIdle`: system może je pokazać kwadrans później, za to nie
  prosimy o pozwolenie na dokładne budziki, którego sklepy pilnują. Terminy
  rolnicze liczy się w dniach, nie w minutach.
- **Strefa czasowa z urządzenia.** Bez niej przypomnienie o 7:00 odezwałoby
  się o innej godzinie, bo biblioteka czasu domyślnie stoi na czasie
  uniwersalnym. Gdy odczyt strefy zawiedzie, przypomnienie i tak zostaje
  zaplanowane — z przesunięciem, ale zostaje.
- **Najwyżej 32 przypomnienia naraz i horyzont 31 dni** — system ogranicza
  liczbę zaplanowanych powiadomień, a dalszy kalendarz i tak się zmieni.
- **Stały numer przypomnienia** liczony z identyfikatora terminu: ponowne
  ułożenie planu zastępuje stare przypomnienia, zamiast dokładać drugie takie
  same.

## Rzeczy świadomie odłożone

- **Terminy liczone od zdarzenia** (7 dni na zgłoszenie cielęcia) — dojdą
  razem ze zwierzętami w kroku 9.
- **Nabór wniosków** jako termin roczny: data zależy od ogłoszenia ARiMR,
  więc wejdzie do słownika reguł, gdy będzie znana, a nie do kodu.
- **Terminy nawożenia** z planu są oznaczone jako „do weryfikacji" i czekają
  na sprawdzenie w aktualnym rozporządzeniu (plan, pkt 10) — kalendarz
  pokaże je z adnotacją, gdy wejdą do słownika w kroku 6.
- **Własny dźwięk i ikona powiadomienia** — na razie systemowe.
