# Weryfikacja współczynników DJP w rozporządzeniu

15 października 2026 r. Zamyka otwartą sprawę z kroku 9 etapu 1
(`etap1-krok9-zwierzeta.md`).

## Źródło

**Dz.U. 2020 poz. 243**, załącznik nr 1, **tabela 3** — „Współczynniki
przeliczeniowe sztuk rzeczywistych zwierząt gospodarskich na DJP"
z Programu działań mających na celu zmniejszenie zanieczyszczenia wód
azotanami pochodzącymi ze źródeł rolniczych (program azotanowy).

Dokument dostarczył właściciel projektu jako PDF (2 strony). Plik nie wchodzi
do repozytorium — jest aktem prawnym do pobrania ze strony rządowej,
a repozytorium trzyma tylko wynik odczytu w słowniku reguł.

## Jak sprawdzaliśmy

Powstał skrypt `tools/djp/wspolczynniki_djp.py` (Python, `pdfplumber`),
uruchamiany **na komputerze dewelopera** (CLAUDE.md, reguła 3):

1. Tabela 85 grup jest w skrypcie przepisana z rozporządzenia — skrypt
   **nie czyta liczb z układu tabeli**, bo dwukolumnowy skład łamie nazwy
   w pół („Krowy powyżej 500 kg masy **1,2** ciała").
2. Dla każdej pary „nazwa grupy + współczynnik" skrypt szuka liczby
   w tekście PDF-a i sprawdza, czy w jej otoczeniu stoją wszystkie słowa
   nazwy. Jedna niezgodność → nic nie zapisuje i wypisuje, czego brakuje.
3. Kontrola w drugą stronę: każda liczba z PDF-a musi mieć odpowiednik
   w tabeli — to wyłapuje pominięty wiersz.
4. Dopiero potem skrypt zapisuje `wspolczynniki_djp` do
   `assets/dane/reguly_prawne.json`.

Wynik uruchomienia:

```
grup w tabeli: 85, gatunków: 22
każda para „nazwa + współczynnik” odnaleziona w PDF
żadna liczba z PDF nie została pominięta
zapisano 85 grup do assets/dane/reguly_prawne.json
```

Skrypt jest odtwarzalny: uruchomiony na kopii słownika daje plik
bajt w bajt taki sam, jaki leży w repozytorium.

## Co się zmieniło w słowniku

| Miara | Przed | Po |
| --- | --- | --- |
| Grupy zwierząt | 16 (wpisane „na start") | **85** (cała tabela 3) |
| Gatunki | 6 | **22** |
| `status_weryfikacji` | `do_weryfikacji` | **`potwierdzone`** |
| `zrodlo` | „do sprawdzenia w załączniku…" | Dz.U. 2020 poz. 243, zał. 1, tab. 3 |
| Nazwy grup | potoczne („tucznik") | dosłownie z rozporządzenia („Tuczniki, loszki i knurki hodowlane") |
| Wersja słownika | 2026.10.15.1 | 2026.10.15.2 |

Nazwy zostały przepisane z rozporządzenia, bo tak czyta je kontrola.
Doszło też pole `sprawdzono` z datą weryfikacji.

## Trzy wartości były błędne

Porównanie wszystkich 16 grup wpisanych w kroku 9 z rozporządzeniem:

| Grupa z kroku 9 | Było | W rozporządzeniu | Ocena |
| --- | --- | --- | --- |
| cielę do 6 miesięcy | 0,15 | Cielęta do 6 miesiąca — 0,15 | zgadza się |
| młodzież 6–12 miesięcy | 0,3 | Jałówki od 6 miesiąca do 1 roku — 0,3 | zgadza się |
| młodzież 12–18 miesięcy | 0,5 | — | **takiej grupy nie ma** |
| jałówka powyżej 18 miesięcy | 0,8 | Jałówki powyżej 1 roku — 0,8 | zgadza się |
| krowa | 1,0 | Krowy — 1 | zgadza się |
| buhaj | 1,4 | Buhaje — 1,4 | zgadza się |
| prosię do 2 miesięcy | 0,02 | Prosięta do 2 miesiąca — 0,02 | zgadza się |
| warchlak 2–4 miesiące | 0,07 | Warchlaki od 2 miesiąca do 4 miesiąca — 0,07 | zgadza się |
| tucznik | 0,14 | Tuczniki, loszki i knurki hodowlane — 0,14 | zgadza się |
| locha | 0,35 | Lochy — 0,35 | zgadza się |
| jagnię | 0,05 | Jagnięta do 3,5 miesiąca — 0,05 | zgadza się |
| owca dorosła | 0,1 | Owce powyżej 1,5 roku — 0,1 | zgadza się |
| koza dorosła | 0,1 | Kozy matki — 0,15 / Pozostałe kozy — 0,1 | **za mało dla kozy matki** |
| koń dorosły | 1,2 | konie ras dużych — 1,2 / ras małych — 0,6 | zgadza się tylko dla ras dużych |
| kura nioska | 0,004 | Kury, kaczki — 0,004 | zgadza się |
| brojler | 0,0025 | Kurczęta brojlery — 0,0036 | **o blisko trzecią część za mało** |

**13 z 16 wartości** było zgodnych z przepisem. Trzy były błędne, a jedna
(„koń dorosły") zlepiała dwa różne wiersze przepisu — konie ras dużych
i małych mają inny przelicznik. Przy stadzie 10 000 brojlerów różnica
0,0025 → 0,0036 to **25 DJP zamiast 36**: po starych liczbach gospodarstwo
mogło nie zobaczyć obowiązku, który je dotyczy. Dlatego wynik był oznaczony
jako „do sprawdzenia" i dlatego ta reguła z CLAUDE.md istnieje.

## Co to zmienia w aplikacji

- Karta DJP **nie pokazuje już ostrzeżenia** „Przeliczniki czekają na
  sprawdzenie w przepisie" — wynik jest pewny, dopóki każde zwierzę ma
  grupę.
- Ekran wyboru grupy pokazuje **pierwsze gatunki z listy** (bydło, świnie,
  drób, owce, kozy, konie ras dużych), a pozostałe 16 gatunków — strusie,
  jenoty, szynszyle, bawoły — po naciśnięciu **„Więcej zwierząt (16)"**.
  Kolejność gatunków ustala słownik, nie kod ekranu.
- Mechanizm ostrzegania został zachowany i objęty testem: gdy kiedyś
  wejdzie nowa grupa ze statusem `do_weryfikacji`, aplikacja znowu oznaczy
  DJP jako niepewne.

## Liczby

| Miara | Wartość |
| --- | --- |
| Grup w słowniku | 85 (22 gatunki) |
| Wartości sprawdzonych maszynowo z PDF | 85 (+ 48 liczb w drugą stronę) |
| Błędne wartości znalezione | 3 (plus 1 grupa zmyślona) |
| Nowy skrypt | `tools/djp/wspolczynniki_djp.py` |
| Testy dodane | 3 |
| Testy w całym projekcie | 260 (było 257) |
| `flutter analyze` | bez ostrzeżeń |

## Czego ten PDF nie rozstrzyga

Załącznik nr 1 to **tylko tabela 3**. Nadal czeka na sprawdzenie:

- **Terminy nawożenia** (np. 15.10, 15.04–31.07) — są w innych tabelach
  programu działań; w słowniku mają `status_weryfikacji: "do_weryfikacji"`
  i oznaczenie „terminy z ARiMR 2019 — do sprawdzenia".
- **Limit 170 kg N/ha z nawozów naturalnych** i progi obowiązku planu
  nawożenia azotem — też w programie działań, w rozdziałach o nawożeniu.

Przy pełnym programie działań (albo samych tabelach z terminami) te dwie
sprawy da się zamknąć tak samo: skryptem, który sprawdza każdą wartość
z dokumentem, zanim trafi do słownika.
