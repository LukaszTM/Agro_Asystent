"""Sprawdza kanały RSS z wiadomościami rolniczymi — etap 3, krok 6.

Program nie pobiera stron z urządzenia rolnika po to, żeby się dowiedzieć,
czy adres kanału jest aktualny (CLAUDE.md, reguła 3: dane przygotowuje
skrypt na komputerze dewelopera). Ten skrypt odpytuje każdy kanał
z `assets/dane/kanaly_wiadomosci.json`, sprawdza, czy odpowiedź wygląda na
RSS albo Atom i czy da się z niej wyjąć choć jeden tytuł z odnośnikiem,
a potem wpisuje wynik do pola `status`:

* `potwierdzone`   — kanał odpowiedział i dało się go odczytać,
* `do_weryfikacji` — nie odpowiedział, zwrócił błąd albo nie jest kanałem.

Aplikacja działa niezależnie od tego pola: kanał, który nie odpowiada,
jest po cichu pomijany. Status służy człowiekowi — po to, żeby wiedzieć,
czy lista w wydaniu jest sprawdzona, czy tylko wpisana z pamięci.

Użycie:

    python3 tools/wiadomosci/sprawdz_kanaly.py --sprawdz-tylko
    python3 tools/wiadomosci/sprawdz_kanaly.py \\
        --plik assets/dane/kanaly_wiadomosci.json --zapisz
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET

DOMYSLNY_PLIK = pathlib.Path("assets/dane/kanaly_wiadomosci.json")

# Przedstawiamy się tak samo jak aplikacja — serwisy mają prawo wiedzieć,
# kto puka.
PRZEDSTAWIENIE = "AgroAsystent/0.1 (github.com/LukaszTM/Agro_Asystent)"

POTWIERDZONE = "potwierdzone"
DO_WERYFIKACJI = "do_weryfikacji"


class WynikKanalu:
    """Co wyszło ze sprawdzenia jednego kanału."""

    def __init__(self, nazwa: str, adres: str, status: str, opis: str, wpisow: int = 0):
        self.nazwa = nazwa
        self.adres = adres
        self.status = status
        self.opis = opis
        self.wpisow = wpisow

    @property
    def dziala(self) -> bool:
        return self.status == POTWIERDZONE

    def __repr__(self) -> str:  # pragma: no cover - pomoc przy debugowaniu
        return f"WynikKanalu({self.nazwa!r}, {self.status!r}, {self.opis!r})"


def policz_wpisy(tresc: bytes) -> int:
    """Ile wiadomości da się wyjąć z odpowiedzi — zero znaczy „to nie kanał"."""
    korzen = ET.fromstring(tresc)
    wpisy = []
    for element in korzen.iter():
        nazwa = element.tag.split("}")[-1]
        if nazwa in {"item", "entry"}:
            wpisy.append(element)

    czytelne = 0
    for wpis in wpisy:
        tytul = None
        odnosnik = None
        for dziecko in wpis:
            nazwa = dziecko.tag.split("}")[-1]
            if nazwa == "title" and (dziecko.text or "").strip():
                tytul = dziecko.text.strip()
            if nazwa == "link":
                adres = (dziecko.text or "").strip() or dziecko.attrib.get("href", "")
                if adres.startswith("http"):
                    odnosnik = adres
        if tytul and odnosnik:
            czytelne += 1
    return czytelne


def sprawdz_kanal(kanal: dict, *, pobierz=None, limit_sekund: int = 20) -> WynikKanalu:
    """Odpytuje jeden kanał. `pobierz` podmieniamy w testach."""
    nazwa = kanal.get("nazwa", "bez nazwy")
    adres = kanal.get("adres", "")

    if not adres.startswith("https://"):
        return WynikKanalu(nazwa, adres, DO_WERYFIKACJI, "adres nie jest https")

    pobieranie = pobierz or _pobierz_z_sieci
    try:
        tresc = pobieranie(adres, limit_sekund)
    except Exception as blad:  # noqa: BLE001 - każdy błąd znaczy to samo
        return WynikKanalu(nazwa, adres, DO_WERYFIKACJI, f"nie odpowiada: {blad}")

    try:
        wpisow = policz_wpisy(tresc)
    except ET.ParseError as blad:
        return WynikKanalu(nazwa, adres, DO_WERYFIKACJI, f"to nie jest kanał: {blad}")

    if wpisow == 0:
        return WynikKanalu(nazwa, adres, DO_WERYFIKACJI, "kanał bez czytelnych wpisów")
    return WynikKanalu(nazwa, adres, POTWIERDZONE, f"{wpisow} wiadomości", wpisow)


def _pobierz_z_sieci(adres: str, limit_sekund: int) -> bytes:
    zadanie = urllib.request.Request(
        adres,
        headers={
            "User-Agent": PRZEDSTAWIENIE,
            "Accept": "application/rss+xml, application/xml, text/xml",
        },
    )
    with urllib.request.urlopen(zadanie, timeout=limit_sekund) as odpowiedz:  # noqa: S310
        if odpowiedz.status != 200:
            raise urllib.error.HTTPError(
                adres, odpowiedz.status, "zły kod odpowiedzi", odpowiedz.headers, None
            )
        return odpowiedz.read()


def sprawdz_wszystkie(dane: dict, *, pobierz=None) -> list[WynikKanalu]:
    return [sprawdz_kanal(kanal, pobierz=pobierz) for kanal in dane.get("kanaly", [])]


def zastosuj_wyniki(dane: dict, wyniki: list[WynikKanalu]) -> dict:
    """Wpisuje statusy do danych. Nic poza statusem nie jest ruszane."""
    po_adresie = {wynik.adres: wynik.status for wynik in wyniki}
    nowe = json.loads(json.dumps(dane))
    for kanal in nowe.get("kanaly", []):
        if kanal.get("adres") in po_adresie:
            kanal["status"] = po_adresie[kanal["adres"]]
    return nowe


def main(argumenty: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plik", type=pathlib.Path, default=DOMYSLNY_PLIK)
    parser.add_argument(
        "--zapisz",
        action="store_true",
        help="wpisz wyniki do pliku (bez tego tylko raport)",
    )
    parser.add_argument(
        "--sprawdz-tylko",
        action="store_true",
        help="nie odpytuj sieci, sprawdź tylko kształt pliku",
    )
    opcje = parser.parse_args(argumenty)

    dane = json.loads(opcje.plik.read_text(encoding="utf-8"))
    kanaly = dane.get("kanaly", [])
    if not kanaly:
        print("Plik nie ma ani jednego kanału.")
        return 1

    if opcje.sprawdz_tylko:
        for kanal in kanaly:
            for pole in ("nazwa", "adres", "strona", "status"):
                if pole not in kanal:
                    print(f"Kanał {kanal} nie ma pola {pole}.")
                    return 1
        print(f"Plik w porządku: {len(kanaly)} kanałów.")
        return 0

    wyniki = sprawdz_wszystkie(dane)
    for wynik in wyniki:
        znak = "OK " if wynik.dziala else "NIE"
        print(f"{znak} {wynik.nazwa}: {wynik.opis} ({wynik.adres})")

    dzialajace = sum(1 for wynik in wyniki if wynik.dziala)
    print(f"\nDziała {dzialajace} z {len(wyniki)} kanałów.")

    if opcje.zapisz:
        nowe = zastosuj_wyniki(dane, wyniki)
        opcje.plik.write_text(
            json.dumps(nowe, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"Statusy zapisane do {opcje.plik}.")

    return 0 if dzialajace else 2


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
