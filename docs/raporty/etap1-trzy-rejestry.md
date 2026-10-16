# Trzy rejestry do wydruku i eksportu — domknięcie etapu 1

16 października 2026 r. Plan (pkt 8) obiecuje w wersji darmowej **trzy
rejestry: podgląd, wydruk, eksport**. Aplikacja drukowała dwa — i to
ewidencję nawożenia po kolumnach ekoschematów, czyli pod inną podstawą
prawną niż ta, której wymaga program azotanowy.

## Co było nie tak

Dokument wybierało się **po rodzaju zabiegu**: oprysk → ewidencja środków
ochrony roślin, wszystko inne → rejestr ekoschematów. To działa dla
oprysków, ale nawożenie zasila **dwa** rejestry o różnych kolumnach
i różnej podstawie:

- program azotanowy wymaga ewidencji nawożenia azotem (wzór z tabeli 15),
- Plan Strategiczny WPR wymaga rejestru zabiegów agrotechnicznych.

Dodatkowo żaden z nich nie miał czym wypełnić kolumn o nawozie: wpis
rejestru nosił tylko szczegóły oprysku, więc nazwa nawozu i dawka nie
docierały do dokumentu. Rejestr ekoschematów nie miał nawet kolumn
„nawóz" i „ilość", choć słownik sam je wymieniał w opisie obowiązku.

## Co powstało

| Plik | Zmiana |
| --- | --- |
| `lib/funkcje/dokumenty/rodzaj_rejestru.dart` | **nowy**: trzy rejestry, każdy ze swoim obowiązkiem i rodzajem zabiegów |
| `lib/funkcje/dokumenty/usluga_dokumentow.dart` | dokument wybiera się po rejestrze, nie po rodzaju zabiegu |
| `lib/funkcje/zabiegi/rejestr_zabiegow.dart` | `SzczegolyNawozeniaWpisu`: nawóz, dawka i azot w wpisie rejestru (czwarte zapytanie) |
| `lib/funkcje/zabiegi/kompletnosc_ewidencji.dart` | mapowanie dziewięciu kolumn tabeli 15 oraz kolumn „nawóz" i „ilość" |
| `lib/funkcje/dokumenty/wydruk_pdf.dart` | stałe szerokości nowych kolumn, żeby liczby nie łamały się na dwa wiersze |
| `lib/wyglad/prosty/dokumenty/ekran_dokumenty.dart` | wybór jednego z trzech rejestrów |
| `assets/dane/reguly_prawne.json` | rejestr ekoschematów dostaje kolumny „nawóz" i „ilość nawozu" |

Kolumny każdego rejestru nadal pochodzą **wyłącznie ze słownika reguł**
(`wymagane_pola`) — w kodzie nie ma ani jednej nazwy kolumny z przepisu
(CLAUDE.md, reguła 1). Nowy plik `rodzaj_rejestru.dart` mówi tylko, który
obowiązek i które zabiegi złożyć w jeden dokument.

## Ewidencja nawożenia azotem po urzędowemu

Dziewięć kolumn z tabeli 15 (załącznik nr 10 do programu azotanowego,
sprawdzone w rozporządzeniu — `terminy-nawozenia-azotem.md`):

| Kolumna | Skąd |
| --- | --- |
| Data zastosowania nawozu | data zabiegu |
| Pole, na którym zastosowano nawóz | nazwa własna pola |
| Uprawa (gatunek) | uprawa pola |
| Powierzchnia uprawy (ha) | suma powierzchni pól wpisu |
| Powierzchnia, na której zastosowano nawóz (ha) | powierzchnia zabiegu |
| Rodzaj nawozu (zawartość N) | nazwa nawozu + azot na ha, gdy znany |
| Dawka (kg N/ha) | azot wyliczony ze składu nawozu |
| Dawka (N na zastosowaną powierzchnię) | azot × powierzchnia zabiegu |
| Data przyorania nawozu naturalnego | **zostaje pusta** — wymagana tylko na terenie o dużym nachyleniu, a aplikacja nie zna nachylenia pola |

Dwie rzeczy, których nie zgadujemy: **nawóz bez znanej zawartości azotu**
daje w kolumnach dawki „brak", nie liczbę na oko, a **data przyorania**
jest polem rolnika, nie aplikacji. Oba braki widać w podglądzie przed
wydrukiem, bo wpis jest wtedy „niekompletny" — tak jak przy opryskach.

## Liczby

| Miara | Wartość |
| --- | --- |
| Rejestry do wydruku | **3** (było 2) |
| Kolumny ewidencji nawożenia azotem | 9 |
| Kolumny rejestru ekoschematów | 7 (było 5) |
| Nowe pliki kodu | 1 (+ zmiany w sześciu) |
| Testy dodane | 5 |
| Testy w całym projekcie | 284 (było 279) |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Do wyboru są trzy rejestry i każdy ma kolumny ze słownika.
- Rejestr nieopisany w słowniku daje `null`, a nie pusty plik.
- Ewidencja nawożenia liczy azot na hektar i łącznie (200 kg/ha × 34% =
  68 kg N/ha; na 4 ha razem 272 kg N) i rozdziela powierzchnię uprawy od
  powierzchni nawożonej.
- Nawóz bez znanej zawartości azotu nie udaje dawki — w obu kolumnach
  zostaje brak.
- Eksport CSV ewidencji nawożenia zawiera nazwę nawozu, azot i nazwę pola.
- Nawożenie mierzymy ewidencją nawożenia azotem, nie rejestrem
  ekoschematów.

## Stan etapu 1

Dziesięć kroków z planu (pkt 4) jest zrobione, a obietnica trzech
rejestrów z pkt 8 — spełniona. Znane luki do uzupełnienia później:

1. ~~**Kopia danych do pliku**~~ — **zrobione 16.10.2026**, razem
   z usuwaniem gospodarstwa: `docs/raporty/etap1-kopia-danych.md`.
2. **Rejestr stada do wydruku** — IRZplus prowadzi własny rejestr;
   gdybyśmy chcieli go drukować, potrzebny jest urzędowy układ kolumn.
3. **Dane prawne do uzupełnienia**: art. 20 ustawy o nawozach (zakaz dla
   gleb zamarzniętych), progi planu nawożenia z Prawa wodnego art. 105a,
   lista upraw intensywnych (załącznik nr 7), tabela 14 z maksymalnymi
   dawkami azotu, tabela 1 z odległościami od wód.
4. **Uprawy bez decyzji o kodzie EPPO** — `uprawy_eppo_do_decyzji.csv` z P3.
5. **Format „maszynowo odczytywalny"** wymagany od 1.01.2027 nie jest
   jeszcze ogłoszony.
