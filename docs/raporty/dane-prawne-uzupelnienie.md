# Uzupełnienie danych prawnych — luka 1

16 października 2026 r. Lista z podsumowania etapu 1, punkt 1: art. 20
ustawy o nawozach, progi planu nawożenia z Prawa wodnego, lista upraw
intensywnych, tabela 1 z odległościami od wód i tabela 14 z maksymalnymi
dawkami azotu.

## Źródła, które doszły

| Dokument | Po co |
| --- | --- |
| **Dz.U. 2021 poz. 76** — ustawa z 10 lipca 2007 r. o nawozach i nawożeniu | zakazy, do których program azotanowy tylko odsyła |
| **Dz.U. 2024 poz. 1087** — ustawa – Prawo wodne | progi obowiązku planu nawożenia azotem (art. 105a) |
| **Dz.U. 2023 poz. 244**, załącznik nr 7 i tabela 1 | lista upraw intensywnych, odległości od wód |

Wszystkie trzy sprawdza `tools/azotany/terminy_nawozenia.py`: **29 wzorców**
w trzech dokumentach (20 w programie, 5 w ustawie o nawozach, 4 w Prawie
wodnym). Każda wartość, którą skrypt zapisuje, musi się znaleźć w swoim
dokumencie — inaczej nic nie zapisuje.

Przy okazji wyszła trzecia wada warstwy tekstowej Dziennika Ustaw: **wyrazy
przenoszone na końcu wiersza** („na grun- tach ornych"). Jeden wzorzec
z Prawa wodnego pękł właśnie na tym. Do przeszukiwanego tekstu dokładamy
więc wariant bez przeniesień; łącznik bez odstępu („amonowo-węglanowych")
zostaje nietknięty.

## Zakazy, które były tylko odesłaniem

Program azotanowy mówił: „do stosowania nawozów na glebach zamarzniętych
(…) stosuje się przepisy art. 20 (…) ustawy o nawozach i nawożeniu".
Tej ustawy nie czytaliśmy, więc zakaz był oznaczony jako „do sprawdzenia".
Teraz jest przeczytany i doszły trzy kolejne:

| Zakaz | Podstawa |
| --- | --- |
| Gleby zamarznięte, zalane, nasycone wodą albo pod śniegiem | art. 20 ust. 1 pkt 1 |
| **Za zamarzniętą nie uznaje się gleby, która rozmarza co najmniej powierzchniowo w ciągu dnia** | art. 20 ust. 3 |
| Gnojowica i gnojówka na rośliny do bezpośredniego spożycia przez ludzi, w czasie wegetacji | art. 20 ust. 1 pkt 2 |
| Nawozy amonowo-węglanowe | art. 20a |
| Mocznik granulowany bez inhibitora ureazy albo powłoki biodegradowalnej | art. 20b |

Ustęp 3 jest dla rolnika najważniejszy z całej tej piątki: mówi, że szron
rano nie jest glebą zamarzniętą. Bez niego aplikacja ostrzegałaby zbyt
ostro. Zakaz nie dotyczy stawów rybnych — to też jest w danych.

## Progi planu nawożenia — potwierdzone i uzupełnione

Art. 105a ust. 1 pkt 2 Prawa wodnego potwierdza dokładnie to, co było
w słowniku: **powyżej 100 ha UR, powyżej 50 ha upraw intensywnych na
gruntach ornych albo powyżej 60 DJP** (stan średnioroczny). Doszły trzy
rzeczy, których nie mieliśmy:

- plan wymagany jest też przy chowie **drobiu powyżej 40 000 stanowisk**,
  **świń powyżej 2000 stanowisk** (albo 750 dla macior) oraz przy nabywaniu
  nawozu naturalnego od importera — tego aplikacja **nie ocenia** i mówi
  o tym w uwagach obowiązku;
- **wyjątek z ust. 7**: kto nie stosuje nawozów naturalnych na swoich
  działkach, planu nie opracowuje;
- plan przechowuje się **3 lata** (ust. 9).

## Uprawy intensywne — próg, który nigdy się nie włączał

Załącznik nr 7 podaje **22 uprawy**: 19 w uprawie polowej i 3 pod osłonami.
Przy ośmiu pierwszych „intensywna" zależy od dawki azotu:

| Uprawa | Intensywna powyżej |
| --- | --- |
| pszenica | 120 kg N/ha |
| pszenżyto, żyto mieszańcowe | 100 kg N/ha |
| kukurydza | 160 kg N/ha |
| rzepak, burak cukrowy, burak pastewny | 150 kg N/ha |
| ziemniak późny | 120 kg N/ha |

Pozostałe (kapusta głowiasta biała, kalafior, brokuł, brukselka, marchew,
seler korzeniowy, burak ćwikłowy, ogórek, cukinia, cebula, por; pod
osłonami pomidor, ogórek, papryka) są intensywne zawsze.

**To był realny brak w aplikacji**: `powierzchniaUprawIntensywnychHa`
w profilu gospodarstwa była zawsze zerem, więc próg 50 ha nie mógł się
włączyć — gospodarstwo z 60 ha kapusty nie dowiedziałoby się, że musi mieć
plan nawożenia. Teraz profil liczy tę powierzchnię z pól gospodarstwa:

- dopasowanie nazwy jest dosłowne — „żyto mieszańcowe" nie złapie zwykłego
  żyta, a „ziemniak późny" nie złapie ziemniaka;
- przy uprawach warunkowych liczy się **azot wniesiony na to pole
  w sezonie**, z ewidencji nawożenia. Pole bez nawożenia ma zero azotu,
  czyli uprawą intensywną jeszcze nie jest.

## Odległości od wód (tabela 1)

| Nawóz | Odległość | Od czego |
| --- | --- | --- |
| nawozy bez gnojowicy | 5 m | brzeg jezior i zbiorników do 50 ha, cieków, rowów (bez rowów do 5 m), kanałów |
| gnojowica | 10 m | to samo |
| wszystkie nawozy | 20 m | ujęcia wody bez strefy ochronnej, jeziora powyżej 50 ha, morski pas nadbrzeżny |

Przy uprawie roślin odległość wolno zmniejszyć **o połowę, ale nie poniżej
3 m**, gdy nawóz aplikuje się urządzeniami wprost do gleby albo gdy pełną
dawkę dzieli się co najmniej na 3 równe części. Widać to na ekranie
nawożenia.

To nie to samo co nasze dotychczasowe 3 m — tamto jest z normy GAEC 4
(warunkowość), a te odległości z programu azotanowego.

## Liczby

| Miara | Wartość |
| --- | --- |
| Wzorców sprawdzonych w dokumentach | 29 (3 dokumenty) |
| Zakazy w słowniku | 5 (było 2, z czego 1 niepewny) |
| Uprawy intensywne | 22 |
| Odległości od wód | 3 + warunki zmniejszenia |
| Wszystkie zasady nawożenia `potwierdzone` | tak — żadna nie czeka na sprawdzenie |
| Testy dodane | 6 |
| Testy w całym projekcie | 305 (było 299) |
| Wersja słownika | 2026.10.16.4 |

## Co zostaje z luki 1

**Tabela 14 — maksymalne ilości azotu działającego** (załącznik nr 9).
Dotyczy gospodarstw **bez** obowiązku planu nawożenia: mają stosować dawki
nieprzekraczające wartości z tej tabeli. Tabela jest duża (kilkanaście
stron, dawki per uprawa i poziom plonu) i wymaga własnego ekranu —
ostrzeżenia „ta dawka przekracza maksimum dla tej uprawy". To osobne
zadanie, nie dopisek do słownika.
