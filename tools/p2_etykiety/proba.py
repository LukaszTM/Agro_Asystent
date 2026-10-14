"""Próba bazy etykiet: spis → pobranie → odczyt karencji → raport (zadanie P2).

Domyślnie pracuje na jednej podstronie alfabetycznej (A–B), zgodnie z planem.
Pliki trafiają do katalogu roboczego poza repozytorium, a wynik — do bazy
SQLite zbudowanej w P1 (tabela `karencja`).
"""

from __future__ import annotations

import argparse
import datetime as dt
import sqlite3
import sys
from collections import Counter
from pathlib import Path

import pdfplumber

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).parent))

from odczyt import odczytaj_etykiete  # noqa: E402
from spis import adres_podstrony, policz_dokumenty, zbierz_etykiety  # noqa: E402
from wspolne.pobieranie import Pobieracz  # noqa: E402

SCHEMAT = """
CREATE TABLE IF NOT EXISTS etykieta (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    nazwa_srodka    TEXT NOT NULL,
    srodek_id       INTEGER REFERENCES srodek(id),
    data_etykiety   TEXT NOT NULL,
    adres           TEXT NOT NULL,
    data_pobrania   TEXT NOT NULL,
    stan_odczytu    TEXT NOT NULL,
    liczba_zabiegow INTEGER,
    liczba_zabiegow_rozna INTEGER NOT NULL DEFAULT 0,
    sezon           TEXT,
    prewencja_dni   INTEGER,
    prewencja_tekst TEXT,
    UNIQUE (nazwa_srodka, data_etykiety)
);

CREATE TABLE IF NOT EXISTS karencja (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    etykieta_id INTEGER NOT NULL REFERENCES etykieta(id),
    uprawa      TEXT,
    dni         INTEGER,
    stan        TEXT NOT NULL CHECK (stan IN ('dni', 'nie_dotyczy', 'do_sprawdzenia')),
    tekst       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_karencja_etykieta ON karencja(etykieta_id);
CREATE INDEX IF NOT EXISTS idx_etykieta_srodek   ON etykieta(nazwa_srodka);
"""


def czytaj_pdf(sciezka: Path) -> tuple[str, int]:
    with pdfplumber.open(sciezka) as pdf:
        strony = pdf.pages
        return "\n".join((s.extract_text() or "") for s in strony), len(strony)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--podstrona", default="a-b1", help="litery podstrony (domyślnie a-b1)")
    parser.add_argument("--katalog", type=Path, default=Path("dane/pobrane/p2"))
    parser.add_argument("--baza", type=Path, default=Path("dane/wynik/srodki_ochrony.sqlite"))
    parser.add_argument("--przerwa", type=float, default=2.0, help="przerwa między pobraniami [s]")
    parser.add_argument("--ile", type=int, default=0, help="ogranicz liczbę etykiet (0 = wszystkie)")
    parser.add_argument("--bez-zapisu", action="store_true", help="nie zapisuj do bazy")
    parser.add_argument("--offline", action="store_true",
                        help="pracuj na plikach już pobranych, bez łączenia się z siecią")
    args = parser.parse_args(argv)

    katalog_pdf = args.katalog / "etykiety"
    katalog_pdf.mkdir(parents=True, exist_ok=True)
    pobieracz = Pobieracz(args.katalog, args.przerwa)

    print(f"Spis z podstrony {args.podstrona}…")
    plik_strony = args.katalog / f"{args.podstrona}.html"
    if not (args.offline and plik_strony.exists()):
        plik_strony = pobieracz.pobierz(
            adres_podstrony(args.podstrona), f"{args.podstrona}.html"
        ).sciezka
    tresc = plik_strony.read_text(encoding="utf-8", errors="replace")
    print("  dokumenty na stronie:", policz_dokumenty(tresc))

    etykiety = zbierz_etykiety(tresc)
    if args.ile:
        etykiety = etykiety[: args.ile]
    print(f"  etykiet do pobrania: {len(etykiety)}"
          f" ({sum(e.rozmiar_mb for e in etykiety):.0f} MB)\n")

    pobieracz_pdf = Pobieracz(katalog_pdf, args.przerwa)
    stany: Counter[str] = Counter()
    bledy: list[str] = []
    wyniki = []

    for numer, etykieta in enumerate(etykiety, 1):
        sciezka = katalog_pdf / etykieta.nazwa_pliku
        try:
            if not (args.offline and sciezka.exists()):
                sciezka = pobieracz_pdf.pobierz(etykieta.adres, etykieta.nazwa_pliku).sciezka
            tekst, stron = czytaj_pdf(sciezka)
        except Exception as blad:  # noqa: BLE001 — każdy błąd ma trafić do raportu
            stany["blad_pobrania"] += 1
            bledy.append(f"{etykieta.nazwa_srodka}: {type(blad).__name__} {blad}")
            continue
        odczyt = odczytaj_etykiete(tekst, stron)
        stany[odczyt.stan] += 1
        wyniki.append((etykieta, odczyt))
        if numer % 25 == 0:
            print(f"  {numer}/{len(etykiety)}…")

    zapisz_i_podsumuj(wyniki, stany, bledy, args)
    return 0


