# Drugi wygląd telefonu: „Nowoczesny" (luka 6)

Data: 16.10.2026. Gałąź: `claude/eloquent-hopper-etevk6`.

Plan (pkt 5) obiecuje **dwa wyglądy na telefonie**: „Prosty" dla osób starszych
i „Nowoczesny" dla osób obytych ze smartfonem, przełączane w ustawieniach, z tymi
samymi danymi, regułami i dokumentami. Wygląd prosty był gotowy od etapu 1;
tym zadaniem domykamy drugi i przełącznik.

## Co powstało

| Plik | Wiersze | Co robi |
| --- | --- | --- |
| `ekran_glowny.dart` | 182 | powłoka: cztery zakładki + dolny pasek z „+" |
| `start/widok_start.dart` | 377 | podsumowanie sezonu, pasek azotu, najbliższy termin, ostatnie zabiegi |
| `pola/widok_pola.dart` | 297 | mapa na całą szerokość, wyszukiwarka, filtry upraw, karta pola |
| `pola/ekran_nowe_pole.dart` | 143 | nowe pole: nazwa, powierzchnia przyciskami, uprawa z listy |
| `wpis/ekran_wpis.dart` | 764 | wpis zabiegu **na jednym ekranie** + potwierdzenie z karencją |
| `terminy/widok_terminy.dart` | 297 | kalendarz obowiązków i przełącznik przypomnień |
| `dokumenty/widok_dokumenty.dart` | 288 | trzy rejestry, okres, podgląd, PDF/CSV/XLSX |
| `rejestr/ekran_rejestr.dart` | 216 | lista wpisów z wyszukiwarką i filtrem rodzaju |
| `rejestr/ekran_wpis_rejestru.dart` | 515 | wpis w całości, poprawka (dawka, godzina, karencja), cofnięcie |
| `ustawienia/ekran_ustawienia.dart` | 360 | wygląd, gospodarstwo, zwierzęta, kopia danych |
| `motyw.dart` + `widgety/` | 577 | kolory i rozmiary z planu, karta, ostrzeżenie, pasek limitu, wybór, liczba z „+/−" |

Razem **4016 wierszy** w `lib/wyglad/nowoczesny/` (wygląd prosty: 6499).

Wartości z planu, pkt 5: tło `#F6F7F4`, karty `#FFFFFF` z zaokrągleniem 20 px, tekst
`#0F1F12`, tekst pomocniczy `#4F5F51`, zieleń `#1E5B2E`, pasek `#0F1F12` z przyciskiem
`#B9E26A`, tekst 13–16 px, cel dotyku ≥ 44 px. Żaden ekran nie wpisuje kodu koloru ani
rozmiaru — wszystko z `motyw.dart`.

## Przełącznik wyglądu

- `lib/funkcje/ustawienia/wybor_wygladu.dart` — `Wyglad.prosty` / `Wyglad.nowoczesny`
  w tabeli `ustawienia` (klucz `wyglad`). **Domyślnie prosty**: aplikacja jest przede
  wszystkim dla rolników 60+.
- Przełącza się w **obu** wyglądach: w prostym w „Gospodarstwo → Wygląd aplikacji",
  w nowoczesnym w „Ustawienia → Wygląd". Motyw jest nad ekranami, więc zmiana wraca do
  `AplikacjaAgroAsystent` i przebudowuje całość od razu.
- Dopóki wybór nie jest odczytany z bazy, nie pokazujemy żadnego z wyglądów — inaczej
  na chwilę mignąłby ten niewybrany.

## Czego pilnują testy (26 nowych, razem 332 na zielono)

- Dolny pasek: cztery zakładki, przycisk „+", brak szuflady i menu „trzy kropki";
  każdy cel dotyku ≥ 44 px; **żaden napis < 13 px**.
- Start: sezon, liczba pól, powierzchnia (4,70 ha z dwóch pól), pasek azotu z limitem
  **wziętym ze słownika reguł**, a nie z kodu testu.
