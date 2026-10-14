"""Pobieranie plików rejestru środków ochrony roślin.

Zasady (CLAUDE.md, tools/README.md):
- uruchamiane na komputerze dewelopera, nigdy z telefonu rolnika,
- skrypt przedstawia się uczciwym nagłówkiem User-Agent,
- sprawdza robots.txt i przerywa, gdy serwis zabrania pobierania,
- robi przerwy między żądaniami i nie pobiera ponownie tego, co już ma
  (nagłówek If-Modified-Since).
"""

from __future__ import annotations

import argparse
import email.utils
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
from dataclasses import dataclass
from pathlib import Path

NAZWA_PROGRAMU = "AgroAsystent-dev/0.1"
KONTAKT = "https://github.com/LukaszTM/Agro_Asystent"
UZYTKOWNIK = f"{NAZWA_PROGRAMU} (+{KONTAKT})"

PRZERWA_SEKUND = 2.0

#: Ile razy ponawiać żądanie przy zerwanym połączeniu.
PROBY = 4

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


@dataclass
class Wynik:
    nazwa: str
    sciezka: Path
    pobrany: bool
    rozmiar: int
    data_serwera: str | None


class Pobieracz:
    def __init__(self, katalog: Path, przerwa: float = PRZERWA_SEKUND) -> None:
        self.katalog = katalog
        self.przerwa = przerwa
        self._ostatnie_zadanie = 0.0
        self._robots: dict[str, urllib.robotparser.RobotFileParser] = {}

    # ── robots.txt ────────────────────────────────────────────────────────
    def wolno_pobrac(self, adres: str) -> bool:
        czesci = urllib.parse.urlsplit(adres)
        host = f"{czesci.scheme}://{czesci.netloc}"
        if host not in self._robots:
            czytnik = urllib.robotparser.RobotFileParser()
            czytnik.set_url(f"{host}/robots.txt")
            try:
                self._odczekaj()
                with urllib.request.urlopen(
                    urllib.request.Request(
                        f"{host}/robots.txt", headers={"User-Agent": UZYTKOWNIK}
                    ),
                    timeout=30,
                ) as odp:
                    czytnik.parse(odp.read().decode("utf-8", "replace").splitlines())
            except urllib.error.URLError:
                # Brak robots.txt oznacza brak ograniczeń.
                czytnik.parse([])
            self._robots[host] = czytnik
        return self._robots[host].can_fetch(NAZWA_PROGRAMU, adres)

    def _odczekaj(self) -> None:
        minelo = time.monotonic() - self._ostatnie_zadanie
        if minelo < self.przerwa:
            time.sleep(self.przerwa - minelo)
        self._ostatnie_zadanie = time.monotonic()

    # ── pobieranie ────────────────────────────────────────────────────────
    def pobierz(self, adres: str, nazwa_pliku: str) -> Wynik:
        cel = self.katalog / nazwa_pliku
        if not self.wolno_pobrac(adres):
            raise PermissionError(
                f"robots.txt serwisu zabrania pobrania {adres} — przerywam."
            )

        naglowki = {"User-Agent": UZYTKOWNIK}
        if cel.exists():
            naglowki["If-Modified-Since"] = email.utils.formatdate(
                cel.stat().st_mtime, usegmt=True
            )

        ostatni_blad: Exception | None = None
        for proba in range(1, PROBY + 1):
            self._odczekaj()
            try:
                with urllib.request.urlopen(
                    urllib.request.Request(adres, headers=naglowki), timeout=120
                ) as odp:
                    tresc = odp.read()
                    data_serwera = odp.headers.get("Last-Modified")
                cel.write_bytes(tresc)
                if data_serwera:
                    znacznik = email.utils.parsedate_to_datetime(data_serwera).timestamp()
                    os.utime(cel, (znacznik, znacznik))
                return Wynik(nazwa_pliku, cel, True, len(tresc), data_serwera)
            except urllib.error.HTTPError as blad:
                if blad.code == 304:  # Not Modified — mamy aktualny plik
                    return Wynik(nazwa_pliku, cel, False, cel.stat().st_size, None)
                if blad.code in (429, 500, 502, 503, 504):
                    ostatni_blad = blad
                else:
                    raise
            except (urllib.error.URLError, ConnectionError, TimeoutError) as blad:
                # Zerwane połączenie zdarza się przy dłuższych pobraniach.
                ostatni_blad = blad
            if proba < PROBY:
                czekaj = self.przerwa * 2**proba
                print(f"    ponawiam za {czekaj:.0f} s ({ostatni_blad})")
                time.sleep(czekaj)
        raise ostatni_blad  # type: ignore[misc]


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
