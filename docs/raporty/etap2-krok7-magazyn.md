# Etap 2, krok 7: magazyn środków i nawozów

17 października 2026 r.

Ostatni krok etapu 2. Magazyn mówi, ile czego zostało — i robi to bez
pytania rolnika o liczby, które aplikacja już zna z wpisów zabiegów.

## Stan liczy się z ruchów, nie jest osobną liczbą

W bazie (migracja 9) są dwie tabele: `magazyn_pozycja` (środek albo nawóz
z jednostką) i `magazyn_ruch` (zakup, zużycie, poprawka stanu). Stan na
dany dzień to suma ruchów do tego dnia, więc:

- każdą liczbę da się wytłumaczyć („kupione 20 l, zużyte 2,4 l"),
- poprawka nie nadpisuje historii — dopisuje różnicę,
- stan sprzed tygodnia da się pokazać bez cofania czegokolwiek,
- cofnięty ruch zostaje w bazie ze śladem w dzienniku zmian.

## Zużycie dopisuje się samo

Po zapisie oprysku albo nawożenia aplikacja odpisuje towar z magazynu:
ilość liczy z dawki i powierzchni (0,75 l/ha na 3,20 ha to 2,40 l).
Reguły, których pilnują testy:

| Sytuacja | Co robi aplikacja |
| --- | --- |
| Rolnik nie prowadzi tej pozycji w magazynie | nic nie zakłada; magazyn pokazuje to, co rolnik do niego wpisał |
| Dawka niepewna albo liczona nie na hektar | nie zgaduje ilości, ruchu nie ma |
| Poprawka tego samego wpisu zabiegu | ruch ma identyfikator z zabiegu i pozycji, więc nie odpisuje towaru drugi raz |
| Ten sam oprysk scalony z drugiego urządzenia | ten sam identyfikator, więc jeden ruch, nie dwa |
| Brak premium | magazyn milczy, a **wpis zabiegu zapisuje się tak samo** |

Ostatni wiersz jest tu najważniejszy: ewidencja nigdy nie zależy od
magazynu. Magazyn to funkcja premium (plan, pkt 8) — oszczędza czas, ale
żadnej dokumentacji nie warunkuje. Warunek „czy rolnik kupił" stoi tam,
gdzie powinien: w `lib/rdzen/dostep/`, a ekrany pytają o to przez
`DostepFunkcji.czyDostepna(Funkcja.magazyn)`.

## Ostrzeżenie o środku wycofanym

Rejestr MRiRW podaje przy środkach **termin do stosowania** — datę, po
której wolno już tylko zutylizować zapas. Słownik aplikacji nosi tę datę
(skrypt `tools/zbuduj_slowniki.py` ją przepisuje, a środki po terminie
w ogóle do niego nie wchodzą), więc po dodaniu środka do magazynu
aplikacja wie, kiedy ostrzec:

> Bez Etykiety 100 SC wolno było stosować do 30.06.2026, a w magazynie
> zostało 5,00 l.
> Nie stosuj go już na polu. Zapytaj sprzedawcę albo gminę, jak oddać
> środek do unieszkodliwienia.

Gdy rejestr terminu nie podaje, nie zamieniamy tego na „wolno bez końca" —
pozycja po prostu nie ma daty i ostrzeżenia nie ma.

Drugie ostrzeżenie mówi o stanie ujemnym: gdy zużycie przewyższa zakupy,
magazyn prosi o dopisanie brakującego zakupu i od razu uspokaja, że
ewidencja zabiegów zostaje bez zmian.

## Co widzi rolnik

Ekran „Magazyn" w obu wyglądach (prosty — z ustawień gospodarstwa,
nowoczesny — z ustawień): stan każdej pozycji, kupione i zużyte, data
ostatniego zakupu, ostrzeżenia. Pozycje dodaje się z tego, co rolnik już
ma: z własnego spisu nawozów albo ze środków, którymi już opryskiwał.
Ilości wpisuje się przyciskami „+" i „−", bez klawiatury. Bez premium
ekran mówi jednym zdaniem, że to funkcja płatna, i że wpisy, rejestry,
wydruk i eksport działają bez opłaty.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 574 | **594** |
| Testy magazynu | — | 15 (silnik) + 4 (ekrany) |
| Testy Python | 136 | 136 |
| Wersja schematu bazy | 8 | **9** |
| `flutter analyze` | czysto | czysto |

Nowe tabele weszły do kopii danych i do reguł scalania — pilnuje tego
test „każda tabela bazy jest w kopii danych i ma regułę scalania".

## Etap 2 zamknięty

| Krok | Co dało |
| --- | --- |
| 1 | normy GAEC jako dane z wersją, z kontrolą wobec tekstu jednolitego |
| 2 | rodzaj użytku pola i historia upraw od 2023 r. |
| 3 | GAEC 7: zmianowanie, dywersyfikacja, ostrzeżenie przed czwartym rokiem |
| 4 | GAEC 6: okrywa ochronna gleby z deklaracją rolnika |
| 5 | GAEC 4 i GAEC 8 oraz wpis siewu, zbioru i innych prac |
| 6 | ekran „Warunkowość" w obu wyglądach i wydruk na kontrolę |
| 7 | magazyn środków i nawozów (premium) |

## Co zostaje do zrobienia poza kodem

- Potwierdzić w EUR-Leksie zwolnienia z rozp. (UE) 2025/2649 (≤ 10 ha
  i ≤ 30 ha) — z kontenera nie da się tam wejść.
- Potwierdzić listę form okrywy, gdy ministerstwo wyda ją
  w rozporządzeniu, a nie tylko w komunikacie ARiMR.
- Próba na telefonie: klucz podpisujący i cztery sekrety w GitHubie,
  potem pierwszy plik APK z gałęzi.
- Konto Google Play i wycena premium; dokumenty prawne (regulamin,
  polityka prywatności).
