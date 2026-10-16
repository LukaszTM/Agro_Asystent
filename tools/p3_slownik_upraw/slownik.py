"""Słownik upraw: jedna nazwa urzędowa dla wszystkich zapisów (zadanie P3).

Ta sama uprawa występuje w kilku miejscach pod różnymi zapisami:

- **rejestr środków ochrony roślin** — urzędowy słownik 1052 nazw (zadanie P1),
- **etykiety** — nazwy pisane wielką literą, czasem w liczbie mnogiej (P2),
- **wniosek z eWniosekPlus** — własne nazewnictwo ARiMR (zadanie P4),
- **kod EPPO** — wymagany w ewidencji zabiegów od 2027 r.

Skrypt sprowadza zapisy do nazw urzędowych z rejestru. Dopasowania pewne
zapisuje od razu; przybliżone odkłada do ręcznej decyzji — zgodnie z zasadą,
że nie zgadujemy (CLAUDE.md).
"""

from __future__ import annotations

import argparse
import csv
import difflib
import re
import sqlite3
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from p1_zastosowania.importuj import wczytaj_csv_slownik  # noqa: E402
from wspolne.tekst import postac_porownawcza, znormalizuj  # noqa: E402

#: Powyżej tego podobieństwa uznajemy dopasowanie za warte obejrzenia.
#: Niżej nie proponujemy nic — lepiej brak podpowiedzi niż zła podpowiedź.
PROG_PODOBIENSTWA = 0.86

SCHEMAT = """
CREATE TABLE IF NOT EXISTS slownik_uprawy (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    wariant       TEXT NOT NULL,
    zrodlo        TEXT NOT NULL,
    nazwa_urzedowa TEXT,
    sposob        TEXT NOT NULL CHECK (sposob IN ('dokladne', 'zblizone', 'podobienstwo', 'brak')),
    podobienstwo  REAL,
    kod_eppo      TEXT,
    zatwierdzone  INTEGER NOT NULL DEFAULT 0,
    UNIQUE (wariant, zrodlo)
);

CREATE INDEX IF NOT EXISTS idx_slownik_wariant ON slownik_uprawy(wariant);
CREATE INDEX IF NOT EXISTS idx_slownik_urzedowa ON slownik_uprawy(nazwa_urzedowa);
"""


@dataclass
class Dopasowanie:
    wariant: str
    zrodlo: str
    nazwa_urzedowa: str | None
    sposob: str
    podobienstwo: float | None = None
    kod_eppo: str | None = None

    @property
    def wymaga_decyzji(self) -> bool:
        return self.sposob in {"podobienstwo", "brak"}


class SlownikUpraw:
    """Dopasowuje dowolny zapis nazwy uprawy do nazwy urzędowej z rejestru."""

    def __init__(self, nazwy_urzedowe: list[str]) -> None:
        self.nazwy_urzedowe = list(nazwy_urzedowe)
        self._po_normalizacji = {znormalizuj(n): n for n in nazwy_urzedowe}
        self._po_porownaniu: dict[str, str] = {}
        for nazwa in nazwy_urzedowe:
            self._po_porownaniu.setdefault(postac_porownawcza(nazwa), nazwa)

    def _dopasuj_poczatek(self, porownawcza: str) -> str | None:
        """Propozycja dla zapisów typu „cebula uprawiana z siewu".

        Bierzemy najdłuższy początek nazwy, który jest uprawą ze słownika.
        To tylko podpowiedź do zatwierdzenia: dopisek potrafi zmieniać
        przeznaczenie uprawy (cebula na szczypior to nie cebula na zbiór),
        a wraz z nim dawkę i karencję.
        """
        slowa = porownawcza.split()
        for dlugosc in range(len(slowa) - 1, 0, -1):
            trafienie = self._po_porownaniu.get(" ".join(slowa[:dlugosc]))
            if trafienie:
                return trafienie
        return None

    def dopasuj(self, wariant: str, zrodlo: str) -> Dopasowanie:
        trafienie = self._po_normalizacji.get(znormalizuj(wariant))
        if trafienie:
            return Dopasowanie(wariant, zrodlo, trafienie, "dokladne", 1.0)

        porownawcza = postac_porownawcza(wariant)
        trafienie = self._po_porownaniu.get(porownawcza)
        if trafienie:
            return Dopasowanie(wariant, zrodlo, trafienie, "zblizone", 1.0)

        po_czlonie = self._dopasuj_poczatek(porownawcza)
        if po_czlonie:
            return Dopasowanie(wariant, zrodlo, po_czlonie, "podobienstwo", None)

        podobne = difflib.get_close_matches(
            porownawcza, self._po_porownaniu.keys(), n=1, cutoff=PROG_PODOBIENSTWA
        )
        if podobne:
            miara = difflib.SequenceMatcher(None, porownawcza, podobne[0]).ratio()
            return Dopasowanie(
                wariant, zrodlo, self._po_porownaniu[podobne[0]], "podobienstwo", miara
            )
        return Dopasowanie(wariant, zrodlo, None, "brak", None)


