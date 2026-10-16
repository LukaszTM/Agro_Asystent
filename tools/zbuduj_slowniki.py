"""Składa jeden plik słowników dla aplikacji (zadanie P7).

Źródła: wyniki zadań P1 (rejestr środków), P2 (etykiety i karencja) oraz P3
(kody EPPO). Plik `slowniki.sqlite` jest **tylko do odczytu** i wymienia się go
w całości przy aktualizacji danych (ADR-0004).

Zawiera tylko to, czego potrzebuje aplikacja — bez kolumn roboczych i bez
środków po terminie stosowania, które i tak nie mogą trafić do ewidencji.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import shutil
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from wspolne.tekst import postac_porownawcza  # noqa: E402

SCHEMAT = """
CREATE TABLE srodek (
    id             INTEGER PRIMARY KEY,
    nazwa          TEXT NOT NULL,
    nr_zezwolenia  TEXT NOT NULL,
    rodzaj         TEXT,
    substancja_czynna TEXT,
    producent      TEXT,
    adres_etykiety TEXT,
    termin_do_stosowania TEXT
);

CREATE TABLE zastosowanie (
    id                INTEGER PRIMARY KEY,
    srodek_id         INTEGER NOT NULL REFERENCES srodek(id),
    agrofag           TEXT,
    dawka_wartosc     REAL,
    dawka_jednostka   TEXT,
    dawka_odniesienie TEXT,
    dawka_tekst       TEXT,
    dawka_pewnosc     TEXT NOT NULL,
    termin_tekst      TEXT,
    bbch_od           INTEGER,
    bbch_do           INTEGER,
    maloobszarowe     INTEGER
);

CREATE TABLE zastosowanie_uprawa (
    zastosowanie_id INTEGER NOT NULL REFERENCES zastosowanie(id),
    uprawa          TEXT NOT NULL
);

