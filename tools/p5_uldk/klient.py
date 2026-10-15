"""Pobieranie granic działek ewidencyjnych z usługi ULDK (GUGiK) — zadanie P5.

Usługa jest bezpłatna, bez logowania i przyjmuje wyłącznie żądania GET:
https://uldk.gugik.gov.pl/opis.html

Zasada z planu: granice pobieramy **raz**, zapisujemy lokalnie i dalej
pracujemy bez internetu. Skrypt uruchamiany jest na komputerze dewelopera albo
jednorazowo przy dodawaniu działki w aplikacji — nigdy masowo z telefonu.
"""

from __future__ import annotations

import argparse
import re
import sqlite3
import sys
import urllib.error
import urllib.parse
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from wspolne.pobieranie import Pobieracz  # noqa: E402

ADRES = "https://uldk.gugik.gov.pl/"

#: Identyfikator działki: WWPPGG_R.OOOO[.AR_NR].NR_DZ
IDENTYFIKATOR = re.compile(r"^\d{6}_\d\.\d{4}(?:\.AR_\d+)?\.\d+(?:/\d+)?$")

SCHEMAT = """
CREATE TABLE IF NOT EXISTS dzialka_geometria (
    identyfikator TEXT PRIMARY KEY,
    wkt           TEXT NOT NULL,
    srid          INTEGER NOT NULL,
    powierzchnia_m2 REAL,
    wojewodztwo   TEXT,
    powiat        TEXT,
    gmina         TEXT,
    obreb         TEXT,
    data_pobrania TEXT NOT NULL,
    zrodlo        TEXT NOT NULL
);
"""


class BladUldk(Exception):
    """Usługa odpowiedziała błędem albo odpowiedź jest nieczytelna."""


@dataclass
class Dzialka:
    identyfikator: str
    wkt: str
    srid: int
    powierzchnia_m2: float | None = None
    wojewodztwo: str | None = None
    powiat: str | None = None
    gmina: str | None = None
    obreb: str | None = None


#: Pola odpowiedzi w kolejności, w jakiej je zamawiamy — usługa zwraca je
#: dokładnie w tym porządku, rozdzielone znakiem „|".
POLA_WYNIKU = ["geom_wkt", "teryt", "voivodeship", "county", "commune", "region", "parcel"]


def adres_zapytania(identyfikator: str, srid: int = 4326) -> str:
    """Buduje adres żądania GetParcelById."""
    parametry = {
        "request": "GetParcelById",
        "id": identyfikator,
        "result": ",".join(POLA_WYNIKU),
        "srid": str(srid),
    }
    return ADRES + "?" + urllib.parse.urlencode(parametry)


def rozbierz_geometrie(pole: str) -> tuple[str, int | None]:
    """Usługa zwraca geometrię w postaci EWKT: „SRID=4326;POLYGON((…))".

    Zwraca samo WKT oraz układ współrzędnych odczytany z przedrostka.
    """
    tekst = pole.strip()
    srid: int | None = None
    if tekst.upper().startswith("SRID="):
        przedrostek, _, reszta = tekst.partition(";")
        try:
            srid = int(przedrostek.split("=", 1)[1])
        except (IndexError, ValueError):
            srid = None
        tekst = reszta.strip()
    return tekst, srid


def odczytaj_odpowiedz(tresc: str, identyfikator: str, srid: int) -> Dzialka:
    """Odpowiedź ULDK: pierwszy wiersz to status (0 = w porządku), dalej dane
    rozdzielone znakiem „|", z geometrią w postaci WKT."""
    wiersze = [w for w in tresc.strip().splitlines() if w.strip()]
    if not wiersze:
        raise BladUldk(f"{identyfikator}: pusta odpowiedź usługi")

    status = wiersze[0].strip()
    if not status.startswith("0"):
        raise BladUldk(f"{identyfikator}: usługa zwróciła status „{status}”")
    if len(wiersze) < 2:
        raise BladUldk(f"{identyfikator}: brak danych w odpowiedzi")

    pola = [p.strip() for p in wiersze[1].split("|")]
    dane = dict(zip(POLA_WYNIKU, pola))

    wkt, srid_z_odpowiedzi = rozbierz_geometrie(dane.get("geom_wkt", ""))
    if not wkt.upper().startswith(("POLYGON", "MULTIPOLYGON")):
        raise BladUldk(f"{identyfikator}: w odpowiedzi nie ma geometrii")

    return Dzialka(
        identyfikator=identyfikator,
        wkt=wkt,
        srid=srid_z_odpowiedzi or srid,
        wojewodztwo=dane.get("voivodeship") or None,
        powiat=dane.get("county") or None,
        gmina=dane.get("commune") or None,
        obreb=dane.get("region") or None,
    )


