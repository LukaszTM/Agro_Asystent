# ADR-0008. Skąd bierzemy pogodę

- Stan: **przyjęte** (18 października 2026 r., etap 3, krok 5)
- Dotyczy: zamówienia właściciela („szczegółowa pogoda na co najmniej 3 dni")
  oraz reguły offline-first i budżetu zero

## Problem

Program ma pokazywać pogodę na kilka dób — a jednocześnie:

- działać w całości **bez internetu** (pogoda może być tylko dodatkiem),
- nie kosztować nic (budżet projektu = 0),
- mieć licencję pozwalającą na **użycie komercyjne**, bo aplikacja ma mieć
  wersję płatną,
- nie wymagać własnego serwera ani konta z kluczem, którego nie ma gdzie
  bezpiecznie trzymać w aplikacji instalowanej u rolnika.

## Co sprawdzono

| Źródło | Ocena |
| --- | --- |
| **MET Norway** (Norweski Instytut Meteorologiczny, `api.met.no`, Locationforecast 2.0) | bezpłatne, bez klucza, dane otwarte na licencji **CC BY 4.0** (plus NLOD) — a CC BY 4.0 dopuszcza użycie komercyjne. Wymaga przedstawienia się w nagłówku `User-Agent` (nazwa aplikacji i kontakt), podania źródła oraz oszczędnego odpytywania. **Wybrane.** |
| **Open-Meteo** | darmowe API wolno używać **tylko niekomercyjnie** (do użytku komercyjnego potrzebna płatna subskrypcja). Odpada przy założeniu wersji płatnej. |
| **IMGW-PIB** (`danepubliczne.imgw.pl`) | polskie dane publiczne, dobre do ostrzeżeń i pomiarów ze stacji; warunków ponownego wykorzystania **nie udało się potwierdzić** z tego środowiska, a prognozy punktowej w tym API nie ma. Zostaje jako kandydat na ostrzeżenia meteorologiczne — do sprawdzenia. |

## Decyzja

Pogodę pobieramy z **MET Norway**, bez klucza, z nagłówkiem `User-Agent`
zawierającym nazwę programu i adres kontaktowy. Nazwa źródła stoi na karcie
pogody — to warunek licencji, nie ozdoba.

Położenie gospodarstwa liczymy **z granic działek** pobranych wcześniej
z ULDK (środek wszystkich obrysów). Rolnik nie podaje adresu ani miasta,
a program nie wysyła nic poza zaokrągloną do czterech miejsc współrzędną.
Bez ani jednej działki z granicami karta mówi wprost, że nie wie, gdzie
leży gospodarstwo — i nie zgaduje.

Ostatnią prognozę zapisujemy w bazie (`pogoda_zapis`) i pokazujemy ją
**z datą pobrania**, gdy sieci nie ma. Nowe pobranie najwyżej raz na trzy
godziny, chyba że rolnik sam kliknie „Pobierz na nowo".

## Następstwa

- Program działa bez internetu dokładnie tak samo jak dotąd; bez sieci
  znika tylko świeżość prognozy, a nie żadna funkcja dokumentacyjna.
- Zapis pogody **nie jedzie w kopii danych** (`KopiaDanych.pozaKopia`):
  to dane z sieci, nie wpisy rolnika, i na drugim urządzeniu pobiorą się
  własne.
- **Dopuszczalnej prędkości wiatru przy oprysku program nie podaje.** To
  wartość z przepisów i z etykiety środka, więc gdy ma się pojawić, trafi
  do słownika reguł (`assets/dane/reguly_prawne.json`), a nie do kodu
  pogody (CLAUDE.md, reguła 1). Dziś karta pokazuje liczbę i odsyła do
  etykiety.
- Przed wydaniem trzeba: wpisać w `User-Agent` prawdziwy adres kontaktowy
  właściciela i **przeczytać w całości regulamin MET** (z tego środowiska
  `api.met.no` jest nieosiągalny, więc warunki znamy z dokumentacji
  pośredniej — to jedyny element tej decyzji oparty na źródle z drugiej
  ręki).
