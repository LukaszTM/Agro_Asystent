"""Notowania cen skupu jako dane z wersją — etap 3, krok 7.

Skąd dane: Zintegrowany System Rolniczej Informacji Rynkowej (ZSRIR)
Ministerstwa Rolnictwa i Rozwoju Wsi publikuje tygodniowe notowania cen
skupu zbóż, rzepaku, mleka i żywca w podziale na makroregiony
i województwa.

Dlaczego skrypt, a nie pobieranie z aplikacji: **stron ministerstwa nie
pobieramy z urządzenia rolnika** (CLAUDE.md, reguła 3). Notowania
przygotowuje ten skrypt na komputerze dewelopera, a do programu jadą jako
gotowy plik z numerem wersji i z tygodniem, którego dotyczą.

Dlaczego plik w repozytorium jest pusty: **cen nie wolno zmyślić**
(CLAUDE.md, reguła 5). Dopóki nikt nie uruchomi skryptu na prawdziwym
pliku notowań, program mówi wprost, że notowań nie ma — zamiast pokazać
liczbę, na podstawie której ktoś mógłby sprzedać zboże.

Dwa wejścia:

* `--csv` — prosty plik: produkt;jednostka;region;cena
  (tak samo wpisze się notowania z biuletynu ręcznie),
* `--zsrir` — plik pobrany z ZSRIR; kolumny rozpoznajemy po nagłówkach,
  a wynik dostaje status `do_weryfikacji`, bo układ pliku bywa zmieniany.

Użycie:

    python3 tools/ceny/ceny_skupu.py --csv dane/ceny/notowania.csv \\
        --od 2026-10-06 --do 2026-10-12 --zapisz assets/dane/ceny_skupu.json
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import pathlib
import sys
import unicodedata

DOMYSLNY_PLIK = pathlib.Path("assets/dane/ceny_skupu.json")

POTWIERDZONE = "potwierdzone"
DO_WERYFIKACJI = "do_weryfikacji"

# Nagłówki, po których poznajemy kolumny w pliku z ZSRIR. Lista jest
# celowo szeroka — ministerstwo nazywa te same kolumny różnie w różnych
# zestawieniach.
NAGLOWKI = {
    "produkt": ("produkt", "towar", "asortyment", "wyszczegolnienie"),
    "jednostka": ("jednostka", "jm", "jedn"),
    "region": ("region", "wojewodztwo", "makroregion", "obszar"),
    "cena": ("cena", "cena netto", "srednia cena", "cena skupu"),
}


class Notowanie:
    """Jedna cena: co, za ile, w jakim regionie."""

    def __init__(
        self,
        produkt: str,
        jednostka: str,
        region: str,
        cena: float,
        status: str = POTWIERDZONE,
    ):
        if not produkt.strip():
            raise ValueError("notowanie bez nazwy produktu")
        if not jednostka.strip():
            raise ValueError(f"notowanie „{produkt}” bez jednostki")
        if not region.strip():
            raise ValueError(f"notowanie „{produkt}” bez regionu")
        if cena <= 0:
            raise ValueError(f"notowanie „{produkt}” z ceną {cena}")

        self.produkt = produkt.strip()
        self.jednostka = jednostka.strip()
        self.region = region.strip().lower()
        self.cena = round(float(cena), 2)
        self.status = status

    def __repr__(self) -> str:  # pragma: no cover - pomoc przy debugowaniu
        return f"Notowanie({self.produkt!r}, {self.region!r}, {self.cena})"


def bez_ogonkow(tekst: str) -> str:
    """Nagłówek do porównania: bez polskich znaków, kropek i skrótów.

    Ministerstwo pisze tę samą kolumnę jako „Jedn.", „jednostka" albo
    „j.m." — porównujemy więc same litery.
    """
    rozlozony = unicodedata.normalize("NFKD", tekst.strip().lower())
    bez_znakow = "".join(
        znak for znak in rozlozony if not unicodedata.combining(znak)
    )
    tylko_litery = "".join(
        znak if znak.isalnum() else " " for znak in bez_znakow
    )
    return " ".join(tylko_litery.split())


def liczba(zapis: str) -> float:
    """„1 234,56" → 1234.56. Polskie pliki mają przecinek i spacje."""
    oczyszczony = (
        zapis.replace("\xa0", "").replace(" ", "").replace(",", ".").strip()
    )
    return float(oczyszczony)


def wczytaj_csv(wiersze: list[dict[str, str]]) -> list[Notowanie]:
    """Prosty plik: produkt;jednostka;region;cena."""
    notowania = []
    for wiersz in wiersze:
        notowania.append(
            Notowanie(
                produkt=wiersz["produkt"],
                jednostka=wiersz["jednostka"],
                region=wiersz["region"],
                cena=liczba(wiersz["cena"]),
            )
        )
    return notowania