def zapisz_i_podsumuj(wyniki, stany, bledy, args) -> None:
    razem = max(sum(stany.values()), 1)
    print("\n── Odczyt etykiet ──")
    for stan in ("odczytana", "czesciowa", "do_sprawdzenia", "skan", "blad_pobrania"):
        ile = stany.get(stan, 0)
        print(f"  {stan:16} {ile:5}  ({100 * ile / razem:5.1f}%)")

    karencje = [k for _, o in wyniki for k in o.karencje]
    z_dniami = [k for k in karencje if k.stan == "dni"]
    print(f"\n  pozycji karencji:        {len(karencje)}")
    print(f"  z liczbą dni:            {len(z_dniami)}")
    nie_dotyczy = sum(1 for k in karencje if k.stan == "nie_dotyczy")
    print(f"  bez karencji (nie dotyczy): {nie_dotyczy}")
    print(f"  do sprawdzenia:          "
          f"{sum(1 for k in karencje if k.stan == 'do_sprawdzenia')}")
    print(f"  etykiet z liczbą zabiegów: "
          f"{sum(1 for _, o in wyniki if o.liczba_zabiegow is not None)}")
    print(f"  etykiet z okresem prewencji: "
          f"{sum(1 for _, o in wyniki if o.prewencja_tekst)}")
    print(f"  etykiet z różną liczbą zabiegów dla upraw: "
          f"{sum(1 for _, o in wyniki if o.liczba_zabiegow_rozna)}")
    if z_dniami:
        dni = sorted(k.dni for k in z_dniami)
        print(f"  karencja: od {dni[0]} do {dni[-1]} dni, "
              f"najczęstsza {Counter(dni).most_common(1)[0][0]} dni")
    if bledy:
        print(f"\n  błędy pobrania ({len(bledy)}):")
        for opis in bledy[:10]:
            print("   ", opis)

    if args.bez_zapisu or not args.baza.exists():
        return

    polaczenie = sqlite3.connect(args.baza)
    polaczenie.executescript(SCHEMAT)
    dzis = dt.date.today().isoformat()
    dopasowane = 0
    for etykieta, odczyt in wyniki:
        srodek = polaczenie.execute(
            "SELECT id FROM srodek WHERE nazwa = ? LIMIT 1", (etykieta.nazwa_srodka,)
        ).fetchone()
        dopasowane += int(srodek is not None)
        kursor = polaczenie.execute(
            """INSERT OR REPLACE INTO etykieta (nazwa_srodka, srodek_id, data_etykiety,
                   adres, data_pobrania, stan_odczytu, liczba_zabiegow,
                   liczba_zabiegow_rozna, sezon, prewencja_dni, prewencja_tekst)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (
                etykieta.nazwa_srodka,
                srodek[0] if srodek else None,
                etykieta.data_etykiety.isoformat(),
                etykieta.adres,
                dzis,
                odczyt.stan,
                odczyt.liczba_zabiegow,
                int(odczyt.liczba_zabiegow_rozna),
                odczyt.sezon,
                odczyt.prewencja_dni,
                odczyt.prewencja_tekst,
            ),
        )
        id_etykiety = int(kursor.lastrowid)
        polaczenie.execute("DELETE FROM karencja WHERE etykieta_id = ?", (id_etykiety,))
        for k in odczyt.karencje:
            for uprawa in k.uprawy or (None,):
                polaczenie.execute(
                    "INSERT INTO karencja (etykieta_id, uprawa, dni, stan, tekst)"
                    " VALUES (?,?,?,?,?)",
                    (id_etykiety, uprawa, k.dni, k.stan, k.tekst),
                )
    polaczenie.commit()
    polaczenie.close()
    print(f"\n  zapisano do {args.baza}; etykiet powiązanych ze środkiem z rejestru: "
          f"{dopasowane}/{len(wyniki)}")


if __name__ == "__main__":
    raise SystemExit(main())
