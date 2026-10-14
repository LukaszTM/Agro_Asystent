"""Spis „środek → najnowsza etykieta" z alfabetycznej podstrony gov.pl.

Przy każdym środku strona wymienia kilka dokumentów (etykieta, zezwolenie,
decyzje, postanowienia). Bierzemy wyłącznie etykiety — rozpoznajemy je po
tytule „<nazwa środka> - ET DD-MM-YYYY" — i z nich najnowszą.
"""

from __future__ import annotations

import datetime as dt
import html
import re
from dataclasses import dataclass

#: Odnośnik do pliku w sekcji „Materiały".
_ZALACZNIK = re.compile(
    r'<a class="file-download" href="(?P<adres>/attachment/[^"]+)"[^>]*'
    r'aria-label="\s*Pobierz plik (?P<tytul>.*?)\s*Rozmiar:\s*(?P<rozmiar>[\d.]+)MB',
    re.DOTALL,
)

#: Tytuł etykiety: nazwa środka, myślnik, „ET" i data wydania.
_TYTUL_ETYKIETY = re.compile(r"^(?P<nazwa>.+?)\s*-\s*ET\s*(?P<data>\d{2}-\d{2}-\d{4})$")

PODSTRONY = [
    "a-b1", "c-d1", "e-f1", "g-h1", "i-j1", "k-l1",
    "m-n1", "o-p1", "q-r1", "s-t1", "u-v1", "y-z1",
]


@dataclass(frozen=True)
class Etykieta:
    nazwa_srodka: str
    data_etykiety: dt.date
    adres: str
    rozmiar_mb: float

    @property
    def nazwa_pliku(self) -> str:
        bezpieczna = re.sub(r"[^\w.-]+", "_", self.nazwa_srodka).strip("_")
        return f"{bezpieczna}__{self.data_etykiety.isoformat()}.pdf"


def adres_podstrony(litery: str) -> str:
    return f"https://www.gov.pl/web/rolnictwo/{litery}"


def zbierz_etykiety(tresc_html: str) -> list[Etykieta]:
    """Zwraca po jednej, najnowszej etykiecie na środek."""
    najnowsze: dict[str, Etykieta] = {}
    for dopasowanie in _ZALACZNIK.finditer(tresc_html):
        tytul = html.unescape(re.sub(r"\s+", " ", dopasowanie.group("tytul"))).strip()
        rozpoznany = _TYTUL_ETYKIETY.match(tytul)
        if not rozpoznany:
            continue  # zezwolenie, decyzja, postanowienie — nie etykieta
        dzien, miesiac, rok = rozpoznany.group("data").split("-")
        etykieta = Etykieta(
            nazwa_srodka=rozpoznany.group("nazwa").strip(),
            data_etykiety=dt.date(int(rok), int(miesiac), int(dzien)),
            adres="https://www.gov.pl" + dopasowanie.group("adres"),
            rozmiar_mb=float(dopasowanie.group("rozmiar")),
        )
        poprzednia = najnowsze.get(etykieta.nazwa_srodka)
        if poprzednia is None or etykieta.data_etykiety > poprzednia.data_etykiety:
            najnowsze[etykieta.nazwa_srodka] = etykieta
    return sorted(najnowsze.values(), key=lambda e: e.nazwa_srodka.lower())


def policz_dokumenty(tresc_html: str) -> dict[str, int]:
    """Ile na stronie jest etykiet, a ile innych dokumentów — do raportu."""
    liczby = {"etykieta": 0, "zezwolenie": 0, "decyzja": 0, "inne": 0}
    for dopasowanie in _ZALACZNIK.finditer(tresc_html):
        tytul = html.unescape(re.sub(r"\s+", " ", dopasowanie.group("tytul"))).strip()
        maly = tytul.lower()
        if _TYTUL_ETYKIETY.match(tytul):
            liczby["etykieta"] += 1
        elif "zezw" in maly or "pozwolenie" in maly:
            liczby["zezwolenie"] += 1
        elif "dec" in maly or "odnowienie" in maly or "postanowienie" in maly:
            liczby["decyzja"] += 1
        else:
            liczby["inne"] += 1
    return liczby