def zbierz_warianty(baza: Path) -> dict[str, set[str]]:
    """Nazwy upraw występujące w danych, pogrupowane według źródła."""
    warianty: dict[str, set[str]] = {"etykieta": set(), "rejestr_nieznane": set()}
    if not baza.exists():
        return warianty
    polaczenie = sqlite3.connect(baza)
    try:
        warianty["etykieta"] = {
            nazwa for (nazwa,) in polaczenie.execute(
                "SELECT DISTINCT uprawa FROM karencja WHERE uprawa IS NOT NULL"
            )
        }
    except sqlite3.OperationalError:
        pass  # tabela powstaje dopiero w P2
    warianty["rejestr_nieznane"] = {
        nazwa for (nazwa,) in polaczenie.execute(
            "SELECT DISTINCT uprawa FROM zastosowanie_uprawa WHERE pewnosc = 'do_sprawdzenia'"
        )
    }
    polaczenie.close()
    return warianty


def wczytaj_kody_eppo(sciezka: Path) -> dict[str, str]:
    """Kody EPPO z pliku decyzji jako postać porównawcza → kod.

    Kodów nie wymyślamy ani nie zgadujemy — pochodzą wyłącznie z pliku
    wskazanego przez użytkownika (baza EPPO albo wykaz urzędowy).

    Gdy plik ma kolumnę `stan`, bierzemy **tylko wiersze potwierdzone**.
    Propozycja i podpowiedź nie mogą wejść do słownika jako kod pewny:
    trafiłyby na wydruk ewidencji jako fakt (P3).
    """
    kody: dict[str, str] = {}
    pominiete: dict[str, int] = {}
    with sciezka.open(encoding="utf-8-sig", newline="") as plik:
        próbka = plik.read(2048)
        plik.seek(0)
        rozdzielnik = ";" if próbka.count(";") >= próbka.count(",") else ","
        pierwszy = next(csv.reader(plik, delimiter=rozdzielnik), None) or []
        plik.seek(0)

        ma_naglowek = not re.fullmatch(
            r"[A-Z0-9]{5,6}", (pierwszy[1] if len(pierwszy) > 1 else "").strip()
        )
        if ma_naglowek:
            czytnik = csv.DictReader(plik, delimiter=rozdzielnik)
            nazwy_kolumn = czytnik.fieldnames or []
            kolumna_nazwy = nazwy_kolumn[0]
            kolumna_kodu = nazwy_kolumn[1]
            for wiersz in czytnik:
                stan = (wiersz.get("stan") or "potwierdzone").strip()
                nazwa = (wiersz.get(kolumna_nazwy) or "").strip()
                kod = (wiersz.get(kolumna_kodu) or "").strip().upper()
                if not nazwa or not kod:
                    continue
                if stan != "potwierdzone":
                    pominiete[stan] = pominiete.get(stan, 0) + 1
                    continue
                kody[postac_porownawcza(nazwa)] = kod
        else:
            for wiersz in csv.reader(plik, delimiter=rozdzielnik):
                if len(wiersz) >= 2 and wiersz[0].strip() and wiersz[1].strip():
                    kody[postac_porownawcza(wiersz[0])] = wiersz[1].strip().upper()

    for stan, ile in sorted(pominiete.items()):
        print(
            f"  pominięto {ile} wierszy ze stanem {stan!r}: "
            "do słownika wchodzą tylko potwierdzone"
        )
    return kody


def wczytaj_nazwy_z_pliku(sciezka: Path) -> list[str]:
    """Nazwy upraw z pliku CSV (jedna kolumna albo pierwsza kolumna)."""
    with sciezka.open(encoding="utf-8-sig", newline="") as plik:
        return [w[0].strip() for w in csv.reader(plik) if w and w[0].strip()]


def zapisz_csv(sciezka: Path, dopasowania: list[Dopasowanie]) -> None:
    sciezka.parent.mkdir(parents=True, exist_ok=True)
    with sciezka.open("w", encoding="utf-8", newline="") as plik:
        zapis = csv.writer(plik, delimiter=";")
        zapis.writerow(
            ["wariant", "zrodlo", "nazwa_urzedowa", "sposob", "podobienstwo", "kod_eppo", "decyzja"]
        )
        for d in dopasowania:
            zapis.writerow([
                d.wariant,
                d.zrodlo,
                d.nazwa_urzedowa or "",
                d.sposob,
                f"{d.podobienstwo:.2f}" if d.podobienstwo else "",
                d.kod_eppo or "",
                "",
            ])


