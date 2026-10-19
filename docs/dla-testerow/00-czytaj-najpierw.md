# Agro Asystent — pakiet dla testera (beta 1)

Dziękujemy, że chcesz wypróbować program. Ten pakiet to wszystko, czego
potrzebujesz: jak zainstalować, jak obsługiwać, co sprawdzić i jak dać znać,
że coś nie działa.

## Co to za program

Agro Asystent prowadzi dokumentację gospodarstwa, której wymaga ARiMR
i kontrole: pola i działki, zabiegi (opryski, nawożenie, siew, zbiór),
karencje, terminy, trzy rejestry do wydruku. Działa **bez internetu** —
sieć jest potrzebna tylko do pobrania granic działki, pogody i wiadomości.
Nie ma konta ani logowania. Wszystko zostaje w Twoim telefonie albo
komputerze; nic nie jest nigdzie wysyłane.

Są dwie wersje:

- **na telefon** (Android) — tu wpisuje się zabiegi, stojąc w polu;
- **na komputer** (Windows) — pulpit gospodarstwa, pola, rejestry, wydruki.
  Na komputerze **nie wpisuje się zabiegów** — te robi się na telefonie
  i przenosi kopią danych.

## Co jest w pakiecie

| Plik | Po co |
| --- | --- |
| `01-telefon-instalacja-i-obsluga.md` | jak zainstalować aplikację na telefonie i co gdzie jest |
| `02-komputer-instalacja-i-obsluga.md` | to samo dla programu na Windows |
| `03-plan-testow-telefon.md` | lista rzeczy do sprawdzenia na telefonie — zakreślasz TAK albo NIE |
| `04-plan-testow-komputer.md` | lista rzeczy do sprawdzenia na komputerze |
| `05-zgloszenie-bledu.md` | wzór, jak opisać, że coś nie zadziałało |

Kolejność: zainstaluj (01 albo 02) → przejdź listę (03 albo 04) → każde
NIE opisz według wzoru (05).

## Ile to zajmie

- telefon: około godziny, można w kilku podejściach;
- komputer: około 40 minut.

Nie trzeba robić wszystkiego naraz ani wszystkiego w ogóle. Każda
wypełniona linijka się liczy.

## Zasady — trzy rzeczy do zapamiętania

1. **Wpisuj dane na próbę, nie swoją prawdziwą ewidencję.** To wersja
   testowa: przy aktualizacji trzeba odinstalować starą wersję, a to kasuje
   dane (instrukcja mówi, jak zrobić kopię). Zmyślone pole „Za stodołą"
   i zmyślony oprysk w zupełności wystarczą.
2. **Nie wysyłaj zrzutów ekranu z prawdziwymi numerami działek, nazwiskiem
   ani numerem producenta.** Jeśli na ekranie są takie dane — zasłoń je albo
   opisz problem słowami.
3. **Wszystkie dodatki są w tej wersji odblokowane** (wniosek z PDF,
   zdjęcie etykiety, magazyn, plan nawożenia, kilka gospodarstw). W wersji
   dla rolnika część z nich będzie płatna. **Nigdy płatna nie będzie
   dokumentacja**: wpisy, rejestry, wydruk, eksport, kopia danych.

## Czego jeszcze nie ma — nie zgłaszaj tego jako błędu

- **Cen skupu** — karta jest, ale notowania nie są jeszcze wczytane
  (program mówi o tym wprost).
- **Rejestru stada i liczenia DJP** — będzie w następnym etapie.
- **Wpisywania zabiegów na komputerze** — robi się to na telefonie.
- **Kanały wiadomości** są oznaczone „do weryfikacji", a **kalendarz
  biodynamiczny** to tradycja, nie przepis — program sam to pisze.
- **Terminy nawożenia** w słowniku są oznaczone „do weryfikacji" wobec
  aktualnego rozporządzenia.
- Na Windows program nie ma podpisu wydawcy — SmartScreen ostrzega. To
  znany stan (instrukcja 02 mówi, co kliknąć).

## Jak zakreślać wyniki

W planach testów jest kolumna **Udało się?** Wpisz albo zakreśl:

- **TAK** — stało się to, co opisane w kolumnie „Co powinno się stać";
- **NIE** — stało się coś innego; w kolumnie „Uwagi" napisz co, choćby
  jednym zdaniem („przycisk nic nie robi", „napis ucięty");
- **–** (kreska) — nie robiłeś tego punktu.

Najcenniejsze są uwagi w stylu „nie wiedziałem, co nacisnąć" albo „za
małe litery". To nie są błędy programu — to błędy projektu, i o nie nam
chodzi najbardziej.

## Gdzie wysłać wyniki

Wypełniony plan (zdjęcie kartki albo plik) i zgłoszenia wyślij tam, skąd
dostałeś ten pakiet. Jeśli masz konto na GitHubie, zgłoszenia możesz też
wpisać jako „Issue" w repozytorium
https://github.com/LukaszTM/Agro_Asystent — wzór jest w pliku 05.

## Gotowa wiadomość do przekazania testerowi

> Cześć! Robię aplikację do dokumentacji gospodarstwa (zabiegi, nawożenie,
> terminy ARiMR) i proszę Cię o wypróbowanie wersji testowej. W załączniku
> jest pakiet: instrukcja instalacji, instrukcja obsługi i lista rzeczy do
> sprawdzenia, przy której zakreślasz TAK albo NIE.
>
> Najważniejsze: wpisuj dane na próbę (to wersja testowa), nie przysyłaj
> zrzutów z prawdziwymi numerami działek, a każde NIE opisz jednym zdaniem.
> Wszystko działa bez internetu, nic nie trzeba zakładać.
>
> Najbardziej zależy mi na jednym: spróbuj zapisać zabieg tak, jakbyś robił
> to w polu, i powiedz, co było niejasne albo za wolne.
