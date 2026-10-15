"""Wytwarza zanonimizowany wzorzec wniosku o płatności (zadanie P4).

Prawdziwy wniosek z eWniosekPlus zawiera dane osobowe i **nie może trafić do
repozytorium** (plan, pkt 11). Wzorzec odwzorowuje układ sprawdzony na
prawdziwym wniosku za 2026 r., ale wszystkie dane są zmyślone.

Odwzorowane cechy prawdziwego pliku:

- strona pozioma A4, nagłówki tabel rozbite na kilka wierszy,
- wiersz z numerami kolumn pod nagłówkiem (w tabeli X z kropkami, w XI bez),
- wartości wyśrodkowane w kolumnach tabeli X,
- identyfikator działki referencyjnej łamany na dwa wiersze,
- nazwa uprawy łamana na dwa wiersze,
- kilka działek ewidencyjnych pod jedną działką rolną (wiersze bez oznaczenia),
- stopka na każdej stronie,
- brak podsumowania powierzchni (wniosek go nie zawiera).
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from reportlab.lib.pagesizes import A4, landscape
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas as rl_canvas

SZEROKOSC, WYSOKOSC = landscape(A4)
MARGINES = 18
WIERSZ = 11

KROJ = "DejaVuSans"
PLIK_KROJU = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"

#: Środki kolumn tabeli X — jak w prawdziwym wniosku.
SRODKI_X = [22, 92, 203, 316, 415, 503, 590, 677, 778]
NAGLOWKI_X = ["Lp.", "województwo", "powiat", "gmina", "nazwa obrębu",
              "nr obrębu", "nr arkusza", "nr działki", "powierzchnia [ha]"]

#: Lewe krawędzie wartości w tabeli XI oraz środki kolumn numeracji.
X_OZNACZENIE, X_UPRAWA, X_HA, X_AR = 36, 105, 171, 205
X_IDENTYFIKATOR, X_CZESC_HA, X_CZESC_AR, X_PLATNOSCI = 236, 328, 362, 443
SRODKI_XI = [37, 112, 190, 269, 347, 465, 587, 667, 748, 809]

STOPKA = "000000000-PLA-26-0001 Status wniosku: Roboczy"


@dataclass(frozen=True)
class DzialkaEwidencyjna:
    lp: int
    wojewodztwo: str
    powiat: str
    gmina: str
    obreb: str
    nr_obrebu: str
    arkusz: str
    nr_dzialki: str
    powierzchnia_ha: float

    @property
    def identyfikator(self) -> str:
        return f"140100_2.{self.nr_obrebu}.{self.nr_dzialki}"


@dataclass(frozen=True)
class Czesc:
    identyfikator: str
    ha: int
    ar: int


@dataclass(frozen=True)
class DzialkaRolna:
    oznaczenie: str
    uprawa: str
    ha: int
    ar: int
    czesci: tuple[Czesc, ...]
    platnosci: str


def przykladowe_dane() -> tuple[list[DzialkaEwidencyjna], list[DzialkaRolna]]:
    """Dane zmyślone, liczbowo zgodne z opisem z planu:
    20 działek ewidencyjnych, 34 działki rolne, 28,91 ha."""
    obreby = ["PRZYKŁADOWO", "TESTOWA WOLA", "POLE GÓRNE", "ZAGRODY"]
    ewidencyjne = [
        DzialkaEwidencyjna(
            lp=numer + 1,
            wojewodztwo="testowe",
            powiat="testowy",
            gmina="Nowa Testowa",
            obreb=obreby[numer % 4],
            nr_obrebu=f"{(numer % 4) + 1:04d}",
            arkusz="",
            nr_dzialki=f"{100 + numer * 7}" + ("/2" if numer % 3 == 0 else ""),
            powierzchnia_ha=round(0.9 + (numer % 9) * 0.23, 2),
        )
        for numer in range(20)
    ]

    uprawy = ["TUZ", "pszenica zwyczajna ozima", "kukurydza na ziarno",
              "owies zwyczajny", "jęczmień ozimy", "Sad", "ziemniak",
              "trawy wieloletnie na gruntach ornych"]
    platnosci = ["ONW, PWD", "ONW, PWD, UPP", "PWD"]
    oznaczenia = [chr(65 + i) for i in range(26)] + [f"A{chr(65 + i)}" for i in range(8)]

    rolne: list[DzialkaRolna] = []
    pozostalo_ar = 2891
    for numer, oznaczenie in enumerate(oznaczenia):
        ostatnia = numer == len(oznaczenia) - 1
        ar_razem = (
            pozostalo_ar
            if ostatnia
            else min(pozostalo_ar - (len(oznaczenia) - numer - 1), 60 + numer * 3)
        )
        pozostalo_ar -= ar_razem
        # Co siódma działka rolna leży na trzech działkach ewidencyjnych.
        ile_czesci = 3 if numer % 7 == 3 else 1
        czesci: list[Czesc] = []
        zostalo = ar_razem
        for kolejna in range(ile_czesci):
            udzial = zostalo if kolejna == ile_czesci - 1 else zostalo // ile_czesci
            zostalo -= udzial
            czesci.append(
                Czesc(
                    identyfikator=ewidencyjne[(numer + kolejna) % 20].identyfikator,
                    ha=udzial // 100,
                    ar=udzial % 100,
                )
            )
        rolne.append(
            DzialkaRolna(
                oznaczenie=oznaczenie,
                uprawa=uprawy[numer % len(uprawy)],
                ha=ar_razem // 100,
                ar=ar_razem % 100,
                czesci=tuple(czesci),
                platnosci=platnosci[numer % len(platnosci)],
            )
        )
    return ewidencyjne, rolne


class Rysownik:
    def __init__(self, plik: Path) -> None:
        pdfmetrics.registerFont(TTFont(KROJ, PLIK_KROJU))
        self.canvas = rl_canvas.Canvas(str(plik), pagesize=landscape(A4))
        self.y = WYSOKOSC - MARGINES
        self.strona = 1
        self.stron_razem = 9

    def stopka(self) -> None:
        self.canvas.setFont(KROJ, 6)
        self.canvas.drawString(5, 6, f"{STOPKA} {self.strona}/{self.stron_razem}")
        self.canvas.setFont(KROJ, 6)
        self.canvas.drawRightString(
            SZEROKOSC - 5, 6, "WZORZEC TESTOWY — DANE ZMYŚLONE"
        )

    def nowa_strona(self) -> None:
        self.stopka()
        self.canvas.showPage()
        self.strona += 1
        self.y = WYSOKOSC - MARGINES

    def miejsce(self, wierszy: int = 1) -> bool:
        if self.y - wierszy * WIERSZ < MARGINES + 20:
            self.nowa_strona()
            return True
        return False

    def wiersz(self, kolumny: list[tuple[float, str]], rozmiar: float = 7,
               srodkiem: bool = False) -> None:
        self.miejsce()
        self.canvas.setFont(KROJ, rozmiar)
        for x, wartosc in kolumny:
            if srodkiem:
                self.canvas.drawCentredString(x, self.y, wartosc)
            else:
                self.canvas.drawString(x, self.y, wartosc)
        self.y -= WIERSZ

    def tytul(self, tekst: str) -> None:
        self.miejsce(3)
        self.canvas.setFont(KROJ, 9)
        self.canvas.drawString(14, self.y, tekst)
        self.y -= WIERSZ * 1.6

    def zapisz(self) -> None:
        self.stopka()
        self.canvas.save()


def zbuduj(plik: Path) -> tuple[list[DzialkaEwidencyjna], list[DzialkaRolna]]:
    ewidencyjne, rolne = przykladowe_dane()
    r = Rysownik(plik)

    r.tytul("WNIOSEK O PRZYZNANIE PŁATNOŚCI NA ROK 2026")
    r.wiersz([(14, "Numer identyfikacyjny: 000000000")])
    r.wiersz([(14, "Nazwisko i imię: dane zmyślone, nie dotyczą żadnej osoby")])

    # ── tabela X ──
    r.tytul("X. OŚWIADCZENIE O DZIAŁKACH REFERENCYJNYCH")
    r.wiersz([(SRODKI_X[1], "Położenie działki referencyjnej:"),
              (SRODKI_X[5], "Dane według ewidencji gruntów i budynków:")], rozmiar=6)
    r.wiersz(list(zip(SRODKI_X, NAGLOWKI_X)), rozmiar=6, srodkiem=True)
    r.wiersz([(x, f"{numer}.") for numer, x in enumerate(SRODKI_X, 1)],
             rozmiar=6, srodkiem=True)
    for dzialka in ewidencyjne:
        r.wiersz(
            list(
                zip(
                    SRODKI_X,
                    [
                        str(dzialka.lp),
                        dzialka.wojewodztwo,
                        dzialka.powiat,
                        dzialka.gmina,
                        dzialka.obreb,
                        dzialka.nr_obrebu,
                        dzialka.arkusz,
                        dzialka.nr_dzialki,
                        f"{dzialka.powierzchnia_ha:.2f}",
                    ],
                )
            ),
            srodkiem=True,
        )

    # ── tabela XI ──
    r.tytul("XI. OŚWIADCZENIE O ZADEKLAROWANYCH POWIERZCHNIACH")
    r.wiersz([(X_OZNACZENIE, "Oznaczenie"), (X_UPRAWA, "Uprawa"),
              (X_HA, "Wielkość zadeklarowanej"), (X_IDENTYFIKATOR, "Nr działki"),
              (X_CZESC_HA, "Wielkość zadeklarowanej"),
              (X_PLATNOSCI, "Interwencje, płatności")], rozmiar=6)
    r.wiersz([(X_OZNACZENIE, "działki"), (X_HA, "powierzchni"),
              (X_IDENTYFIKATOR, "referencyjnej"),
              (X_CZESC_HA, "powierzchni w granicach")], rozmiar=6)
    r.wiersz([(X_HA, "ha"), (X_AR, "a"), (X_CZESC_HA, "ha"), (X_CZESC_AR, "a")],
             rozmiar=6)
    numeracja = [(x, str(numer)) for numer, x in enumerate(SRODKI_XI, 1)]
    r.wiersz(numeracja, rozmiar=6, srodkiem=True)

    def numeracja_po_zmianie_strony() -> None:
        if r.y > WYSOKOSC - MARGINES - WIERSZ * 2:  # właśnie zaczęła się strona
            r.wiersz(numeracja, rozmiar=6, srodkiem=True)

    for dzialka in rolne:
        czlony = dzialka.uprawa.split()
        pierwszy_czlon = czlony[0]
        reszta_nazwy = " ".join(czlony[1:])
        glowa, _, ogon = dzialka.czesci[0].identyfikator.rpartition(".")

        numeracja_po_zmianie_strony()
        r.wiersz([
            (X_OZNACZENIE, dzialka.oznaczenie),
            (X_UPRAWA, pierwszy_czlon),
            (X_HA, str(dzialka.ha)),
            (X_AR, f"{dzialka.ar:02d}"),
            (X_IDENTYFIKATOR, glowa),
            (X_CZESC_HA, str(dzialka.czesci[0].ha)),
            (X_CZESC_AR, f"{dzialka.czesci[0].ar:02d}"),
            (X_PLATNOSCI, dzialka.platnosci),
        ])
        # Ogon identyfikatora (i ewentualnie reszta nazwy uprawy) w następnym wierszu.
        dalszy: list[tuple[float, str]] = [(X_IDENTYFIKATOR + 25, f".{ogon}")]
        if reszta_nazwy:
            dalszy.insert(0, (X_UPRAWA - 14, reszta_nazwy))
        r.wiersz(dalszy)

        for czesc in dzialka.czesci[1:]:
            glowa, _, ogon = czesc.identyfikator.rpartition(".")
            numeracja_po_zmianie_strony()
            r.wiersz([
                (X_IDENTYFIKATOR, glowa),
                (X_CZESC_HA, str(czesc.ha)),
                (X_CZESC_AR, f"{czesc.ar:02d}"),
                (X_PLATNOSCI, dzialka.platnosci),
            ])
            r.wiersz([(X_IDENTYFIKATOR + 25, f".{ogon}")])

    r.zapisz()
    return ewidencyjne, rolne


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plik", type=Path, default=Path("test/dane/wzorzec_wniosku.pdf"))
    args = parser.parse_args(argv)
    args.plik.parent.mkdir(parents=True, exist_ok=True)
    ewidencyjne, rolne = zbuduj(args.plik)
    suma_ar = sum(d.ha * 100 + d.ar for d in rolne)
    print(f"Zapisano {args.plik}")
    print(f"  działek ewidencyjnych: {len(ewidencyjne)}")
    print(f"  działek rolnych:       {len(rolne)}")
    print(f"  powierzchnia razem:    {suma_ar // 100},{suma_ar % 100:02d} ha")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
