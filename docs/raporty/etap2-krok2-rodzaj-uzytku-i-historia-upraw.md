# Etap 2, krok 2: rodzaj użytku i uprawy pola po sezonach

17 października 2026 r.

Norma GAEC 7 pyta o dwie rzeczy, których baza nie miała:

1. **Ile jest gruntów ornych** — próg 10 ha i wszystkie udziały (40 %,
   75 %, 95 %) liczą się od gruntów ornych, nie od całej powierzchni
   gospodarstwa. Łąka i sad ich nie powiększają.
2. **Co rosło na polu rok po roku** — warunek „ta sama uprawa w plonie
   głównym nie dłużej niż 3 lata, licząc od 2023 r." wymaga historii,
   a kolumna `uprawa` w tabeli pola mówi tylko, co rośnie **teraz**.

## Co powstało

| Zmiana | Gdzie |
| --- | --- |
| Rodzaj użytku pola (grunty orne / łąka / uprawa trwała) | kolumna `rodzaj_uzytku`, migracja 5 |
| Uprawy pola po sezonach, z plonem głównym i międzyplonem | nowa tabela `uprawa_pola` |
| Historia pisze się sama, przy każdym zapisie pola | dwa wyzwalacze bazy |
| Poprawka wpisu o roku zostaje w dzienniku zmian | wyzwalacz `historia_uprawa_pola_zmiana` |
| Zakres lat z przepisu, nie z kodu | `UslugaHistoriiUpraw` czyta `licz_od_roku` ze słownika |
| Ekran pola z rodzajem użytku i historią | oba wyglądy |

Migracja przenosi to, co aplikacja już wie, zamiast pytać rolnika od
nowa: uprawę z pola i **poprzednie uprawy z dziennika zmian**. Z dziennika
bierze tylko wpisy dotyczące innego sezonu niż obecny — poprawka literówki
w tym samym roku nie jest historią plonów i nie może przesłonić uprawy
bieżącej. To ma własny test.

## Dlaczego wyzwalacze, a nie kod

Pierwsza wersja dopisywała historię z `RepozytoriumPol`. Testy pokazały
dziurę: **pola wstawia nie tylko ekran „Nowe pole"**. Robi to też import
wniosku (wprost do tabeli) i scalanie danych z drugiego urządzenia. Pola
z wniosku — czyli zwykle wszystkie — nie miałyby historii upraw, a GAEC 7
pokazywałby „brak danych" w gospodarstwie, które wszystko zadeklarowało.

Dopisywanie historii robią więc dwa wyzwalacze na tabeli pola: jeden przy
wstawieniu, drugi przy zmianie uprawy, kodu EPPO albo sezonu. Jedno
miejsce w bazie zamiast trzech w kodzie, który musiałby o tym pamiętać —
i cztery miejsca, gdyby doszedł kolejny sposób zapisu pola.

Identyfikator wiersza uprawy jest **wyliczany** (`up-<pole>-<sezon>-g`),
a nie losowy: dwa urządzenia dopisujące tę samą uprawę na ten sam sezon
trafiają w ten sam wiersz, więc scalanie danych nie robi z tego dwóch
wpisów. Nowa tabela weszła do kopii danych i do reguł scalania — inaczej
historia upraw nie przeszłaby na drugi telefon.

## Czego aplikacja nie zgaduje

| Sytuacja | Co robi aplikacja |
| --- | --- |
| Nie wie, czy pole to grunt orny, łąka czy sad | pisze „Nie wiemy, czy to grunt orny, łąka czy sad", pokazuje podpowiedź z nazwy uprawy i czeka na wybór rolnika |
| Pole ma to samo oznaczenie we wniosku co pole z 2025 r. | pokazuje uprawę z tamtego wniosku jako **propozycję**; dopisze ją dopiero po dotknięciu — oznaczenia działek rolnych zmieniają się między latami i tylko rolnik wie, czy to ten sam kawałek pola |
| Brak uprawy w jakimś roku | pokazuje przycisk „Dopisz rok 2024" i mówi, po co: bez tego nie policzy zmianowania |

Podpowiedź rodzaju użytku idzie po słowach w nazwie uprawy („łąka",
„pastwisko", „sad", „chmiel", „szkółka"), a słowa są **danymi** ze
słownika reguł — ze statusem `podpowiedz` i zapisanym wprost w opisie, że
nie pochodzą z przepisu. Dopasowanie bierze całe słowa, więc „ziemniak na
sadzeniaki" nie robi z pola sadu (też ma test).

## Usterka wyłapana przy okazji

Pigułka „Łąka lub pastwisko (TUZ)" przycinała się o 2,6 px na ekranie
420 px. Nazwy dla rolnika są teraz krótkie („Łąka lub pastwisko", „Sad lub
uprawa trwała"), a pełne nazwy urzędowe zostają na wydruku. To druga taka
usterka w tym tygodniu — testy przewijające ekran do końca zarobiły już na
siebie dwa razy.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 430 | **453** |
| Migracje bazy | 4 | **5** |
| Tabele w bazie | 15 | **16** |
| Wersja słownika reguł | 2026.10.17.1 → **2026.10.17.2** |
| `flutter analyze` | czysto | czysto |

## Następny krok

Krok 3: policzyć GAEC 7 — udział 40 % innej uprawy niż rok wcześniej,
regułę trzech lat i dywersyfikację (2 uprawy do 30 ha, 3 powyżej), razem
z wyłączeniami z § 5 ust. 3 i 11. Dane są już w bazie; teraz trzeba je
porównać z progami ze słownika i powiedzieć rolnikowi jednym zdaniem, co
z tego wynika.
