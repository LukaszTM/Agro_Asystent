"""Czytnik wniosku o płatności z eWniosekPlus: tabele X i XI (zadanie P4).

Czyta dwie tabele:

- **X. Oświadczenie o działkach referencyjnych** — działki ewidencyjne,
- **XI. Oświadczenie o zadeklarowanych powierzchniach** — działki rolne
  (uprawa, powierzchnia, przypisanie do działek ewidencyjnych).

Kolumny rozpoznajemy po położeniu nagłówka na stronie, a nie po liniach siatki,
bo wniosek jest składany tekstem. Na koniec sprawdzamy sumę powierzchni
z podsumowaniem wniosku — rozbieżność oznacza, że czegoś nie odczytaliśmy
i wynik nie nadaje się do użycia bez obejrzenia przez człowieka.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass, field
from pathlib import Path

import pdfplumber

NAGLOWEK_X = "OŚWIADCZENIE O DZIAŁKACH REFERENCYJNYCH"
NAGLOWEK_XI = "OŚWIADCZENIE O ZADEKLAROWANYCH POWIERZCHNIACH"

KOLUMNY_X = ["Województwo", "Powiat", "Gmina", "Nazwa obrębu", "Nr obrębu",
             "Nr arkusza", "Nr działki", "Powierzchnia"]
KOLUMNY_XI = ["Oznaczenie", "Uprawa", "ha", "a", "Identyfikator", "Płatności"]

_OZNACZENIE = re.compile(r"^[A-Z]{1,2}$")
_IDENTYFIKATOR = re.compile(r"^\d{6}_\d\.\d{4}\.(?:AR_\d+\.)?\d+(?:/\d+)?$")
_LICZBA = re.compile(r"^\d+(?:[.,]\d+)?$")


@dataclass
class DzialkaEwidencyjna:
    wojewodztwo: str = ""
    powiat: str = ""
    gmina: str = ""
    obreb: str = ""
    nr_obrebu: str = ""
    arkusz: str = ""
    nr_dzialki: str = ""
    powierzchnia_ha: float | None = None


@dataclass
class DzialkaRolna:
    oznaczenie: str = ""
    uprawa: str = ""
    ha: int = 0
    ar: int = 0
    identyfikatory: list[str] = field(default_factory=list)
    platnosci: str = ""

    @property
    def powierzchnia_ar(self) -> int:
        return self.ha * 100 + self.ar


@dataclass
class Kontrola:
    """Porównanie odczytu z podsumowaniem wniosku."""

    suma_z_odczytu_ar: int = 0
    suma_z_wniosku_ar: int | None = None
    liczba_dzialek_rolnych: int = 0
    liczba_z_wniosku: int | None = None
    #: Wiersze pominięte jako niebędące danymi (nagłówki i stopki stron).
    wiersze_pominiete: int = 0
    przyklady_pominietych: list[str] = field(default_factory=list)
    ostrzezenia: list[str] = field(default_factory=list)

    @property
    def suma_zgodna(self) -> bool:
        return (
            self.suma_z_wniosku_ar is not None
            and self.suma_z_odczytu_ar == self.suma_z_wniosku_ar
        )

    @property
    def wynik_pewny(self) -> bool:
        return self.suma_zgodna and not self.ostrzezenia


@dataclass
class Wniosek:
    dzialki_ewidencyjne: list[DzialkaEwidencyjna] = field(default_factory=list)
    dzialki_rolne: list[DzialkaRolna] = field(default_factory=list)
    kontrola: Kontrola = field(default_factory=Kontrola)

    @property
    def uprawy(self) -> list[str]:
        return sorted({d.uprawa for d in self.dzialki_rolne if d.uprawa})


# ── odczyt wierszy i kolumn ───────────────────────────────────────────────

@dataclass
class Slowo:
    tekst: str
    x0: float
    x1: float


def wiersze_strony(strona) -> list[list[Slowo]]:
    """Grupuje słowa w wiersze po wysokości (tolerancja 2 punkty)."""
    wiersze: dict[int, list[Slowo]] = {}
    for slowo in strona.extract_words():
        klucz = round(float(slowo["top"]) / 2)
        wiersze.setdefault(klucz, []).append(
            Slowo(slowo["text"], float(slowo["x0"]), float(slowo["x1"]))
        )
    return [sorted(w, key=lambda s: s.x0) for _, w in sorted(wiersze.items())]


def granice_kolumn(naglowek: list[Slowo], nazwy: list[str]) -> list[float]:
    """Lewe krawędzie kolumn, wzięte z położenia nagłówka tabeli."""
    granice: list[float] = []
    uzyte = 0
    for nazwa in nazwy:
        pierwsze_slowo = nazwa.split()[0]
        for numer in range(uzyte, len(naglowek)):
            if naglowek[numer].tekst.startswith(pierwsze_slowo):
                granice.append(naglowek[numer].x0)
                uzyte = numer + 1
                break
    return granice


def do_kolumn(wiersz: list[Slowo], granice: list[float]) -> list[str]:
    """Rozdziela słowa wiersza do kolumn według ich położenia."""
    komorki = ["" for _ in granice]
    for slowo in wiersz:
        numer = 0
        for i, granica in enumerate(granice):
            if slowo.x0 >= granica - 3:
                numer = i
        komorki[numer] = f"{komorki[numer]} {slowo.tekst}".strip()
    return komorki


def _czy_naglowek(wiersz: list[Slowo], nazwy: list[str]) -> bool:
    tresc = " ".join(s.tekst for s in wiersz)
    return sum(1 for n in nazwy if n.split()[0] in tresc) >= max(2, len(nazwy) - 2)


def _liczba(tekst: str) -> float | None:
    tekst = tekst.replace(" ", "").replace(",", ".")
    return float(tekst) if _LICZBA.match(tekst.replace(".", "", 1) or "0") and tekst else None


# ── czytanie tabel ────────────────────────────────────────────────────────

def czytaj(sciezka: Path) -> Wniosek:
    wniosek = Wniosek()
    with pdfplumber.open(sciezka) as pdf:
        wszystkie: list[list[Slowo]] = []
        for strona in pdf.pages:
            wszystkie.extend(wiersze_strony(strona))

    sekcja: str | None = None
    granice: list[float] = []
    for wiersz in wszystkie:
        tresc = " ".join(s.tekst for s in wiersz)

        if NAGLOWEK_X in tresc:
            sekcja, granice = "X", []
            continue
        if NAGLOWEK_XI in tresc:
            sekcja, granice = "XI", []
            continue
        if sekcja is None:
            continue

        nazwy = KOLUMNY_X if sekcja == "X" else KOLUMNY_XI
        if _czy_naglowek(wiersz, nazwy):
            granice = granice_kolumn(wiersz, nazwy)  # także po przejściu na nową stronę
            if len(granice) != len(nazwy):
                brakujace = len(nazwy) - len(granice)
                wniosek.kontrola.ostrzezenia.append(
                    f"tabela {sekcja}: rozpoznano {len(granice)} z {len(nazwy)} kolumn "
                    f"(brakuje {brakujace}) — wiersze mogą być niekompletne"
                )
            continue
        if not granice:
            continue

        if tresc.startswith("Razem"):
            _odczytaj_podsumowanie(tresc, wniosek)
            continue

        komorki = do_kolumn(wiersz, granice)
        if sekcja == "X":
            _dodaj_dzialke_ewidencyjna(komorki, wniosek)
        else:
            _dodaj_dzialke_rolna(komorki, wniosek)

    _podsumuj(wniosek)
    return wniosek


def _pomin(komorki: list[str], wniosek: Wniosek) -> None:
    """Wiersz spoza tabeli: nagłówek albo stopka strony."""
    wniosek.kontrola.wiersze_pominiete += 1
    if len(wniosek.kontrola.przyklady_pominietych) < 5:
        wniosek.kontrola.przyklady_pominietych.append(" ".join(c for c in komorki if c)[:70])


def _dodaj_dzialke_ewidencyjna(komorki: list[str], wniosek: Wniosek) -> None:
    if not komorki[0]:
        return
    # Wiersz danych wypełnia większość kolumn; nagłówek strony — jedną.
    if sum(1 for c in komorki if c.strip()) < 4:
        _pomin(komorki, wniosek)
        return
    powierzchnia = _liczba(komorki[7])
    wniosek.dzialki_ewidencyjne.append(
        DzialkaEwidencyjna(
            wojewodztwo=komorki[0],
            powiat=komorki[1],
            gmina=komorki[2],
            obreb=komorki[3],
            nr_obrebu=komorki[4],
            arkusz=komorki[5],
            nr_dzialki=komorki[6],
            powierzchnia_ha=powierzchnia,
        )
    )
    if powierzchnia is None:
        wniosek.kontrola.ostrzezenia.append(
            f"działka ewidencyjna {komorki[6]}: nie odczytano powierzchni"
        )


def _dodaj_dzialke_rolna(komorki: list[str], wniosek: Wniosek) -> None:
    oznaczenie = komorki[0].strip()

    if _OZNACZENIE.match(oznaczenie):
        ha = _liczba(komorki[2])
        ar = _liczba(komorki[3])
        dzialka = DzialkaRolna(
            oznaczenie=oznaczenie,
            uprawa=komorki[1].strip(),
            ha=int(ha) if ha is not None else 0,
            ar=int(ar) if ar is not None else 0,
            platnosci=komorki[5].strip() if len(komorki) > 5 else "",
        )
        if komorki[4].strip():
            dzialka.identyfikatory.append(komorki[4].strip())
        wniosek.dzialki_rolne.append(dzialka)
        if ha is None and ar is None:
            wniosek.kontrola.ostrzezenia.append(
                f"działka rolna {oznaczenie}: nie odczytano powierzchni"
            )
        return

    if oznaczenie:
        # Coś stoi w kolumnie oznaczenia, ale nie jest oznaczeniem działki —
        # to nagłówek albo stopka strony, nie ciąg dalszy uprawy.
        _pomin(komorki, wniosek)
        return

    # Wiersz bez oznaczenia: ciąg dalszy poprzedniej działki rolnej.
    if not wniosek.dzialki_rolne:
        return
    poprzednia = wniosek.dzialki_rolne[-1]
    dalsza_uprawa = komorki[1].strip()
    dalszy_identyfikator = komorki[4].strip() if len(komorki) > 4 else ""
    if dalsza_uprawa:
        poprzednia.uprawa = f"{poprzednia.uprawa} {dalsza_uprawa}".strip()
    if dalszy_identyfikator:
        poprzednia.identyfikatory.append(dalszy_identyfikator)


def _odczytaj_podsumowanie(tresc: str, wniosek: Wniosek) -> None:
    if "powierzchnia" in tresc.lower():
        dopasowanie = re.search(r"(\d+)[,.](\d{1,2})\s*ha", tresc)
        if dopasowanie:
            wniosek.kontrola.suma_z_wniosku_ar = (
                int(dopasowanie.group(1)) * 100 + int(dopasowanie.group(2).ljust(2, "0"))
            )
    elif "rolnych" in tresc.lower():
        dopasowanie = re.search(r"(\d+)\s*$", tresc)
        if dopasowanie:
            wniosek.kontrola.liczba_z_wniosku = int(dopasowanie.group(1))


def _podsumuj(wniosek: Wniosek) -> None:
    kontrola = wniosek.kontrola
    kontrola.suma_z_odczytu_ar = sum(d.powierzchnia_ar for d in wniosek.dzialki_rolne)
    kontrola.liczba_dzialek_rolnych = len(wniosek.dzialki_rolne)

    if kontrola.suma_z_wniosku_ar is None:
        kontrola.ostrzezenia.append("nie znaleziono podsumowania powierzchni we wniosku")
    elif not kontrola.suma_zgodna:
        roznica = kontrola.suma_z_odczytu_ar - kontrola.suma_z_wniosku_ar
        kontrola.ostrzezenia.append(
            f"suma powierzchni różni się od podsumowania o {roznica / 100:+.2f} ha"
        )
    if (
        kontrola.liczba_z_wniosku is not None
        and kontrola.liczba_z_wniosku != kontrola.liczba_dzialek_rolnych
    ):
        kontrola.ostrzezenia.append(
            f"odczytano {kontrola.liczba_dzialek_rolnych} działek rolnych, "
            f"wniosek podaje {kontrola.liczba_z_wniosku}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plik", type=Path, help="wniosek w formacie PDF")
    parser.add_argument("--uprawy-csv", type=Path, default=None,
                        help="zapisz nazwy upraw do pliku (wejście dla zadania P3)")
    args = parser.parse_args(argv)

    wniosek = czytaj(args.plik)
    kontrola = wniosek.kontrola
    print(f"Działki ewidencyjne: {len(wniosek.dzialki_ewidencyjne)}")
    print(f"Działki rolne:       {len(wniosek.dzialki_rolne)}")
    print(f"Powierzchnia z odczytu:   {kontrola.suma_z_odczytu_ar / 100:.2f} ha")
    if kontrola.suma_z_wniosku_ar is not None:
        print(f"Powierzchnia z wniosku:   {kontrola.suma_z_wniosku_ar / 100:.2f} ha")
    print(f"Różnych upraw:       {len(wniosek.uprawy)}")
    if kontrola.wiersze_pominiete:
        print(f"Pominięte wiersze (nagłówki i stopki stron): {kontrola.wiersze_pominiete}")
        for przyklad in kontrola.przyklady_pominietych:
            print(f"    {przyklad}")
    print("Kontrola: " + ("zgodna" if kontrola.wynik_pewny else "NIEZGODNA"))
    for ostrzezenie in kontrola.ostrzezenia:
        print("  ! " + ostrzezenie)

    if args.uprawy_csv:
        args.uprawy_csv.parent.mkdir(parents=True, exist_ok=True)
        args.uprawy_csv.write_text(
            "\n".join(wniosek.uprawy) + "\n", encoding="utf-8"
        )
        print(f"Nazwy upraw zapisane do {args.uprawy_csv}")
    return 0 if kontrola.wynik_pewny else 1


if __name__ == "__main__":
    raise SystemExit(main())
