# Dostęp do funkcji płatnych w całej aplikacji

17 października 2026 r.

Plan (pkt 8) obiecuje konkretny podział na wersję darmową i płatną, ale
w kodzie pytały o niego tylko dwa miejsca: magazyn i kilka gospodarstw.
Import wniosku z PDF, odczyt zdjęcia i zabieg na kilku polach naraz były
gotowe i **darmowe**, choć w planie stoją jako dodatki płatne. Ten krok
porządkuje to w jednym miejscu, zanim cokolwiek pójdzie do sprzedaży.

## Gdzie zapada decyzja, a gdzie stoją słowa

| Co | Gdzie |
| --- | --- |
| Czy funkcja jest płatna | `lib/rdzen/dostep/dostep_funkcji.dart` |
| Lista funkcji | `lib/rdzen/dostep/funkcja.dart` |
| Słowa dla rolnika | `lib/rdzen/dostep/opis_premium.dart` (nowe) |
| Pytanie ze ekranu | `uslugi.dostep.czyDostepna(Funkcja...)` |

Ekrany nie wiedzą, co znaczy „kupił" — test architektury nie przepuszcza
słów `maPremium` i `_tylkoPremium` poza katalogiem `lib/rdzen/dostep/`.
Słowa też nie są rozsypane po ekranach: `OpisPremium` daje nazwę funkcji
po polsku i zdanie **jak zrobić to samo bez opłaty**, zawsze zakończone
obietnicą, że wpisy, rejestry, wydruk i eksport są darmowe.

## Dwie zasady, które z tego wynikły

**Podczas wpisu zabiegu funkcji płatnej po prostu nie ma** — bez
przycisku i bez słowa o wersji płatnej (plan, pkt 8: „podczas wpisu
zabiegu żadnych okien z ofertą"). Dotyczy to rozpoznawania etykiety ze
zdjęcia i zabiegu na kilku polach naraz. Testy w obu wyglądach sprawdzają
teraz, że w trakcie wpisu nie pojawia się ani słowo „premium", ani
„płatn".

**Poza wpisem zostaje jedno zdanie zamiast przycisku.** Rolnik ma
wiedzieć, że funkcja istnieje i co zrobić bez niej — ukrycie bez
wyjaśnienia wygląda jak brak funkcji, a nie jak wybór wersji.

## Co jest teraz zamknięte dostępem

| Funkcja | Gdzie | Co widzi rolnik bez premium |
| --- | --- | --- |
| Wczytanie wniosku z PDF | lista pól (prosty), zakładka Pola (nowoczesny) | zdanie: działki dodasz po numerze, pola wpiszesz ręcznie |
| Rozpoznanie etykiety ze zdjęcia | wybór środka (prosty), wpis zabiegu (nowoczesny) | nic — wybór środka z listy, jak zawsze |
| Odczyt worka ze zdjęcia | formularz nowego nawozu, oba wyglądy | jedno zdanie; nawóz wpisuje się ręcznie |
| Jeden wpis na kilku polach | wpis zabiegu (nowoczesny) | wybór pola zamienia poprzednie + zdanie „Jeden wpis dotyczy jednego pola" |
| Magazyn | ustawienia, oba wyglądy | zdanie o wersji płatnej (było wcześniej) |
| Kilka gospodarstw | ustawienia, oba wyglądy | zdanie o wersji płatnej (było wcześniej) |

Przy okazji doszła metoda `Uslugi.zDostepem(...)`: po zakupie premium
aplikacja nie otwiera bazy od nowa, tylko podmienia obiekt dostępu.

## Czego świadomie **nie** zamknąłem — do Twojej decyzji

Trzy pozycje z tabeli planu zostawiam darmowe, bo zamknięcie ich kłóci
się z regułą 4 z CLAUDE.md („nie blokujemy dokumentacji za brak
płatności") albo z bezpieczeństwem rolnika:

1. **Karencja z bazy etykiet.** Plan daje darmowo tylko wpis ręczny.
   Ukrycie znanej karencji znaczy, że rolnik w wersji darmowej może
   zebrać plon za wcześnie — a karencja jest informacją o bezpieczeństwie
   żywności, nie udogodnieniem. Teraz karencja pokazuje się zawsze.
2. **Ostrzeżenia przed błędem (azot, zmianowanie, okrywa).** Te
   ostrzeżenia chronią rolnika przed złamaniem przepisu i karą — a nie
   oszczędzają mu czasu. Teraz pokazują się zawsze.
3. **Wczytanie kopii z pliku.** Formalnie to część „synchronizacji", ale
   przy zmianie telefonu bez tego nie da się odzyskać własnej
   dokumentacji. Kopia i jej wczytanie zostają darmowe; płatna
   synchronizacja (automatyczna, w tle) i tak jeszcze nie istnieje.

Jeśli chcesz trzymać się planu co do litery, powiedz — to są trzy linie
w `_tylkoPremium` i trzy warunki na ekranach.

## Czego w ogóle jeszcze nie ma

Dwie funkcje płatne z planu nie istnieją w kodzie (nie da się ich
zamknąć, bo nie ma czego): **zestawienie do wniosku** i **komplet na
kontrolę jednym przyciskiem**. Plan nawożenia azotem też jeszcze nie jest
dokumentem — aplikacja mówi tylko, czy przepis go wymaga, co jest
obowiązkiem i zostaje darmowe.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 594 | **601** |
| Miejsca pytające o dostęp | 2 | **8** |
| `flutter analyze` | czysto | czysto |

Nowe testy: cztery o słowach (każda funkcja płatna ma nazwę, każde
wyjaśnienie kończy się obietnicą darmowej dokumentacji, nigdzie nie ma
„kup"), test ekranu pól w obu wersjach, test formularza nawozu bez
premium i test, że w premium wpis na kilku polach liczy powierzchnię sam.

## Co przy okazji wyszło

Test spisu nawozów przewijał ekran, trzymając się **wnętrza pola
tekstowego** zamiast listy — działało tylko dlatego, że przycisk zapisu
mieścił się na ekranie. Po dodaniu jednego zdania test przestał docierać
do przycisku. Poprawka w teście (przewijanie listy ekranu) i w ekranie:
na formularzu zostaje jedno krótkie zdanie, a nie ramka z dwoma — rolnik
przyszedł tam wpisać nawóz, nie czytać o wersjach.
