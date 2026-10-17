# Etap 2 — podsumowanie: warunkowość i magazyn

17 października 2026 r.

Etap 2 zamknięty w siedmiu krokach. Aplikacja liczy teraz cztery z dziewięciu
norm GAEC, o pozostałych mówi, czego nie wie, i prowadzi magazyn środków oraz
nawozów. Każdy krok zostawił działającą aplikację i własny raport.

## Co powstało

| Krok | Co dostał rolnik | Raport |
| --- | --- | --- |
| 1 | normy GAEC jako dane z wersją, czytane z tekstu jednolitego | `etap2-krok1-dane-warunkowosci.md` |
| 2 | rodzaj użytku pola i historia upraw od 2023 r. | `etap2-krok2-rodzaj-uzytku-i-historia-upraw.md` |
| 3 | GAEC 7: zmianowanie, dywersyfikacja, ostrzeżenie przed czwartym rokiem | `etap2-krok3-gaec7-zmianowanie.md` |
| 4 | GAEC 6: okrywa ochronna gleby z deklaracją rolnika | `etap2-krok4-gaec6-okrywa.md` |
| 5 | GAEC 4 i GAEC 8 oraz wpis siewu, zbioru i innych prac | `etap2-krok5-gaec4-gaec8.md` |
| 6 | ekran „Warunkowość" w obu wyglądach i wydruk na kontrolę | `etap2-krok6-ekran-warunkowosci.md` |
| 7 | magazyn środków i nawozów (premium) | `etap2-krok7-magazyn.md` |

## Liczby

| Miara | Koniec etapu 1 | Koniec etapu 2 |
| --- | --- | --- |
| Testy Flutter | 453 | **594** |
| Testy Python | 130 | **136** |
| Wersja słownika reguł | 2026.10.17.2 | **2026.10.17.6** |
| Wersja schematu bazy | 4 | **9** |
| Nowe migracje | — | 5 (okrywa, rodzaj użytku, woda, podrodzaj, magazyn) |

## Trzy zasady, które przeszły przez cały etap

**1. Liczba z przepisu nigdy nie trafia do kodu.** Progi (10 ha, 30 ha, 80 %,
40 %, 75 %, 95 %, 3 m, 5 m, 2 m, 100 m²), terminy (15.10, 1.11–15.02,
15.04–31.07) i okresy (4 tygodnie, 3 lata od 2023 r.) stoją w słowniku reguł.
Skrypt `tools/warunkowosc/normy_gaec.py` sprawdza każdą wartość wobec
dosłownego brzmienia rozporządzenia i **odmawia zapisu**, gdy przepis się
zmieni. Dzięki temu nowelizacja psuje build, a nie wynik kontroli u rolnika.

**2. Brak danych nigdy nie daje „spełniona".** Każdy silnik ma stan
„do sprawdzenia" i wchodzi w niego, gdy brakuje rodzaju użytku, uprawy
z poprzedniego roku, deklaracji okrywy albo odpowiedzi o wodzie. Jedyny
wyjątek jest rachunkiem, nie domysłem: gdy same potwierdzone pola przekraczają
80 % okrywy, reszta deklaracji nie zmieni wyniku.

**3. Aplikacja podpowiada, rolnik potwierdza.** Rodzaj użytku, forma okrywy,
granica z wodą i rodzaj pracy przy drzewach to decyzje rolnika. Aplikacja
podpowiada je z jego własnych wpisów (siew po zbiorze, uprawa na następny rok,
nazwa uprawy) i zawsze mówi, skąd podpowiedź się wzięła. Gleby odkrytej nie
podpowiada nigdy — z „nie wiem" zrobiłaby „niespełnione".

## Czego aplikacja nie policzy i mówi to wprost

GAEC 1 (udział TUZ w skali kraju), GAEC 2 (wykaz torfowisk z Dz.U. z 2025 r.
poz. 307 — po stronie IUNG-PIB i ARiMR), GAEC 3 (zakaz wypalania), GAEC 5
(nachylenie stoku), GAEC 9 (cenne TUZ na Natura 2000). Na ekranie
„Warunkowość" mają treść normy, powód z danych i zdanie: te dane ma urząd,
nie telefon. Żadna nie pokaże się jako spełniona.

Z norm liczonych aplikacja też nie udaje wszechwiedzy: nie wie, czy
opryskiwacz sięgnął brzegu (GAEC 4), nie policzy okrywy w międzyrzędziach
sadów (GAEC 6) i nie dowie się o przycinaniu, którego rolnik nie zapisał
(GAEC 8).

## Defekty znalezione przez testy w tym etapie

| Defekt | Jak wyszedł |
| --- | --- |
| Historia upraw nie powstawała przy imporcie wniosku i przy scalaniu | przeniesienie zapisu z kodu Dart do wyzwalaczy bazy |
| Chip z długą nazwą wychodził 115 px za ekran na telefonie 420 px | test przewijający ekran do końca |
| Homoglif z cyrylicy w opisie formy okrywy | nowa kontrola znaków w skrypcie danych |
| Wpis zbioru pokazywałby się jako niekompletny (mierzony ewidencją nawożenia) | test kompletności po dodaniu nowych rodzajów zabiegu |
| Brak nowych tabel w kopii danych uszedłby bez śladu | nowy test: każda tabela bazy musi być w kopii i mieć regułę scalania |

## Co zostaje poza kodem

- Potwierdzić w EUR-Leksie zwolnienia z rozp. (UE) 2025/2649 (≤ 10 ha
  z całej warunkowości, ≤ 30 ha z GAEC 7) — z kontenera nie da się tam wejść,
  wartości pochodzą z komunikatu ARiMR i są oznaczone „do weryfikacji".
- Potwierdzić listę form okrywy, gdy ministerstwo wyda ją w rozporządzeniu.
- Sprawdzić terminy nawożenia wobec aktualnego rozporządzenia (oznaczone
  „do weryfikacji" od etapu 1).
- Próba na telefonie: klucz podpisujący i cztery sekrety w GitHubie, potem
  pierwszy plik APK z gałęzi.
- Konto Google Play, wycena premium, regulamin i polityka prywatności.

## Następny etap

Plan nie rozpisuje jeszcze etapu 3. Z rzeczy gotowych, a odłączonych, czeka
**produkcja zwierzęca**: rejestr stada, DJP i terminy zgłoszeń do IRZplus są
napisane i przetestowane (krok 9 etapu 1), tylko odcięte od ekranów. Druga
naturalna droga to **koszty i przychody** — magazyn już trzyma ceny zakupu,
więc zestawienie kosztów na hektar jest o jeden krok.