def zapisz_do_bazy(baza: Path, dopasowania: list[Dopasowanie]) -> None:
    polaczenie = sqlite3.connect(baza)
    polaczenie.executescript(SCHEMAT)
    for d in dopasowania:
        polaczenie.execute(
            """INSERT OR REPLACE INTO slownik_uprawy
                   (wariant, zrodlo, nazwa_urzedowa, sposob, podobienstwo, kod_eppo, zatwierdzone)
               VALUES (?,?,?,?,?,?,?)""",
            (
                d.wariant,
                d.zrodlo,
                d.nazwa_urzedowa,
                d.sposob,
                d.podobienstwo,
                d.kod_eppo,
                int(d.sposob in {"dokladne", "zblizone"}),
            ),
        )
    polaczenie.commit()
    polaczenie.close()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--slownik-rejestru", type=Path,
                        default=Path("dane/pobrane/p1/Slownik_Uprawy.csv"))
    parser.add_argument("--baza", type=Path,
                        default=Path("dane/wynik/srodki_ochrony.sqlite"))
    parser.add_argument("--wniosek", type=Path, default=None,
                        help="CSV z nazwami upraw z wniosku (powstanie w zadaniu P4)")
    parser.add_argument("--wynik", type=Path,
                        default=Path("dane/wynik/slownik_upraw.csv"))
    parser.add_argument("--kody-eppo", type=Path, default=None,
                        help="CSV z kolumnami: nazwa uprawy, kod EPPO. Kody biorą "
                             "się wyłącznie z tego pliku, nigdy ze zgadywania")
    parser.add_argument("--do-decyzji", type=Path,
                        default=Path("dane/wynik/uprawy_do_decyzji.csv"))
    args = parser.parse_args(argv)

    nazwy_urzedowe = wczytaj_csv_slownik(args.slownik_rejestru)
    slownik = SlownikUpraw(nazwy_urzedowe)
    print(f"Nazwy urzędowe z rejestru: {len(nazwy_urzedowe)}")

    warianty = zbierz_warianty(args.baza)
    if args.wniosek:
        warianty["wniosek"] = set(wczytaj_nazwy_z_pliku(args.wniosek))

    kody = wczytaj_kody_eppo(args.kody_eppo) if args.kody_eppo else {}
    if args.kody_eppo:
        print(f"Kody EPPO wczytane z pliku: {len(kody)}")

    dopasowania: list[Dopasowanie] = []
    for zrodlo, nazwy in warianty.items():
        for nazwa in sorted(nazwy):
            dopasowanie = slownik.dopasuj(nazwa, zrodlo)
            if dopasowanie.nazwa_urzedowa and not dopasowanie.wymaga_decyzji:
                dopasowanie.kod_eppo = kody.get(
                    postac_porownawcza(dopasowanie.nazwa_urzedowa)
                )
            dopasowania.append(dopasowanie)

    podsumuj(dopasowania, warianty, args)
    zapisz_csv(args.wynik, dopasowania)
    zapisz_csv(args.do_decyzji, [d for d in dopasowania if d.wymaga_decyzji])
    if args.baza.exists():
        zapisz_do_bazy(args.baza, dopasowania)
        print(f"\nZapisano do {args.baza} (tabela slownik_uprawy)")
    print(f"Pełny wykaz:        {args.wynik}")
    print(f"Do ręcznej decyzji: {args.do_decyzji}")
    return 0


def podsumuj(dopasowania, warianty, args) -> None:
    print("\nWarianty nazw do dopasowania:")
    for zrodlo, nazwy in warianty.items():
        print(f"  {zrodlo:18} {len(nazwy)}")

    razem = max(len(dopasowania), 1)
    liczby = Counter(d.sposob for d in dopasowania)
    print("\nSposób dopasowania:")
    for sposob in ("dokladne", "zblizone", "podobienstwo", "brak"):
        ile = liczby.get(sposob, 0)
        print(f"  {sposob:14} {ile:5}  ({100 * ile / razem:5.1f}%)")

    z_kodem = sum(1 for d in dopasowania if d.kod_eppo)
    if z_kodem:
        print(f"\nZ kodem EPPO: {z_kodem} z {razem}")
    else:
        print("\nKody EPPO: brak źródła — kolumna pozostaje pusta (patrz raport P3)")

    do_decyzji = [d for d in dopasowania if d.wymaga_decyzji]
    if do_decyzji:
        print(f"\nDo ręcznej decyzji: {len(do_decyzji)}")
        for d in sorted(do_decyzji, key=lambda x: (x.sposob, x.wariant))[:15]:
            propozycja = (
                f"→ {d.nazwa_urzedowa} ({d.podobienstwo:.2f})"
                if d.nazwa_urzedowa
                else "→ brak propozycji"
            )
            print(f"  [{d.zrodlo:16}] {d.wariant[:44]:44} {propozycja}")


if __name__ == "__main__":
    raise SystemExit(main())
