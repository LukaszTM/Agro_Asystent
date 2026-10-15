"""Czytnik wniosku o płatności z eWniosekPlus: tabele X i XI (zadanie P4).

Układ sprawdzony na prawdziwym wniosku za 2026 r. (strona pozioma, 31 stron):

- **X. Oświadczenie o działkach referencyjnych** — pod nagłówkiem jest wiersz
  z numerami kolumn („1. 2. 3. …"), a wartości są wyśrodkowane w kolumnach;
  po tym wierszu rozpoznajemy kolumny.
- **XI. Oświadczenie o zadeklarowanych powierzchniach** — tam numeracja kolumn
  nie pokrywa się z położeniem wartości, więc wiersz rozbieramy po wzorcu
  identyfikatora działki referencyjnej: przed nim stoją uprawa i powierzchnia
  zadeklarowana, po nim powierzchnia w granicach działki i płatności.

Pułapki, które czytnik obsługuje: identyfikator działki łamany na dwa wiersze,
nazwa uprawy łamana na dwa wiersze, kilka działek ewidencyjnych pod jedną
działką rolną (wiersze bez oznaczenia), tabela przechodząca przez strony
z powtórzonym nagłówkiem oraz stopki stron.

Wniosek nie zawiera podsumowania powierzchni, więc poprawność sprawdzamy
wewnętrznie: suma powierzchni w granicach działek referencyjnych musi się
zgadzać z powierzchnią zadeklarowaną, a każdy identyfikator z tabeli XI musi
występować w tabeli X.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass, field
from pathlib import Path

import pdfplumber

NAGLOWEK_X = "OŚWIADCZENIE O DZIAŁKACH REFERENCYJNYCH"
NAGLOWEK_XI = "OŚWIADCZENIE O ZADEKLAROWANYCH POWIERZCHNIACH"

#: Kolumny tabeli X w kolejności numeracji ze wniosku.
KOLUMNY_X = ["lp", "wojewodztwo", "powiat", "gmina", "obreb", "nr_obrebu",
             "arkusz", "nr_dzialki", "powierzchnia"]

_OZNACZENIE = re.compile(r"^[A-Z]{1,2}$")
_IDENTYFIKATOR_GLOWA = re.compile(r"^\d{6}_\d\.\d{4}$")
_IDENTYFIKATOR_OGON = re.compile(r"^\.(?:AR_\d+\.)?\d+(?:/\d+)?$")
_CALKOWITA = re.compile(r"^\d{1,4}$")
_DZIESIETNA = re.compile(r"^\d+[.,]\d+$")
_NUMER_KOLUMNY = re.compile(r"^(\d{1,2})\.?$")


@dataclass
class DzialkaEwidencyjna:
    lp: str = ""
    wojewodztwo: str = ""
    powiat: str = ""
    gmina: str = ""
    obreb: str = ""
    nr_obrebu: str = ""
    arkusz: str = ""
    nr_dzialki: str = ""
    powierzchnia_ha: float | None = None

    @property
    def identyfikator(self) -> str:
        arkusz = f"AR_{self.arkusz}." if self.arkusz else ""
        return f"{self.nr_obrebu}.{arkusz}{self.nr_dzialki}"


@dataclass
class CzescDzialkiRolnej:
    """Część działki rolnej leżąca na jednej działce ewidencyjnej."""

    identyfikator: str = ""
    ha: int = 0
    ar: int = 0

    @property
    def powierzchnia_ar(self) -> int:
        return self.ha * 100 + self.ar


@dataclass
class DzialkaRolna:
    oznaczenie: str = ""
    uprawa: str = ""
    ha: int = 0
    ar: int = 0
    czesci: list[CzescDzialkiRolnej] = field(default_factory=list)
    platnosci: str = ""

    @property
    def powierzchnia_ar(self) -> int:
        return self.ha * 100 + self.ar

    @property
    def identyfikatory(self) -> list[str]:
        return [c.identyfikator for c in self.czesci if c.identyfikator]


@dataclass
class Kontrola:
    suma_z_odczytu_ar: int = 0
    suma_z_wniosku_ar: int | None = None
    liczba_dzialek_rolnych: int = 0
    liczba_z_wniosku: int | None = None
    wiersze_pominiete: int = 0
    przyklady_pominietych: list[str] = field(default_factory=list)
    ostrzezenia: list[str] = field(default_factory=list)

    @property
    def suma_zgodna(self) -> bool:
        return (
            self.suma_z_wniosku_ar is None
            or self.suma_z_odczytu_ar == self.suma_z_wniosku_ar
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
        return sorted({oczysc_uprawe(d.uprawa) for d in self.dzialki_rolne if d.uprawa})


def oczysc_uprawe(nazwa: str) -> str:
    """Usuwa końcowy znak odsyłacza, którym wniosek znaczy niektóre uprawy
    („Uprawa mieszana_"). Reszty nazwy nie ruszamy."""
    return nazwa.rstrip("_ ").strip()


# ── wiersze i kolumny ─────────────────────────────────────────────────────

@dataclass
class Slowo:
    tekst: str
    x0: float
    x1: float

    @property
    def srodek(self) -> float:
        return (self.x0 + self.x1) / 2


#: Pas przy dolnej krawędzi strony zajęty przez stopkę („Status wniosku…",
#: numer strony). Nigdy nie ma tam danych, a bez odcięcia stopka wsiąkała
#: w nazwę uprawy ostatniej działki na stronie.
WYSOKOSC_STOPKI = 20


def wiersze_strony(strona) -> list[list[Slowo]]:
    """Grupuje słowa w wiersze po wysokości (tolerancja 2 punkty), bez stopki."""
    granica_stopki = float(strona.height) - WYSOKOSC_STOPKI
    wiersze: dict[int, list[Slowo]] = {}
    for slowo in strona.extract_words():
        if float(slowo["top"]) > granica_stopki:
            continue
        klucz = round(float(slowo["top"]) / 2)
        wiersze.setdefault(klucz, []).append(
            Slowo(slowo["text"], float(slowo["x0"]), float(slowo["x1"]))
        )
    return [sorted(w, key=lambda s: s.x0) for _, w in sorted(wiersze.items())]


def numeracja_kolumn(wiersz: list[Slowo]) -> list[float] | None:
    """Zwraca środki kolumn, jeśli wiersz jest numeracją „1. 2. 3. …"."""
    if len(wiersz) < 6:
        return None
    oczekiwany = 1
    srodki: list[float] = []
    for slowo in wiersz:
        dopasowanie = _NUMER_KOLUMNY.match(slowo.tekst)
        if not dopasowanie or int(dopasowanie.group(1)) != oczekiwany:
            return None
        srodki.append(slowo.srodek)
        oczekiwany += 1
    return srodki


def do_kolumn_srodkiem(wiersz: list[Slowo], srodki: list[float]) -> list[str]:
    """Przypisuje słowa do najbliższej kolumny — wartości są wyśrodkowane."""
    komorki = ["" for _ in srodki]
    for slowo in wiersz:
        numer = min(range(len(srodki)), key=lambda i: abs(srodki[i] - slowo.srodek))
        komorki[numer] = f"{komorki[numer]} {slowo.tekst}".strip()
    return komorki


def _liczba(tekst: str) -> float | None:
    tekst = tekst.strip().replace(" ", "").replace(",", ".")
    try:
        return float(tekst)
    except ValueError:
        return None


# ── tabela X ──────────────────────────────────────────────────────────────

def _dodaj_dzialke_ewidencyjna(komorki: list[str], wniosek: Wniosek) -> None:
    dane = dict(zip(KOLUMNY_X, komorki))
    powierzchnia = _liczba(dane.get("powierzchnia", ""))
    wniosek.dzialki_ewidencyjne.append(
        DzialkaEwidencyjna(
            lp=dane.get("lp", ""),
            wojewodztwo=dane.get("wojewodztwo", ""),
            powiat=dane.get("powiat", ""),
            gmina=dane.get("gmina", ""),
            obreb=dane.get("obreb", ""),
            nr_obrebu=dane.get("nr_obrebu", ""),
            arkusz=dane.get("arkusz", ""),
            nr_dzialki=dane.get("nr_dzialki", ""),
            powierzchnia_ha=powierzchnia,
        )
    )
    if powierzchnia is None:
        wniosek.kontrola.ostrzezenia.append(
            f"tabela X, pozycja {dane.get('lp', '?')}: nie odczytano powierzchni"
        )


# ── tabela XI ─────────────────────────────────────────────────────────────

def _rozbierz_wiersz_xi(tokeny: list[str]) -> dict | None:
    """Rozbiera wiersz tabeli XI wokół identyfikatora działki referencyjnej.

    Układ: [oznaczenie] uprawa… ha a IDENTYFIKATOR ha a płatności…
    """
    pozycja = next(
        (i for i, t in enumerate(tokeny) if _IDENTYFIKATOR_GLOWA.match(t)), None
    )
    if pozycja is None:
        return None

    przed = tokeny[:pozycja]
    po = tokeny[pozycja + 1 :]

    if not przed:
        # Wiersz kolejnej działki ewidencyjnej tej samej działki rolnej:
        # bez oznaczenia, bez nazwy uprawy i bez powierzchni zadeklarowanej.
        return {
            "identyfikator": tokeny[pozycja],
            "ha": None,
            "ar": None,
            "czesc_ha": int(po[0]) if po and _CALKOWITA.match(po[0]) else None,
            "czesc_ar": int(po[1]) if len(po) > 1 and _CALKOWITA.match(po[1]) else None,
            "platnosci": " ".join(po[2:]),
            "oznaczenie": "",
            "uprawa": "",
        }

    if len(przed) < 2 or not all(_CALKOWITA.match(t) for t in przed[-2:]):
        return None

    wynik = {
        "identyfikator": tokeny[pozycja],
        "ha": int(przed[-2]),
        "ar": int(przed[-1]),
        "czesc_ha": int(po[0]) if po and _CALKOWITA.match(po[0]) else None,
        "czesc_ar": int(po[1]) if len(po) > 1 and _CALKOWITA.match(po[1]) else None,
        "platnosci": " ".join(po[2:]),
    }
    reszta = przed[:-2]
    if reszta and _OZNACZENIE.match(reszta[0]):
        wynik["oznaczenie"] = reszta[0]
        wynik["uprawa"] = " ".join(reszta[1:])
    else:
        wynik["oznaczenie"] = ""
        wynik["uprawa"] = " ".join(reszta)
    return wynik


def _dodaj_do_xi(wiersz: list[Slowo], wniosek: Wniosek, x_identyfikatora: float | None) -> None:
    tokeny = [s.tekst for s in wiersz]
    rozebrany = _rozbierz_wiersz_xi(tokeny)

    if rozebrany is None:
        _ciag_dalszy_xi(wiersz, wniosek, x_identyfikatora)
        return

    czesc = CzescDzialkiRolnej(
        identyfikator=rozebrany["identyfikator"],
        ha=rozebrany["czesc_ha"] or 0,
        ar=rozebrany["czesc_ar"] or 0,
    )
    if rozebrany["ha"] is None and not rozebrany["oznaczenie"]:
        # Sam identyfikator z powierzchnią — kolejna część działki rolnej.
        if wniosek.dzialki_rolne:
            wniosek.dzialki_rolne[-1].czesci.append(czesc)
        else:
            _pomin(tokeny, wniosek)
        return

    if rozebrany["oznaczenie"]:
        wniosek.dzialki_rolne.append(
            DzialkaRolna(
                oznaczenie=rozebrany["oznaczenie"],
                uprawa=rozebrany["uprawa"],
                ha=rozebrany["ha"],
                ar=rozebrany["ar"],
                czesci=[czesc],
                platnosci=rozebrany["platnosci"],
            )
        )
    elif wniosek.dzialki_rolne:
        # Kolejna działka ewidencyjna tej samej działki rolnej.
        wniosek.dzialki_rolne[-1].czesci.append(czesc)
    else:
        _pomin(tokeny, wniosek)


def _ciag_dalszy_xi(
    wiersz: list[Slowo], wniosek: Wniosek, x_identyfikatora: float | None
) -> None:
    """Wiersz bez identyfikatora: dalszy ciąg nazwy uprawy albo ogon identyfikatora.

    O tym, czy fragment należy do nazwy uprawy, decyduje jego położenie na
    stronie — inaczej do nazwy uprawy wsiąkałyby kody płatności z prawej
    strony wiersza.
    """
    tokeny = [s.tekst for s in wiersz]
    if not wniosek.dzialki_rolne:
        _pomin(tokeny, wniosek)
        return

    dzialka = wniosek.dzialki_rolne[-1]
    uzyte = False
    for slowo in wiersz:
        token = slowo.tekst
        na_lewo_od_identyfikatora = (
            x_identyfikatora is None or slowo.x0 < x_identyfikatora - 10
        )
        if _IDENTYFIKATOR_OGON.match(token) and dzialka.czesci:
            # Numer działki ewidencyjnej łamie się do następnego wiersza.
            ostatnia = next(
                (c for c in reversed(dzialka.czesci) if _IDENTYFIKATOR_GLOWA.match(c.identyfikator)),
                None,
            )
            if ostatnia is not None:
                ostatnia.identyfikator += token
                uzyte = True
        elif na_lewo_od_identyfikatora and re.match(
            r"^[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż_-]", token
        ):
            dzialka.uprawa = f"{dzialka.uprawa} {token}".strip()
            uzyte = True
    if not uzyte:
        _pomin(tokeny, wniosek)


def _pomin(tokeny: list[str], wniosek: Wniosek) -> None:
    wniosek.kontrola.wiersze_pominiete += 1
    if len(wniosek.kontrola.przyklady_pominietych) < 5:
        wniosek.kontrola.przyklady_pominietych.append(" ".join(tokeny)[:70])


# ── całość ────────────────────────────────────────────────────────────────

def czytaj(sciezka: Path) -> Wniosek:
    wniosek = Wniosek()
    with pdfplumber.open(sciezka) as pdf:
        wszystkie = [w for strona in pdf.pages for w in wiersze_strony(strona)]

    sekcja: str | None = None
    srodki: list[float] = []
    x_identyfikatora: float | None = None
    for wiersz in wszystkie:
        tokeny = [s.tekst for s in wiersz]
        tresc = " ".join(tokeny)

        if NAGLOWEK_X in tresc:
            sekcja, srodki = "X", []
            continue
        if NAGLOWEK_XI in tresc:
            sekcja, srodki = "XI", []
            continue
        if sekcja is None:
            continue
        if re.match(r"^[IVX]{1,5}[A-Z]?\.\s+[A-ZĄĆĘŁŃÓŚŹŻ]", tresc):
            sekcja = None  # kolejna sekcja wniosku — koniec tabeli
            continue

        nowa_numeracja = numeracja_kolumn(wiersz)
        if nowa_numeracja:
            srodki = nowa_numeracja
            continue

        if tresc.lower().startswith("razem"):
            _odczytaj_podsumowanie(tresc, wniosek)
            continue

        if not srodki:
            # Przed wierszem numeracji jest wielowierszowy nagłówek tabeli —
            # to nie są dane.
            continue

        if sekcja == "X":
            if not re.match(r"^\d+$", tokeny[0]):
                continue
            _dodaj_dzialke_ewidencyjna(do_kolumn_srodkiem(wiersz, srodki), wniosek)
        else:
            if x_identyfikatora is None:
                glowa = next(
                    (s for s in wiersz if _IDENTYFIKATOR_GLOWA.match(s.tekst)), None
                )
                if glowa is not None:
                    x_identyfikatora = glowa.x0
            _dodaj_do_xi(wiersz, wniosek, x_identyfikatora)

    _podsumuj(wniosek)
    return wniosek


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

    if kontrola.suma_z_wniosku_ar is not None and not kontrola.suma_zgodna:
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

    # Kontrola wewnętrzna 1: części muszą się sumować do powierzchni działki rolnej.
    for dzialka in wniosek.dzialki_rolne:
        suma_czesci = sum(c.powierzchnia_ar for c in dzialka.czesci)
        if suma_czesci and suma_czesci != dzialka.powierzchnia_ar:
            kontrola.ostrzezenia.append(
                f"działka rolna {dzialka.oznaczenie}: powierzchnia {dzialka.powierzchnia_ar / 100:.2f} ha, "
                f"a części dają {suma_czesci / 100:.2f} ha"
            )

    # Kontrola wewnętrzna 2: identyfikatory z XI muszą być w tabeli X.
    # Tabela X podaje numer obrębu bez kodu gminy, więc porównujemy końcówki.
    znane = {d.identyfikator for d in wniosek.dzialki_ewidencyjne}
    if znane:
        nieznane = {
            identyfikator
            for dzialka in wniosek.dzialki_rolne
            for identyfikator in dzialka.identyfikatory
            if not any(identyfikator.endswith(k) for k in znane)
        }
        if nieznane:
            kontrola.ostrzezenia.append(
                f"{len(nieznane)} identyfikatorów z tabeli XI nie ma w tabeli X"
            )

    # Kontrola wewnętrzna 3: oznaczenia nie mogą się powtarzać.
    oznaczenia = [d.oznaczenie for d in wniosek.dzialki_rolne]
    if len(set(oznaczenia)) != len(oznaczenia):
        kontrola.ostrzezenia.append("oznaczenia działek rolnych się powtarzają")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plik", type=Path, help="wniosek w formacie PDF")
    parser.add_argument("--uprawy-csv", type=Path, default=None,
                        help="zapisz nazwy upraw do pliku (wejście dla zadania P3)")
    parser.add_argument("--dzialki-csv", type=Path, default=None,
                        help="zapisz identyfikatory działek (wejście dla zadania P5)")
    args = parser.parse_args(argv)

    wniosek = czytaj(args.plik)
    kontrola = wniosek.kontrola
    suma_ewidencyjnych = sum(
        d.powierzchnia_ha or 0 for d in wniosek.dzialki_ewidencyjne
    )
    print(f"Działki ewidencyjne: {len(wniosek.dzialki_ewidencyjne)}"
          f"  ({suma_ewidencyjnych:.2f} ha)")
    print(f"Działki rolne:       {len(wniosek.dzialki_rolne)}")
    print(f"Powierzchnia zadeklarowana: {kontrola.suma_z_odczytu_ar / 100:.2f} ha")
    print(f"Różnych upraw:       {len(wniosek.uprawy)}")
    if kontrola.wiersze_pominiete:
        print(f"Pominięte wiersze:   {kontrola.wiersze_pominiete}")
        for przyklad in kontrola.przyklady_pominietych:
            print(f"    {przyklad}")
    print("Kontrola: " + ("zgodna" if kontrola.wynik_pewny else "NIEZGODNA"))
    for ostrzezenie in kontrola.ostrzezenia[:10]:
        print("  ! " + ostrzezenie)

    if args.uprawy_csv:
        args.uprawy_csv.parent.mkdir(parents=True, exist_ok=True)
        args.uprawy_csv.write_text("\n".join(wniosek.uprawy) + "\n", encoding="utf-8")
        print(f"Nazwy upraw zapisane do {args.uprawy_csv}")
    if args.dzialki_csv:
        args.dzialki_csv.parent.mkdir(parents=True, exist_ok=True)
        args.dzialki_csv.write_text(
            "\n".join(sorted({d.identyfikator for d in wniosek.dzialki_ewidencyjne}))
            + "\n",
            encoding="utf-8",
        )
        print(f"Identyfikatory działek zapisane do {args.dzialki_csv}")
    return 0 if kontrola.wynik_pewny else 1


if __name__ == "__main__":
    raise SystemExit(main())
