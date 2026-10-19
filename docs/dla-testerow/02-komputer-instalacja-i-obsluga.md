# Komputer (Windows) — instalacja i obsługa

## 1. Instalacja (5 minut)

1. Otwórz w przeglądarce:
   **https://github.com/LukaszTM/Agro_Asystent/releases/tag/pc-test**
2. Pobierz plik `agro-asystent-windows-0.2.0+2.zip` (20 MB).
3. **Rozpakuj cały folder** (prawy przycisk → Wyodrębnij wszystko). Nie
   uruchamiaj programu z wnętrza archiwum — obok `agro_asystent.exe` leżą
   biblioteki, bez których program nie wstanie.
4. Uruchom `agro_asystent.exe`.
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
| **Pola** | lista pól, dodawanie pola, „Działka po numerze", „Wczytaj wniosek z PDF"; po wybraniu pola — rodzaj użytku, woda przy polu, zmiana nazwy |
| **Rejestr zabiegów** | wszystkie wpisy z telefonu |
| **Terminy** | co trzeba zrobić i do kiedy |
| **Warunkowość** | normy GAEC ze stanem, wydruk i eksport |
| **Dokumenty** | trzy rejestry: Wydrukuj, Zapisz PDF, Zapisz CSV, Zapisz XLSX |
| **Magazyn** | stan środków i nawozów |
| **Ustawienia** | wielkość tekstu, dane gospodarstwa, kopia i dane z telefonu, słowniczek, numer wersji |

**Na komputerze nie wpisuje się zabiegów.** Wpisy robi się na telefonie
(w polu), a na komputer przenosi plikiem kopii — patrz punkt 3.5.

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

### 3.5 Dane z telefonu

Na telefonie: Ustawienia → Kopia danych → **Zrób kopię** → zapisz plik
(np. wyślij sobie mailem albo wgraj na dysk w chmurze). Na komputerze:
Ustawienia → **Dołącz dane z telefonu** → wskaż ten plik. Nic nie znika:
nowszy wpis wygrywa, starszy zostaje w dzienniku zmian; program mówi, ile
wpisów doszło.

W drugą stronę tak samo: Ustawienia → **Zrób kopię** na komputerze, na
telefonie **Dołącz dane z drugiego urządzenia**.

### 3.6 Wydruk i eksport

Dokumenty → przy rejestrze **Wydrukuj** / **Zapisz PDF** / **Zapisz CSV** /
**Zapisz XLSX**. Otwórz PDF w czytniku i sprawdź polskie znaki oraz czy
tabela się nie rozjeżdża. CSV i XLSX otwórz w Excelu albo LibreOffice.

### 3.7 Terminy, warunkowość, magazyn

Jak na telefonie: terminy zależą od danych gospodarstwa; warunkowość pokazuje
każdą normę GAEC ze stanem („do sprawdzenia" tam, gdzie program nie umie
policzyć); magazyn trzyma stany środków i nawozów.

## 4. Numer wersji

Ustawienia → karta „O programie" → „Agro Asystent • Wersja 0.2.0 (budowa
2)". Podaj go w zgłoszeniu.
