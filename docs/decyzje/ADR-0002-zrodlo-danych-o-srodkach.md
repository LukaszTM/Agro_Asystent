# ADR-0002. Źródło danych o środkach ochrony roślin

- Stan: **przyjęte** (14 października 2026 r., zadanie P1)
- Dotyczy: plan, pkt 6.3 i zadanie P1

## Problem

Plan zakładał jedno źródło: plik XLSX ze strony MRiRW („wyszukiwarka środków
ochrony roślin"). W trakcie P1 okazało się, że ten sam rejestr jest też
w portalu otwartych danych — w postaci znormalizowanej i na wyraźnej licencji.

## Co znaleziono

| | Strona MRiRW (gov.pl) | Portal dane.gov.pl, zbiór „Wyszukiwarka środków ochrony roślin" |
| --- | --- | --- |
| Postać | jeden arkusz, 18 kolumn | 2 rejestry + 5 słowników |
| Wierszy zastosowań | 18 785 | 18 659 |
| Licencja | materiał urzędowy, bez wyraźnej noty | **CC0 1.0** (domena publiczna) |
| Aktualizacja | doraźnie (plik z 12.10.2026) | kwartalnie (ostatnie wydanie 30.09.2026) |
| Dodatkowo | rodzaj użytkownika, środek mikrobiologiczny, stosowanie agrolotnicze | producent, **adres etykiety**, słowniki upraw, agrofagów, substancji |

## Decyzja

Używamy **obu źródeł**:

1. **Rejestr zastosowań ze strony MRiRW** jako podstawa — jest świeższy i ma
   kolumny, których nie ma wydanie kwartalne (m.in. informacja, czy środek jest
   tylko do stosowania profesjonalnego).
2. **Wydanie z dane.gov.pl** jako uzupełnienie — stamtąd bierzemy producenta
   i adres etykiety (przyda się w P2) oraz **słownik upraw**, którym rozbijamy
   listy upraw z rejestru.

## Następstwa

- Rozbijanie list upraw opiera się na urzędowym słowniku 1052 nazw, a nie na
  zgadywaniu po przecinkach: 99,4% pozycji rozpoznanych, reszta oznaczona
  jako „do sprawdzenia".
- Pytanie z planu (pkt 10) o regulamin gov.pl przestaje blokować P1: dane
  w wersji CC0 wolno pobierać i przetwarzać bez warunków. Dla pliku ze strony
  MRiRW obowiązuje `robots.txt`, który sprawdziliśmy u źródła — zezwala na
  pobieranie (`User-Agent: *`, `Allow: /`).
- Aktualizacje: kwartalne wydanie jest przewidywalne i wersjonowane, więc
  w aplikacji pokazujemy datę danych, z których korzysta rolnik.
- Adres etykiety przy 2 964 z 2 991 środków zawęża pracę w P2 — nie trzeba
  przeszukiwać dziesięciu podstron alfabetycznych w ciemno.
