"""Kody EPPO dla upraw z rejestru (uzupełnienie zadania P3).

Źródło: baza EPPO Global Database w postaci SQLite (`eppocodes_all.sqlite`),
pobrana przez użytkownika z serwisu EPPO. Skrypt **nie wymyśla kodów** — bierze
wyłącznie te, które baza wiąże z polską nazwą rośliny. Nazwy bez odpowiednika
trafiają do pliku z ręczną decyzją.

Wynik: `dane/wynik/uprawy_eppo.csv` (nazwa urzędowa;kod EPPO) — ten sam format,
który przyjmuje `slownik.py --kody-eppo`.
"""

from __future__ import annotations

import argparse
import csv
import sqlite3
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from p1_zastosowania.importuj import wczytaj_csv_slownik  # noqa: E402
from wspolne.tekst import postac_porownawcza  # noqa: E402

#: Rodzaje danych EPPO, które są roślinami uprawnymi.
RODZAJE_ROSLIN = ("PFL", "SPT")

#: Status „A" oznacza nazwę aktualną; „N" to nazwa wycofana.
STATUS_AKTUALNY = "A"


def nazwy_polskie(baza: Path) -> dict[str, list[str]]:
    """Postać porównawcza polskiej nazwy → lista kodów EPPO."""
    polaczenie = sqlite3.connect(f"file:{baza}?mode=ro", uri=True)
    wynik: dict[str, list[str]] = {}
    zapytanie = f"""
        SELECT n.fullname, c.eppocode
        FROM t_names n
        JOIN t_codes c ON c.codeid = n.codeid
        WHERE n.codelang = 'pl'
          AND n.status = ?
          AND c.status = ?
          AND c.dtcode IN ({",".join("?" * len(RODZAJE_ROSLIN))})
    """
    for nazwa, kod in polaczenie.execute(
        zapytanie, (STATUS_AKTUALNY, STATUS_AKTUALNY, *RODZAJE_ROSLIN)
    ):
        klucz = postac_porownawcza(nazwa)
        if kod not in wynik.setdefault(klucz, []):
            wynik[klucz].append(kod)
    polaczenie.close()
    return wynik


def _rozwiniecia(porownawcza: str, slownik_eppo: dict[str, list[str]]) -> list[tuple[str, str]]:
    """Nazwy EPPO będące naszą nazwą z dopowiedzeniem: „jabłoń" → „jabłoń domowa".

    Dopasowujemy wyłącznie przez przedłużenie pełnej nazwy, nigdy przez sam
    pierwszy człon: „pszenica ozima" nie może trafić w „pszenica płaskurka",
    bo to inny gatunek.
    """
    poczatek = porownawcza + " "
    return [
        (nazwa, kody[0])
        for nazwa, kody in slownik_eppo.items()
        if nazwa.startswith(poczatek) and len(kody) == 1
    ]


def _ten_sam_rodzaj(porownawcza: str, slownik_eppo: dict[str, list[str]]) -> list[tuple[str, str]]:
    """Inne gatunki o tym samym pierwszym członie nazwy — **trop, nie propozycja**.

    Dla „pszenica ozima" zwróci np. „pszenica płaskurka=TRZMO". To inny gatunek
    i kodu z tego brać nie wolno; ma tylko ułatwić doradcy odszukanie
    właściwego gatunku w bazie EPPO.
    """
    czlony = porownawcza.split()
    if not czlony:
        return []
    czlon = czlony[0] + " "
    return sorted(
        {
            (nazwa, kody[0])
            for nazwa, kody in slownik_eppo.items()
            if nazwa.startswith(czlon) and len(kody) == 1
        }
    )


