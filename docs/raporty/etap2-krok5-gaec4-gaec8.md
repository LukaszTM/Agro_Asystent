# Etap 2, krok 5: GAEC 4 i GAEC 8

17 października 2026 r.

Dwie normy, które nie są rachunkiem, a zakazem czynności: pas od brzegu
wody (GAEC 4) i okres lęgowy ptaków (GAEC 8). Aplikacja nie udaje, że
wie, czy opryskiwacz sięgnął brzegu — przypomina o zakazie **w chwili
wpisu**, bo wtedy rolnik jeszcze pamięta, jak jechał.

## GAEC 4: pas 3 m od wody

| Co | Przepis | Skąd liczba |
| --- | --- | --- |
| Pas bez nawozów i środków ochrony roślin | § 2 | próg `pas_od_wody_m` = 3 m |
| Rowy wyłączone z normy | § 2 | próg `row_bez_pasa_m` = 5 m |

Czy pole graniczy z wodą, wie tylko rolnik: granice z ULDK nie mówią, czy
rów ma cztery, czy sześć metrów, a rowy do 5 m przepis z tej normy
wyłącza. Dlatego na ekranie pola stoi pytanie „Woda przy polu" z dwiema
odpowiedziami, a pusta kolumna `granica_z_woda` (migracja 7) znaczy
**„nie wiem"**, nie „nie" — i wtedy aplikacja o pasie nie ostrzega.

Przy wpisie oprysku i nawożenia na takim polu, **nad** polem dawki:

> Pole Za stodołą graniczy z wodą, a norma GAEC 4 zabrania tu stosowania
> środków ochrony roślin w pasie 3 m od brzegu.
> Zapisz zabieg tak, jak był — dokumentacja ma być prawdziwa. Jeśli
> zabieg sięgnął brzegu, przy kontroli liczy się to jako złamanie normy.
> Rowów szerszych niż 5 m to nie dotyczy.

Ostrzeżenie stoi na górze ekranu nie bez powodu: pod spodem musi zostać
przycisk „Zapisz" w zasięgu palca. Treść nawożenia mówi o nawozach,
a oprysku o środkach ochrony roślin — to ten sam przepis, ale rolnik
czyta o tym, co właśnie robi.

Stan normy w gospodarstwie zostaje „do sprawdzenia", gdy jest choć jedno
pole przy wodzie: czy pas został zachowany, wie tylko ten, kto jechał
opryskiwaczem. Udawanie wyniku byłoby tu gorsze niż jego brak.

## GAEC 8: okres lęgowy i elementy krajobrazu

| Co | Przepis | Skąd dane |
| --- | --- | --- |
| Zakaz przycinania drzew i żywopłotów 15.04–31.07 | § 6 ust. 10 pkt 2 | termin `zakaz_przycinania` normy `gaec_8` |
| Wyłączenie: wierzby, drzewa owocowe, zagajniki | § 6 ust. 10 pkt 2 | osobna praca na liście |
| Zakaz niszczenia rowów do 2 m i oczek < 100 m² | § 6 ust. 10 pkt 1 | progi `row_chroniony_m`, `oczko_wodne_m2` |

Najtrudniejsze pytanie brzmiało: **skąd aplikacja ma wiedzieć, że rolnik
przycina żywopłot?** Odpowiedź „z tekstu uwag" byłaby zgadywaniem — do
uwag można napisać wszystko albo nic. Dlatego rolnik wybiera pracę
z listy (dane `warunkowosc.prace_krajobrazowe`, status `podpowiedz`),
a praca wskazuje normę i jej termin, zamiast trzymać własne daty:

| Praca | Kiedy ostrzegamy |
| --- | --- |
| Przycinanie drzew albo żywopłotu | w okresie z przepisu (15.04–31.07) |
| Przycinanie wierzby, drzewa owocowego albo zagajnika | nigdy — przepis je wyłącza |
| Usunięcie drzewa, rowu albo oczka wodnego | cały rok |
| Inna praca na polu | nigdy — nie dotyczy tej normy |

Podział prac nie jest z przepisu (rozporządzenie prac nie dzieli) i tak
jest oznaczony w danych. Z przepisu jest to, czego zakaz dotyczy i kiedy
obowiązuje — dlatego zmiana okresu w rozporządzeniu wejdzie do aplikacji
bez zmiany kodu.

## Przy okazji: siew, zbiór i inne prace da się wreszcie zapisać

Do tej pory oba wyglądy przyjmowały tylko oprysk i nawożenie — przy
pozostałych rodzajach stało „ta część jeszcze nie działa". To była dziura
nie tylko w rejestrze zabiegów agrotechnicznych: krok 4 czyta **dzień
zbioru z wpisu zabiegu** (od niego liczy się okrywa GAEC 6), a rolnik nie
miał go gdzie wpisać.

Teraz siew, zbiór, uprawę gleby i inne prace zapisuje się bez środka
i bez dawki: data i powierzchnia uzupełniają się same, zostaje „Zapisz".
Przy pracy „inny" dochodzi jedno pytanie — co dokładnie robisz — i dopóki
nie ma odpowiedzi, zapis jest zablokowany, bo od niej zależy ostrzeżenie
GAEC 8. Wybrana praca trafia do kolumny `podrodzaj` (migracja 8) i do
uwag, więc w rejestrze widać „Przycinanie drzew albo żywopłotu", a nie
samo „Inny".

Przy tym wyszedł defekt, którego nikt by nie zauważył bez tych wpisów:
`KompletnoscEwidencji` mierzyła **każdy** zabieg niebędący opryskiem
wymaganiami ewidencji nawożenia azotem. Wpis zbioru pokazywałby się jako
niekompletny — bez nawozu i bez ilości nawozu. Teraz siew, zbiór, uprawa
gleby i inne prace nie mają wymaganych pól z przepisu, bo żaden przepis
ich nie wymaga.

## Czego aplikacja nie robi

- Nie liczy, czy pas 3 m został zachowany — nie wie, gdzie jechał
  opryskiwacz.
- Nie blokuje żadnego zapisu. Praca mogła być już wykonana, a wpis ma
  pokazywać prawdę; przy kontroli liczy się to, co się stało.
- Nie odgaduje rodzaju pracy z uwag ani rodzaju wody z granic działki.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 519 | **554** |
| Testy silników GAEC 4 i GAEC 8 | — | 13 + 11 |
| Testy Python | 133 | **136** |
| Wersja słownika reguł | 2026.10.17.5 | **2026.10.17.6** |
| Wersja schematu bazy | 6 | **8** |
| `flutter analyze` | czysto | czysto |

## Następny krok

Krok 6: ekran „Warunkowość" w obu wyglądach — każda norma ze stanem
(dotyczy / nie dotyczy / spełniona / do sprawdzenia), jedno zdanie co
zrobić i wydruk na kontrolę. Silniki GAEC 4, 6, 7 i 8 już ten stan
zwracają; normy, których aplikacja nie policzy (GAEC 1, 2, 5, 9), pokażą
treść i to, że dane o działkach ma urząd, nie telefon.