CREATE TABLE uprawa (
    nazwa      TEXT PRIMARY KEY,
    kod_eppo   TEXT,
    -- 'kod' — jest kod EPPO; 'rodzajowa' — rejestr nie podaje gatunku,
    -- aplikacja pyta rolnika; 'poza_zakresem', 'grupa', 'nie_uprawa';
    -- 'brak' — nazwa bez decyzji.
    stan       TEXT NOT NULL DEFAULT 'brak',
    -- Dla nazw rodzajowych: gatunki do wyboru, rozdzielone znakiem '|'.
    gatunki    TEXT,
    -- O co pyta ekran wyboru uprawy przy nazwie rodzajowej.
    pytanie    TEXT,
    -- Ile zastosowań w rejestrze dotyczy tej uprawy — po tym układamy
    -- listę wyboru, żeby najczęstsze uprawy były na górze.
    zastosowan INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE karencja (
    srodek_nazwa   TEXT NOT NULL,
    uprawa         TEXT,
    dni            INTEGER,
    stan           TEXT NOT NULL,
    data_etykiety  TEXT,
    zrodlo         TEXT NOT NULL
);

CREATE TABLE zrodlo_danych (
    plik         TEXT NOT NULL,
    adres        TEXT,
    licencja     TEXT,
    data_pliku   TEXT,
    data_importu TEXT
);

CREATE INDEX idx_zu_uprawa ON zastosowanie_uprawa(uprawa);
CREATE INDEX idx_zu_zastosowanie ON zastosowanie_uprawa(zastosowanie_id);
CREATE INDEX idx_zastosowanie_srodek ON zastosowanie(srodek_id);
CREATE INDEX idx_srodek_nazwa ON srodek(nazwa);
CREATE INDEX idx_karencja_srodek ON karencja(srodek_nazwa, uprawa);
"""


#: Stany kodu, które wolno wpisać do pliku aplikacji. Kod niepotwierdzony
#: wyszedłby na wydruku ewidencji jako fakt (P3) — nie wchodzi.
STANY_PEWNE = {"kod", "potwierdzone", ""}


def wczytaj_kody_eppo(sciezka: Path) -> dict[str, str]:
    """Kody upraw z wyniku P3 — tylko te o pewnym stanie."""
    if not sciezka.exists():
        return {}
    with sciezka.open(encoding="utf-8-sig", newline="") as plik:
        czytnik = csv.DictReader(plik, delimiter=";")
        return {
            postac_porownawcza(w["nazwa_urzedowa"]): w["kod_eppo"]
            for w in czytnik
            if w.get("nazwa_urzedowa")
            and w.get("kod_eppo")
            and (w.get("stan") or "").strip() in STANY_PEWNE
        }


#: Stany z pliku decyzji → stany w słowniku aplikacji.
STANY_DECYZJI = {
    "potwierdzone": "kod",
    "rodzajowa": "rodzajowa",
    "poza_zakresem": "poza_zakresem",
    "grupa_upraw": "grupa",
    "nie_uprawa": "nie_uprawa",
}


def wczytaj_decyzje_upraw(sciezka: Path) -> dict[str, dict[str, str]]:
    """Plik decyzji o uprawach: postać porównawcza nazwy → wiersz.

    Stąd bierze się stan uprawy i lista gatunków do wyboru przy nazwie
    rodzajowej („łubin" → biały, żółty, wąskolistny).
    """
    if not sciezka.exists():
        return {}
    with sciezka.open(encoding="utf-8-sig", newline="") as plik:
        return {
            postac_porownawcza(w["nazwa_uprawy"]): w
            for w in csv.DictReader(plik, delimiter=";")
            if w.get("nazwa_uprawy")
        }


def zbuduj(
    zrodlo: Path,
    cel: Path,
    kody_eppo: dict[str, str],
    decyzje: dict[str, dict[str, str]] | None = None,
) -> dict[str, int]:
    if cel.exists():
        cel.unlink()
    cel.parent.mkdir(parents=True, exist_ok=True)

    wy = sqlite3.connect(cel)
    wy.executescript(SCHEMAT)
    wy.execute("ATTACH DATABASE ? AS zr", (str(zrodlo),))

    # Środki po terminie stosowania pomijamy — nie wolno ich już stosować,
    # a informacja o wycofaniu i tak idzie osobnym powiadomieniem.
    wy.execute(
        """INSERT INTO srodek
           SELECT id, nazwa, nr_zezwolenia, rodzaj, substancja_czynna, producent,
                  adres_etykiety, termin_do_stosowania
           FROM zr.srodek WHERE wycofany = 0"""
    )
    wy.execute(
        """INSERT INTO zastosowanie
           SELECT z.id, z.srodek_id, z.agrofag, z.dawka_wartosc, z.dawka_jednostka,
                  z.dawka_odniesienie, z.dawka_tekst, z.dawka_pewnosc, z.termin_tekst,
                  z.bbch_od, z.bbch_do, z.maloobszarowe
           FROM zr.zastosowanie z
           JOIN srodek s ON s.id = z.srodek_id
           WHERE z.uklad_podejrzany = 0"""
    )
    wy.execute(
        """INSERT INTO zastosowanie_uprawa
           SELECT zu.zastosowanie_id, zu.uprawa
           FROM zr.zastosowanie_uprawa zu
           JOIN zastosowanie z ON z.id = zu.zastosowanie_id
           WHERE zu.pewnosc = 'slownik'"""
    )
    try:
        wy.execute(
            """INSERT INTO karencja
               SELECT e.nazwa_srodka, k.uprawa, k.dni, k.stan, e.data_etykiety,
                      'etykieta MRiRW'
               FROM zr.karencja k JOIN zr.etykieta e ON e.id = k.etykieta_id"""
        )
    except sqlite3.OperationalError:
        pass  # etykiety powstają w zadaniu P2
    wy.execute(
        """INSERT INTO zrodlo_danych SELECT plik, adres, licencja, data_pliku, data_importu
           FROM zr.zrodlo_danych"""
    )

    decyzje = decyzje or {}
    uzycia = dict(
        wy.execute(
            "SELECT uprawa, COUNT(*) FROM zastosowanie_uprawa GROUP BY uprawa"
        )
    )
    wiersze_upraw = []
    for nazwa in sorted(uzycia):
        klucz = postac_porownawcza(nazwa)
        kod = kody_eppo.get(klucz)
        decyzja = decyzje.get(klucz, {})
        stan = (
            "kod"
            if kod
            else STANY_DECYZJI.get((decyzja.get("stan") or "").strip(), "brak")
        )
        wiersze_upraw.append(
            (
                nazwa,
                kod,
                stan,
                (decyzja.get("zamiast") or "") or None,
                (decyzja.get("nazwa_eppo") or "") if stan == "rodzajowa" else None,
                uzycia[nazwa],
            )
        )
    wy.executemany(
        """INSERT INTO uprawa (nazwa, kod_eppo, stan, gatunki, pytanie,
                               zastosowan)
           VALUES (?,?,?,?,?,?)""",
        wiersze_upraw,
    )

    wy.commit()
    liczby = {
        t: wy.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
        for t in ["srodek", "zastosowanie", "zastosowanie_uprawa", "uprawa", "karencja"]
    }
    liczby["uprawy_z_kodem"] = wy.execute(
        "SELECT COUNT(*) FROM uprawa WHERE kod_eppo IS NOT NULL"
    ).fetchone()[0]
    liczby["uprawy_rodzajowe"] = wy.execute(
        "SELECT COUNT(*) FROM uprawa WHERE stan = 'rodzajowa'"
    ).fetchone()[0]
    wy.execute("DETACH DATABASE zr")
    wy.execute("VACUUM")
    wy.close()
    return liczby


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--zrodlo", type=Path,
                        default=Path("dane/wynik/srodki_ochrony.sqlite"))
    parser.add_argument("--kody-eppo", type=Path,
                        default=Path("dane/wynik/uprawy_eppo.csv"))
    parser.add_argument("--decyzje", type=Path,
                        default=Path("assets/dane/kody_eppo_decyzje.csv"),
                        help="plik decyzji o uprawach: stan i gatunki do wyboru")
    parser.add_argument("--cel", type=Path, default=Path("dane/wynik/slowniki.sqlite"))
    parser.add_argument("--asset", type=Path,
                        default=Path("assets/dane/slowniki.sqlite.gz"),
                        help="spakowany plik dołączany do aplikacji")
    args = parser.parse_args(argv)

    if not args.zrodlo.exists():
        print(f"Brak bazy {args.zrodlo}. Uruchom najpierw P1.", file=sys.stderr)
        return 1

    liczby = zbuduj(
        args.zrodlo,
        args.cel,
        wczytaj_kody_eppo(args.kody_eppo),
        wczytaj_decyzje_upraw(args.decyzje),
    )
    for nazwa, ile in liczby.items():
        print(f"  {nazwa:22} {ile}")
    print(f"\nPlik: {args.cel}  ({args.cel.stat().st_size / 1_048_576:.1f} MB)")

    if args.asset:
        args.asset.parent.mkdir(parents=True, exist_ok=True)
        with args.cel.open("rb") as wejscie, gzip.open(args.asset, "wb", compresslevel=9) as wyjscie:
            shutil.copyfileobj(wejscie, wyjscie)
        print(f"Asset: {args.asset}  ({args.asset.stat().st_size / 1_048_576:.1f} MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
