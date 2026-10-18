# Agro Asystent — wersja testowa na telefon

Ten plik jest do przekazania osobom, które będą próbować aplikacji.
Na końcu jest gotowa wiadomość do skopiowania.

## Jak zainstalować (5 minut)

> **Najważniejsze na początek: nie klikaj linku wewnątrz Messengera ani
> Facebooka.** Otworzy się w ich własnej przeglądarce, pobieranie stanie
> na 100 % i plik nigdzie nie trafi. Skopiuj adres i wklej go w **Chrome**
> — albo w tym okienku naciśnij trzy kropki ⋮ → **Otwórz w Chrome**.

1. Otwórz **w Chrome**:
   **https://github.com/LukaszTM/Agro_Asystent/releases/tag/apk-test**
   (na telefonie pliki bywają schowane pod napisem **Assets** — trzeba go
   rozwinąć).
2. Naciśnij plik z dopiskiem **`-arm64`** — `agro-asystent-0.2.0+2-arm64.apk`.
   Waży 39 MB i wchodzi na telefony z ostatnich kilku lat. Obok leży plik
   bez dopiska: ten sam program, ale 101 MB; bierz go tylko wtedy, gdy
   mniejszy nie chce się zainstalować.
3. Android zapyta, czy zezwolić na instalację z tego miejsca
   („nieznane źródła"). Trzeba zezwolić — aplikacji nie ma jeszcze
   w sklepie Google Play.
4. Otwórz pobrany plik (**Pliki → Pobrane**) i naciśnij **Zainstaluj**.
   Jeśli pojawi się ostrzeżenie Play Protect, wybierz **Zainstaluj mimo
   to**.
5. Przy pierwszym uruchomieniu aplikacja zapyta o wygląd: **Prosty**
   (duże przyciski, dla osób, które nie przepadają za telefonem) albo
   **Nowoczesny**. Można to potem zmienić w ustawieniach.

### Gdy pobieranie staje i nie chce się skończyć

| Co widać | Co zrobić |
| --- | --- |
| Pasek doszedł do końca, ale okienko dalej pisze „Pobieram…" | To przeglądarka wbudowana w inną aplikację. Sprawdź **Pliki → Pobrane** — plik często już tam jest. Jeśli nie, pobierz jeszcze raz z Chrome. |
| „Plik może być niebezpieczny", Chrome przekreśla pobieranie | Rozwiń pobieranie u dołu ekranu → **Zachowaj mimo to**. |
| Pobieranie zrywa się w połowie | Weź mniejszy plik `-arm64` i pobieraj przy Wi-Fi. |
| „Aplikacja nie została zainstalowana" | Pobierz plik **bez** dopiska `-arm64` — ten wchodzi na każdy telefon. |

**Przy nowej wersji trzeba najpierw odinstalować starą.** Tak będzie do
czasu, aż aplikacja dostanie stały podpis wydawniczy. Odinstalowanie
kasuje też wpisy — w czasie testów warto więc najpierw zrobić kopię
danych (Ustawienia → Zrób kopię).

## W tej wersji masz odblokowane wszystko

Plik do testów jest zbudowany tak, że **wszystkie dodatki są włączone** —
wczytanie wniosku z PDF, odczyt zdjęcia etykiety, magazyn, plan
nawożenia, kilka gospodarstw. Chodzi o to, żebyś obejrzał całość
i powiedział, co jest warte pieniędzy, a co nie.

W wersji, którą dostanie rolnik, część z tych rzeczy będzie płatna.
**Nigdy płatna nie będzie dokumentacja**: wpisy, trzy rejestry, wydruk
PDF, eksport CSV/XLSX, kopia danych i dodawanie działek po numerze
zostają darmowe zawsze. Na ekranie Ustawień, pod numerem wersji, stoi
o tym jedno zdanie.

## Co warto sprawdzić

| Rzecz | Na co patrzeć |
| --- | --- |
| **Dodanie pola** | Czy da się dodać pole bez pisania na klawiaturze? Ile dotknięć zajmuje? |
| **Działka po numerze** | Wpisz numer działki z wypisu — czy pobiera granice i czy mapka pokazuje właściwy kształt? |
| **Wpis oprysku** | Najważniejsze: czy da się zapisać zabieg w pięciu dotknięciach, stojąc w polu? |
| **Nawożenie** | Czy limit azotu i terminy zgadzają się z tym, co wiesz? |
| **Terminy** | Czy aplikacja pokazuje obowiązki, które faktycznie Cię dotyczą? |
| **Wydruk i eksport** | Czy wydruk rejestru wygląda tak, jak trzeba go pokazać przy kontroli? |
| **Czytelność** | Czy tekst jest dość duży? Czy coś ucieka poza ekran? |

Wszystko działa **bez internetu**. Zasięg jest potrzebny tylko przy
pobieraniu granic działki, pogody i wiadomości.

> Testujesz „po kolei", a nie z głowy? Pełna lista przypadków jest
> w `docs/przypadki-testowe.md`, a zasady rundy w
> `docs/plan-testow-manualnych.md`. Rolnikowi nie są potrzebne — ta
> tabelka wyżej w zupełności wystarczy.

## O co prosimy w zgłoszeniu

1. Co robiłeś (np. „dodawałem oprysk na polu Za stodołą").
2. Co się stało i czego się spodziewałeś.
3. Numer wersji — stoi na dole ekranu Ustawienia („Agro Asystent •
   Wersja 0.2.0").
4. Model telefonu, jeśli łatwo go sprawdzić.

Zdjęcie ekranu mówi więcej niż opis — jeśli to możliwe, dołącz.

## Czego jeszcze nie ma (nie zgłaszaj tego jako usterki)

- **Cen skupu** — mechanizm jest, ale notowania nie są jeszcze wczytane.
- **Wysyłki zgłoszeń do IRZplus** i rejestru stada powiązanego z ekranami.
- **Zestawienia do wniosku** i „kompletu na kontrolę jednym przyciskiem".
- Na komputerze z Windows: wpisu zabiegu i poprawiania wpisów.

## Co aplikacja robi z danymi

Wszystko zostaje w telefonie. Nie ma konta, logowania ani serwera —
wpisy, pola i dokumenty leżą w pamięci urządzenia. Do internetu
aplikacja sięga tylko wtedy, gdy sam o to poprosisz: po granice działki
(państwowa usługa ULDK), po pogodę i po nagłówki wiadomości. Nic poza tym
nie jest nigdzie wysyłane.

## Gotowa wiadomość do wysłania

> Cześć, robię aplikację do prowadzenia dokumentacji gospodarstwa
> (zabiegi, nawożenie, terminy ARiMR) i szukam kilku osób do
> wypróbowania jej na telefonie.
>
> Instalacja: skopiuj ten adres i otwórz go **w Chrome** (nie klikaj
> wprost w Messengerze — tamtejsza przeglądarka nie dokańcza pobierania):
> https://github.com/LukaszTM/Agro_Asystent/releases/tag/apk-test
> Pobierz plik z dopiskiem **-arm64** (39 MB). Android zapyta, czy
> zezwolić na instalację spoza sklepu — trzeba zezwolić, bo aplikacji
> nie ma jeszcze w Google Play. Gdyby napisał „aplikacja nie została
> zainstalowana", weź ten drugi plik, bez dopiska.
>
> Wszystko działa bez internetu, nic nie trzeba zakładać ani podawać.
> Dane zostają w telefonie.
>
> Najbardziej zależy mi na jednym: spróbuj zapisać zabieg tak, jakbyś
> robił to w polu, i powiedz, co było niejasne albo za wolne. Każda
> uwaga się przyda, także „nie wiedziałem, co nacisnąć".
