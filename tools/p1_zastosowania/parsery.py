"""Odczyt pól tekstowych z rejestru zastosowań środków ochrony roślin.

Każda funkcja zwraca też informację o pewności odczytu. Gdy odczyt jest
niepewny, zwracamy wartość pustą i znacznik „do_sprawdzenia" — nigdy wartości
przybliżonej (zasada z CLAUDE.md: nie zgadujemy dawek).
"""

from __future__ import annotations

import re
import unicodedata
from dataclasses import dataclass, field

# ──────────────────────────────────────────────────────────────────────────
# Dawka
# ──────────────────────────────────────────────────────────────────────────

#: Jednostki ilości środka spotykane w rejestrze.
JEDNOSTKI = r"l|ml|kg|g|mg|dm3|szt\.?|sztuk"

#: Do czego odniesiona jest dawka (powierzchnia, masa, pojedyncza roślina…).
ODNIESIENIA = (
    r"ha|kg\s+ziarna|kg\s+nasion|kg\s+bulw|kg|t|m2|m²|m3|m³|ar|l\s+wody|"
    r"litrów\s+wody|drzewo|drzewa|krzew|roślinę|rośliny|roślina|rodzinę|ul|"
    r"tonę|tony|sztukę"
)

#: Artefakty po znakach końca wiersza, zostawiane przez Excel w komórkach.
_SMIECI = re.compile(r"_x[0-9A-Fa-f]{4}_")

_LICZBA = r"\d+(?:[.,]\d+)?"

_DAWKA = re.compile(
    rf"(?P<od>{_LICZBA})\s*(?:[-–—]\s*(?P<do>{_LICZBA})\s*)?"
    rf"(?P<jednostka>{JEDNOSTKI})\s*(?:środka\s*)?/\s*"
    rf"(?P<mnoznik>{_LICZBA}\s*)?(?P<odniesienie>{ODNIESIENIA})(?![a-ząćęłńóśźż])",
    re.IGNORECASE,
)

_STEZENIE = re.compile(rf"(?P<od>{_LICZBA})\s*%")


@dataclass(frozen=True)
class Dawka:
    """Dawka odczytana z opisu. ``wartosc`` to dawka maksymalna."""

    wartosc: float | None
    jednostka: str | None
    odniesienie: str | None
    pewnosc: str  # 'odczytana' | 'zakres' | 'do_sprawdzenia'
    tekst: str

    @property
    def znana(self) -> bool:
        return self.wartosc is not None


def _na_liczbe(tekst: str) -> float:
    return float(tekst.replace(",", "."))


def odczytaj_dawke(tekst: str | None) -> Dawka:
    """Wyciąga dawkę maksymalną z opisu w rodzaju
    „Maksymalna/zalecana dawka dla jednorazowego zastosowania: 0,14 kg/ha."
    """
    surowy = _SMIECI.sub(" ", tekst or "").strip()
    if not surowy:
        return Dawka(None, None, None, "do_sprawdzenia", "")

    dopasowanie = _DAWKA.search(surowy)
    if dopasowanie:
        od = _na_liczbe(dopasowanie.group("od"))
        gorna = dopasowanie.group("do")
        jednostka = dopasowanie.group("jednostka").lower().rstrip(".")
        odniesienie = re.sub(r"\s+", " ", dopasowanie.group("odniesienie").lower())
        mnoznik = (dopasowanie.group("mnoznik") or "").strip()
        if mnoznik:
            # „20 g/10 m2" — odniesienie zapisujemy dosłownie, bez przeliczania.
            odniesienie = f"{mnoznik} {odniesienie}"
        if gorna:
            # Zakres „0,1–0,2 l/ha": dawką maksymalną jest górna granica.
            return Dawka(_na_liczbe(gorna), jednostka, odniesienie, "zakres", surowy)
        return Dawka(od, jednostka, odniesienie, "odczytana", surowy)

    stezenie = _STEZENIE.search(surowy)
    if stezenie:
        return Dawka(_na_liczbe(stezenie.group("od")), "%", "stezenie", "odczytana", surowy)

    return Dawka(None, None, None, "do_sprawdzenia", surowy)


# ──────────────────────────────────────────────────────────────────────────
# Faza wzrostu (BBCH)
# ──────────────────────────────────────────────────────────────────────────

_BBCH = re.compile(r"BBCH\s*(\d{1,2})(?:\s*[-–—]\s*(\d{1,2}))?", re.IGNORECASE)


def odczytaj_bbch(tekst: str | None) -> tuple[int | None, int | None]:
    """Zwraca zakres faz BBCH z opisu terminu zabiegu.

    Bierzemy najmniejszą i największą fazę wymienioną w opisie — opis potrafi
    wymieniać kilka zakresów dla różnych sytuacji.
    """
    surowy = tekst or ""
    fazy: list[int] = []
    for dopasowanie in _BBCH.finditer(surowy):
        fazy.append(int(dopasowanie.group(1)))
        if dopasowanie.group(2):
            fazy.append(int(dopasowanie.group(2)))
    if not fazy:
        return None, None
    return min(fazy), max(fazy)


# ──────────────────────────────────────────────────────────────────────────
# Lista upraw
# ──────────────────────────────────────────────────────────────────────────

@dataclass
class Uprawy:
    """Wynik rozbicia komórki „uprawa" na pojedyncze pozycje."""

    rozpoznane: list[str] = field(default_factory=list)
    do_sprawdzenia: list[str] = field(default_factory=list)

    @property
    def wszystkie(self) -> list[str]:
        return self.rozpoznane + self.do_sprawdzenia


def znormalizuj(nazwa: str) -> str:
    """Postać porównawcza nazwy: małe litery, bez ogonków i podwójnych spacji."""
    bez_ogonkow = unicodedata.normalize("NFKD", nazwa.lower())
    bez_ogonkow = "".join(z for z in bez_ogonkow if not unicodedata.combining(z))
    return re.sub(r"\s+", " ", bez_ogonkow.replace("ł", "l")).strip()


def rozbij_uprawy(komorka: str | None, slownik: set[str]) -> Uprawy:
    """Rozbija „oberżyna, ogórek, papryka, uprawa w szklarni" na pozycje.

    Nazwy ze słownika mogą same zawierać przecinek (np. „odnowienia,
    zalesienia"), więc dopasowujemy zachłannie od najdłuższego ciągu.
    Fragment spoza słownika trafia do „do_sprawdzenia" — nie zgadujemy.
    """
    wynik = Uprawy()
    surowy = (komorka or "").strip()
    if not surowy:
        return wynik

    wzorce = {znormalizuj(n): n for n in slownik}
    czesci = [c.strip() for c in surowy.split(",") if c.strip()]

    i = 0
    while i < len(czesci):
        dopasowano = False
        # Najpierw próbujemy najdłuższego połączenia sąsiednich fragmentów.
        for dlugosc in range(min(3, len(czesci) - i), 0, -1):
            kandydat = ", ".join(czesci[i : i + dlugosc])
            nazwa = wzorce.get(znormalizuj(kandydat))
            if nazwa is not None:
                wynik.rozpoznane.append(nazwa)
                i += dlugosc
                dopasowano = True
                break
        if not dopasowano:
            wynik.do_sprawdzenia.append(czesci[i])
            i += 1
    return wynik
