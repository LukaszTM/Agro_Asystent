"""Odczyt karencji, okresu prewencji i liczby zabiegów z urzędowej etykiety.

Etykieta jest dokumentem decydującym o tym, kiedy rolnik może zebrać plon,
więc obowiązuje zasada z CLAUDE.md: przy niepewnym odczycie zwracamy wartość
pustą i znacznik „do_sprawdzenia", nigdy wartości przybliżonej.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

# Zdania wprowadzające poszczególne okresy. Etykiety różnią się odstępami
# i łamaniem wierszy, więc dopuszczamy dowolne białe znaki.
_KARENCJA_ZBIOR = re.compile(
    r"okres\s+od\s+ostatniego\s+zastosowania\s+środka\s+do\s+dnia\s+zbioru"
    r".{0,80}?\(okres\s+karencji\)\s*:?\s*(?P<tresc>.{0,400})",
    re.IGNORECASE | re.DOTALL,
)
_KARENCJA_KONSUMPCJA = re.compile(
    r"do\s+dnia\s+przeznaczenia\s+ich\s+do\s+konsumpcji"
    r".{0,40}?\(okres\s+karencji\)\s*:?\s*(?P<tresc>.{0,400})",
    re.IGNORECASE | re.DOTALL,
)
_PREWENCJA = re.compile(
    r"\(okres\s+prewencji\)\s*:?\s*(?P<tresc>.{0,300})", re.IGNORECASE | re.DOTALL
)
_LICZBA_ZABIEGOW = re.compile(
    r"(?:maksymalna\s+)?liczba\s+zabiegów"
    r"(?:\s+w\s+sezonie\s+(?P<sezon>\w+))?\s*:?\s*(?P<ile>\d+)",
    re.IGNORECASE,
)

#: Zwroty kończące interesujący nas fragment — dalej zaczyna się kolejna
#: sekcja etykiety.
_KONIEC = re.compile(
    r"okres\s+od\s+(?:ostatniego\s+)?zastosowania"
    r"|okres\s+prewencji"
    r"|okres\s+karencji\s+dla\s+pasz",
    re.IGNORECASE,
)

#: Nagłówek pisany wersalikami, np. „WARUNKI PRZECHOWYWANIA…".
#: Celowo bez IGNORECASE — chodzi właśnie o wielkie litery.
_NAGLOWEK = re.compile(r"[A-ZĄĆĘŁŃÓŚŹŻ]{3,}(?:\s+[A-ZĄĆĘŁŃÓŚŹŻ]{2,}){2,}")

#: Początek listy numerowanej („1. Strategia zarządzania odpornością…") —
#: tam kończy się zdanie o karencji, a zaczynają zalecenia.
_LISTA = re.compile(r"\s\d+\.\s+[A-ZĄĆĘŁŃÓŚŹŻ]")

_DNI = re.compile(r"(\d+)\s*(dni|dzień|dnia)\b", re.IGNORECASE)
#: Trzy równoważne sposoby zapisania braku okresu karencji.
_BRAK_KARENCJI = re.compile(r"nie\s*dotyczy|nie\s*wymagan[ayeo]|brak\s+karencji", re.IGNORECASE)


@dataclass(frozen=True)
class Karencja:
    """Karencja dla jednej uprawy albo dla całej etykiety (``uprawy`` puste)."""

    uprawy: tuple[str, ...]
    dni: int | None
    stan: str  # 'dni' | 'nie_dotyczy' | 'do_sprawdzenia'
    tekst: str


@dataclass
class OdczytEtykiety:
    karencje: list[Karencja] = field(default_factory=list)
    karencja_tekst: str | None = None
    prewencja_tekst: str | None = None
    prewencja_dni: int | None = None
    liczba_zabiegow: int | None = None
    #: Etykieta podaje liczbę zabiegów osobno dla upraw i wartości się różnią —
    #: jednej liczby nie wolno wtedy pokazywać jako obowiązującej dla wszystkich.
    liczba_zabiegow_rozna: bool = False
    sezon: str | None = None
    znakow_tekstu: int = 0
    stan: str = "do_sprawdzenia"  # 'odczytana' | 'czesciowa' | 'do_sprawdzenia' | 'skan'


def _utnij(tresc: str) -> str:
    """Zwija łamanie wierszy i obcina fragment przed kolejną sekcją etykiety."""
    jedna_linia = re.sub(r"\s+", " ", tresc)
    granice = [
        d.start()
        for d in (
            _KONIEC.search(jedna_linia),
            _NAGLOWEK.search(jedna_linia),
            _LISTA.search(jedna_linia),
        )
        if d
    ]
    return (jedna_linia[: min(granice)] if granice else jedna_linia).strip(" .;\t")


def _podziel_na_pozycje(tresc: str) -> list[str]:
    """Pozycje rozdziela średnik; przecinek rozdziela uprawy w jednej pozycji."""
    return [c.strip() for c in tresc.split(";") if c.strip()]


def odczytaj_karencje(tekst: str) -> tuple[list[Karencja], str | None]:
    """Zwraca listę karencji oraz surowy fragment etykiety, z którego pochodzą."""
    dopasowanie = _KARENCJA_ZBIOR.search(tekst) or _KARENCJA_KONSUMPCJA.search(tekst)
    if not dopasowanie:
        return [], None

    fragment = _utnij(dopasowanie.group("tresc"))
    if not fragment:
        return [], None

    wynik: list[Karencja] = []
    for pozycja in _podziel_na_pozycje(fragment):
        dni = _DNI.search(pozycja)
        # Nazwy upraw stoją przed myślnikiem: „Ogórek, pomidor – 3 dni".
        przed_myslnikiem = re.split(r"\s[–—-]\s|\s*[–—-]\s*(?=\d|nie\s)", pozycja, maxsplit=1)
        uprawy: tuple[str, ...] = ()
        if len(przed_myslnikiem) == 2 and przed_myslnikiem[0]:
            uprawy = tuple(
                u.strip(" ,.")
                for u in przed_myslnikiem[0].split(",")
                if u.strip(" ,.") and not _DNI.search(u)
            )
        if dni:
            wynik.append(Karencja(uprawy, int(dni.group(1)), "dni", pozycja))
        elif _BRAK_KARENCJI.search(pozycja):
            wynik.append(Karencja(uprawy, None, "nie_dotyczy", pozycja))
        else:
            wynik.append(Karencja(uprawy, None, "do_sprawdzenia", pozycja))
    return wynik, fragment


def odczytaj_prewencje(tekst: str) -> tuple[str | None, int | None]:
    dopasowanie = _PREWENCJA.search(tekst)
    if not dopasowanie:
        return None, None
    fragment = _utnij(dopasowanie.group("tresc"))
    dni = _DNI.search(fragment)
    return (fragment or None), (int(dni.group(1)) if dni else None)


def odczytaj_liczbe_zabiegow(tekst: str) -> tuple[int | None, str | None, bool]:
    """Zwraca (liczba zabiegów, sezon, czy wartości się różnią).

    Etykieta wymienia liczbę zabiegów osobno dla każdej uprawy. Gdy wartości
    są różne, zwracamy największą i zaznaczamy to — aplikacja musi wtedy
    odesłać rolnika do etykiety zamiast podawać jedną liczbę.
    """
    dopasowania = list(_LICZBA_ZABIEGOW.finditer(tekst))
    if not dopasowania:
        return None, None, False
    wartosci = {int(d.group("ile")) for d in dopasowania}
    sezony = {d.group("sezon").lower() for d in dopasowania if d.group("sezon")}
    return max(wartosci), (sorted(sezony)[0] if sezony else None), len(wartosci) > 1


#: Poniżej tylu znaków na stronę uznajemy plik za skan bez warstwy tekstowej.
PROG_SKANU = 200


def odczytaj_etykiete(tekst: str, stron: int = 1) -> OdczytEtykiety:
    wynik = OdczytEtykiety(znakow_tekstu=len(tekst))

    if len(tekst) < PROG_SKANU * max(stron, 1):
        wynik.stan = "skan"
        return wynik

    wynik.karencje, wynik.karencja_tekst = odczytaj_karencje(tekst)
    wynik.prewencja_tekst, wynik.prewencja_dni = odczytaj_prewencje(tekst)
    (
        wynik.liczba_zabiegow,
        wynik.sezon,
        wynik.liczba_zabiegow_rozna,
    ) = odczytaj_liczbe_zabiegow(tekst)

    pewne = [k for k in wynik.karencje if k.stan != "do_sprawdzenia"]
    if pewne and wynik.liczba_zabiegow is not None:
        wynik.stan = "odczytana"
    elif pewne or wynik.liczba_zabiegow is not None:
        wynik.stan = "czesciowa"
    else:
        wynik.stan = "do_sprawdzenia"
    return wynik
