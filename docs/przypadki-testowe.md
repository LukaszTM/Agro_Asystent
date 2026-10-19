# Przypadki testowe — wersja 0.2.0

Plan i zasady prowadzenia testów: `docs/plan-testow-manualnych.md`.
Priorytety: **A** blokujący, **B** poważny, **C** niewygoda.

Oznaczenia obszarów: INS instalacja · POL pola i działki · WPI wpis
zabiegu · NAW nawożenie · TER terminy · WAR warunkowość · DOK dokumenty ·
MAG magazyn · KOP kopia i dwa urządzenia · OFF bez internetu ·
PRE darmowe i płatne · ERG ergonomia · PC program na Windows.

---

## INS — instalacja i start

### INS-01 — Pierwsza instalacja z pliku (A)
**Warunki:** telefon bez aplikacji.
**Kroki:** 1. Pobrać plik APK w Chrome. 2. Otworzyć pobrany plik.
3. Zezwolić na instalację z nieznanych źródeł. 4. Przy ostrzeżeniu Play
Protect wybrać „Zainstaluj mimo to". 5. Uruchomić aplikację.
**Oczekiwane:** aplikacja wstaje, pyta o wygląd (Prosty / Nowoczesny),
po wyborze pokazuje ekran główny. Nie żąda logowania ani internetu.

### INS-02 — Wybór wyglądu zostaje po zamknięciu (B)
**Kroki:** wybrać wygląd Prosty → zamknąć aplikację z listy zadań →
otworzyć od nowa.
**Oczekiwane:** ten sam wygląd, bez pytania od nowa.

### INS-03 — Zmiana wyglądu w ustawieniach (C)
**Kroki:** Ustawienia → Wygląd → wybrać drugi.
**Oczekiwane:** cała aplikacja przechodzi na nowy wygląd od razu, dane
zostają bez zmian (pola, wpisy).

### INS-04 — Numer wersji widoczny dla testera (B)
**Kroki:** Ustawienia → zjechać na sam dół.
**Oczekiwane:** napis „Mój Łan • Wersja 0.2.0 (budowa 2)".

### INS-05 — Aktualizacja na wierzch poprzedniej (A)
**Warunki:** zainstalowana wcześniejsza wersja **podpisana tym samym
kluczem** i kilka wpisów w bazie.
**Kroki:** zainstalować nowszy plik bez odinstalowania starego.
**Oczekiwane:** instalacja przechodzi, **wszystkie wpisy, pola
i ustawienia zostają**. Nic nie znika i nie dubluje się.
*Uwaga: przy pliku podpisanym kluczem debugowym ten przypadek wypadnie —
Android odmówi instalacji. To znany stan, nie błąd (patrz
`docs/wydanie-android.md`).*

---

## POL — pola i działki

### POL-01 — Dodanie pola bez klawiatury (A)
**Kroki:** Pola → Dodaj pole → wybrać uprawę z listy → ustawić
powierzchnię przyciskami „+" i „−" → Zapisz.
**Oczekiwane:** pole na liście z nazwą, uprawą i powierzchnią w ha.
Klawiatura nie była potrzebna (nazwa może zostać domyślna).

### POL-02 — Uprawa spoza słownika (B)
**Kroki:** dodając pole, wpisać uprawę, której nie ma na liście.
**Oczekiwane:** aplikacja przyjmuje własną nazwę i **nie wymyśla kodu
EPPO** — na wydruku w kolumnie kodu stoi „brak", nie przypadkowy kod.

### POL-03 — Działka po numerze z ULDK (A)
**Warunki:** internet włączony, numer działki z wypisu.
**Kroki:** Pola → Działki → Dodaj działkę po numerze → wpisać numer →
Szukaj → obejrzeć kształt na mapie → Zapisz.
**Oczekiwane:** kształt i położenie zgadzają się z rzeczywistością,
działka ląduje na liście, numer się zgadza.

