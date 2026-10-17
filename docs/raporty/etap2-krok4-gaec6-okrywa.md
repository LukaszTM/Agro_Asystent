# Etap 2, krok 4: GAEC 6 — okrywa ochronna gleby

17 października 2026 r.

Aplikacja liczy udział gruntów ornych z okrywą ochronną gleby i pilnuje
terminu 15 października. Formy okrywy **nie zgaduje** — podpowiada ją
z wpisów rolnika, a zapisuje tylko to, czego rolnik dotknie.

## Co mówi przepis i co z tego liczymy

| Warunek | Przepis | Jak liczymy |
| --- | --- | --- |
| Okrywa na ≥ 80 % gruntów ornych | § 4 ust. 1 pkt 1 | udział powierzchni pól z formą okrywy, która liczy się do normy |
| Od dnia zbioru plonu głównego do 15 października | § 4 ust. 1 pkt 1 | dzień zbioru z wpisu zabiegu, termin ze słownika reguł |
| Przerwa do 4 tygodni na siew ozimin i międzyplonów | § 4 ust. 1 pkt 1 | pole z dłuższą przerwą nie liczy się do udziału |
| Okrywa w międzyrzędziach sadów 1.11–15.02 | § 4 ust. 1 pkt 2 | **nie liczymy** — aplikacja mówi, że tego nie policzy z wpisów |

W kodzie Dart nie ma ani jednej z tych liczb. 80 % i 4 tygodnie to progi
`udzial_gruntow_ornych_procent` i `przerwa_tygodnie` z normy `gaec_6`,
a 15 października to termin `okrywa_grunty_orne` — dlatego silnik liczy
limit przerwy jako „tygodnie z przepisu × 7 dni", a nie jako wpisane 28.

## Czego przepis nie mówi: formy okrywy

Rozporządzenie nie wymienia, co jest okrywą. Lista ośmiu form pochodzi
z komunikatu ARiMR o normach na 2026 r. i w słowniku stoi ze statusem
`do_weryfikacji` razem ze źródłem — aplikacja mówi o tym rolnikowi
wprost, zamiast udawać pewność.

| Forma | Liczy się do 80 % | Podpowiadamy ze słów |
| --- | --- | --- |
| Uprawa ozima | tak | ozima, ozimy, ozime, ozimina, oziminy |
| Międzyplon | tak | miedzyplon, miedzyplony, poplon, facelia |
| Wsiewka | tak | wsiewka, wsiewki |
| Trawy | tak | trawy, trawa, lucerna, koniczyna |
| Ściernisko | tak | sciernisko, sciern |
| Resztki po zbiorze | tak | resztki, mulcz, samosiew, samosiewy |
| Ugór zielony | tak | ugor, ugorowany, ugorowana |
| Gleba odkryta | **nie** | — (pusta lista, patrz niżej) |

Słowa są danymi, nie listą w kodzie. Skrypt odmawia zapisu, gdy któreś ma
ogonki albo wielkie litery (aplikacja porównuje nazwy znormalizowane)
oraz gdy forma „gleba odkryta" dostanie jakiekolwiek słowo: **tego jednego
aplikacja nie ma prawa podpowiedzieć**, bo z „nie wiem" zrobiłaby
„niespełnione".

## Skąd się bierze podpowiedź

Kolejność szukania — od najmocniejszego świadectwa do najsłabszego:

1. **wpis rolnika po zbiorze** (siew, uprawa gleby) — „z twojego wpisu:
   »międzyplon ścierniskowy — gorczyca«";
2. **uprawa zapisana na następny rok** — ozimina zasiana tą jesienią to
   plon główny przyszłego sezonu;
3. **uprawa tego sezonu** — trawy i ugór zostają na polu same.

Siew sprzed dnia zbioru nie jest podpowiedzią okrywy — wsiewka wsiana
w kwietniu w kukurydzę zbieraną we wrześniu nie mówi nic o tym, co
zostało po zbiorze. Gdy nie ma z czego podpowiedzieć, nie podpowiadamy
niczego.

Potwierdzona podpowiedź zapisuje się ze źródłem `podpowiedz
potwierdzona`, a własny wybór — `rolnik`. Przy kontroli widać, skąd się
wzięła każda deklaracja.

## Gdzie aplikacja mówi „do sprawdzenia"

