"""Grzeczne pobieranie plików ze stron urzędowych.

Wspólne dla wszystkich zadań przygotowawczych (P1, P2, P5):
- uczciwy nagłówek User-Agent z nazwą programu i adresem projektu,
- sprawdzenie robots.txt przed pierwszym pobraniem z danego serwera,
- przerwy między żądaniami,
- pamięć podręczna: nie pobieramy ponownie (If-Modified-Since),
- ponawianie przy zerwanym połączeniu.
"""

from __future__ import annotations

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