### POL-04 — Zły numer działki (B)
**Kroki:** wpisać numer z literówką.
**Oczekiwane:** jedno zdanie, co poszło nie tak, i co zrobić. Aplikacja
**nie pokazuje przypadkowej działki**.

### POL-05 — ULDK niedostępne (B)
**Kroki:** wyłączyć internet → spróbować dodać działkę po numerze.
**Oczekiwane:** komunikat o braku połączenia z podpowiedzią, reszta
aplikacji działa dalej.

### POL-06 — Mapa działek bez internetu (A)
**Warunki:** działka z granicami pobrana wcześniej.
**Kroki:** włączyć tryb samolotowy → otworzyć mapę.
**Oczekiwane:** granice rysują się tak samo jak z internetem.

### POL-07 — Wczytanie wniosku z PDF (A, premium)
**Warunki:** premium włączone, plik wniosku z eWniosekPlus.
**Kroki:** Pola → Wczytaj wniosek z PDF → wybrać plik → sprawdzić
podsumowanie → Zapisz.
**Oczekiwane:** liczba działek i pól zgadza się z wnioskiem;
powierzchnie co do ara; uprawy bez kodu EPPO są **wymienione z nazwy**,
a nie po cichu uzupełnione.

### POL-08 — Wniosek wczytany dwa razy (B)
**Kroki:** wczytać ten sam plik ponownie.
**Oczekiwane:** pola nie dublują się; podsumowanie mówi, ile wpisów
uzupełniono, a ile dodano.

### POL-09 — Nie-wniosek zamiast wniosku (B)
**Kroki:** wybrać zdjęcie albo inny PDF.
**Oczekiwane:** „Nie udało się odczytać tego pliku" + podpowiedź, żeby
wziąć plik z eWniosekPlus. Bez wysypania aplikacji.

### POL-10 — Rodzaj użytku i woda przy polu (B)
**Kroki:** otworzyć pole → ustawić rodzaj użytku → odpowiedzieć na
pytanie o wodę.
**Oczekiwane:** odpowiedzi zostają po wyjściu z ekranu; dopóki ich nie
ma, warunkowość pokazuje „do sprawdzenia", a nie „spełniona".

---

## WPI — wpis zabiegu

### WPI-01 — Oprysk w pięciu dotknięciach (A)
**Warunki:** jedno pole z uprawą.
**Kroki:** Dodaj zabieg → pole → Oprysk → środek z listy → dawka →
Zapisz.
**Oczekiwane:** wpis zapisany; data, godzina i powierzchnia uzupełnione
same; **liczba dotknięć ≤ 5**, klawiatura niepotrzebna.

### WPI-02 — Karencja z etykiety (A)
**Kroki:** przy wpisie oprysku podać karencję ręcznie.
**Oczekiwane:** aplikacja liczy dzień, od którego wolno zbierać,
i pokazuje go wprost. **Nie zgaduje** karencji, gdy jej nie podano —
pole zostaje puste i oznaczone „do potwierdzenia".

### WPI-03 — Wpis nawożenia (A)
**Kroki:** Dodaj zabieg → pole → Nawożenie → nawóz → dawka → Zapisz.
**Oczekiwane:** wpis w rejestrze nawożenia; przeliczenie azotu widoczne.

### WPI-04 — Inny zabieg: siew, zbiór, uprawa gleby (B)
**Kroki:** Dodaj zabieg → pole → wybrać „Siew" (potem „Zbiór").
**Oczekiwane:** wpis zapisuje się bez pytania o środek i dawkę; nie jest
oznaczony jako niekompletny w rejestrze oprysków.

### WPI-05 — Poprawienie wpisu zostawia ślad (A)
**Kroki:** Rejestr → wybrać wpis → Popraw → zmienić dawkę → Zapisz.
**Oczekiwane:** rejestr pokazuje nową wartość; **poprzednia wersja nie
znika z historii** (wpisy są dopisywane, nie nadpisywane).