| Sytuacja | Co pokazujemy |
| --- | --- |
| Pole bez deklaracji | „do sprawdzenia" z liczbą pól i zdaniem, czego brakuje |
| Deklaracje pewne dają już 80 % | **„spełniona"** — reszta deklaracji nie zmieni wyniku, więc nie każemy na nią czekać |
| Nawet z polami bez deklaracji nie wyjdzie 80 % | „niespełniona" — tu brak danych już niczego nie ratuje |
| Forma, której słownik nie zna (starsza wersja aplikacji) | pole nie liczy się do udziału |
| Pole bez rodzaju użytku | wymienione osobno; grunty orne to tylko pola potwierdzone przez rolnika |
| Sad, uprawa trwała | uwaga o międzyrzędziach 1.11–15.02 i o tym, że tego nie policzymy |
| Gospodarstwo do 10 ha | zwolnienie z rozp. (UE) 2025/2649 **pokazane**, ale rachunek i tak się liczy |

Zasada jak w kroku 3: **brak danych nigdy nie daje „norma spełniona"** —
z jednym wyjątkiem, który jest rachunkiem, a nie domysłem: gdy same
potwierdzone pola przekraczają 80 %, norma jest spełniona niezależnie od
pozostałych.

## Co widzi rolnik

Na ekranie pola, pod historią upraw:

> **Co zostaje na polu po zbiorze**
> Nie wiemy, co zostaje po zbiorze.
> Norma GAEC 6 chce okrywy na co najmniej 80 % gruntów ornych do
> 15 października 2026. Zaznacz, co zostaje na tym polu — tego aplikacja
> nie zgadnie z uprawy.
> Zbiór: 20.07.2026 — od tego dnia liczy się okrywa.
> Podpowiedź: Międzyplon — z twojego wpisu: „siew międzyplon ścierniskowy".

Po wyborze formy, która liczy się do okrywy, dochodzi pytanie o przerwę
(„Bez przerwy", „1 tydzień" … „Dłużej niż 4 tygodnie"). Pytanie idzie
w tygodniach, tak jak przepis, więc rolnik nie liczy dni — a wybrana
liczba tygodni jest dokładna, nie przybliżona. Przy przerwie dłuższej niż
dopuszczalna wpis zostaje taki, jak było, z jednym zdaniem: przy kontroli
to pole nie liczy się do okrywy.

Zdania stoją w `OpisOkrywyPola` (warstwa `funkcje/`), więc „Prosty"
i „Nowoczesny" mówią to samo; różni się tylko sposób wyboru — duże
przyciski albo chipy.

## Baza i synchronizacja

Migracja 6 dodaje tabelę `okrywa_pola` (pole, sezon, forma, dzień zbioru,
przerwa, uwagi) z wyzwalaczem dopisującym poprzednią treść do dziennika
zmian — deklaracje są dopisywane, nie nadpisywane. Identyfikator jest
wyliczany (`ok-<pole>-<sezon>`), więc ta sama deklaracja z telefonu
i z komputera scala się w jeden wiersz, a nie w dwa. Tabela weszła też do
kopii danych i do reguł scalania (nowszy wpis wygrywa).

Nowy test pilnuje, żeby to się już nie zdarzyło po cichu: **każda tabela
bazy musi być w kopii danych i mieć regułę scalania**. Bez tego dane
z drugiego urządzenia nie dochodziłyby, a zauważyłaby to dopiero kontrola.

## Co znalazły testy

| Defekt | Skutek |
| --- | --- |
| Chip w wyglądzie nowoczesnym nie łamał długiej etykiety | „Resztki pożniwne, samosiewy albo mulcz" wychodziło 115 px za ekran na telefonie 420 px — teraz etykieta łamie się na dwie linie, a nazwy form są krótsze (szczegóły zostały w opisie) |
| Cyrylickie „а" w opisie formy | wyglądało jak polskie, psułoby porównania nazw; skrypt ma teraz kontrolę, która odmawia zapisu danych ze znakami poza polskim alfabetem |

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 478 | **519** |
| Testy silnika GAEC 6 | — | 30 |
| Testy Python | 130 | **133** |
| Wersja słownika reguł | 2026.10.17.3 | **2026.10.17.5** |
| Wersja schematu bazy | 5 | **6** |
| `flutter analyze` | czysto | czysto |

## Co zostaje do potwierdzenia

- Lista form okrywy (`do_weryfikacji`) — z komunikatu ARiMR, nie z aktu.
  Gdy ministerstwo wyda wykaz w rozporządzeniu, status zmieni skrypt.
- Zwolnienia z rozp. (UE) 2025/2649 — EUR-Lex jest nieosiągalny
  z kontenera, więc wartości nadal pochodzą ze strony ARiMR.
- Okrywa w międzyrzędziach sadów: aplikacja jej nie policzy z wpisów
  i mówi o tym wprost.

## Następny krok

Krok 5: GAEC 4 i GAEC 8 — pas 3 m od wód jako cecha pola z ostrzeżeniem
przy oprysku i nawożeniu oraz zakaz przycinania drzew i żywopłotów
15.04–31.07 przy wpisie zabiegu (termin jest już w kalendarzu).
