# nowoczesny
Wygląd dla osób obytych ze smartfonem. Te same dane, reguły i dokumenty co w wyglądzie
prostym — różnią się tylko ekrany.

- `ekran_glowny.dart` — powłoka: cztery zakładki (Start, Pola, Terminy, Dokumenty)
  i dolny pasek nawigacji z przyciskiem „+".
- `start/` — podsumowanie sezonu, pasek azotu, najbliższy termin, ostatnie zabiegi.
- `pola/` — mapa na całą szerokość, wyszukiwarka, filtry upraw, karta wybranego pola.
- `wpis/` — wpis zabiegu na jednym ekranie (rodzaj, kilka pól naraz, środek, dawka, powód).
- `terminy/`, `dokumenty/`, `rejestr/`, `ustawienia/` — kalendarz obowiązków, trzy
  rejestry z wydrukiem i eksportem, poprawka i cofnięcie wpisu, wybór wyglądu.
- `motyw.dart` — kolory, odstępy i rozmiary (plan, pkt 5). Ekrany nie wpisują kodów
  kolorów ani rozmiarów.
- `widgety/` — karta, ostrzeżenie, pasek limitu, wybór, liczba z „+" i „−".

Kod wspólny dla obu wyglądów leży w `lib/rdzen/wspolne/` (np. mapa działek, opis
karencji) — wygląd nie może importować drugiego wyglądu.
