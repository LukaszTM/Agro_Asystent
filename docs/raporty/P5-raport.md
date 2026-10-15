# Raport P5 — granice działek z ULDK i mapa offline

15 października 2026 r. Zadanie: „P5. Prototyp ULDK" z planu (pkt 9):
pobranie granic po identyfikatorze, zapis lokalny, wyświetlenie na mapie offline.

## Stan zadania

| Część | Stan |
| --- | --- |
| Klient usługi ULDK (budowa zapytania, odczyt odpowiedzi, pamięć podręczna) | **gotowe, nieprzetestowane na żywej usłudze** |
| Zapis granic do bazy lokalnej | **gotowe** |
| Rysowanie granic bez internetu | **gotowe** |
| Decyzja o podkładzie mapy | **gotowe** — `docs/decyzje/ADR-0003-mapa-offline.md` |
| Sprawdzenie na prawdziwych działkach | **zablokowane** — `uldk.gugik.gov.pl` poza dozwolonymi domenami środowiska |

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `tools/p5_uldk/klient.py` | pobiera granice działek z ULDK i zapisuje do `dane/wynik/dzialki.sqlite` |
| `tools/p5_uldk/mapa.py` | zamienia geometrię WKT na rysunek SVG — bez żadnego serwera kafelków |
| `tools/p5_uldk/test_uldk.py` | 13 testów (bez łączenia się z siecią) |

Klient korzysta ze wspólnego pobieracza z P1/P2: sprawdza `robots.txt`,
przedstawia się nagłówkiem User-Agent, robi przerwy między żądaniami, nie
pobiera ponownie tego, co już ma, i ponawia próbę przy zerwanym połączeniu.
Granice pobiera się **raz na działkę** — potem wszystko dzieje się offline.

## Czego jeszcze nie wiemy

Usługa ULDK jest w tym środowisku niedostępna, więc **klient nie został
sprawdzony na żywej usłudze**. Zbudowany jest według opisu z planu (pkt 6.1)
i dokumentacji `uldk.gugik.gov.pl/opis.html`, a odczyt odpowiedzi jest objęty
testami na przykładowej treści — ale to nie to samo co prawdziwe wywołanie.
Doświadczenie z P4 mówi wprost, czego się spodziewać: prawdziwa usługa prawie
na pewno różni się w szczegółach od opisu.

Po dodaniu `uldk.gugik.gov.pl` do dozwolonych domen wystarczy:

```bash
python3 tools/p5_uldk/klient.py --plik dane/prywatne/dzialki_z_wniosku.pdf.csv
python3 tools/p5_uldk/mapa.py
```

Identyfikatory 20 działek z prawdziwego wniosku są już odczytane przez czytnik
z P4 i czekają w katalogu roboczym.

## Mapa bez internetu — sprawdzona

Na zmyślonej geometrii (9 działek) rysunek powstaje poprawnie: obrysy, numery
działek, kolory z makiety aplikacji, poprawka na zbieżność południków, żeby
działki nie wyglądały na rozciągnięte. Rysunek nie wymaga żadnego połączenia.

Decyzja o podkładzie: **etap 1 bez zdjęcia lotniczego** (ADR-0003). Publiczne
serwery OpenStreetMap zabraniają masowego pobierania kafelków, a warunki
trzymania ortofotomapy z Geoportalu offline nadal nie są potwierdzone. Dla
wyboru pola wystarczy obrys, numer działki i własna nazwa pola.

## Następny krok

**P6. Model danych** — schemat SQLite z migracjami według punktu 7 planu.
Wszystkie cztery źródła danych są już rozpoznane: rejestr środków (P1),
etykiety i karencja (P2), słownik upraw i kody EPPO (P3), wniosek (P4),
granice działek (P5). Teraz trzeba je złożyć w jedną bazę aplikacji.