### WPI-06 — Cofnięcie wpisu (B)
**Kroki:** Rejestr → wpis → Cofnij / Usuń.
**Oczekiwane:** wpis znika z rejestru i z wydruku, ale zostaje ślad
w dzienniku zmian.

### WPI-07 — Przerwany wpis (B)
**Kroki:** zacząć wpis, w połowie zamknąć aplikację z listy zadań,
otworzyć od nowa.
**Oczekiwane:** aplikacja wstaje bez błędu; niedokończony wpis nie
trafia do rejestru jako połowiczny.

### WPI-08 — Brak oferty premium w trakcie wpisu (A)
**Kroki:** przejść cały wpis zabiegu w wersji darmowej.
**Oczekiwane:** **ani jednego okna ani zachęty do zakupu** po drodze
(plan, pkt 8).

### WPI-09 — Ostrzeżenie o pasie od wody (A)
**Warunki:** pole z odpowiedzią „graniczy z wodą: tak".
**Kroki:** zapisać na nim oprysk (potem nawożenie).
**Oczekiwane:** przed zapisem staje ostrzeżenie o pasie bez środków
i nawozów od brzegu wody, z podaną szerokością ze słownika reguł. Wpis
da się zapisać mimo ostrzeżenia.

### WPI-10 — Ostrzeżenie w okresie lęgowym (B)
**Kroki:** zapisać pracę w elementach krajobrazu (np. wycinka,
przycinanie żywopłotu) w terminie objętym zakazem.
**Oczekiwane:** ostrzeżenie mówi, czego dotyczy zakaz i do kiedy trwa.
Poza terminem zakazu — żadnego ostrzeżenia.

---

## NAW — nawożenie i azot

### NAW-01 — Limit azotu z nawozów naturalnych (A)
**Warunki:** gospodarstwo z zapisanym nawożeniem naturalnym.
**Kroki:** Nawożenie → zestawienie azotu.
**Oczekiwane:** liczba kilogramów azotu na hektar zgadza się z ręcznym
przeliczeniem (dawka × zawartość N ÷ powierzchnia); przekroczenie limitu
jest oznaczone.

### NAW-02 — Termin stosowania nawozów azotowych (A)
**Kroki:** zapisać nawożenie azotowe w dniu poza okresem dozwolonym →
otworzyć ekran Nawożenie i zakładkę Terminy.
**Oczekiwane:** aplikacja ostrzega — jedno zdanie, co jest nie tak,
i co zrobić. Wpis **mimo to da się zapisać**: dokumentujemy
rzeczywistość, nie blokujemy rolnika. Termin pokazany jest z dopiskiem
„do weryfikacji", jeśli tak stoi w słowniku reguł.

### NAW-03 — Własny nawóz (B)
**Kroki:** Nawozy → Nowy nawóz → nazwa i zawartość azotu z worka →
Zapisz.
**Oczekiwane:** nawóz na liście; przy wpisie liczy się z podanej
zawartości.

---

## TER — terminy

### TER-01 — Lista terminów odpowiada gospodarstwu (A)
**Kroki:** Terminy.
**Oczekiwane:** są tylko obowiązki, które dotyczą tego gospodarstwa
(powierzchnia, uprawy, zwierzęta). Obowiązki niepewne mają dopisek, że
są do sprawdzenia — nie są pokazywane jako pewne.

### TER-02 — Karencja po oprysku trafia do terminów (A)
**Kroki:** zapisać oprysk z karencją → otworzyć Terminy.
**Oczekiwane:** pozycja z dniem, od którego wolno zbierać, przypisana do
właściwego pola.

### TER-03 — Termin po czasie jest wyróżniony (B)
**Oczekiwane:** pozycje po terminie widać na pierwszy rzut oka
(wyróżnienie, nie tylko data).

### TER-04 — Powiadomienie przychodzi (B)
**Warunki:** przypomnienia włączone, zezwolenie na powiadomienia.
**Kroki:** ustawić przypomnienie, zostawić telefon do następnego dnia.
**Oczekiwane:** powiadomienie przychodzi; kliknięcie otwiera właściwy
ekran. *Sprawdzić też przy włączonym oszczędzaniu energii.*