- Pola: filtr uprawy i wyszukiwarka zawężają listę; bez granic działek nie udajemy mapy;
  karta pola prowadzi do wpisu z już wybranym polem; nowe pole bierze kod EPPO ze słownika.
- Wpis: rodzaj → pola → środek → zapis bez zmiany ekranu, dawka i powód podpowiedziane
  z rejestru; kilka pól naraz liczy powierzchnię samo i ostrzega o różnych uprawach;
  bez środka zapis jest zablokowany i napisane, czego brakuje; **żadnej oferty premium
  podczas wpisu**; nawóz bez znanego azotu nie dostaje wyliczonej dawki azotu.
- Rejestr: braki ewidencji widać na liście; poprawka dawki trafia do bazy i zostawia
  wpis w `historia_zmian`; cofnięcie zostawia wiersz z `usuniety = 1`.
- Dokumenty: trzy rejestry, eksport CSV z tych samych wpisów; bez wpisów nie udajemy
  dokumentu.
- Wygląd: zapis wyboru w obu wyglądach, start aplikacji w wyglądzie z bazy, domyślnie prosty.

## Co znaleźliśmy po drodze

1. **Pasek aplikacji wyglądu prostego rozjeżdżał się na wąskim telefonie** (420 px:
   logo + „Agro Asystent" przy 26 px nie mieściły się — nadmiar 10 px). Nazwa dostała
   `Flexible` z przycięciem. Dotyczyło prawdziwych telefonów, nie tylko testu.
2. **Podpisy dolnego paska brały rozmiar z `Theme.of`**, więc w chwili przełączania
   wyglądu dostawały 18 px z motywu prostego, łamały się na dwie linijki i pasek
   przestawał się mieścić. Rozmiar bierzemy teraz wprost z `MotywNowoczesny`.
3. Trzy miejsca wołały `setState(() => _coś = Future...)` — Flutter to odrzuca
   („setState callback argument returned a Future"). Poprawione na bloki.
4. `MapaDzialek` i `OpisKarencji` były w plikach wyglądu prostego, a potrzebują ich oba
   wyglądy → przeniesione do `lib/rdzen/wspolne/` (mapa dostaje barwy od wyglądu, więc
   `rdzen/` nadal nie zależy od ekranów). Pilnuje tego `test/architektura_test.dart`.
5. `RepozytoriumPol` dostało `dzialkiReferencyjne(poleId)` — karta pola pokazuje numery
   działek z wniosku i wyróżnia pierwszą na mapie.

## Czego wygląd nowoczesny jeszcze nie ma

Te funkcje działają w wyglądzie prostym i **nie są duplikowane** w nowoczesnym:

| Funkcja | Gdzie jest |
| --- | --- |
| Działki ewidencyjne: dodanie po numerze, granice z ULDK | `wyglad/prosty/dzialki/` |
| Wczytanie wniosku z PDF | `wyglad/prosty/dzialki/ekran_import_wniosku.dart` |
| Nawozy gospodarstwa i zestawienie azotu z terminami jesiennymi | `wyglad/prosty/nawozenie/` |
| Dane gospodarstwa do wydruku, konto, usunięcie gospodarstwa | `wyglad/prosty/ustawienia/` |

To około 1500 wierszy formularzy, które w obu wyglądach robiłyby to samo. Zalecenie na
uzupełnianie luk: zamiast przepisywać je drugi raz, wyjąć je do
`lib/rdzen/wspolne/` z parametrem stylu — tak jak zrobiliśmy z `MapaDzialek`
(`BarwyMapy`). Do tego czasu rolnik, który wybrał wygląd nowoczesny, robi te rzeczy po
przełączeniu na prosty; wpisy, rejestry, wydruk i eksport ma w całości u siebie.

## Polecenia kontrolne

```
flutter analyze            # bez ostrzeżeń
dart format --set-exit-if-changed lib test
flutter test               # 332 testy
```
