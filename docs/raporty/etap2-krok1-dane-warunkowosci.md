# Etap 2, krok 1: normy GAEC jako dane

17 października 2026 r.

Etap drugi zaczyna się tam, gdzie każdy etap tego projektu musi: od danych
z aktu prawnego. Bez tego „kontrola warunkowości" byłaby zbiorem liczb
wpisanych w kod — czyli dokładnie tym, czego CLAUDE.md zabrania.

## Które źródło i dlaczego to ważne

Normy GAEC określa rozporządzenie Ministra Rolnictwa i Rozwoju Wsi
z 10 marca 2023 r. (Dz.U. 2023 poz. 478). **Ten tekst jest już w kilku
miejscach nieaktualny** — i właśnie dlatego ten krok jest pierwszy.

Aplikacja bierze dane z **tekstu jednolitego**: Dz.U. z 2025 r. poz. 1674
(obwieszczenie z 14 listopada 2025 r.), który uwzględnia trzy nowelizacje:

| Nowelizacja | Co zmieniła |
| --- | --- |
| 11 marca 2024 r. (Dz.U. 2024 poz. 369) | GAEC 4: pas 3 m obejmuje też „inne substancje zawierające azot"; GAEC 7: reguła trzech lat liczy się od 2023 r., doszło spełnienie zastępcze przez rejestr zabiegów |
| 26 czerwca 2024 r. (Dz.U. 2024 poz. 945) | GAEC 6: nowy termin okrywy; GAEC 7: dywersyfikacja 75 %/95 % i granica 30 ha, wyłączenie plantacji nasiennych kukurydzy; **uchylone** § 6 ust. 1–9 (4 % obszarów nieprodukcyjnych) i załączniki 1–3 |
| 7 marca 2025 r. (Dz.U. 2025 poz. 293) | GAEC 2 (torfowiska i obszary podmokłe) od 15 marca 2025 r. |

Trzy różnice, które wyszłyby rolnikowi na kontroli, gdyby aplikacja
trzymała się tekstu z 2023 r.:

| Co | Akt z 2023 r. | Brzmienie obowiązujące |
| --- | --- | --- |
| Okrywa na gruntach ornych (GAEC 6) | 1 listopada – 15 lutego | **od zbioru plonu głównego do 15 października**, z przerwą do 4 tygodni na siew ozimin |
| Dywersyfikacja (GAEC 7) | 3 uprawy, największa ≤ 65 %, dwie ≤ 90 % | **do 30 ha: 2 uprawy, największa ≤ 75 %; powyżej 30 ha: 3 uprawy, ≤ 75 % i ≤ 95 %** |
| 4 % obszarów nieprodukcyjnych | obowiązywało | **uchylone** |

Plan projektu (pkt 3) opisywał GAEC 6 jako „okrywa 80 % GO do 15.10" —
i to się zgadza z brzmieniem obowiązującym, ale wziąć to z planu zamiast
z aktu byłoby zgadywaniem.

## Co weszło do słownika

| Miara | Wartość |
| --- | --- |
| Normy GAEC | **9** (GAEC 1–9) |
| Normy, które aplikacja policzy sama | **4**: GAEC 4, 6, 7, 8 |
| Progów liczbowych | **16** |
| Terminów | **4** |
| Zwolnień z kontroli | **3** |
| Wersja słownika reguł | 2026.10.16.5 → **2026.10.17.1** |

Każda norma, której aplikacja **nie** policzy, mówi dlaczego — zamiast
milczeć albo udawać wynik:

| Norma | Dlaczego nie liczymy |
| --- | --- |
| GAEC 1 (udział TUZ) | wskaźnik jest krajowy, nie gospodarstwa; obowiązek ogłasza minister |
| GAEC 2 (torfowiska) | wykaz obszarów prowadzą IUNG-PIB i ARiMR (Dz.U. 2025 poz. 307) — telefon nie wie, czy pole jest na liście |
| GAEC 3 (wypalanie) | to zakaz czynności, nie liczba do policzenia |
| GAEC 5 (stoki ≥ 14 %) | nachylenia nie znamy — granice z ULDK nie zawierają wysokości |
| GAEC 9 (cenne TUZ) | które TUZ są wyznaczone, wie ARiMR |

## Kontrola, która przerywa zapis

Treść normy to proza prawnicza, więc skrypt `tools/warunkowosc/normy_gaec.py`
jej nie parsuje. Zamiast tego trzyma wprost wypisane progi i terminy,
a przy zapisie sprawdza, czy **dosłowny zwrot z aktu** nadal w nim stoi —
na przykład „co najmniej 40 %", „do dnia 15 października roku, w którym
dokonano zbioru", „nie więcej niż 30 ha", „od dnia 15 kwietnia do dnia
31 lipca". Gdy ministerstwo zmieni próg, kontrola się nie zgodzi i skrypt
odmówi zapisu, zamiast zostawić w aplikacji wartość z poprzedniego
brzmienia. Osobna kontrola pilnuje, że § 6 ust. 1 jest **nadal uchylony** —
gdyby 4 % obszarów nieprodukcyjnych wróciło, aplikacja musiałaby o tym
mówić.

Dziennik Ustaw łamie wyrazy na końcach wierszy („po-wierzchni"), więc
tekst jest najpierw sklejany; ma to własny test.

## Czego nie dało się potwierdzić w akcie

Dwa zwolnienia decydują o tym, czy warunkowość w ogóle dotyczy
gospodarstwa, a pochodzą z prawa unijnego, nie z rozporządzenia:

- gospodarstwa do **10 ha** — zwolnione z kontroli warunkowości i kar,
- gospodarstwa do **30 ha** — zwolnione z kontroli wymogów **GAEC 7**.

Oba są przepisane z komunikatu ARiMR „Normy GAEC obowiązujące w 2026 r."
i wskazują art. 2 rozporządzenia (UE) 2025/2649. **EUR-Lex jest
niedostępny z kontenera sesji** (połączenie odrzucane przez pośrednika),
więc obie wartości mają w słowniku `status_weryfikacji:
"do_weryfikacji"` — aplikacja powie o tym rolnikowi, a nie poda ich jako
pewnych. To samo dotyczy uznania norm GAEC 1, 3, 4, 5, 6 i 7 za spełnione
w gospodarstwach ekologicznych z certyfikatem.

**Do zrobienia na komputerze z dostępem do EUR-Lexu:** sprawdzić art. 2
rozporządzenia (UE) 2025/2649 i zmienić status na „potwierdzone".

## Porządki przy okazji

W słowniku leżał blok `parametry_warunkowosci` z dwiema wartościami
(pas 3 m, okrywa 80 %) bez wskazania przepisu — i **nieużywany przez
żaden ekran**. Zniknął razem z klasą `ParametrWarunkowosci`: te same
wartości stoją teraz w normach GAEC 4 i GAEC 6, z paragrafem i źródłem.
Dwa miejsca z tą samą liczbą to jedno miejsce za dużo.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 413 | **430** |
| Testy skryptów | 120 | **130** |
| `flutter analyze` | czysto | czysto |

## Następny krok

Krok 2: rodzaj użytku (grunty orne, TUZ, uprawy trwałe) i historia upraw
pola od 2023 r. Bez tego nie da się policzyć ani progu 10 ha gruntów
ornych, ani reguły trzech lat — a to są liczby, o które pyta kontrola.