def dopasuj(nazwy_urzedowe: list[str], slownik_eppo: dict[str, list[str]]):
    """Zwraca listę (nazwa urzędowa, kod, stan).

    Stany: 'kod' — nazwa polska zgodna co do znaku; 'propozycja' — nazwa EPPO
    jest naszą nazwą z dopowiedzeniem, więc wymaga potwierdzenia; 'wiele' —
    kilku kandydatów; 'brak' — nic nie pasuje.
    """
    wynik = []
    for nazwa in nazwy_urzedowe:
        porownawcza = postac_porownawcza(nazwa)
        kody = slownik_eppo.get(porownawcza, [])
        if len(kody) == 1:
            wynik.append((nazwa, kody[0], "kod"))
            continue
        if len(kody) > 1:
            # Kilka kodów na jedną nazwę — wyboru nie zgadujemy.
            wynik.append((nazwa, "", "wiele"))
            continue
        rozwiniecia = _rozwiniecia(porownawcza, slownik_eppo)
        if len(rozwiniecia) == 1:
            wynik.append((nazwa, rozwiniecia[0][1], "propozycja"))
        elif len(rozwiniecia) > 1:
            wynik.append((nazwa, "", "wiele"))
        else:
            wynik.append((nazwa, "", "brak"))
    return wynik


def wczytaj_decyzje(sciezka: Path) -> dict[str, tuple[str, str]]:
    """Kody rozstrzygnięte przez człowieka: postać porównawcza → (kod, stan).

    Stan „potwierdzone" oznacza decyzję użytkownika albo doradcy, „propozycja" —
    kod wyszukany w bazie EPPO, który czeka na potwierdzenie.
    """
    decyzje: dict[str, tuple[str, str]] = {}
    with sciezka.open(encoding="utf-8-sig", newline="") as plik:
        czytnik = csv.reader(plik, delimiter=";")
        next(czytnik, None)
        for wiersz in czytnik:
            if len(wiersz) >= 4 and wiersz[0].strip() and wiersz[1].strip():
                stan = "kod" if wiersz[3].strip() == "potwierdzone" else "propozycja"
                decyzje[postac_porownawcza(wiersz[0])] = (wiersz[1].strip(), stan)
    return decyzje


def liczba_zastosowan(baza: Path) -> dict[str, int]:
    """Ile razy uprawa występuje w rejestrze — żeby decydować od najważniejszych."""
    if not baza.exists():
        return {}
    polaczenie = sqlite3.connect(f"file:{baza}?mode=ro", uri=True)
    try:
        return {
            nazwa: ile
            for nazwa, ile in polaczenie.execute(
                "SELECT uprawa, COUNT(*) FROM zastosowanie_uprawa "
                "WHERE pewnosc = 'slownik' GROUP BY 1"
            )
        }
    finally:
        polaczenie.close()


def zapisz_kody(sciezka: Path, wiersze) -> None:
    """Plik gotowy do użycia: nazwa urzędowa i jeden pewny kod."""
    sciezka.parent.mkdir(parents=True, exist_ok=True)
    with sciezka.open("w", encoding="utf-8", newline="") as plik:
        zapis = csv.writer(plik, delimiter=";")
        zapis.writerow(["nazwa_urzedowa", "kod_eppo", "stan", "decyzja"])
        for nazwa, kod, stan in wiersze:
            if stan == "kod":
                zapis.writerow([nazwa, kod, stan, ""])