def zapisz(baza: Path, dzialki: list[Dzialka], data: str) -> None:
    baza.parent.mkdir(parents=True, exist_ok=True)
    polaczenie = sqlite3.connect(baza)
    polaczenie.executescript(SCHEMAT)
    polaczenie.executemany(
        """INSERT OR REPLACE INTO dzialka_geometria
               (identyfikator, wkt, srid, powierzchnia_m2, wojewodztwo, powiat,
                gmina, obreb, data_pobrania, zrodlo)
           VALUES (?,?,?,?,?,?,?,?,?,?)""",
        [
            (d.identyfikator, d.wkt, d.srid, d.powierzchnia_m2, d.wojewodztwo,
             d.powiat, d.gmina, d.obreb, data, "ULDK (GUGiK)")
            for d in dzialki
        ],
    )
    polaczenie.commit()
    polaczenie.close()


def main(argv: list[str] | None = None) -> int:
    import datetime as dt

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("identyfikatory", nargs="*", help="identyfikatory działek")
    parser.add_argument("--plik", type=Path, default=None,
                        help="plik z identyfikatorami, po jednym w wierszu")
    parser.add_argument("--baza", type=Path, default=Path("dane/wynik/dzialki.sqlite"))
    parser.add_argument("--katalog", type=Path, default=Path("dane/pobrane/p5"),
                        help="pamięć podręczna odpowiedzi usługi")
    parser.add_argument("--srid", type=int, default=4326,
                        help="układ współrzędnych (domyślnie 4326, czyli WGS 84)")
    parser.add_argument("--przerwa", type=float, default=1.5)
    args = parser.parse_args(argv)

    identyfikatory = list(args.identyfikatory)
    if args.plik:
        identyfikatory += [
            w.strip() for w in args.plik.read_text(encoding="utf-8").splitlines() if w.strip()
        ]
    if not identyfikatory:
        parser.error("podaj identyfikatory działek albo --plik")

    niepoprawne = [i for i in identyfikatory if not IDENTYFIKATOR.match(i)]
    for identyfikator in niepoprawne:
        print(f"  pomijam „{identyfikator}” — to nie jest identyfikator działki",
              file=sys.stderr)
    identyfikatory = [i for i in identyfikatory if IDENTYFIKATOR.match(i)]

    args.katalog.mkdir(parents=True, exist_ok=True)
    pobieracz = Pobieracz(args.katalog, args.przerwa)
    dzialki: list[Dzialka] = []
    bledy: list[str] = []

    for numer, identyfikator in enumerate(identyfikatory, 1):
        nazwa_pliku = re.sub(r"[^\w.-]", "_", identyfikator) + ".txt"
        try:
            wynik = pobieracz.pobierz(adres_zapytania(identyfikator, args.srid), nazwa_pliku)
            tresc = wynik.sciezka.read_text(encoding="utf-8", errors="replace")
            dzialki.append(odczytaj_odpowiedz(tresc, identyfikator, args.srid))
            print(f"  [{numer}/{len(identyfikatory)}] {identyfikator}: granice pobrane")
        except (urllib.error.URLError, PermissionError, BladUldk) as blad:
            bledy.append(f"{identyfikator}: {blad}")
            print(f"  [{numer}/{len(identyfikatory)}] {identyfikator}: BŁĄD", file=sys.stderr)

    if dzialki:
        zapisz(args.baza, dzialki, dt.date.today().isoformat())
    print(f"\nPobrano granice: {len(dzialki)} z {len(identyfikatory)}")
    print(f"Zapisano do: {args.baza}")
    if bledy:
        print(f"Błędy ({len(bledy)}):")
        for opis in bledy[:10]:
            print("  ! " + opis)
    return 0 if dzialki and not bledy else 1


if __name__ == "__main__":
    raise SystemExit(main())
