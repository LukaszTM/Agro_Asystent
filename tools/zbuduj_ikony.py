"""Wytwarza ikony aplikacji i ekran powitalny z jednego pliku logo.

Źródłem jest zawsze `assets/logo/agro_asystent.png`. Dzięki temu nie powstają
rozjeżdżone warianty logo rysowane ręcznie — zmiana logo to podmiana jednego
pliku i ponowne uruchomienie tego skryptu.

    python3 tools/zbuduj_ikony.py
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

#: Gęstości ekranu Androida i bok ikony w pikselach.
GESTOSCI = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}

#: Logo na ekranie powitalnym — większe niż ikona.
POWITALNE = {"mdpi": 160, "hdpi": 240, "xhdpi": 320, "xxhdpi": 480, "xxxhdpi": 640}

#: Android przycina pierwszy plan ikony adaptacyjnej do koła albo kwadratu,
#: więc logo musi mieć zapas przy krawędziach.
UDZIAL_LOGO_W_IKONIE_ADAPTACYJNEJ = 0.62

ROZMIARY_WINDOWS = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def zbuduj(logo: Path, katalog_android: Path, ikona_windows: Path) -> list[str]:
    zrodlo = Image.open(logo).convert("RGBA")
    zrobione: list[str] = []

    for gestosc, bok in GESTOSCI.items():
        katalog = katalog_android / f"mipmap-{gestosc}"
        katalog.mkdir(parents=True, exist_ok=True)
        zrodlo.resize((bok, bok), Image.LANCZOS).save(
            katalog / "ic_launcher.png", optimize=True
        )

        bok_adaptacyjny = round(bok * 108 / 48)
        plansza = Image.new("RGBA", (bok_adaptacyjny, bok_adaptacyjny), (0, 0, 0, 0))
        wielkosc = round(bok_adaptacyjny * UDZIAL_LOGO_W_IKONIE_ADAPTACYJNEJ)
        logo_male = zrodlo.resize((wielkosc, wielkosc), Image.LANCZOS)
        odstep = (bok_adaptacyjny - wielkosc) // 2
        plansza.paste(logo_male, (odstep, odstep), logo_male)
        plansza.save(katalog / "ic_launcher_foreground.png", optimize=True)
        zrobione.append(f"ikona {gestosc}: {bok}×{bok}")

    for gestosc, bok in POWITALNE.items():
        katalog = katalog_android / f"drawable-{gestosc}"
        katalog.mkdir(parents=True, exist_ok=True)
        zrodlo.resize((bok, bok), Image.LANCZOS).save(
            katalog / "logo_powitalne.png", optimize=True
        )
        zrobione.append(f"logo powitalne {gestosc}: {bok}×{bok}")

    ikona_windows.parent.mkdir(parents=True, exist_ok=True)
    zrodlo.save(ikona_windows, sizes=ROZMIARY_WINDOWS)
    zrobione.append(f"ikona Windows: {len(ROZMIARY_WINDOWS)} rozmiarów")
    return zrobione


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--logo", type=Path, default=Path("assets/logo/agro_asystent.png"))
    parser.add_argument("--android", type=Path, default=Path("android/app/src/main/res"))
    parser.add_argument(
        "--windows", type=Path, default=Path("windows/runner/resources/app_icon.ico")
    )
    args = parser.parse_args(argv)

    if not args.logo.exists():
        print(f"Brak pliku logo: {args.logo}")
        return 1
    for opis in zbuduj(args.logo, args.android, args.windows):
        print(f"  {opis}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
