# ADR-0003. Mapa działek bez internetu

- Stan: **przyjęte** (15 października 2026 r., zadanie P5)
- Dotyczy: plan, pkt 6.1 („warunki pobierania ortofotomapy do pracy offline do sprawdzenia")

## Problem

Rolnik wybiera pole na mapie, stojąc w polu — czyli zwykle bez zasięgu.
Potrzebujemy mapy, która działa offline, a jednocześnie nie łamie warunków
korzystania z cudzych serwerów kafelków.

## Co sprawdzono

| Źródło podkładu | Ocena |
| --- | --- |
| **Granice działek z ULDK (GUGiK)** | bezpłatne, bez logowania, pobierane raz na działkę i trzymane lokalnie — nadaje się |
| **Ortofotomapa z Geoportalu** | warunki pobierania **do pracy offline** wciąż niepotwierdzone; usługa nie jest przystosowana do masowego ściągania kafelków |
| **Publiczne serwery OpenStreetMap** | regulamin wprost zabrania masowego pobierania kafelków — odpada |
| **Brak podkładu (same obrysy działek)** | działa zawsze, nic nie narusza, nic nie waży |

## Decyzja

**Etap 1: mapa bez podkładu.** Pokazujemy obrysy działek i pól na jednolitym
tle w kolorach aplikacji, z numerem działki i własną nazwą pola („Za stodołą").
Granice pobieramy z ULDK raz — przy dodawaniu działki — i trzymamy w bazie
lokalnej. Od tej chwili mapa działa bez internetu.

Dla wyboru pola to wystarcza: rolnik rozpoznaje swoje pola po kształcie,
położeniu względem sąsiednich i po nazwie, a nie po zdjęciu lotniczym.

**Podkład zdjęciowy jest dodatkiem na później** — włączanym świadomie przez
rolnika dla wskazanego obszaru, po rozstrzygnięciu warunków licencyjnych.
Nigdy nie pobieramy kafelków w tle ani „na zapas".

## Następstwa

- Praca w polu nie zależy od zasięgu i od cudzych serwerów.
- Aplikacja nie rozrasta się o setki megabajtów kafelków.
- Dopóki nie ma podkładu, ważniejsze stają się: czytelny obrys, numer działki
  i własna nazwa pola nadana przez rolnika.
- Geometria w bazie jest w układzie WGS 84 (EPSG:4326), bo tego potrzebuje
  mapa i odbiornik GPS w telefonie. ULDK domyślnie zwraca EPSG:2180, więc
  o układ prosimy wprost w zapytaniu.
- Pozostaje do rozstrzygnięcia: czy i na jakich warunkach wolno trzymać
  ortofotomapę offline (pytanie do GUGiK, razem z pytaniem do MRiRW o etykiety).