def dopasuj_kolumny(naglowki: list[str]) -> dict[str, str]:
    """Które kolumny pliku ZSRIR odpowiadają naszym polom."""
    znalezione: dict[str, str] = {}
    for pole, warianty in NAGLOWKI.items():
        for naglowek in naglowki:
            if bez_ogonkow(naglowek) in warianty:
                znalezione[pole] = naglowek
                break
    brakujace = set(NAGLOWKI) - set(znalezione)
    if brakujace:
        raise ValueError(
            "w pliku brakuje kolumn: " + ", ".join(sorted(brakujace))
        )
    return znalezione


def wczytaj_zsrir(wiersze: list[dict[str, str]]) -> list[Notowanie]:
    """Plik z ZSRIR. Wynik dostaje status `do_weryfikacji`."""
    if not wiersze:
        return []
    kolumny = dopasuj_kolumny(list(wiersze[0].keys()))
    notowania = []
    for wiersz in wiersze:
        zapis = (wiersz.get(kolumny["cena"]) or "").strip()
        if not zapis or zapis in {"-", "x", "."}:
            # Brak notowania w danym tygodniu zostaje brakiem — nie
            # przepisujemy ceny z poprzedniego tygodnia.
            continue
        notowania.append(
            Notowanie(
                produkt=wiersz[kolumny["produkt"]],
                jednostka=wiersz[kolumny["jednostka"]],
                region=wiersz[kolumny["region"]],
                cena=liczba(zapis),
                status=DO_WERYFIKACJI,
            )
        )
    return notowania


def zbuduj(
    notowania: list[Notowanie],
    *,
    od: dt.date,
    do: dt.date,
    wzorzec: dict,
    wersja: str | None = None,
) -> dict:
    """Składa plik danych: produkty, a w każdym ceny po regionach."""
    if do < od:
        raise ValueError("koniec tygodnia wcześniej niż początek")

    produkty: dict[tuple[str, str], dict] = {}
    for notowanie in notowania:
        klucz = (notowanie.produkt, notowanie.jednostka)
        produkt = produkty.setdefault(
            klucz,
            {"nazwa": notowanie.produkt, "jednostka": notowanie.jednostka, "ceny": []},
        )
        produkt["ceny"].append(
            {
                "region": notowanie.region,
                "cena": notowanie.cena,
                "status": notowanie.status,
            }
        )

    nowe = json.loads(json.dumps(wzorzec))
    nowe["wersja"] = wersja or f"{do.isoformat().replace('-', '.')}.1"
    nowe["tydzien"] = {"od": od.isoformat(), "do": do.isoformat()}
    nowe["produkty"] = [
        produkty[klucz] for klucz in sorted(produkty, key=lambda k: k[0].lower())
    ]
    return nowe


def _wiersze_pliku(sciezka: pathlib.Path) -> list[dict[str, str]]:
    tresc = sciezka.read_text(encoding="utf-8-sig")
    rozdzielnik = ";" if tresc.count(";") >= tresc.count(",") else ","
    return list(csv.DictReader(tresc.splitlines(), delimiter=rozdzielnik))


def main(argumenty: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--csv", type=pathlib.Path)
    parser.add_argument("--zsrir", type=pathlib.Path)
    parser.add_argument("--od", required=False, help="początek tygodnia, RRRR-MM-DD")
    parser.add_argument("--do", required=False, help="koniec tygodnia, RRRR-MM-DD")
    parser.add_argument("--zapisz", type=pathlib.Path, default=None)
    parser.add_argument("--plik", type=pathlib.Path, default=DOMYSLNY_PLIK)
    parser.add_argument("--sprawdz-tylko", action="store_true")
    opcje = parser.parse_args(argumenty)

    wzorzec = json.loads(opcje.plik.read_text(encoding="utf-8"))

    if opcje.sprawdz_tylko:
        for pole in ("wersja", "zrodlo", "uwaga", "zastrzezenie", "produkty"):
            if pole not in wzorzec:
                print(f"Plik nie ma pola {pole}.")
                return 1
        print(
            f"Plik w porządku: {len(wzorzec['produkty'])} produktów, "
            f"tydzień {wzorzec.get('tydzien')}."
        )
        return 0

    if not opcje.csv and not opcje.zsrir:
        print("Podaj --csv albo --zsrir (albo --sprawdz-tylko).")
        return 1
    if not opcje.od or not opcje.do:
        print("Podaj tydzień notowań: --od i --do.")
        return 1

    if opcje.csv:
        notowania = wczytaj_csv(_wiersze_pliku(opcje.csv))
    else:
        notowania = wczytaj_zsrir(_wiersze_pliku(opcje.zsrir))

    if not notowania:
        print("Plik nie zawiera ani jednego notowania — nic nie zapisuję.")
        return 2

    nowe = zbuduj(
        notowania,
        od=dt.date.fromisoformat(opcje.od),
        do=dt.date.fromisoformat(opcje.do),
        wzorzec=wzorzec,
    )
    print(f"Produktów: {len(nowe['produkty'])}, notowań: {len(notowania)}.")
    for produkt in nowe["produkty"]:
        print(f"  {produkt['nazwa']} ({produkt['jednostka']}): "
              f"{len(produkt['ceny'])} regionów")

    if opcje.zapisz:
        opcje.zapisz.write_text(
            json.dumps(nowe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"Zapisane do {opcje.zapisz}.")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