def zapisz_do_decyzji(sciezka: Path, wiersze, uzycia, slownik_eppo) -> None:
    """Lista do rozstrzygnięcia, od upraw najczęściej występujących w rejestrze."""
    sciezka.parent.mkdir(parents=True, exist_ok=True)
    pozostale = [w for w in wiersze if w[2] != "kod"]
    pozostale.sort(key=lambda w: -uzycia.get(w[0], 0))
    with sciezka.open("w", encoding="utf-8", newline="") as plik:
        zapis = csv.writer(plik, delimiter=";")
        zapis.writerow(
            ["nazwa_urzedowa", "zastosowan_w_rejestrze", "stan", "propozycja",
             "kandydaci", "inne_gatunki_tego_rodzaju_tylko_trop", "kod_eppo_do_wpisania"]
        )
        for nazwa, kod, stan in pozostale:
            porownawcza = postac_porownawcza(nazwa)
            kandydaci = _rozwiniecia(porownawcza, slownik_eppo)
            opis = "; ".join(f"{n}={k}" for n, k in kandydaci[:5])
            tropy = ""
            if not kandydaci:
                tropy = "; ".join(
                    f"{n}={k}" for n, k in _ten_sam_rodzaj(porownawcza, slownik_eppo)[:5]
                )
            zapis.writerow([nazwa, uzycia.get(nazwa, 0), stan, kod, opis, tropy, ""])


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baza-eppo", type=Path,
                        default=Path("dane/pobrane/p3_eppo/eppocodes_all.sqlite"))
    parser.add_argument("--slownik-rejestru", type=Path,
                        default=Path("dane/pobrane/p1/Slownik_Uprawy.csv"))
    parser.add_argument("--decyzje", type=Path,
                        default=Path("assets/dane/kody_eppo_decyzje.csv"),
                        help="kody rozstrzygnięte ręcznie — mają pierwszeństwo przed "
                             "dopasowaniem po nazwie polskiej")
    parser.add_argument("--baza", type=Path,
                        default=Path("dane/wynik/srodki_ochrony.sqlite"),
                        help="baza z P1 — służy do ustalenia, które uprawy są najważniejsze")
    parser.add_argument("--wynik", type=Path, default=Path("dane/wynik/uprawy_eppo.csv"))
    parser.add_argument("--do-decyzji", type=Path,
                        default=Path("dane/wynik/uprawy_eppo_do_decyzji.csv"))
    args = parser.parse_args(argv)

    if not args.baza_eppo.exists():
        print(f"Brak bazy EPPO: {args.baza_eppo}", file=sys.stderr)
        return 1

    slownik_eppo = nazwy_polskie(args.baza_eppo)
    nazwy_urzedowe = wczytaj_csv_slownik(args.slownik_rejestru)
    wiersze = dopasuj(nazwy_urzedowe, slownik_eppo)

    decyzje = wczytaj_decyzje(args.decyzje) if args.decyzje and args.decyzje.exists() else {}
    if decyzje:
        print(f"Kody rozstrzygnięte ręcznie: {len(decyzje)}")
        wiersze = [
            (nazwa, decyzje.get(postac_porownawcza(nazwa), (kod, stan))[0],
             decyzje.get(postac_porownawcza(nazwa), (kod, stan))[1])
            for nazwa, kod, stan in wiersze
        ]

    liczby = Counter(stan for _, _, stan in wiersze)
    razem = max(len(wiersze), 1)
    print(f"Polskie nazwy roślin w bazie EPPO: {len(slownik_eppo)}")
    print(f"Nazwy upraw z rejestru:            {len(nazwy_urzedowe)}")
    print("\nDopasowanie kodów:")
    for stan, opis in [("kod", "nazwa polska zgodna"),
                       ("propozycja", "nazwa z dopowiedzeniem — do potwierdzenia"),
                       ("wiele", "kilku kandydatów — do wyboru"),
                       ("brak", "brak polskiej nazwy w EPPO")]:
        ile = liczby.get(stan, 0)
        print(f"  {opis:28} {ile:5}  ({100 * ile / razem:5.1f}%)")

    uzycia = liczba_zastosowan(args.baza)
    if uzycia:
        suma = sum(uzycia.values())
        z_kodem = {n for n, _, stan in wiersze if stan == "kod"}
        pokryte = sum(ile for nazwa, ile in uzycia.items() if nazwa in z_kodem)
        print(f"\nUdział zastosowań z gotowym kodem: {100 * pokryte / max(suma, 1):.1f}%")
        brakujace = sorted(
            ((ile, nazwa) for nazwa, ile in uzycia.items() if nazwa not in z_kodem),
            reverse=True,
        )[:5]
        print("Najważniejsze uprawy czekające na decyzję:")
        for ile, nazwa in brakujace:
            print(f"  {nazwa[:32]:32} {ile:5} zastosowań")

    zapisz_kody(args.wynik, wiersze)
    zapisz_do_decyzji(args.do_decyzji, wiersze, uzycia, slownik_eppo)
    print(f"\nKody do użycia:     {args.wynik}")
    print(f"Do ręcznej decyzji: {args.do_decyzji}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
