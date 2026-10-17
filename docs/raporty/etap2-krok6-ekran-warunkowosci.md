# Etap 2, krok 6: ekran „Warunkowość" i wydruk na kontrolę

17 października 2026 r.

Jedno miejsce, w którym rolnik widzi stan każdej normy GAEC — i jeden
wydruk, który może pokazać kontroli. Nic tu nie jest liczone od nowa:
stany pochodzą z silników kroków 3–5, a zdania z warstwy `funkcje/`, więc
oba wyglądy i wydruk mówią dokładnie to samo.

## Co widzi rolnik

Dla każdej z dziewięciu norm: numer i nazwa, stan jednym słowem
(**Spełniona / Niespełniona / Nie dotyczy / Do sprawdzenia**), zdania
o tym, co aplikacja policzyła, jedno zdanie „co zrobić" i treść normy.
Stan ma ikonę i słowo — kto nie rozróżnia kolorów, przeczyta to samo.

| Norma | Skąd stan |
| --- | --- |
| GAEC 4 | `PasOdWody.ocen` — pola przy wodzie i pola bez odpowiedzi |
| GAEC 6 | `Okrywa.ocen` — udział okrywy, termin, przerwy |
| GAEC 7 | `Zmianowanie.ocen` — 40 %, trzy lata, dywersyfikacja |
| GAEC 8 | wpisy prac: przycinanie w okresie lęgowym |
| GAEC 1, 2, 3, 5, 9 | nie liczymy — treść normy i zdanie, gdzie są dane |

Wejście stoi w zakładce „Terminy" w obu wyglądach: warunkowość to
obowiązki bez dat (stan zależy od upraw i wpisów, nie od kalendarza), ale
rolnik szuka obowiązków właśnie tam. Ekran główny wyglądu prostego
zostaje przy czterech kafelkach, jak chce plan (pkt 5).

## GAEC 8 liczona z wpisów — i powiedziane, co to znaczy

Nowe w tym kroku: normę GAEC 8 aplikacja **sprawdza w rejestrze**. Jeśli
w okresie lęgowym ptaków jest wpis przycinania drzew albo żywopłotu,
norma jest niespełniona, a ekran prosi o sprawdzenie, czy nie chodziło
o wierzbę albo drzewo owocowe (przepis je wyłącza). Gdy wpisu nie ma,
piszemy **„Według wpisów w 2026 r. nie było przycinania…"** — bo brak
wpisu nie dowodzi, że nikt nie przycinał. Zakaz niszczenia pomników
przyrody, wąskich rowów i małych oczek obowiązuje cały rok i tego
aplikacja nie sprawdzi; mówi to wprost.

## Normy, których aplikacja nie policzy

GAEC 1 (udział TUZ w skali kraju), GAEC 2 (wyznaczone torfowiska
i obszary podmokłe), GAEC 3 (zakaz wypalania), GAEC 5 (nachylenie stoku)
i GAEC 9 (cenne TUZ na Natura 2000) dostają stan **„Do sprawdzenia"**,
powód z danych (`dlaczego_nie_liczy`) i zdanie: te dane ma urząd, nie
telefon. Żadna z nich nie pokaże się nigdy jako „spełniona" — to była
główna zasada tego kroku.

## Wydruk na kontrolę

Zestawienie powstaje jako ten sam `DokumentEwidencji`, z którego już
korzystają trzy rejestry, więc PDF, CSV i XLSX składają się bez nowego
kodu renderującego. Kolumny: norma, co mówi, stan, co wiemy, co zrobić.
Normy nieliczone mają w kolumnie braków wpisane „stan policzony przez
aplikację" — kontrola widzi, czego w tym dokumencie nie ma. Nagłówek
niesie nazwę gospodarstwa, numer producenta (albo „brak"), rok, podstawę
prawną, **wersję słownika reguł** i datę sporządzenia.

Wydruk i eksport są darmowe, jak każda dokumentacja (plan, pkt 8) — na
ekranie nie ma ani jednego pytania o wersję płatną; testy to sprawdzają.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 554 | **574** |
| Testy przeglądu i wydruku | — | 15 + 3 |
| Testy ekranów warunkowości | — | 2 (po jednym na wygląd) |
| `flutter analyze` | czysto | czysto |

Wersja słownika reguł i schemat bazy bez zmian — ten krok nie dodał
żadnych danych ani kolumn, tylko pokazał to, co już policzone.

## Następny krok

Krok 7, ostatni w etapie 2: **magazyn** (premium, plan pkt 8) — zakup
i zużycie środków oraz nawozów, stan na dziś, zużycie liczone z wpisu
zabiegu i ostrzeżenie o środku wycofanym z obrotu. Dokumentacja zostaje
darmowa; magazyn to funkcja oszczędzająca czas, więc decyzja o dostępie
zapadnie wyłącznie w `lib/rdzen/dostep/`.
