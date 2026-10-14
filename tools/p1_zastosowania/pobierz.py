"""Pobieranie plików rejestru środków ochrony roślin (zadanie P1)."""

from __future__ import annotations

import argparse
import sys
import urllib.error
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from wspolne.pobieranie import PRZERWA_SEKUND, Pobieracz  # noqa: E402

#: Źródło główne: portal otwartych danych, licencja CC0 1.0, aktualizacja kwartalna.
WYDANIE_DANE_GOV = "20261001"
PLIKI_DANE_GOV = {
    "Rejestr_podstawowe.xlsx": "rejestr podstawowy (środki)",
    "Rejestr_zastosowanie.xlsx": "rejestr zastosowań",
    "Slownik_Uprawy.csv": "słownik upraw",
    "Slownik_Agrofagi.csv": "słownik agrofagów",
    "Slownik_Grup_Stosowania.csv": "słownik grup stosowania",
    "Slownik_Rodzaj_preparatu.csv": "słownik rodzajów preparatu",
    "Slownik_Substancji_aktywnych.csv": "słownik substancji aktywnych",
}

#: Źródło pomocnicze: strona MRiRW — ten sam rejestr w jednym, szerszym arkuszu,
#: zwykle świeższy niż wydanie kwartalne.
ADRES_MRIRW = "https://www.gov.pl/attachment/716adc81-3da6-4607-ac39-d155a1283e12"

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Pobiera rejestr środków ochrony roślin do katalogu roboczego."
    )
    parser.add_argument(
        "--katalog",
        type=Path,
        default=Path("dane/pobrane"),
        help="gdzie zapisać pliki (domyślnie dane/pobrane)",
    )
    parser.add_argument(
        "--przerwa",
        type=float,
        default=PRZERWA_SEKUND,
        help="przerwa między żądaniami w sekundach (domyślnie 2)",
    )
    parser.add_argument(
        "--bez-mrirw",
        action="store_true",
        help="pomiń plik ze strony ministerstwa (pobierz tylko wydanie z dane.gov.pl)",
    )
    args = parser.parse_args(argv)

    args.katalog.mkdir(parents=True, exist_ok=True)
    pobieracz = Pobieracz(args.katalog, args.przerwa)

    zadania = [
        (f"https://api.dane.gov.pl/media/resources/{WYDANIE_DANE_GOV}/{plik}", plik, opis)
        for plik, opis in PLIKI_DANE_GOV.items()
    ]
    if not args.bez_mrirw:
        zadania.append((ADRES_MRIRW, "MRiRW_Rejestr_zastosowanie.xlsx", "rejestr zastosowań (MRiRW)"))

    pobrane = pominiete = 0
    for adres, nazwa, opis in zadania:
        try:
            wynik = pobieracz.pobierz(adres, nazwa)
        except (urllib.error.URLError, PermissionError) as blad:
            print(f"  BŁĄD  {opis}: {blad}", file=sys.stderr)
            return 1
        if wynik.pobrany:
            pobrane += 1
            print(f"  pobrano    {opis:34} {wynik.rozmiar:>9} B")
        else:
            pominiete += 1
            print(f"  aktualny   {opis:34} {wynik.rozmiar:>9} B")

    print(f"\nGotowe: pobranych {pobrane}, bez zmian {pominiete}. Katalog: {args.katalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
