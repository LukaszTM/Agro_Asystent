"""Przycina czcionkę DejaVu Sans do znaków potrzebnych na wydrukach.

Pełna DejaVu Sans waży 1,5 MB (zwykła i pogrubiona), a na dokumentach
używamy tylko łacinki, polskich znaków i garści symboli — po przycięciu
zostaje około 36 kB. Skrypt uruchamia się na komputerze dewelopera, wynik
wchodzi do `assets/czcionki/` (zadanie: etap 1, krok 4).

Licencja DejaVu (Bitstream Vera) pozwala na użycie, zmianę i sprzedaż pod
warunkiem dołączenia treści licencji — leży w `assets/czcionki/LICENCJA.txt`.

Użycie:
    python3 tools/zbuduj_czcionki.py [--zrodlo /usr/share/fonts/truetype/dejavu]
"""

from __future__ import annotations

import argparse
from pathlib import Path

from fontTools import subset

#: Znaki, które naprawdę pojawiają się na wydrukach i w eksportach.
ZNAKI = (
    "U+0020-007E,U+00A0-00FF,"  # łacinka podstawowa i Latin-1
    "U+0104-0107,U+0118-0119,U+0141-0144,U+015A-015B,U+0179-017C,"  # polskie
    "U+2010-2015,U+2018-201E,U+2020-2022,U+2026,U+2030,"  # myślniki, cudzysłowy
    "U+2212,U+2260,U+2264,U+2265,U+20AC"  # znaki matematyczne, euro
)

PLIKI = [
    ("DejaVuSans.ttf", "dejavu_sans_pl.ttf"),
    ("DejaVuSans-Bold.ttf", "dejavu_sans_pl_bold.ttf"),
]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--zrodlo",
        type=Path,
        default=Path("/usr/share/fonts/truetype/dejavu"),
        help="katalog z plikami DejaVuSans*.ttf",
    )
    parser.add_argument(
        "--wynik",
        type=Path,
        default=Path("assets/czcionki"),
        help="katalog docelowy w projekcie",
    )
    args = parser.parse_args(argv)
    args.wynik.mkdir(parents=True, exist_ok=True)

    for nazwa_zrodla, nazwa_wyniku in PLIKI:
        zrodlo = args.zrodlo / nazwa_zrodla
        if not zrodlo.exists():
            print(f"Brak pliku {zrodlo} — zainstaluj czcionki DejaVu.")
            return 1
        cel = args.wynik / nazwa_wyniku
        subset.main([
            str(zrodlo),
            f"--unicodes={ZNAKI}",
            "--layout-features=",
            "--no-hinting",
            "--desubroutinize",
            f"--output-file={cel}",
        ])
        print(f"{zrodlo.name}: {zrodlo.stat().st_size // 1024} kB "
              f"→ {cel.name}: {cel.stat().st_size // 1024} kB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
