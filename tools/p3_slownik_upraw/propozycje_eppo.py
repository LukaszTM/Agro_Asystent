"""Propozycje kodów EPPO, które wynikają z bazy EPPO, a nie z domysłu.

Zadanie P3 zostawiło 63 uprawy do ręcznej decyzji, bo baza EPPO nie ma
polskich nazw dla większości polskich upraw. Jedna część tej listy daje się
rozstrzygnąć **bez domysłu**: gdy nazwa z rejestru ma w EPPO kilku
kandydatów, ale **wszyscy wskazują ten sam kod** — np. „soja" to „soja
warzywna" i „soja owłosiona", oba `GLXMA`. Którakolwiek nazwa byłaby
właściwa, kod jest ten sam.

**Pojedynczego kandydata z dopowiedzeniem celowo nie proponujemy.**
Wyglądał na bezpieczny („marchew" → „marchew zwyczajna" `DAUCA`), ale
sprawdzenie na całej liście pokazało, że dopowiedzenie potrafi oznaczać
**inny gatunek**:

- „pszenica" → „pszenica płaskurka" `TRZMO` (a nie `TRZAX`),
- „sorgo" → „sorgo alepskie" `SORHA` — to chwast, nie uprawa,
- „nasiona" → `CRIHA`, kod winorośli balonowej.

Takie nazwy trafiają do pliku decyzji ze stanem `do_decyzji` i podpowiedzią
— widać je, ale aplikacja ich nie użyje. Kodów nie wymyślamy: błędny kod
EPPO to błąd w dokumencie urzędowym, który od 2027 r. ma być czytany
maszynowo (P3).

Skrypt oznacza też nazwy, **które uprawą nie są** — miejsca stosowania
i przedmioty z kolumny „uprawa" rejestru (doniczki, noże, stoły, uprawa
pod osłonami). Takie nazwy nigdy nie dostaną kodu i nie mają zaniżać
pokrycia; lista pochodzi z raportu P3.

Użycie:

    python3 tools/p3_slownik_upraw/propozycje_eppo.py \\
        --do-decyzji dane/wynik/uprawy_eppo_do_decyzji.csv \\
        --eppo dane/pobrane/p3_eppo/eppocodes_all.sqlite
"""

from __future__ import annotations

import argparse
import csv
import re
import sqlite3
import sys
from datetime import date
from pathlib import Path

#: Status „A" w bazie EPPO oznacza nazwę aktualną.
STATUS_AKTUALNY = "A"

#: Nazwy z kolumny „uprawa" rejestru, które uprawą nie są (raport P3):
#: miejsca stosowania, przedmioty i terminy agrotechniczne.
NIE_UPRAWY = [
    "uprawa pod osłonami",
    "uprawa w szklarni",
    "doniczki",
    "noże",
    "sekatory",
    "stoły",
    "worki",
    "skrzynie do przechowywania",
    "nasypy",
    "siew jesienny",
    "siew wiosenny",
]

KOD_W_KANDYDACIE = re.compile(r"([^;=]+)=([A-Z0-9]{4,6})")


def kandydaci(zapis: str) -> list[tuple[str, str]]:
    """Pary „nazwa EPPO" → kod z kolumny kandydatów."""
    return [
        (nazwa.strip(), kod)
        for nazwa, kod in KOD_W_KANDYDACIE.findall(zapis or "")
    ]


def nazwy_kodu(baza: sqlite3.Connection, kod: str) -> list[str]:
    """Polskie nazwy aktualne dla kodu EPPO."""
    return [
        nazwa
        for (nazwa,) in baza.execute(
            """
            SELECT n.fullname
            FROM t_codes c
            JOIN t_names n ON n.codeid = c.codeid
            WHERE c.eppocode = ? AND n.codelang = 'pl' AND n.status = ?
            """,
            (kod, STATUS_AKTUALNY),
        )
    ]


def istnieje(baza: sqlite3.Connection, kod: str) -> bool:
    return (
        baza.execute(
            "SELECT 1 FROM t_codes WHERE eppocode = ? LIMIT 1", (kod,)
        ).fetchone()
        is not None
    )


def propozycje(
    wiersze: list[dict[str, str]], baza: sqlite3.Connection
) -> tuple[list[dict[str, str]], list[str]]:
    """Propozycje wynikające z bazy i powody odrzucenia pozostałych."""
    wynik: list[dict[str, str]] = []
    odrzucone: list[str] = []
    dzisiaj = date.today().isoformat()

    for wiersz in wiersze:
        nazwa = wiersz["nazwa_urzedowa"]
        pary = kandydaci(wiersz.get("kandydaci", ""))
        kody = {kod for _, kod in pary}

        if wiersz["stan"] == "wiele" and len(kody) == 1:
            kod = next(iter(kody))
            powod = "wszyscy kandydaci z bazy EPPO wskazują ten sam kod"
        else:
            continue

        if not istnieje(baza, kod):
            odrzucone.append(f"{nazwa}: kodu {kod} nie ma w bazie EPPO")
            continue
        polskie = nazwy_kodu(baza, kod)
        if not polskie:
            odrzucone.append(
                f"{nazwa}: kod {kod} nie ma aktualnej polskiej nazwy"
            )
            continue

        wynik.append(
            {
                "nazwa_uprawy": nazwa,
                "kod_eppo": kod,
                "nazwa_eppo": "; ".join(polskie[:3]),
                "stan": "propozycja",
                "zrodlo": powod,
                "data": dzisiaj,
            }
        )
    return wynik, odrzucone