---

## WAR — warunkowość (GAEC)

### WAR-01 — Przegląd norm (A)
**Kroki:** Terminy → Warunkowość.
**Oczekiwane:** każda norma ma stan: spełniona / do sprawdzenia /
niespełniona, a przy „do sprawdzenia" stoi, **czego brakuje**.

### WAR-02 — Brak danych nie udaje spełnienia (A)
**Warunki:** pole bez rodzaju użytku.
**Oczekiwane:** normy zależne od rodzaju użytku są „do sprawdzenia",
nigdy „spełnione".

### WAR-03 — Wydruk warunkowości (B)
**Kroki:** Warunkowość → Wydrukuj / Eksport.
**Oczekiwane:** dokument zawiera stan każdej normy i zastrzeżenie, że
stan policzyła aplikacja.

---

## DOK — dokumenty, wydruk i eksport

### DOK-01 — Trzy rejestry są darmowe (A)
**Warunki:** wersja **bez** premium.
**Kroki:** Dokumenty → kolejno Opryski, Nawożenie azotem, Ekoschematy.
**Oczekiwane:** wszystkie trzy otwierają się, pokazują kolumny z przepisu
i **żaden nie jest zablokowany za opłatą**.

### DOK-02 — Wydruk PDF (A)
**Kroki:** Dokumenty → Opryski → Wydrukuj.
**Oczekiwane:** otwiera się podgląd wydruku systemu; polskie znaki są
poprawne; nagłówek ma nazwę gospodarstwa i numer producenta.

### DOK-03 — Eksport CSV i XLSX (A)
**Kroki:** Dokumenty → Plik CSV → zapisać; to samo dla XLSX.
**Oczekiwane:** plik otwiera się w arkuszu (Excel, LibreOffice, Arkusze
Google); polskie znaki i przecinki dziesiętne poprawne; liczba wierszy
zgadza się z rejestrem.

### DOK-04 — Braki w ewidencji widać przed wydrukiem (B)
**Warunki:** wpis bez pola wymaganego przepisem.
**Oczekiwane:** wiersz jest oznaczony jako niekompletny w podglądzie,
a nie dopiero po wydrukowaniu.

### DOK-05 — Wybór okresu (C)
**Kroki:** przełączyć rok / „Wszystkie lata".
**Oczekiwane:** zestawienie zmienia się zgodnie z wyborem.

---

## MAG — magazyn (premium)

### MAG-01 — Bez premium magazyn mówi wprost (B)
**Oczekiwane:** ekran wyjaśnia, że to dodatek płatny, **i jak poradzić
sobie bez niego** — bez blokowania dokumentacji.

### MAG-02 — Zakup i stan (B, premium)
**Kroki:** Magazyn → Dodaj zakup → ilość i cena → Zapisz.
**Oczekiwane:** stan rośnie o zakupioną ilość; wartość zakupów się
zgadza.

### MAG-03 — Zużycie po zabiegu (B, premium)
**Kroki:** zapisać oprysk środkiem, który jest w magazynie.
**Oczekiwane:** stan maleje o zużytą ilość; ten sam zabieg **nie odpisuje
towaru dwa razy** po ponownym otwarciu ekranu.

### MAG-04 — Magazyn nie wpływa na ewidencję (A, premium)
**Kroki:** doprowadzić stan do zera i zapisać kolejny oprysk.
**Oczekiwane:** zabieg zapisuje się normalnie; magazyn pokazuje stan
ujemny albo ostrzeżenie, ale **nie blokuje wpisu**.

---

## KOP — kopia danych i dwa urządzenia

### KOP-01 — Kopia jest darmowa (A)
**Warunki:** wersja bez premium.
**Kroki:** Ustawienia → Kopia danych → Zrób kopię.
**Oczekiwane:** plik powstaje i da się go zapisać (dysk, poczta,
chmura).

