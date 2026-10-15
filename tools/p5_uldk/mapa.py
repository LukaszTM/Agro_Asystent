"""Rysowanie granic działek bez internetu (zadanie P5).

Granice pobrane z ULDK trzymamy lokalnie jako WKT. Ten moduł zamienia je na
rysunek SVG — bez żadnego serwera kafelków. To sprawdzian założenia z planu:
mapa ma działać w polu, gdzie nie ma zasięgu.

Podkład (ortofotomapa) to osobna sprawa — patrz ADR-0003.
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
from dataclasses import dataclass
from pathlib import Path

#: Kolory z makiety (plan, pkt 5) — rysunek ma wyglądać jak ekran aplikacji.
TLO = "#F4F6F0"
WYPELNIENIE = "#E4EEDF"
OBRYS = "#1E5B2E"
TEKST = "#10230F"

Punkt = tuple[float, float]
Pierscien = list[Punkt]


@dataclass
class Ksztalt:
    """Obrys działki: zewnętrzny pierścień i ewentualne wycięcia."""

    identyfikator: str
    pierscienie: list[Pierscien]


def _punkty(tekst: str) -> Pierscien:
    punkty: Pierscien = []
    for para in tekst.split(","):
        czesci = para.split()
        if len(czesci) >= 2:
            punkty.append((float(czesci[0]), float(czesci[1])))
    return punkty


def wczytaj_wkt(wkt: str) -> list[Pierscien]:
    """Zamienia POLYGON / MULTIPOLYGON na listę pierścieni.

    Nie obsługujemy całego standardu WKT — tylko to, co zwraca ULDK dla działek.
    """
    tekst = wkt.strip()
    rodzaj = tekst.split("(", 1)[0].strip().upper()
    if rodzaj not in {"POLYGON", "MULTIPOLYGON"}:
        raise ValueError(f"nieobsługiwany rodzaj geometrii: {rodzaj or tekst[:20]}")
    return [_punkty(grupa) for grupa in re.findall(r"\(([^()]*)\)", tekst) if grupa.strip()]


def zasieg(ksztalty: list[Ksztalt]) -> tuple[float, float, float, float]:
    punkty = [p for k in ksztalty for pierscien in k.pierscienie for p in pierscien]
    if not punkty:
        raise ValueError("brak punktów do narysowania")
    xs = [p[0] for p in punkty]
    ys = [p[1] for p in punkty]
    return min(xs), min(ys), max(xs), max(ys)


def rysuj_svg(ksztalty: list[Ksztalt], szerokosc: int = 900, margines: int = 20,
              podpisy: bool = True) -> str:
    """Rysunek działek w SVG. Współrzędne geograficzne przeliczamy liniowo —
    przy wielkości jednego gospodarstwa zniekształcenie jest nieistotne."""
    minx, miny, maxx, maxy = zasieg(ksztalty)
    szer_geo = max(maxx - minx, 1e-9)
    wys_geo = max(maxy - miny, 1e-9)
    # Na naszej szerokości geograficznej stopień długości jest krótszy niż stopień
    # szerokości — bez tej poprawki działki wyglądałyby na rozciągnięte.
    import math

    skala_x = math.cos(math.radians((miny + maxy) / 2))
    skala = (szerokosc - 2 * margines) / (szer_geo * skala_x)
    wysokosc = int(wys_geo * skala + 2 * margines)

    def na_ekran(punkt: Punkt) -> tuple[float, float]:
        x = margines + (punkt[0] - minx) * skala_x * skala
        y = wysokosc - margines - (punkt[1] - miny) * skala
        return round(x, 1), round(y, 1)

    czesci = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{szerokosc}" '
        f'height="{wysokosc}" viewBox="0 0 {szerokosc} {wysokosc}">',
        f'<rect width="100%" height="100%" fill="{TLO}"/>',
    ]
    for ksztalt in ksztalty:
        for pierscien in ksztalt.pierscienie:
            if len(pierscien) < 3:
                continue
            sciezka = " ".join(
                f"{'M' if i == 0 else 'L'}{x},{y}"
                for i, (x, y) in enumerate(na_ekran(p) for p in pierscien)
            )
            czesci.append(
                f'<path d="{sciezka} Z" fill="{WYPELNIENIE}" stroke="{OBRYS}" '
                f'stroke-width="1.5"/>'
            )
        if podpisy and ksztalt.pierscienie and ksztalt.pierscienie[0]:
            punkty = ksztalt.pierscienie[0]
            srodek = (
                sum(p[0] for p in punkty) / len(punkty),
                sum(p[1] for p in punkty) / len(punkty),
            )
            x, y = na_ekran(srodek)
            etykieta = ksztalt.identyfikator.rsplit(".", 1)[-1]
            czesci.append(
                f'<text x="{x}" y="{y}" fill="{TEKST}" font-size="13" '
                f'font-family="sans-serif" text-anchor="middle">{etykieta}</text>'
            )
    czesci.append("</svg>")
    return "\n".join(czesci)


def wczytaj_z_bazy(baza: Path) -> list[Ksztalt]:
    polaczenie = sqlite3.connect(f"file:{baza}?mode=ro", uri=True)
    try:
        return [
            Ksztalt(identyfikator=identyfikator, pierscienie=wczytaj_wkt(wkt))
            for identyfikator, wkt in polaczenie.execute(
                "SELECT identyfikator, wkt FROM dzialka_geometria ORDER BY identyfikator"
            )
        ]
    finally:
        polaczenie.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baza", type=Path, default=Path("dane/wynik/dzialki.sqlite"))
    parser.add_argument("--wynik", type=Path, default=Path("dane/wynik/dzialki.svg"))
    parser.add_argument("--szerokosc", type=int, default=900)
    args = parser.parse_args(argv)

    if not args.baza.exists():
        print(f"Brak bazy {args.baza}. Uruchom najpierw klient.py", file=sys.stderr)
        return 1

    ksztalty = wczytaj_z_bazy(args.baza)
    if not ksztalty:
        print("Baza nie zawiera granic działek", file=sys.stderr)
        return 1

    args.wynik.parent.mkdir(parents=True, exist_ok=True)
    args.wynik.write_text(rysuj_svg(ksztalty, args.szerokosc), encoding="utf-8")
    minx, miny, maxx, maxy = zasieg(ksztalty)
    print(f"Działek narysowanych: {len(ksztalty)}")
    print(f"Zasięg: {minx:.5f}–{maxx:.5f} dł. geogr., {miny:.5f}–{maxy:.5f} szer. geogr.")
    print(f"Rysunek: {args.wynik}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
