# Telefon (Android) — instalacja i obsługa

## 1. Instalacja (5 minut)

> **Nie klikaj linku wewnątrz Messengera ani Facebooka.** Ich wbudowana
> przeglądarka nie dokańcza pobierania. Skopiuj adres i wklej go
> w **Chrome** — albo w tamtym okienku naciśnij trzy kropki ⋮ → **Otwórz
> w Chrome**.

1. Otwórz w Chrome: **https://github.com/LukaszTM/Agro_Asystent/releases/tag/apk-test**
   (na telefonie pliki bywają schowane pod napisem **Assets** — rozwiń go).
2. Naciśnij plik z dopiskiem **`-arm64`**: `agro-asystent-0.2.0+2-arm64.apk`
   (39 MB). Obok leży plik bez dopiska (101 MB) — ten sam program, bierz go
   tylko wtedy, gdy mniejszy nie chce się zainstalować.
3. Android zapyta, czy zezwolić na instalację z tego miejsca („nieznane
   źródła"). Zezwól — aplikacji nie ma jeszcze w sklepie Google Play.
4. Otwórz pobrany plik (**Pliki → Pobrane**) i naciśnij **Zainstaluj**. Przy
   ostrzeżeniu Play Protect wybierz **Zainstaluj mimo to**.
5. Przy pierwszym uruchomieniu aplikacja zapyta o wygląd:
   - **Prosty** — duże przyciski, duże litery, mało pisania;
   - **Nowoczesny** — dolny pasek zakładek, podsumowanie sezonu na starcie.

   Wybierz ten, który Ci bardziej pasuje. Można zmienić później.

### Gdy coś idzie nie tak

| Co widać | Co zrobić |
| --- | --- |
| Pasek doszedł do końca, ale okienko dalej pisze „Pobieram…" | To przeglądarka Messengera/Facebooka. Zajrzyj do **Pliki → Pobrane** — plik często już tam jest. Jeśli nie, pobierz z Chrome. |
| „Plik może być niebezpieczny" | Rozwiń pobieranie u dołu ekranu → **Zachowaj mimo to**. |
| Pobieranie zrywa się w połowie | Pobieraj przy Wi-Fi i weź mniejszy plik `-arm64`. |
| „Aplikacja nie została zainstalowana" | Pobierz plik **bez** dopiska `-arm64`. |

### Nowa wersja — jak zaktualizować bez utraty danych

Wersja testowa nie ma jeszcze stałego podpisu, więc nowej nie da się
nałożyć na starą. Kolejność:

1. **Zrób kopię danych** (Prosty: ikona ciągnika → Gospodarstwo → Kopia
   danych → Zrób kopię; Nowoczesny: kółko zębate → Kopia danych → Zrób
   kopię). Zapisz plik tam, gdzie go znajdziesz (np. Pobrane).
2. Odinstaluj starą aplikację.
3. Zainstaluj nową (jak wyżej).
4. **Wczytaj kopię** (ten sam ekran co w punkcie 1).

## 2. Gdzie co jest

### Wygląd Prosty

Ekran główny to cztery duże kafelki:

| Kafelek | Co tam jest |
| --- | --- |
| **Pola** | lista pól, dodawanie pola, „Działki i mapa", „Nawożenie", „Wczytaj wniosek z PDF" |
| **Dodaj zabieg** | wpis oprysku, nawożenia, siewu, zbioru |
| **Terminy** | co trzeba zrobić i do kiedy; stąd też „Warunkowość" (normy GAEC) |
| **Dokumenty** | rejestr zabiegów, podgląd wpisów, „Wydruk i eksport" |

W prawym górnym rogu jest **ikona ciągnika** → ekran **Gospodarstwo**:
dane gospodarstwa (dotknij nazwy, żeby poprawić), zwierzęta, wygląd,
**Magazyn**, **Kopia danych**, **Słowniczek**, numer wersji.

### Wygląd Nowoczesny

Dolny pasek: **Start · Pola · Terminy · Dokumenty**, a na środku duży
przycisk **Dodaj zabieg**. W prawym górnym rogu **kółko zębate** →
**Ustawienia** (dane gospodarstwa, zwierzęta, wygląd, magazyn, kopia
danych, słowniczek, numer wersji).

W tej instrukcji piszemy skrótem „Ustawienia" — w wyglądzie Prostym to ekran
„Gospodarstwo" pod ikoną ciągnika.

## 3. Pierwsze kroki — po kolei

### 3.1 Dane gospodarstwa

Ustawienia → dotknij nazwy gospodarstwa. Wpisz nazwę, właściciela, numer
producenta, powierzchnię użytków rolnych. Te dane stoją na każdym wydruku
i od powierzchni zależy, które obowiązki program włącza. Tam też odpowiedz,
czy masz zwierzęta.

### 3.2 Dodaj pole

Pola → **Dodaj pole**: wpisz nazwę (np. „Za stodołą"), ustaw powierzchnię
przyciskami **+** i **−**, wybierz uprawę z listy (szukaj po kilku literach,
bez polskich znaków też zadziała: „psz ozim"). Gdy Twojej uprawy nie ma —
wpisz własną nazwę; program powie, że nie ma dla niej kodu EPPO i na wydruku
wyjdzie „brak". Dla łąk i pastwisk wybierz uprawę **Trawy**.

Po otwarciu pola możesz: **zmienić uprawę** (po zbiorze), **zmienić nazwę
pola**, ustawić **rodzaj użytku** (grunt orny / łąka lub pastwisko / sad),
odpowiedzieć na pytanie o **wodę przy polu** i dopisać, co rosło
w poprzednich latach.

### 3.3 Dodaj działkę (granice z mapy)

Pola → **Działki i mapa** → **Dodaj działkę**. Trzy drogi:

- **Z wniosku PDF** (Pola → Wczytaj wniosek z PDF): wskaż plik wniosku
  z eWniosekPlus — program wczyta działki i pola. Nic nie jest wysyłane;
  plik czytany jest w telefonie.
- **Mam pełny numer z wniosku**: przepisz numer w postaci
  `061506_2.0007.138` dużą klawiaturą.
- **Znajdź działkę po miejscowości** (dzierżawa, zakup po złożeniu wniosku):
  dotknij województwa, wpisz nazwę wsi z umowy i numer działki → **Znajdź
  działkę**. Gdy w kraju jest kilka takich działek, zobaczysz listę gmin —
  dotknij swojej.

Każda droga kończy się **mapą do potwierdzenia** („Czy to ta działka?").
Do pobrania granic potrzebny jest internet — jeden raz. Potem mapa działa
bez sieci.

### 3.4 Wpis oprysku — najważniejsze

**Dodaj zabieg → pole → Oprysk → środek → Zapisz.** Pięć dotknięć, bez
klawiatury. Data, godzina i powierzchnia uzupełniają się same. Dawka jest
podpowiedziana z rejestru środków; zmienisz ją przyciskami **+** / **−**.

- Jeśli ustawisz dawkę powyżej dopuszczalnej — zobaczysz ostrzeżenie, ale
  zapis nie jest blokowany (dokumentacja ma być prawdziwa).
- Jeśli rejestr **nie podaje dawki** dla środka — program mówi to wprost
  i daje wpisać dawkę z etykiety: liczba zaczyna od zera, jednostkę (l/ha,
  kg/ha…) wybierasz z listy.
- Po zapisie widzisz **karencję** i najwcześniejszy dzień zbioru. Gdy
  rejestr karencji nie zna — program każe sprawdzić etykietę i **nie wstawia
  żadnej liczby**.
- Zamiast szukać środka na liście możesz nacisnąć **Rozpoznaj etykietę**
  i zrobić zdjęcie opakowania.

### 3.5 Nawożenie

Dodaj zabieg → pole → **Nawożenie** → nawóz → dawka → Zapisz. Nawozy
dodajesz w Pola → Nawożenie → **Nawozy** → **Dodaj nawóz** (mineralny albo
naturalny, z zawartością azotu; worek można sfotografować — **Odczytaj
z worka**). Program liczy azot na hektar i pokazuje, ile zostało do limitu.
Przy nawożeniu po terminie granicznym dla Twojej gminy ostrzega.

### 3.6 Siew, zbiór, inne prace

Dodaj zabieg → pole → **Siew** / **Zbiór** / **Inny**. Przy „Inny" program
pyta, co dokładnie robisz (np. przycinanie drzew) — od tego zależy
ostrzeżenie o okresie lęgowym ptaków.

### 3.7 Rejestr: podgląd, poprawka, cofnięcie

Dokumenty → lista wpisów → dotknij wpisu → **Popraw wpis** albo **Cofnij
wpis**. Nic nie znika: poprzednia wersja zostaje w dzienniku zmian (tak
wymaga kontrola).

### 3.8 Wydruk i eksport

Dokumenty → **Wydruk i eksport** → wybierz rok → **Wydrukuj**, **Plik PDF**,
**Plik CSV** albo **Plik XLSX**. Braki w ewidencji (np. brak dawki) program
pokazuje przed wydrukiem. To samo dla warunkowości: Terminy → Warunkowość
→ Zapisz PDF.

### 3.9 Terminy i warunkowość

**Terminy** pokazują obowiązki, które dotyczą Twojego gospodarstwa (zależą
od powierzchni, upraw i zwierząt), oraz karencje z Twoich zabiegów. Termin
po czasie jest wyróżniony. **Warunkowość** (przycisk na ekranie Terminy)
to normy GAEC: każda ma stan, a ta, której program nie umie policzyć, mówi
„do sprawdzenia" — nie udaje spełnionej.

### 3.10 Magazyn, kopia, słowniczek

- **Magazyn** (Ustawienia): zakup środka lub nawozu, stan; zużycie zdejmuje
  się samo po wpisie zabiegu. Magazyn nie zmienia nic w ewidencji.
- **Kopia danych** (Ustawienia): **Zrób kopię** zapisuje wszystko do jednego
  pliku; **Wczytaj kopię** przywraca; **Dołącz dane z drugiego urządzenia**
  scala wpisy z innego telefonu albo komputera — nowszy wpis wygrywa,
  starszy zostaje w dzienniku.
- **Słowniczek** (Ustawienia): co znaczą TUZ, GAEC, DJP, EPPO, ULDK.

## 4. Co działa bez internetu

Wszystko poza trzema rzeczami: pobranie granic nowej działki, pogoda,
wiadomości. Gdy czegoś nie da się zrobić bez sieci, program mówi to jednym
zdaniem i nie blokuje reszty.

## 5. Numer wersji

Ustawienia → wiersz „Agro Asystent • Wersja 0.2.0 (budowa 2)". Podaj go
w każdym zgłoszeniu.
