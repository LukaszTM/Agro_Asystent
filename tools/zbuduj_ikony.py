"""Wytwarza ikony aplikacji i ekran powitalny z plików logo.

Źródła są dwa i każde ma swoje zadanie:

- `assets/logo/moj_lan_znak.png` — **sam znak**, bez nazwy; z niego
  powstają ikony, bo w kwadracie 48 × 48 px napis i tak zlewa się w kreskę,
- `assets/logo/moj_lan.png` — **pełne logo z nazwą**; z niego powstaje
  logo ekranu powitalnego, gdzie jest miejsce na nazwę.

Dzięki temu nie powstają rozjeżdżone warianty rysowane ręcznie — zmiana logo
to podmiana pliku i ponowne uruchomienie tego skryptu.

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

#: Ikona adaptacyjna ma kanwę 108 dp, z czego widoczne zostaje 66 dp —
#: resztę zabiera maska nakładki producenta (koło, zaokrąglony kwadrat).
#: Android dopuszcza znak od 48 do 66 dp, więc bierzemy górną granicę.
UDZIAL_LOGO_W_IKONIE_ADAPTACYJNEJ = 66 / 108

ROZMIARY_WINDOWS = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]

#: Krycie, poniżej którego piksel uznajemy za ślad cienia, a nie rysunek.
#: Pliki od projektanta mają wokół znaku ledwo widoczną poświatę sięgającą
#: krawędzi; bez jej pominięcia logo byłoby na ikonie mniejsze, niż może być.
PROG_OBCINANIA = 32


def przytnij_do_kwadratu(obraz: Image.Image) -> Image.Image:
    """Obcina przezroczysty margines i dokłada zapas do kwadratu.

    Skrypt skaluje źródło wprost do boku ikony, więc obrazek prostokątny
    zostałby ściśnięty, a zbędny margines zabrałby miejsce samemu znakowi.
    """
    ksztalt = obraz.getchannel("A").point(
        lambda v: 255 if v > PROG_OBCINANIA else 0
    )
    obszar = ksztalt.getbbox()
    if obszar is None:
        return obraz
    przyciety = obraz.crop(obszar)
    bok = max(przyciety.size)
    kwadrat = Image.new("RGBA", (bok, bok), (0, 0, 0, 0))
    kwadrat.paste(
        przyciety,
        ((bok - przyciety.width) // 2, (bok - przyciety.height) // 2),
    )
    return kwadrat


def zbuduj(
    logo: Path,
    znak: Path,
    katalog_android: Path,
    ikona_windows: Path,
) -> list[str]:
    zrodlo = przytnij_do_kwadratu(Image.open(logo).convert("RGBA"))
    # Gdy wersji bez nazwy jeszcze nie ma, ikony robimy z pełnego logo —
    # brzydziej, ale skrypt nie wywraca się na brakującym pliku.
    zrodlo_znaku = (
        przytnij_do_kwadratu(Image.open(znak).convert("RGBA"))
        if znak.exists()
        else zrodlo
    )
    zrobione: list[str] = []

    for gestosc, bok in GESTOSCI.items():
        katalog = katalog_android / f"mipmap-{gestosc}"
        katalog.mkdir(parents=True, exist_ok=True)
        zrodlo_znaku.resize((bok, bok), Image.LANCZOS).save(
            katalog / "ic_launcher.png", optimize=True
        )

        bok_adaptacyjny = round(bok * 108 / 48)
        plansza = Image.new("RGBA", (bok_adaptacyjny, bok_adaptacyjny), (0, 0, 0, 0))
        wielkosc = round(bok_adaptacyjny * UDZIAL_LOGO_W_IKONIE_ADAPTACYJNEJ)
        logo_male = zrodlo_znaku.resize((wielkosc, wielkosc), Image.LANCZOS)
        odstep = (bok_adaptacyjny - wielkosc) // 2
        plansza.paste(logo_male, (odstep, odstep), logo_male)
        plansza.save(katalog / "ic_launcher_foreground.png", optimize=True)

        # Warstwa jednobarwna (Android 13+): system barwi ją pod tapetę
        # użytkownika, więc nasze kolory i tak odrzuci — liczy się sam kształt.
        # Bierzemy go z kanału alfa znaku: przerwy w rysunku są przezroczyste,
        # więc zostają dziurami i znak zachowuje podział na pasy.
        sylwetka = Image.new("RGBA", (bok_adaptacyjny, bok_adaptacyjny), (0, 0, 0, 0))
        ksztalt = logo_male.getchannel("A").point(lambda v: 255 if v > 128 else 0)
        sylwetka.paste((0, 0, 0, 255), (odstep, odstep), ksztalt)
        sylwetka.save(katalog / "ic_launcher_monochrome.png", optimize=True)

        zrobione.append(f"ikona ze znaku {gestosc}: {bok}×{bok}")

    for gestosc, bok in POWITALNE.items():
        katalog = katalog_android / f"drawable-{gestosc}"
        katalog.mkdir(parents=True, exist_ok=True)
        zrodlo.resize((bok, bok), Image.LANCZOS).save(
            katalog / "logo_powitalne.png", optimize=True
        )
        zrobione.append(f"logo powitalne z pełnego logo {gestosc}: {bok}×{bok}")

    ikona_windows.parent.mkdir(parents=True, exist_ok=True)
    zrodlo_znaku.save(ikona_windows, sizes=ROZMIARY_WINDOWS)
    zrobione.append(f"ikona Windows: {len(ROZMIARY_WINDOWS)} rozmiarów")
    return zrobione


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--logo", type=Path, default=Path("assets/logo/moj_lan.png"))
    parser.add_argument(
        "--znak", type=Path, default=Path("assets/logo/moj_lan_znak.png")
    )
    parser.add_argument("--android", type=Path, default=Path("android/app/src/main/res"))
    parser.add_argument(
        "--windows", type=Path, default=Path("windows/runner/resources/app_icon.ico")
    )
    args = parser.parse_args(argv)

    if not args.logo.exists():
        print(f"Brak pliku logo: {args.logo}")
        return 1
    for opis in zbuduj(args.logo, args.znak, args.android, args.windows):
        print(f"  {opis}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
