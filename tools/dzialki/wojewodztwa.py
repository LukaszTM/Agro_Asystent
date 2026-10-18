#!/usr/bin/env python3
"""Buduje listę województw z kodami TERYT dla aplikacji.

Po co: usługa ULDK nie umie podać listy województw — umie tylko odpowiedzieć,
jak nazywa się województwo o danym kodzie. Kodów jest szesnaście i nie
zmieniły się od 1999 r., więc pytamy o każdy raz, tu, na komputerze
dewelopera, a wynik jedzie do aplikacji jako plik danych
(``assets/dane/wojewodztwa.json``). Z telefonu rolnika nic nie pobieramy.

Użycie::

    python3 tools/dzialki/wojewodztwa.py --wyjscie assets/dane/wojewodztwa.json
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import urllib.parse
import urllib.request

ADRES_ULDK = "https://uldk.gugik.gov.pl/"

# Kody województw w TERYT: parzyste od 02 do 32. Nie zgadujemy nazw —
# każdą potwierdza usługa.
KODY = [f"{kod:02d}" for kod in range(2, 33, 2)]


def zapytaj(kod: str, adres: str = ADRES_ULDK, limit_s: float = 30) -> str:
    """Nazwa województwa o danym kodzie, prosto z ULDK."""
    zapytanie = urllib.parse.urlencode(
        {"request": "GetVoivodeshipById", "id": kod, "result": "teryt,voivodeship"}
    )
    with urllib.request.urlopen(f"{adres}?{zapytanie}", timeout=limit_s) as odp:
        tresc = odp.read().decode("utf-8", errors="replace")
    return odczytaj(tresc, kod)


def odczytaj(tresc: str, kod: str) -> str:
    """Odpowiedź ma dwa wiersze: status (``0``) i ``TERYT|nazwa``."""
    wiersze = [w.strip() for w in tresc.splitlines() if w.strip()]
    if len(wiersze) < 2 or not wiersze[0].startswith("0"):
        raise ValueError(f"ULDK nie podało województwa o kodzie {kod}: {tresc!r}")
    teryt, _, nazwa = wiersze[1].partition("|")
    if teryt.strip() != kod or not nazwa.strip():
        raise ValueError(f"Niezrozumiały wiersz dla kodu {kod}: {wiersze[1]!r}")
    return nazwa.strip()


def zbuduj(adres: str = ADRES_ULDK) -> dict:
    dzis = dt.date.today()
    return {
        "wersja": f"{dzis:%Y.%m.%d}.1",
        "zrodlo": "ULDK (GUGiK), zapytanie GetVoivodeshipById dla kodów 02–32",
        "po_co": (
            "Pierwszy krok dodawania działki spoza wniosku: rolnik wybiera "
            "województwo z tej listy, a dalej podaje nazwę miejscowości "
            "(obrębu) i numer działki. Usługa ULDK nie umie sama podać listy "
            "województw, więc jedzie ona z aplikacją jako dane."
        ),
        "wojewodztwa": [{"teryt": kod, "nazwa": zapytaj(kod, adres)} for kod in KODY],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--wyjscie", required=True, help="dokąd zapisać plik JSON")
    parser.add_argument("--adres", default=ADRES_ULDK, help="adres usługi ULDK")
    args = parser.parse_args(argv)

    dane = zbuduj(args.adres)
    with open(args.wyjscie, "w", encoding="utf-8") as plik:
        json.dump(dane, plik, ensure_ascii=False, indent=2)
        plik.write("\n")
    print(f"województw: {len(dane['wojewodztwa'])} → {args.wyjscie}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
