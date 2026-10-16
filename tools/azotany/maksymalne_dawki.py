"""Tabela 14: maksymalne ilości azotu działającego dla upraw (zadanie: luka 1).

Źródło: rozporządzenie Rady Ministrów z 31.01.2023 w sprawie „Programu
działań mających na celu zmniejszenie zanieczyszczenia wód azotanami…"
(Dz.U. 2023 poz. 244), załącznik nr 9, tabela 14 — strony 122–127.

Tabela mówi, ile azotu działającego **ze wszystkich źródeł** wolno dać pod
daną uprawę w plonie głównym. Program każe pomniejszyć te wartości o 20%
na glebach bardzo lekkich i o 10% na lekkich; rośliny bobowate mają limit
w innej postaci (30 kg z nawozów mineralnych albo 50 kg z naturalnych).

Warstwa tekstowa Dziennika Ustaw gubi polskie znaki — „Jęczmieo" zamiast
„Jęczmień", „dwikłowy" zamiast „ćwikłowy". Poprawki są wypisane niżej
i stosowane przed dopasowaniem; każda nierozpoznana linia z liczbą kończy
się błędem, żeby nic nie wypadło po cichu.

Użycie:

    python3 tools/azotany/maksymalne_dawki.py \\
        --program dane/pobrane/azotany/D20230244.pdf \\
        --reguly assets/dane/reguly_prawne.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import pdfplumber

#: Strony tabeli 14 w pliku rozporządzenia.
STRONY = range(122, 128)

#: Naprawa warstwy tekstowej: zapis z PDF → zapis poprawny.
POPRAWKI = {
    "Jęczmieo": "Jęczmień",
    "mieszaocowe": "mieszańcowe",
    "Tytoo": "Tytoń",
    "pensylwaoski": "pensylwański",
    "dwikłowy": "ćwikłowy",
    "Ilośd": "Ilość",
    "ilośd": "ilość",
}

#: Nagłówki grup w tabeli — nie są uprawami.
GRUPY = [
    "Zboża",
    "Bobowate",
    "Oleiste",
    "Okopowe",
    "Pastewne",
    "Inne, w tym uprawy trwałe",
    "Rośliny energetyczne",
    "Warzywa wieloletnie",
    "Warzywa polowe",
    "Rośliny sadownicze",
    "Uprawy szkółkarskie (sadownicze i ozdobne)",
    "Rośliny ozdobne",
]

#: Wiersze, które są dopiskiem układu tabeli, a nie uprawą.
POMIJANE = {
    "polowe, gruntowe, kontenerowe",
    "uprawy polowe, gruntowe",
    "lub",
}

#: Uprawy bobowate dzielące jeden limit (tabela podaje go raz, dla całej
#: grupy, w postaci „30 kg z mineralnych albo 50 kg z naturalnych").
BOBOWATE = [
    "Bobik",
    "Grochy",
    "Lędźwian",
    "Łubiny",
    "Seradela",
    "Soczewica",
    "Soja",
    "Wyka",
]

#: Wiersze „zbiorcze" — tabela zamyka nimi grupę („Inne oleiste 160").
#: Aplikacja nie wolno dopasowywać ich po fragmencie nazwy, bo słowo
#: „inne" trafiłoby w cokolwiek; wybiera je tylko rolnik wprost.
NAZWY_OGOLNE = {
    ("Oleiste", "Inne oleiste"),
    ("Okopowe", "Inne"),
    ("Rośliny energetyczne", "Pozostałe"),
    ("Rośliny ozdobne", "Inne gatunki gruntowych roślin ozdobnych"),
}

LINIA_Z_WARTOSCIA = re.compile(r"^(?P<nazwa>.+?)\s+(?P<kg>\d{2,3})$")

#: Etykiety komórki, które nie są częścią nazwy uprawy. Tabela pisze
#: „Warzywa: rabarbar, szczaw…" — zostaje sama nazwa rośliny.
ETYKIETY_KOMORKI = ("Warzywa:",)


def oczysc_nazwe(nazwa: str) -> str:
    """Nazwa uprawy bez resztek układu tabeli.

    Komórki zawijają się na kilka linii, więc do nazwy trafia czasem
    etykieta listy („Warzywa: rabarbar") albo spójnik z prawej kolumny
    („Grochy lub"). Dalsze pozycje zawiniętej listy zaczynają się małą
    literą — to pełne uprawy, tylko z małej napisane.
    """
    nazwa = nazwa.strip().rstrip(":").strip()
    for etykieta in ETYKIETY_KOMORKI:
        if nazwa.startswith(etykieta):
            nazwa = nazwa[len(etykieta) :].strip()
    nazwa = re.sub(r"\s+lub$", "", nazwa).strip()
    if nazwa[:1].islower():
        nazwa = nazwa[:1].upper() + nazwa[1:]
    return nazwa


def popraw(tekst: str) -> str:
    for zly, dobry in POPRAWKI.items():
        tekst = tekst.replace(zly, dobry)
    return tekst


def wiersze_tabeli(pdf: Path) -> list[str]:
    """Linie tabeli 14, bez nagłówków stron i numerów stron."""
    linie: list[str] = []
    with pdfplumber.open(pdf) as dokument:
        for numer in STRONY:
            tekst = dokument.pages[numer - 1].extract_text() or ""
            for linia in tekst.splitlines():
                linia = popraw(linia.strip())
                if not linia:
                    continue
                if linia.startswith(("Dziennik Ustaw", "Dzien nik Ustaw")):
                    continue
                if re.fullmatch(r"\d{1,3}", linia):  # numer strony u dołu
                    continue
                linie.append(linia)
    return linie


def czytaj(pdf: Path) -> tuple[list[dict], dict]:
    """Uprawy z tabeli 14 i zasady pomniejszania z przypisu."""
    linie = wiersze_tabeli(pdf)

    # Podpis tabeli zajmuje kilka linii; tabela zaczyna się dopiero od
    # nagłówka kolumn.
    poczatek = next(
        i
        for i, l in enumerate(linie)
        if l.startswith("Rodzaj uprawy")
        and any(
            p.startswith("Tabela 14.") for p in linie[max(0, i - 6) : i]
        )
    )
    uprawy: list[dict] = []
    grupa = ""
    bobowate_kg: list[int] = []
    w_bobowatych = False
    nierozpoznane: list[str] = []

    for linia in linie[poczatek + 1 :]:
        if linia.startswith("Rodzaj uprawy") or linia.startswith(
            "ze wszystkich źródeł"
        ):
            continue
        if linia.startswith("1)") or linia.startswith("2)"):
            break
        if linia in GRUPY:
            grupa = linia
            w_bobowatych = grupa == "Bobowate"
            continue
        if linia in POMIJANE:
            continue

        # Blok bobowatych: limit podany słownie, raz dla całej grupy —
        # i rozbity na dwie linie („…30 kg z mineralnych" / „lub 50 kg
        # z naturalnych").
        if w_bobowatych or "kg z nawozów" in linia:
            bobowate_kg += [int(k) for k in re.findall(r"(\d+)\s*kg", linia)]
            nazwa = re.sub(r"\s*(lub\s*)?\d+ kg z nawozów.*$", "", linia)
            surowa = nazwa.strip().rstrip(":").strip()
            nazwa = oczysc_nazwe(nazwa)
            if not nazwa or surowa == "lub":
                continue
            dalszy_ciag = (
                surowa[:1].islower()
                and uprawy
                and uprawy[-1].get("bobowate")
            )
            if dalszy_ciag:
                uprawy[-1]["uprawa"] = f"{uprawy[-1]['uprawa']} {nazwa}"
                continue
            uprawy.append(
                {
                    "grupa": grupa or "Pastewne",
                    "uprawa": nazwa,
                    "kg_n_ha": None,
                    "bobowate": True,
                }
            )
            continue

        dopasowanie = LINIA_Z_WARTOSCIA.match(linia)
        if dopasowanie:
            uprawy.append(
                {
                    "grupa": grupa,
                    "uprawa": oczysc_nazwe(dopasowanie.group("nazwa")),
                    "kg_n_ha": int(dopasowanie.group("kg")),
                    "bobowate": False,
                }
            )
            continue

        nierozpoznane.append(linia)

    return uprawy, {
        "bobowate_kg": sorted(set(bobowate_kg)),
        "nierozpoznane": nierozpoznane,
    }


def sprawdz(uprawy: list[dict], dodatki: dict) -> list[str]:
    """Kontrole negatywne — lepiej przerwać niż zapisać połowę tabeli."""
    bledy = []
    if dodatki["nierozpoznane"]:
        bledy.append(
            "linie, których nie umiem przeczytać: "
            + "; ".join(dodatki["nierozpoznane"][:5])
        )
    if dodatki["bobowate_kg"] != [30, 50]:
        bledy.append(
            f"limit bobowatych powinien być 30 i 50 kg, "
            f"a wyszło {dodatki['bobowate_kg']}"
        )
    # Ta sama nazwa bywa w dwóch grupach z różnym limitem (rzepak: 240
    # w oleistych, 200 w pastewnych) — dlatego klucz jest podwójny.
    znane = {(u["grupa"], u["uprawa"]): u["kg_n_ha"] for u in uprawy}
    for grupa, nazwa, oczekiwane in [
        ("Zboża", "Pszenica ozima", 200),
        ("Zboża", "Kukurydza na ziarno", 240),
        ("Oleiste", "Rzepak", 240),
        ("Pastewne", "Rzepak", 200),
        ("Okopowe", "Burak cukrowy", 180),
        ("Okopowe", "Ziemniak późny", 180),
        ("Warzywa polowe", "Kalafior", 350),
        ("Rośliny sadownicze", "Truskawka", 60),
        ("Inne, w tym uprawy trwałe", "Chmiel", 350),
        ("Warzywa wieloletnie", "Rabarbar", 200),
        ("Warzywa wieloletnie", "Szczaw", 150),
        ("Warzywa wieloletnie", "Szparag", 150),
    ]:
        if znane.get((grupa, nazwa)) != oczekiwane:
            bledy.append(
                f"{grupa}/{nazwa}: w tabeli ma być {oczekiwane} kg N/ha, "
                f"a wyszło {znane.get((grupa, nazwa))}"
            )
    bobowate = [u["uprawa"] for u in uprawy if u["grupa"] == "Bobowate"]
    if bobowate != BOBOWATE:
        bledy.append(
            f"grupa Bobowate powinna mieć {BOBOWATE}, a wyszło {bobowate}"
        )
    for u in uprawy:
        if ":" in u["uprawa"] and not u["uprawa"].startswith("Bobowate na"):
            bledy.append(f"nazwa z resztką układu tabeli: {u['uprawa']}")
        if u["uprawa"][:1].islower():
            bledy.append(f"nazwa pisana z małej litery: {u['uprawa']}")
    nazwy = {(u["grupa"], u["uprawa"]) for u in uprawy}
    for brakujaca in NAZWY_OGOLNE - nazwy:
        bledy.append(
            f"wiersz zbiorczy {brakujaca} zniknął z odczytu — "
            "popraw NAZWY_OGOLNE albo sprawdź tabelę"
        )
    if len(uprawy) < 100:
        bledy.append(f"tabela ma ponad 100 wierszy, a wyszło {len(uprawy)}")
    return bledy


def do_regul(uprawy: list[dict]) -> dict:
    return {
        "status_weryfikacji": "potwierdzone",
        "zrodlo": (
            "Dz.U. 2023 poz. 244 — rozporządzenie Rady Ministrów z 31 stycznia "
            "2023 r. w sprawie Programu działań mających na celu zmniejszenie "
            "zanieczyszczenia wód azotanami pochodzącymi ze źródeł rolniczych, "
            "załącznik nr 9, tabela 14"
        ),
        "sprawdzono": "2026-10-16",
        "opis": (
            "Maksymalne ilości azotu działającego ze wszystkich źródeł dla "
            "upraw w plonie głównym. Azot działający liczy się z "
            "równoważnikami z tabeli 11 (załącznik nr 8)."
        ),
        "obnizki": [
            {
                "rodzaj_gleby": "bardzo_lekka",
                "procent": 20,
                "opis": "gleby bardzo lekkie (do 10% cząstek < 0,02 mm)",
            },
            {
                "rodzaj_gleby": "lekka",
                "procent": 10,
                "opis": "gleby lekkie (11–20% cząstek < 0,02 mm)",
            },
        ],
        "bobowate": {
            "kg_n_ha_mineralne": 30,
            "kg_n_ha_naturalne": 50,
            "opis": (
                "Rośliny bobowate: najwyżej 30 kg N/ha z nawozów azotowych "
                "mineralnych albo 50 kg N/ha z nawozów naturalnych."
            ),
        },
        "uprawy": [
            {
                "grupa": u["grupa"],
                "uprawa": u["uprawa"],
                **(
                    {"bobowate": True}
                    if u["bobowate"]
                    else {"kg_n_ha": u["kg_n_ha"]}
                ),
                **(
                    {"ogolna": True}
                    if (u["grupa"], u["uprawa"]) in NAZWY_OGOLNE
                    else {}
                ),
            }
            for u in uprawy
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--program",
        type=Path,
        default=Path("dane/pobrane/azotany/D20230244.pdf"),
    )
    parser.add_argument(
        "--reguly", type=Path, default=Path("assets/dane/reguly_prawne.json")
    )
    parser.add_argument("--sprawdz-tylko", action="store_true")
    args = parser.parse_args(argv)

    if not args.program.exists():
        print(f"Brak pliku rozporządzenia: {args.program}", file=sys.stderr)
        return 1

    uprawy, dodatki = czytaj(args.program)
    bledy = sprawdz(uprawy, dodatki)

    print(f"Upraw w tabeli 14: {len(uprawy)}")
    grupy: dict[str, int] = {}
    for u in uprawy:
        grupy[u["grupa"]] = grupy.get(u["grupa"], 0) + 1
    for grupa, ile in grupy.items():
        print(f"  {grupa:46} {ile:3}")

    if bledy:
        print("\nDo poprawienia:", file=sys.stderr)
        for b in bledy:
            print(f"  - {b}", file=sys.stderr)
        return 1

    if args.sprawdz_tylko:
        print("\nOdczyt zgodny z tabelą.")
        return 0

    reguly = json.loads(args.reguly.read_text(encoding="utf-8"))
    reguly["maksymalne_dawki_azotu"] = do_regul(uprawy)
    args.reguly.write_text(
        json.dumps(reguly, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\nZapisano do {args.reguly}")
    print("Pamiętaj o podniesieniu pola „wersja” w słowniku reguł.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
