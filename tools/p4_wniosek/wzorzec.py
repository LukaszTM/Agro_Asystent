"""Wytwarza zanonimizowany wzorzec wniosku o płatności (zadanie P4).

Prawdziwy wniosek z eWniosekPlus zawiera dane osobowe i **nie może trafić do
repozytorium** (plan, pkt 11). Do testów czytnika służy ten wzorzec: układ
tabel X i XI odwzorowany według opisu z planu (pkt 6.2), ale wszystkie dane
są zmyślone — nazwiska, numery działek i powierzchnie nie należą do nikogo.

Wzorzec celowo odtwarza pułapki prawdziwego wniosku:

- nazwa uprawy i identyfikator działki łamią się na kilka wierszy,
- jedna działka rolna leży na kilku działkach ewidencyjnych
  (kolejne wiersze bez oznaczenia),
- tabela przechodzi przez strony z powtórzonym nagłówkiem,
- podsumowanie powierzchni na końcu.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.pdfgen import canvas as rl_canvas

SZEROKOSC, WYSOKOSC = A4
MARGINES = 36
WIERSZ = 13

KROJ = "DejaVuSans"
PLIK_KROJU = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


@dataclass(frozen=True)
class DzialkaEwidencyjna:
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
        arkusz = f"AR_{self.arkusz}." if self.arkusz else ""
        return f"{self.nr_obrebu}.{arkusz}{self.nr_dzialki}"


@dataclass(frozen=True)
class DzialkaRolna:
    oznaczenie: str
    uprawa: str
    ha: int
    ar: int
    identyfikatory: tuple[str, ...]
    platnosci: str


def przykladowe_dzialki() -> tuple[list[DzialkaEwidencyjna], list[DzialkaRolna]]:
    """Dane zmyślone, dobrane tak, by liczby zgadzały się z planem:
    20 działek ewidencyjnych, 34 działki rolne, razem 28,91 ha."""
    gminy = [("MAZOWIECKIE", "siedlecki", "Mokobody"), ("MAZOWIECKIE", "siedlecki", "Suchożebry")]
    obreby = ["Kolonia Wschodnia", "Zawady Dolne", "Pole za Lasem", "Nowa Wieś"]

    ewidencyjne: list[DzialkaEwidencyjna] = []
    for numer in range(20):
        woj, pow, gm = gminy[numer % 2]
        ewidencyjne.append(
            DzialkaEwidencyjna(
                wojewodztwo=woj,
                powiat=pow,
                gmina=gm,
                obreb=obreby[numer % 4],
                nr_obrebu=f"140100_2.{(numer % 4) + 1:04d}",
                arkusz=str((numer % 3) + 1) if numer % 2 == 0 else "",
                nr_dzialki=f"{100 + numer * 7}/{(numer % 5) + 1}",
                powierzchnia_ha=round(0.84 + (numer % 9) * 0.21, 2),
            )
        )

    uprawy = [
        "pszenica ozima",
        "kukurydza na ziarno",
        "rzepak ozimy",
        "jęczmień jary",
        "owies zwyczajny",
        "mieszanka zbożowo-strączkowa na nasiona z przeznaczeniem na paszę",
        "łąki trwałe",
        "ziemniak",
    ]
    platnosci = ["PB, ONW", "PB", "PB, ONW, E_MPW", "PB, E_MPW"]

    oznaczenia = [chr(65 + i) for i in range(26)] + [f"A{chr(65 + i)}" for i in range(8)]
    rolne: list[DzialkaRolna] = []
    pozostalo_ar = 2891  # 28,91 ha w arach
    for numer, oznaczenie in enumerate(oznaczenia):
        ostatnia = numer == len(oznaczenia) - 1
        ar_razem = pozostalo_ar if ostatnia else min(pozostalo_ar - (len(oznaczenia) - numer - 1), 60 + numer * 3)
        pozostalo_ar -= ar_razem
        # Co siódma działka rolna leży na dwóch działkach ewidencyjnych.
        ile_ewid = 2 if numer % 7 == 3 else 1
        identyfikatory = tuple(
            ewidencyjne[(numer + przesuniecie) % len(ewidencyjne)].identyfikator
            for przesuniecie in range(ile_ewid)
        )
        rolne.append(
            DzialkaRolna(
                oznaczenie=oznaczenie,
                uprawa=uprawy[numer % len(uprawy)],
                ha=ar_razem // 100,
                ar=ar_razem % 100,
                identyfikatory=identyfikatory,
                platnosci=platnosci[numer % len(platnosci)],
            )
        )
    return ewidencyjne, rolne


class Rysownik:
    """Prosty rysownik tekstu z łamaniem kolumn, naśladujący wygląd wniosku."""

    def __init__(self, plik: Path) -> None:
        pdfmetrics.registerFont(TTFont(KROJ, PLIK_KROJU))
        self.canvas = rl_canvas.Canvas(str(plik), pagesize=A4)
        self.y = WYSOKOSC - MARGINES
        self.strona = 1

    def naglowek_strony(self) -> None:
        self.canvas.setFont(KROJ, 7)
        self.canvas.drawString(MARGINES, WYSOKOSC - 20, "WZORZEC TESTOWY — DANE ZMYŚLONE, NIE DOTYCZĄ ŻADNEGO GOSPODARSTWA")
        self.canvas.drawRightString(SZEROKOSC - MARGINES, WYSOKOSC - 20, f"strona {self.strona}")

    def nowa_strona(self) -> None:
        self.canvas.showPage()
        self.strona += 1
        self.y = WYSOKOSC - MARGINES
        self.naglowek_strony()

    def miejsce(self, wierszy: int = 1) -> None:
        if self.y - wierszy * WIERSZ < MARGINES + 40:
            self.nowa_strona()

    def tekst(self, kolumny: list[tuple[float, str]], rozmiar: int = 7, pogrubienie: bool = False) -> None:
        self.miejsce()
        self.canvas.setFont(KROJ, rozmiar)
        for x, wartosc in kolumny:
            self.canvas.drawString(MARGINES + x, self.y, wartosc)
        self.y -= WIERSZ

    def tytul(self, tekst: str) -> None:
        self.miejsce(3)
        self.y -= WIERSZ
        self.canvas.setFont(KROJ, 10)
        self.canvas.drawString(MARGINES, self.y, tekst)
        self.y -= WIERSZ * 1.5

    def zapisz(self) -> None:
        self.canvas.save()


KOLUMNY_X = [0, 75, 130, 190, 290, 360, 412, 478]
NAGLOWEK_X = ["Województwo", "Powiat", "Gmina", "Nazwa obrębu", "Nr obrębu", "Nr arkusza", "Nr działki", "Powierzchnia [ha]"]

KOLUMNY_XI = [0, 48, 268, 294, 325, 452]
NAGLOWEK_XI = ["Oznaczenie", "Uprawa", "ha", "a", "Identyfikator działki", "Płatności"]


def _lamanie(tekst: str, ile_znakow: int) -> list[str]:
    """Dzieli tekst na wiersze — tak jak robi to generator wniosku."""
    slowa = tekst.split()
    wiersze: list[str] = [""]
    for slowo in slowa:
        if len(wiersze[-1]) + len(slowo) + 1 > ile_znakow and wiersze[-1]:
            wiersze.append(slowo)
        else:
            wiersze[-1] = f"{wiersze[-1]} {slowo}".strip()
    return wiersze


def zbuduj(plik: Path) -> tuple[list[DzialkaEwidencyjna], list[DzialkaRolna]]:
    ewidencyjne, rolne = przykladowe_dzialki()
    rysownik = Rysownik(plik)
    rysownik.naglowek_strony()
    rysownik.tytul("WNIOSEK O PRZYZNANIE PŁATNOŚCI NA ROK 2026")
    rysownik.tekst([(0, "Numer identyfikacyjny producenta: 000000000")])
    rysownik.tekst([(0, "Nazwisko i imię: JAN PRZYKŁADOWY (dane zmyślone)")])

    rysownik.tytul("X. OŚWIADCZENIE O DZIAŁKACH REFERENCYJNYCH")
    rysownik.tekst(list(zip(KOLUMNY_X, NAGLOWEK_X)), rozmiar=7)
    for dzialka in ewidencyjne:
        rysownik.tekst(
            list(
                zip(
                    KOLUMNY_X,
                    [
                        dzialka.wojewodztwo,
                        dzialka.powiat,
                        dzialka.gmina,
                        dzialka.obreb,
                        dzialka.nr_obrebu,
                        dzialka.arkusz,
                        dzialka.nr_dzialki,
                        f"{dzialka.powierzchnia_ha:.2f}".replace(".", ","),
                    ],
                )
            )
        )
    suma_ewid = sum(d.powierzchnia_ha for d in ewidencyjne)
    rysownik.tekst([(0, "Razem działek referencyjnych:"), (412, str(len(ewidencyjne))),
                    (478, f"{suma_ewid:.2f}".replace(".", ","))])

    rysownik.tytul("XI. OŚWIADCZENIE O ZADEKLAROWANYCH POWIERZCHNIACH")
    rysownik.tekst(list(zip(KOLUMNY_XI, NAGLOWEK_XI)), rozmiar=7)
    for dzialka in rolne:
        wiersze_uprawy = _lamanie(dzialka.uprawa, 46)
        pierwszy = [
            (KOLUMNY_XI[0], dzialka.oznaczenie),
            (KOLUMNY_XI[1], wiersze_uprawy[0]),
            (KOLUMNY_XI[2], str(dzialka.ha)),
            (KOLUMNY_XI[3], f"{dzialka.ar:02d}"),
            (KOLUMNY_XI[4], dzialka.identyfikatory[0]),
            (KOLUMNY_XI[5], dzialka.platnosci),
        ]
        rysownik.tekst(pierwszy)
        # Dalsze wiersze nazwy uprawy — bez oznaczenia i bez powierzchni.
        for dalszy in wiersze_uprawy[1:]:
            rysownik.tekst([(KOLUMNY_XI[1], dalszy)])
        # Kolejne działki ewidencyjne tej samej działki rolnej.
        for identyfikator in dzialka.identyfikatory[1:]:
            rysownik.tekst([(KOLUMNY_XI[4], identyfikator)])

    suma_ar = sum(d.ha * 100 + d.ar for d in rolne)
    rysownik.tekst([(0, "Razem działek rolnych:"), (KOLUMNY_XI[2], str(len(rolne)))])
    rysownik.tekst([(0, "Razem powierzchnia:"),
                    (KOLUMNY_XI[2], f"{suma_ar // 100},{suma_ar % 100:02d} ha")])
    rysownik.zapisz()
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