### KOP-02 — Odtworzenie kopii na czystym telefonie (A)
**Kroki:** odinstalować i zainstalować od nowa → Wczytaj kopię.
**Oczekiwane:** pola, wpisy i ustawienia wracają w komplecie.

### KOP-03 — Dołączenie danych z drugiego urządzenia (A)
**Warunki:** dwa urządzenia z własnymi wpisami.
**Kroki:** zrobić kopię na telefonie → na komputerze „Dołącz dane
z telefonu".
**Oczekiwane:** wpisy z obu stron są razem; **nic nie ginie**; przy
sprzeczności nowszy wpis wygrywa, a starszy zostaje w dzienniku zmian —
podsumowanie mówi, ile czego doszło.

### KOP-04 — Obcy plik (B)
**Kroki:** wskazać plik, który nie jest kopią aplikacji.
**Oczekiwane:** „To nie jest kopia z tej aplikacji" + podpowiedź; baza
bez zmian.

### KOP-05 — Kopia z nowszej wersji (B)
**Oczekiwane:** komunikat, żeby zaktualizować program; dane bez zmian.

---

## OFF — bez internetu

### OFF-01 — Cała dokumentacja działa offline (A)
**Kroki:** tryb samolotowy → dodać pole, zapisać oprysk i nawożenie,
otworzyć rejestr, zrobić wydruk i eksport, zrobić kopię.
**Oczekiwane:** wszystko działa bez jednego komunikatu o braku sieci.

### OFF-02 — Pogoda bez sieci (B)
**Warunki:** pogoda pobrana wcześniej (program na PC).
**Kroki:** odciąć internet → otworzyć pulpit.
**Oczekiwane:** karta pokazuje **ostatni odczyt z datą i godziną**, a nie
pustkę i nie zmyślone liczby.

### OFF-03 — Wiadomości bez sieci (C)
**Oczekiwane:** ostatnio pobrane nagłówki z datą pobrania albo jedno
zdanie, że żadne źródło nie odpowiedziało.

---

## PRE — co darmowe, co płatne

> **Uwaga: plik rozdawany testerom ma odblokowane wszystkie dodatki**,
> więc tych przypadków **nie da się na nim sprawdzić**. Potrzebny jest
> plik zbudowany bez odblokowania: Actions → „Zbuduj APK" → Run workflow
> → odznaczyć **„Wydanie testowe — wszystkie dodatki odblokowane"**.
> Zachowanie wersji darmowej pilnują też testy automatyczne
> (`test/rdzen/dostep/`), ale wygląd ekranów trzeba obejrzeć okiem.

### PRE-01 — Dokumentacja nigdy za opłatą (A)
**Warunki:** wersja bez premium.
**Oczekiwane:** wpisy, trzy rejestry, wydruk PDF, eksport CSV/XLSX,
kopia danych i dodawanie działek po numerze działają **w całości**.

### PRE-02 — Funkcja płatna tłumaczy się po ludzku (B)
**Kroki:** dotknąć funkcji płatnej (wniosek z PDF, magazyn, odczyt
zdjęcia).
**Oczekiwane:** wyjaśnienie, czego dotyczy dodatek **i jak zrobić to samo
bez opłaty**; nigdzie słowa „kup" w trakcie pracy.

### PRE-03 — Drugie gospodarstwo (C)
**Oczekiwane:** pierwsze gospodarstwo działa w całości; przy próbie
dodania drugiego — wyjaśnienie, że to dodatek płatny.

---

## ERG — ergonomia (wygląd Prosty, rolnik 60+)

### ERG-01 — Czytelność w słońcu (B)
**Kroki:** wyjść z telefonem na zewnątrz w pełnym słońcu.
**Oczekiwane:** tekst i przyciski czytelne; nic nie ginie w jasnym tle.

