"""Terminy stosowania nawozów azotowych jesienią + wykazy gmin.

Dwa źródła, dwa poziomy pewności — i tak samo zapisujemy je do słownika:

1. **Wykazy gmin** (`--zal2`, `--zal3`) czytamy z samych załączników do
   rozporządzenia Rady Ministrów z 31 stycznia 2023 r. (**Dz.U. 2023 poz. 244**,
   załącznik nr 2 = tabela 4, załącznik nr 3 = tabela 5). To źródło pierwotne,
   więc wynik dostaje `status_weryfikacji: "potwierdzone"`.
   Pliki do pobrania ze strony ARiMR „Program azotanowy":
   <https://www.gov.pl/web/arimr/program-azotanowy-2023>

2. **Same daty graniczne** pochodzą z komunikatu Ministerstwa Rolnictwa
   „Zasady i terminy stosowania jesienią nawozów zawierających azot"
   (22.10.2024), który powołuje się na to rozporządzenie. Komunikat jest
   źródłem urzędowym, ale **streszczeniem** — tabeli 2 z rozdziału 1.3
   programu nie czytaliśmy. Dlatego daty dostają
   `status_weryfikacji: "ze_strony_ministerstwa"`, a aplikacja oznacza je
   jako „do sprawdzenia" i każe potwierdzić u doradcy (CLAUDE.md, reguła 5).
   Gdy tabela 2 będzie dostępna, wystarczy sprawdzić wartości i zmienić
   status — kod się nie zmienia.

Zgodnie z regułą 3 z CLAUDE.md skrypt uruchamia **deweloper na komputerze**;
aplikacja na telefonie nigdy nie pobiera stron ministerstwa.

Użycie:

    python3 tools/azotany/terminy_nawozenia.py \\
        --zal2 dane/zrodla/zal2_gminy_15x.pdf \\
        --zal3 dane/zrodla/zal3_gminy_25x.pdf
    python3 tools/azotany/terminy_nawozenia.py --zal2 … --zal3 … --sprawdz-tylko
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

import pdfplumber

ZRODLO_ZALACZNIKOW = (
    "Dz.U. 2023 poz. 244 — rozporządzenie Rady Ministrów z 31 stycznia 2023 r. "
    "w sprawie Programu działań mających na celu zmniejszenie zanieczyszczenia "
    "wód azotanami pochodzącymi ze źródeł rolniczych"
)

ZRODLO_DAT = (
    "Ministerstwo Rolnictwa i Rozwoju Wsi, komunikat „Zasady i terminy "
    "stosowania jesienią nawozów zawierających azot” (22.10.2024), "
    "na podstawie Dz.U. 2023 poz. 244, rozdział 1.3, tabela 2"
)

#: Dopóki nie przeczytamy tabeli 2 w samym rozporządzeniu, daty nie są
#: „potwierdzone" — aplikacja ma o tym mówić wprost.
STATUS_DAT = "ze_strony_ministerstwa"

#: Graniczne terminy jesienne. Rodzaje nawozów i gruntów są wartościami
#: słownikowymi, nie tekstem do czytania przez człowieka.
TERMINY = [
    {
        "id": "azotany_naturalne_stale_grunty_orne",
        "nazwa": "Ostatni dzień na obornik na gruntach ornych",
        "data_roczna": "10-31",
        "rodzaj_nawozu": "naturalne_stale",
        "rodzaj_gruntu": "grunty_orne",
        "co_to_za_nawoz": "obornik, pomiot ptasi",
    },
    {
        "id": "azotany_naturalne_stale_tuz",
        "nazwa": "Ostatni dzień na obornik na łąkach i pastwiskach",
        "data_roczna": "11-30",
        "rodzaj_nawozu": "naturalne_stale",
        "rodzaj_gruntu": "tuz_uprawy_wieloletnie_trwale",
        "co_to_za_nawoz": "obornik, pomiot ptasi",
    },
    {
        "id": "azotany_mineralne_i_plynne_grunty_orne",
        "nazwa": "Ostatni dzień na gnojowicę i saletrę na gruntach ornych",
        "data_roczna": "10-20",
        "rodzaj_nawozu": "mineralne_azotowe_i_naturalne_plynne",
        "rodzaj_gruntu": "grunty_orne",
        "co_to_za_nawoz": "nawozy azotowe mineralne, gnojowica, gnojówka",
        "warianty_gmin": "nawozy_azotowe_grunty_orne",
    },
    {
        "id": "azotany_mineralne_i_plynne_tuz",
        "nazwa": "Ostatni dzień na gnojowicę i saletrę na łąkach i pastwiskach",
        "data_roczna": "10-31",
        "rodzaj_nawozu": "mineralne_azotowe_i_naturalne_plynne",
        "rodzaj_gruntu": "tuz_uprawy_wieloletnie_trwale",
        "co_to_za_nawoz": "nawozy azotowe mineralne, gnojowica, gnojówka",
    },
]

#: Odstępstwa z rozdziału 1.3 programu — też dane, nie warunki w kodzie.
ODSTEPSTWA = [
    {
        "id": "niekorzystna_pogoda",
        "nazwa": "Niekorzystne warunki pogodowe",
        "do_dnia": "11-30",
        "kiedy": "nadmierne uwilgotnienie gleby albo susza uniemożliwiły "
                 "zbiór i nawożenie w terminie",
        "dokumentowanie": "nie_wymaga",
        "uwagi": "Rolnik sam ocenia warunki; program nie wymaga osobnych "
                 "zapisów. Nawożenie nie może wyjść za koniec listopada.",
    },
    {
        "id": "uprawa_po_pozno_zbieranych",
        "nazwa": "Uprawa zakładana jesienią po późno zbieranych",
        "do_dnia": "11-30",
        "kiedy": "zakładanie uprawy po buraku cukrowym, kukurydzy, "
                 "przedplonach albo późnych warzywach",
        "dokumentowanie": "wymaga",
        "limit_azotu_kg_na_ha": 30,
        "limit_dotyczy": "wieloskładnikowe nawozy mineralne dla zakładanej "
                         "uprawy",
        "wymagane_zapisy": [
            "termin zbioru przedplonu",
            "data zastosowania nawozu",
            "zastosowane nawozy",
            "dawka nawozu",
            "termin siewu jesiennej uprawy",
        ],
    },
]

#: Kiedy nawozić nie wolno w ogóle.
ZAKAZY = [
    {
        "id": "gleba_niezdatna",
        "nazwa": "Gleba zamarznięta, zalana, nasycona wodą albo pod śniegiem",
        "opis": "Nawożenie jest zabronione bez względu na termin.",
    },
]

#: Czego terminy nie dotyczą.
WYLACZENIA = ["uprawy pod osłonami", "uprawy kontenerowe"]

#: Warianty gminne: załącznik → data graniczna na gruntach ornych.
WARIANTY_GMIN = [
    {
        "id": "zal2_do_15_10",
        "data_roczna": "10-15",
        "zrodlo": "załącznik nr 2 (tabela 4)",
        "opis": "gminy, w których nawozy azotowe mineralne i naturalne "
                "płynne wolno stosować na gruntach ornych tylko do 15 "
                "października",
    },
    {
        "id": "zal3_do_25_10",
        "data_roczna": "10-25",
        "zrodlo": "załącznik nr 3 (tabela 5)",
        "opis": "gminy, w których nawozy azotowe mineralne i naturalne "
                "płynne wolno stosować na gruntach ornych do 25 października",
    },
]

#: Wiersz wykazu: województwo, siedmiocyfrowy kod TERYT gminy, nazwa.
WIERSZ_WYKAZU = re.compile(r"^\s*([a-ząćęłńóśźż-]+)\s+(\d{7})\s+(.+?)\s*$")

#: Warstwa tekstowa załączników gubi „ń" — tak samo jak w załączniku nr 1
#: („afrykaoskie"). Poprawka jest wypisana wprost, żeby nie zgubić wierszy
#: po cichu: bez niej z wykazów wypadłoby 72 gminy warmińsko-mazurskie.
POPRAWKI_TEKSTU = {"warmiosko-mazurskie": "warmińsko-mazurskie"}

WOJEWODZTWA = {
    "dolnośląskie", "kujawsko-pomorskie", "lubelskie", "lubuskie", "łódzkie",
    "małopolskie", "mazowieckie", "opolskie", "podkarpackie", "podlaskie",
    "pomorskie", "śląskie", "świętokrzyskie", "warmińsko-mazurskie",
    "wielkopolskie", "zachodniopomorskie",
}


def wiersze_wykazu(sciezka: Path) -> tuple[list[tuple[str, str, str]], list[str]]:
    """Rekordy wykazu gmin i linie, których nie udało się rozczytać."""
    with pdfplumber.open(sciezka) as dokument:
        linie: list[str] = []
        for strona in dokument.pages:
            linie += (strona.extract_text() or "").splitlines()

    rekordy: list[tuple[str, str, str]] = []
    nierozczytane: list[str] = []
    for linia in linie:
        if not linia.strip():
            continue
        dopasowanie = WIERSZ_WYKAZU.match(linia)
        if dopasowanie:
            wojewodztwo, kod, nazwa = dopasowanie.groups()
            wojewodztwo = POPRAWKI_TEKSTU.get(wojewodztwo, wojewodztwo)
        if dopasowanie and wojewodztwo in WOJEWODZTWA:
            rekordy.append((wojewodztwo, kod, nazwa))
        else:
            nierozczytane.append(linia.strip())
    return rekordy, nierozczytane


def sprawdz_wykaz(
    opis: str, rekordy: list[tuple[str, str, str]], nierozczytane: list[str]
) -> list[str]:
    """Wykaz jest dobry tylko wtedy, gdy nic się nie zgubiło po drodze."""
    bledy: list[str] = []
    if not rekordy:
        bledy.append(f"{opis}: nie odczytano ani jednej gminy")
        return bledy

    # Najważniejsza kontrola: żadna pominięta linia nie może zawierać kodu
    # gminy — inaczej zgubiliśmy wiersz wykazu.
    zgubione = [
        linia
        for linia in nierozczytane
        if re.search(r"(?<!\d)\d{7}(?!\d)", linia)
    ]
    if zgubione:
        bledy.append(
            f"{opis}: {len(zgubione)} pominiętych linii zawiera kod gminy, "
            f"np. {zgubione[0]!r}"
        )

    kody = [kod for _, kod, _ in rekordy]
    powtorki = sorted({kod for kod in kody if kody.count(kod) > 1})
    if powtorki:
        bledy.append(f"{opis}: powtórzone kody gmin: {powtorki[:5]}")
    return bledy


def wykaz_do_slownika(
    wariant: dict, rekordy: list[tuple[str, str, str]]
) -> dict:
    return {
        "id": wariant["id"],
        "data_roczna": wariant["data_roczna"],
        "zrodlo": wariant["zrodlo"],
        "opis": wariant["opis"],
        "liczba_gmin": len(rekordy),
        # Same kody TERYT: nazwy gmin aplikacja ma już przy działkach,
        # a plik ma być mały.
        "gminy": sorted(kod for _, kod, _ in rekordy),
    }


def zapisz_gminy(
    sciezka: Path, warianty: list[dict], sprawdzono: date
) -> None:
    sciezka.write_text(
        json.dumps(
            {
                "wersja": sprawdzono.isoformat().replace("-", "."),
                "sprawdzono": sprawdzono.isoformat(),
                "status_weryfikacji": "potwierdzone",
                "zrodlo": ZRODLO_ZALACZNIKOW,
                "dotyczy_terminu": "azotany_mineralne_i_plynne_grunty_orne",
                "opis": "Gminy, w których graniczny termin stosowania nawozów "
                        "azotowych mineralnych i naturalnych płynnych na "
                        "gruntach ornych jest inny niż domyślny. Kody to "
                        "siedmiocyfrowe identyfikatory TERYT gmin.",
                "warianty": warianty,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def zapisz_terminy(slownik: Path, sprawdzono: date) -> int:
    dane = json.loads(slownik.read_text(encoding="utf-8"))

    pozostale = [
        termin
        for termin in dane["terminy"]
        if not termin["id"].startswith("azotany_")
    ]
    nowe = [
        {
            "id": termin["id"],
            "obowiazek": "program_azotanowy_ewidencja",
            "nazwa": termin["nazwa"],
            "rodzaj": "data_roczna",
            "data_roczna": termin["data_roczna"],
            "rodzaj_nawozu": termin["rodzaj_nawozu"],
            "rodzaj_gruntu": termin["rodzaj_gruntu"],
            "co_to_za_nawoz": termin["co_to_za_nawoz"],
            **(
                {"warianty_gmin": termin["warianty_gmin"]}
                if "warianty_gmin" in termin
                else {}
            ),
            "status_weryfikacji": STATUS_DAT,
            "zrodlo": ZRODLO_DAT,
            "uwagi": "Data ze streszczenia ministerstwa; tabela 2 z rozdziału "
                     "1.3 programu nie była czytana. Potwierdź u doradcy.",
        }
        for termin in TERMINY
    ]
    dane["terminy"] = pozostale + nowe
    dane["zasady_nawozenia_azotem"] = {
        "status_weryfikacji": STATUS_DAT,
        "zrodlo": ZRODLO_DAT,
        "sprawdzono": sprawdzono.isoformat(),
        "odstepstwa": ODSTEPSTWA,
        "zakazy": ZAKAZY,
        "nie_dotyczy": WYLACZENIA,
    }
    slownik.write_text(
        json.dumps(dane, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return len(nowe)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Wpisuje do słownika reguł jesienne terminy stosowania nawozów "
            "azotowych i wykazy gmin z załączników 2 i 3 programu azotanowego."
        )
    )
    parser.add_argument(
        "--zal2",
        type=Path,
        required=True,
        help="załącznik nr 2: wykaz gmin z terminem do 15 października",
    )
    parser.add_argument(
        "--zal3",
        type=Path,
        required=True,
        help="załącznik nr 3: wykaz gmin z terminem do 25 października",
    )
    parser.add_argument(
        "--slownik",
        type=Path,
        default=Path("assets/dane/reguly_prawne.json"),
        help="słownik reguł prawnych aplikacji",
    )
    parser.add_argument(
        "--gminy",
        type=Path,
        default=Path("assets/dane/gminy_terminy_azotowe.json"),
        help="plik z wykazami gmin",
    )
    parser.add_argument(
        "--sprawdz-tylko",
        action="store_true",
        help="odczytaj i sprawdź, ale nie zapisuj plików",
    )
    argumenty = parser.parse_args()

    bledy: list[str] = []
    warianty: list[dict] = []
    for wariant, sciezka in (
        (WARIANTY_GMIN[0], argumenty.zal2),
        (WARIANTY_GMIN[1], argumenty.zal3),
    ):
        rekordy, nierozczytane = wiersze_wykazu(sciezka)
        opis = f"{wariant['zrodlo']} ({sciezka.name})"
        bledy += sprawdz_wykaz(opis, rekordy, nierozczytane)
        wojewodztwa = {wojewodztwo for wojewodztwo, _, _ in rekordy}
        print(
            f"{opis}: {len(rekordy)} gmin w {len(wojewodztwa)} województwach, "
            f"termin do {wariant['data_roczna'][3:]}.{wariant['data_roczna'][:2]}"
        )
        warianty.append(wykaz_do_slownika(wariant, rekordy))

    wspolne = set(warianty[0]["gminy"]) & set(warianty[1]["gminy"])
    if wspolne:
        bledy.append(
            f"gminy w obu wykazach naraz: {sorted(wspolne)[:5]} — "
            "termin byłby niejednoznaczny"
        )

    if bledy:
        print("Odczyt wykazów się nie broni (nic nie zapisuję):")
        for blad in bledy:
            print(" •", blad)
        return 1

    print(
        f"terminy graniczne: {len(TERMINY)}, odstępstwa: {len(ODSTEPSTWA)}, "
        f"zakazy: {len(ZAKAZY)} — status dat: {STATUS_DAT}"
    )

    if argumenty.sprawdz_tylko:
        return 0

    dzisiaj = date.today()
    zapisz_gminy(argumenty.gminy, warianty, dzisiaj)
    ile = zapisz_terminy(argumenty.slownik, dzisiaj)
    print(f"zapisano {ile} terminów do {argumenty.slownik}")
    print(f"zapisano wykazy gmin do {argumenty.gminy}")
    print("Pamiętaj o podniesieniu pola „wersja” w słowniku reguł.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