def wpisy_do_decyzji(
    wiersze: list[dict[str, str]], juz_proponowane: set[str]
) -> list[dict[str, str]]:
    """Nazwy z podpowiedzią, której **nie** proponujemy — do decyzji.

    Aplikacja takiego wpisu nie użyje; jest po to, żeby właściciel projektu
    widział podpowiedź i mógł rozstrzygnąć jednym podpisem.
    """
    dzisiaj = date.today().isoformat()
    wynik = []
    for wiersz in wiersze:
        nazwa = wiersz["nazwa_urzedowa"]
        if nazwa in juz_proponowane or nazwa in NIE_UPRAWY:
            continue
        podpowiedz = wiersz.get("propozycja") or ""
        kandydat = wiersz.get("kandydaci") or ""
        if not podpowiedz and not kandydat:
            continue
        wynik.append(
            {
                "nazwa_uprawy": nazwa,
                "kod_eppo": "",
                "nazwa_eppo": (podpowiedz or kandydat)[:120],
                "stan": "do_decyzji",
                "zrodlo": "podpowiedź z bazy EPPO — wymaga rozstrzygnięcia, "
                          "dopowiedzenie może oznaczać inny gatunek",
                "data": dzisiaj,
            }
        )
    return wynik


def wpisy_nie_uprawy() -> list[dict[str, str]]:
    dzisiaj = date.today().isoformat()
    return [
        {
            "nazwa_uprawy": nazwa,
            "kod_eppo": "",
            "nazwa_eppo": "",
            "stan": "nie_uprawa",
            "zrodlo": "miejsce stosowania albo przedmiot, nie roślina "
                      "(raport P3)",
            "data": dzisiaj,
        }
        for nazwa in NIE_UPRAWY
    ]


def scal(plik: Path, nowe: list[dict[str, str]]) -> tuple[int, int]:
    """Dopisuje wpisy, nie ruszając już potwierdzonych decyzji."""
    istniejace: list[dict[str, str]] = []
    if plik.exists():
        with plik.open(encoding="utf-8", newline="") as f:
            istniejace = list(csv.DictReader(f, delimiter=";"))
    znane = {w["nazwa_uprawy"] for w in istniejace}

    dopisane = [w for w in nowe if w["nazwa_uprawy"] not in znane]
    wszystkie = istniejace + dopisane
    wszystkie.sort(key=lambda w: (w["stan"], w["nazwa_uprawy"]))

    with plik.open("w", encoding="utf-8", newline="") as f:
        pisarz = csv.DictWriter(
            f,
            fieldnames=[
                "nazwa_uprawy",
                "kod_eppo",
                "nazwa_eppo",
                "stan",
                "zrodlo",
                "data",
            ],
            delimiter=";",
        )
        pisarz.writeheader()
        pisarz.writerows(wszystkie)
    return len(dopisane), len(wszystkie)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Dopisuje do pliku decyzji kody EPPO wynikające z bazy EPPO "
            "oraz nazwy, które uprawą nie są."
        )
    )
    parser.add_argument(
        "--do-decyzji",
        type=Path,
        default=Path("dane/wynik/uprawy_eppo_do_decyzji.csv"),
        help="lista upraw do decyzji z eppo.py",
    )
    parser.add_argument(
        "--eppo",
        type=Path,
        default=Path("dane/pobrane/p3_eppo/eppocodes_all.sqlite"),
        help="baza EPPO Global Database",
    )
    parser.add_argument(
        "--decyzje",
        type=Path,
        default=Path("assets/dane/kody_eppo_decyzje.csv"),
        help="plik decyzji w repozytorium",
    )
    parser.add_argument(
        "--sprawdz-tylko",
        action="store_true",
        help="policz i wypisz, ale nie zapisuj",
    )
    argumenty = parser.parse_args()

    with argumenty.do_decyzji.open(encoding="utf-8", newline="") as f:
        wiersze = list(csv.DictReader(f, delimiter=";"))

    baza = sqlite3.connect(f"file:{argumenty.eppo}?mode=ro", uri=True)
    nowe, odrzucone = propozycje(wiersze, baza)
    baza.close()

    zastosowania = {
        w["nazwa_urzedowa"]: int(w["zastosowan_w_rejestrze"]) for w in wiersze
    }
    suma = sum(zastosowania.get(w["nazwa_uprawy"], 0) for w in nowe)
    print(f"propozycji sprawdzonych w bazie EPPO: {len(nowe)}")
    print(f"zastosowań w rejestrze, które obejmują: {suma}")
    for powod in odrzucone:
        print(" • odrzucone:", powod)

    if argumenty.sprawdz_tylko:
        return 0

    dopisane, razem = scal(
        argumenty.decyzje,
        nowe
        + wpisy_nie_uprawy()
        + wpisy_do_decyzji(wiersze, {w["nazwa_uprawy"] for w in nowe}),
    )
    print(f"dopisano {dopisane} wpisów, plik decyzji ma teraz {razem}")
    print(
        "Propozycje czekają na potwierdzenie — aplikacja nie użyje ich "
        "jako kodu pewnego."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
