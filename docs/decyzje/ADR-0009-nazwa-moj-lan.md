# ADR-0009. Nazwa aplikacji: Mój Łan

- Stan: **przyjęte** (19 października 2026 r.)
- Dotyczy: nazwy w aplikacji, w sklepie, na wydrukach i w plikach do pobrania

## Problem

Projekt nazywał się „Agro Asystent". Przegląd rynku przed publikacją pokazał,
że od 2009 r. istnieje komercyjny program **AgroAsystent 2** firmy AgroPower
(agropower.pl) dla gospodarstw roślinnych: ewidencja działek, zasiewów,
magazyn. Ten sam segment i prawie ta sama nazwa to ryzyko sporu o znak
towarowy i pomyłek u rolników i doradców.

## Decyzja

Nazwa **Mój Łan**. Krótka, polska, zrozumiała dla rolnika 60+; „Mój" odróżnia
ją od zwykłego słowa (łatwiej zastrzec) i mówi, że to własny zeszyt
gospodarstwa, nie portal urzędu. W sieci nie ma aplikacji, programu ani marki
rolniczej o tej nazwie (sprawdzone 19.10.2026; przed publikacją w sklepie
do potwierdzenia w UPRP, klasy 9 i 42, oraz domena `mojlan.pl`).

Co się zmienia:

- `Marka.nazwa`, logo i kolory marki (`lib/rdzen/marka/`), ikony z
  `tools/zbuduj_ikony.py`;
- identyfikator pakietu Androida: `pl.mojlan.app` (testerzy muszą
  zainstalować aplikację od nowa — to inny pakiet);
- program na Windows: `moj_lan.exe`;
- nazwy plików do pobrania: `moj-lan-<wersja>.apk`, `moj-lan-windows-<wersja>.zip`;
- nazwa pliku kopii: `moj-lan-kopia-<data>.zip`.

Co zostaje:

- znacznik formatu wewnątrz pliku kopii (`agro-asystent-kopia`), żeby kopie
  sprzed zmiany nazwy nadal się wczytywały;
- nazwa repozytorium i pakietu Dart (`agro_asystent`) — techniczne, niewidoczne.

## Odrzucone

- **Zagon**, **Morga**, **Pokos**, **Miedza** — równie czyste, ale bez „Mój"
  są zwykłymi słowami, trudniej je zastrzec.
- **Zeszyt Rolnika** — jasne, ale opisowe i blisko istniejących „Ewidencja
  Rolnika", „Gospodarz+".
- Każda nazwa z „Agro" — najgęściej zajęty kawałek rynku.
