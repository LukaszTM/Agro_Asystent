# tools — skrypty przygotowania danych

Skrypty uruchamiane **na komputerze dewelopera**, nigdy z telefonu rolnika
(plan, pkt 11). Zadaniem skryptu jest zamienić pliki urzędowe na gotowy słownik,
który dołączamy do aplikacji jako dane z numerem wersji.

## Uruchomienie

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r tools/requirements.txt
python3 tools/<zadanie>/<skrypt>.py --help
```

## Układ

Każde zadanie przygotowawcze ma własny katalog; wynik zapisuje do `dane/wynik/`,
a pliki źródłowe trzyma w `dane/pobrane/` (oba katalogi są poza repozytorium).

| Katalog | Zadanie | Źródło |
| --- | --- | --- |
| `p1_zastosowania/` | XLSX zastosowań środków → SQLite (**gotowe**) | MRiRW + dane.gov.pl (CC0) — patrz ADR-0002 |
| `p2_etykiety/` | etykiety PDF → karencja, prewencja, liczba zabiegów (**próba A–B gotowa**) | gov.pl, etykiety środków |
| `p3_slownik_upraw/` | uprawy z wniosku ↔ uprawy z rejestru ↔ kod EPPO (**gotowe**) | pliki z P1, P2, P4 i baza EPPO |
| `p4_wniosek_pdf/` | tabele X i XI wniosku z eWniosekPlus | PDF wniosku (lokalnie, nie w repozytorium) |
| `p5_uldk/` | granice działek po identyfikatorze TERYT | uldk.gugik.gov.pl |

## Zasady

- **Pobieranie powoli i z pamięcią podręczną.** Przerwy między żądaniami, brak
  ponownego pobierania tego, co już jest. Przed masowym pobieraniem z gov.pl
  sprawdzić regulamin strony (plan, pkt 10).
- **Niepewny odczyt oznaczamy, nie zgadujemy.** Każdy wiersz wynikowy ma pole
  źródła i znacznik pewności; brakujących wartości nie wypełniamy „na oko".
- **Raport z liczbami po każdym uruchomieniu**: ile wierszy wczytano, ile
  odrzucono i dlaczego. Raporty z zadań trafiają do `docs/raporty/`.
- **Żadnych danych osobowych w repozytorium.** Wnioski zostają na dysku
  dewelopera; do testów służą zanonimizowane wzorce w `test/dane/`.