### ERG-02 — Obsługa w rękawicy roboczej (B)
**Oczekiwane:** przyciski da się trafić palcem w rękawicy — cele są
wystarczająco duże i odstępy nie mylą sąsiednich.

### ERG-03 — Największa czcionka systemu (B)
**Kroki:** ustawić w Androidzie największy rozmiar tekstu → przejść
wszystkie ekrany.
**Oczekiwane:** nic nie ucieka poza ekran, nie ma uciętych napisów ani
nachodzących przycisków.

### ERG-04 — Język rolnika (C)
**Oczekiwane:** na ekranach stoi „oprysk", a nie „zabieg środkiem ochrony
roślin"; nazwy urzędowe tylko na wydrukach.

### ERG-05 — Każde ostrzeżenie mówi, co zrobić (B)
**Oczekiwane:** żadne ostrzeżenie nie kończy się na stwierdzeniu
problemu — zawsze jest zdanie, co z tym zrobić.

---

## PC — program na Windows

### PC-01 — Uruchomienie z rozpakowanego folderu (A)
**Kroki:** rozpakować paczkę → uruchomić `moj_lan.exe` → przy
SmartScreenie „Więcej informacji" → „Uruchom mimo to".
**Oczekiwane:** program wstaje w oknie 1280×720, otwiera się na Pulpicie.

### PC-02 — Uruchomienie z wnętrza archiwum (C)
**Kroki:** kliknąć `.exe` bez rozpakowania.
**Oczekiwane:** program nie wstaje — to oczekiwane; sprawdzamy, czy
instrukcja o tym ostrzega (bo tak zrobi połowa testerów).

### PC-03 — Pulpit pokazuje gospodarstwo (B)
**Warunki:** dane dołączone z telefonu.
**Oczekiwane:** wykres zasiewów zgadza się z listą pól; mapka rysuje
działki; terminy te same co w telefonie.

### PC-04 — Dodanie pola z klawiatury (B)
**Kroki:** Pola → Dodaj pole → wpisać nazwę, uprawę, powierzchnię.
**Oczekiwane:** pole w tabeli; powierzchnia zapisana co do ara
(„3,40 ha" → 340 arów).

### PC-05 — Dane gospodarstwa (B)
**Kroki:** Ustawienia → Popraw dane gospodarstwa.
**Oczekiwane:** nazwa zmienia się od razu w nagłówku programu i na
wydrukach.

### PC-06 — Wydruk i eksport z komputera (A)
**Oczekiwane:** ten sam dokument co z telefonu; plik otwiera się
w arkuszu.

### PC-07 — Wielkość tekstu (B)
**Kroki:** Ustawienia → Bardzo duży → przejść wszystkie zakładki.
**Oczekiwane:** układ nie rozsypuje się, nic nie jest ucięte.

### PC-08 — Wąskie okno (C)
**Kroki:** zwęzić okno poniżej mniej więcej 1000 px.
**Oczekiwane:** nawigacja zwija się do ikon, treść zostaje czytelna.

### PC-09 — Kalendarz biodynamiczny z zastrzeżeniem (B)
**Oczekiwane:** na karcie stoi, że to tradycja, a nie przepis;
rozwinięcie na miesiąc działa; **żaden termin z przepisów nie jest
liczony z Księżyca**.

### PC-10 — Ceny skupu bez notowań (B)
**Oczekiwane:** karta mówi wprost, że notowań nie wczytano, i nie
pokazuje żadnej liczby.

---

## Skrót: przypadki priorytetu A

INS-01, INS-05, POL-01, POL-03, POL-06, POL-07, WPI-01, WPI-02, WPI-03,
WPI-05, WPI-08, WPI-09, NAW-01, NAW-02, TER-01, TER-02, WAR-01, WAR-02, DOK-01,
DOK-02, DOK-03, MAG-04, KOP-01, KOP-02, KOP-03, OFF-01, PRE-01, PC-01,
PC-06.

Te muszą przejść na **co najmniej dwóch różnych telefonach**, zanim
wersja pójdzie szerzej.
