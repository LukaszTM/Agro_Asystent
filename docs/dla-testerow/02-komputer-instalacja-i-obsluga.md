# Komputer (Windows) — instalacja i obsługa

## 1. Instalacja (5 minut)

1. Otwórz w przeglądarce:
   **https://github.com/LukaszTM/Agro_Asystent/releases/tag/pc-test**
2. Pobierz plik `moj-lan-windows-0.2.0+2.zip` (20 MB).
3. **Rozpakuj cały folder** (prawy przycisk → Wyodrębnij wszystko). Nie
   uruchamiaj programu z wnętrza archiwum — obok `moj_lan.exe` leżą
   biblioteki, bez których program nie wstanie.
4. Uruchom `moj_lan.exe`.
5. Windows pokaże niebieskie okno SmartScreen („system Windows ochronił ten
   komputer"), bo program nie ma jeszcze podpisu wydawcy. Kliknij **Więcej
   informacji** → **Uruchom mimo to**. To znany stan wersji testowej.

Program nie instaluje się w systemie — można go przenieść albo usunąć,
kasując folder. Dane trzyma osobno, w profilu użytkownika.

Wymagania: Windows 10 albo 11, 64-bitowy.

## 2. Gdzie co jest

Po lewej stronie okna jest pasek zakładek:

| Zakładka | Co tam jest |
| --- | --- |
| **Pulpit** | pierwsza strona: wykres „Co rośnie" (zasiewy), mapa pól, najbliższe terminy, pogoda, ceny skupu, wiadomości, kalendarz biodynamiczny |
| **Pola** | lista pól, dodawanie pola, „Działka po numerze", „Wczytaj wniosek z PDF"; po wybraniu pola — „Dodaj zabieg", rodzaj użytku, woda przy polu, zmiana nazwy |
| **Rejestr zabiegów** | wszystkie wpisy (z telefonu i z komputera), przycisk **Dodaj zabieg** |
| **Terminy** | co trzeba zrobić i do kiedy |
| **Warunkowość** | normy GAEC ze stanem, wydruk i eksport |
| **Dokumenty** | trzy rejestry: Wydrukuj, Zapisz PDF, Zapisz CSV, Zapisz XLSX |
| **Magazyn** | stan środków i nawozów |
| **Ustawienia** | wielkość tekstu, dane gospodarstwa, kopia i dane z telefonu, słowniczek, numer wersji |

Zabiegi wpisuje się na telefonie (w polu) **albo na komputerze** — patrz
punkt 3.5. Wpisy z telefonu przenosi się na komputer plikiem kopii (3.6).

## 3. Pierwsze kroki — po kolei

### 3.1 Wielkość tekstu

Ustawienia → **Wielkość tekstu** → wybierz. Działa od razu w całym programie.
Monitory są różne — dobierz tak, żeby czytało się bez wysiłku.

### 3.2 Dane gospodarstwa

Ustawienia → **Popraw dane gospodarstwa**: nazwa, właściciel, numer
producenta, powierzchnia użytków rolnych, czy są zwierzęta. Te dane stoją na
wydrukach.

### 3.3 Pola i działki

- **Dodaj pole**: nazwa, uprawa z listy (albo własna nazwa — wtedy bez kodu
  EPPO), powierzchnia w hektarach (np. 2,35).
- **Działka po numerze**: dwie drogi — **Po miejscowości** (województwo,
  nazwa wsi z umowy, numer działki; gdy jest kilka gmin o tej wsi, wybierasz
  z listy) albo **Wpisz pełny numer** (`141201_2.0012.123/4`). Potem
  potwierdzenie na mapie. Potrzebny internet, jeden raz.
- **Wczytaj wniosek z PDF**: wskaż plik wniosku z eWniosekPlus — program
  wczyta działki i pola. Plik nie opuszcza komputera.

### 3.4 Pulpit

Po dodaniu pól zajrzyj na **Pulpit**: wykres zasiewów ma zgadzać się z listą
pól, mapa — z działkami. Pogoda i wiadomości wymagają internetu; bez sieci
karty mówią o tym jednym zdaniem. Ceny skupu w tej wersji są puste (program
pisze dlaczego). Kalendarz biodynamiczny ma oznaczenia jak w kalendarzu na ścianie:
rączka siewna (jedna — dobry dzień do siewu, dwie — bardzo dobry,
przekreślona — zły, bo tego dnia zmienia się faza Księżyca) oraz ikona,
co siać w tej kwadrze (liść, owoc, korzeń) albo szpadel, gdy to czas na
prace w glebie. Tydzień rozwija się do miesiąca. Zastrzeżenie, że to
tradycja, nie przepis, stoi na karcie zawsze.

### 3.5 Wpis zabiegu na komputerze

Rejestr zabiegów → **Dodaj zabieg** (albo Pola → wybierz pole → **Dodaj
zabieg** — wtedy pole jest już wybrane). Wszystko jest w jednym oknie:

- **Kiedy** — data i godzina z zegara komputera; kliknij, żeby zmienić
  (np. gdy dopisujesz zabiegi z kilku dni).
- **Co robisz** — Oprysk, Nawożenie, Siew, Zbiór, Uprawa gleby, Inny.
- **Pole** — jedno; w wersji płatnej kilka naraz (powierzchnia liczy się
  sama).
- **Oprysk**: szukaj środka po nazwie, kliknij go na liście. Dawka z rejestru
  jest podpowiedziana w polu tekstowym — wpisz własną z klawiatury
  (z przecinkiem, np. 0,6). Powyżej dopuszczalnej program ostrzega, ale nie
  blokuje. Gdy rejestr nie podaje dawki — wpisujesz ją z etykiety i wybierasz
  jednostkę.
- **Nawożenie**: nawóz ze spisu (spis uzupełnia się w telefonie), dawka
  z klawiatury, kg/ha albo t/ha; program liczy azot i ostrzega przed
  przekroczeniem tabeli. Przy oborniku i gnojowicy pytamy o **przyoranie**
  (jeszcze nie / tego samego dnia / nazajutrz / inna data).
- **Zapisz zabieg** — wpis od razu jest w tabeli; przy oprysku program
  podaje karencję i najwcześniejszy dzień zbioru.

Poprawki i cofanie wpisów robi się nadal w telefonie.

### 3.6 Dane z telefonu

Na telefonie: Ustawienia → Kopia danych → **Zrób kopię** → zapisz plik
(np. wyślij sobie mailem albo wgraj na dysk w chmurze). Na komputerze:
Ustawienia → **Dołącz dane z telefonu** → wskaż ten plik. Nic nie znika:
nowszy wpis wygrywa, starszy zostaje w dzienniku zmian; program mówi, ile
wpisów doszło.

W drugą stronę tak samo: Ustawienia → **Zrób kopię** na komputerze, na
telefonie **Dołącz dane z drugiego urządzenia**.

### 3.7 Wydruk i eksport

Dokumenty → przy rejestrze **Wydrukuj** / **Zapisz PDF** / **Zapisz CSV** /
**Zapisz XLSX**. Otwórz PDF w czytniku i sprawdź polskie znaki oraz czy
tabela się nie rozjeżdża. CSV i XLSX otwórz w Excelu albo LibreOffice.

### 3.8 Terminy, warunkowość, magazyn

Jak na telefonie: terminy zależą od danych gospodarstwa; warunkowość pokazuje
każdą normę GAEC ze stanem („do sprawdzenia" tam, gdzie program nie umie
policzyć); magazyn trzyma stany środków i nawozów.

## 4. Numer wersji

Ustawienia → karta „O programie" → „Mój Łan • Wersja 0.2.0 (budowa
2)". Podaj go w zgłoszeniu.
