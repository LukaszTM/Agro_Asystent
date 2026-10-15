"""Współczynniki przeliczania zwierząt na DJP (tabela 3 programu działań).

Źródło: **Dz.U. 2020 poz. 243**, załącznik nr 1, tabela 3 — „Współczynniki
przeliczeniowe sztuk rzeczywistych zwierząt gospodarskich na DJP". Od liczby
DJP zależy, czy gospodarstwo musi prowadzić ewidencję nawożenia i mieć plan
nawożenia azotem, dlatego wartości nie mogą być wpisane w kod aplikacji —
trafiają do `assets/dane/reguly_prawne.json` jako dane z numerem wersji.

Skrypt **nie zgaduje i nie czyta liczb z układu tabeli**: tabela poniżej jest
przepisana z rozporządzenia, a skrypt sprawdza każdą parę „nazwa grupy +
współczynnik" w tekście wyciągniętym z PDF. Gdy choć jedna się nie zgadza,
nic nie zapisuje i wypisuje, czego nie znalazł. Tyle samo pracy przy
następnej zmianie przepisu: podmień wartości w TABELA, uruchom skrypt
z nowym PDF-em i zobacz, czy wszystko się broni.

Zgodnie z regułą 3 z CLAUDE.md skrypt uruchamia **deweloper na komputerze**;
aplikacja na telefonie nigdy nie pobiera stron ministerstwa.

Użycie:

    python3 tools/djp/wspolczynniki_djp.py --pdf dane/zrodla/Zal_01_Program_dzialan_2020.pdf
    python3 tools/djp/wspolczynniki_djp.py --pdf <plik> --sprawdz-tylko
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

import pdfplumber

#: Nazwa dokumentu wpisywana do słownika jako źródło danych.
ZRODLO = (
    "Dz.U. 2020 poz. 243 — Program działań mających na celu zmniejszenie "
    "zanieczyszczenia wód azotanami pochodzącymi ze źródeł rolniczych, "
    "załącznik nr 1, tabela 3"
)

#: Nazwa grupy łamie się w tabeli PDF w pół, a liczba stoi w środku
#: („Krowy powyżej 500 kg masy 1,2 ciała”). Dlatego szukamy liczby
#: i sprawdzamy, czy w jej otoczeniu stoją wszystkie słowa nazwy.
OKNO_SZUKANIA = 90

#: Gatunki w kolejności przydatnej na ekranie wyboru: najczęstsze pierwsze.
#: Rozporządzenie wymienia też zwierzęta, których prawie nikt nie trzyma —
#: aplikacja chowa je za przyciskiem „Więcej zwierząt”.
TABELA = [
    ("bydło", [
        ("bydlo_buhaj", "Buhaje", 1.4),
        ("bydlo_krowa", "Krowy", 1),
        ("bydlo_krowa_powyzej_500", "Krowy powyżej 500 kg masy ciała", 1.2),
        ("bydlo_jalowka_cielna", "Jałówki cielne", 1),
        ("bydlo_jalowka_powyzej_1", "Jałówki powyżej 1 roku", 0.8),
        ("bydlo_jalowka_6_12", "Jałówki od 6 miesiąca do 1 roku", 0.3),
        ("bydlo_opasowe_powyzej_1", "Bydło opasowe powyżej 1 roku", 0.9),
        ("bydlo_opasowe_6_12", "Bydło opasowe od 6 miesiąca do 1 roku", 0.36),
        ("bydlo_ciele", "Cielęta do 6 miesiąca", 0.15),
    ]),
    ("świnie", [
        ("swinie_knur", "Knury", 0.4),
        ("swinie_locha", "Lochy", 0.35),
        ("swinie_warchlak", "Warchlaki od 2 miesiąca do 4 miesiąca", 0.07),
        ("swinie_prosie", "Prosięta do 2 miesiąca", 0.02),
        ("swinie_tucznik", "Tuczniki, loszki i knurki hodowlane", 0.14),
    ]),
    ("drób", [
        ("drob_kury_kaczki", "Kury, kaczki", 0.004),
        ("drob_kury_do_20_tygodnia", "Kury do 20 tygodnia", 0.0014),
        ("drob_brojler", "Kurczęta brojlery", 0.0036),
        ("drob_gesi", "Gęsi", 0.008),
        ("drob_indyki_samce", "Indyki samce", 0.044),
        ("drob_indyki_samice", "Indyki samice", 0.020),
        ("drob_przepiorki", "Przepiórki", 0.0003),
        ("drob_perlice", "Perlice", 0.003),
    ]),
    ("owce", [
        ("owce_powyzej_1_5_roku", "Owce powyżej 1,5 roku", 0.1),
        ("owce_tryki_powyzej_1_5_roku", "Tryki powyżej 1,5 roku", 0.12),
        ("owce_jagnieta_do_3_5_miesiaca", "Jagnięta do 3,5 miesiąca", 0.05),
        ("owce_jarlaki_tryczki", "Jarlaki tryczki", 0.08),
        ("owce_jarlaki_maciorki", "Jarlaki maciorki", 0.1),
    ]),
    ("kozy", [
        ("kozy_matki", "Kozy matki", 0.15),
        ("kozy_kozleta_do_3_5_miesiaca", "Koźlęta do 3,5 miesiąca", 0.05),
        ("kozy_kozleta_3_5_miesiaca_1_5_roku",
         "Koźlęta od 3,5 miesiąca do 1,5 roku", 0.08),
        ("kozy_pozostale", "Pozostałe kozy", 0.1),
    ]),
    ("konie ras dużych", [
        ("konie_duze_ogiery_klacze_walachy", "Ogiery, klacze, wałachy", 1.2),
        ("konie_duze_zrebaki_powyzej_2_lat", "Źrebaki powyżej 2 lat", 1),
        ("konie_duze_zrebaki_1_2_lat", "Źrebaki od 1 roku do 2 lat", 0.8),
        ("konie_duze_zrebaki_6_miesiecy_1_rok",
         "Źrebaki od 6 miesiąca do 1 roku", 0.5),
        ("konie_duze_zrebieta_do_6_miesiaca", "Źrebięta do 6 miesiąca", 0.3),
    ]),
    ("konie ras małych", [
        ("konie_male_ogiery_klacze_walachy", "Ogiery, klacze, wałachy", 0.6),
        ("konie_male_zrebaki_powyzej_2_lat", "Źrebaki powyżej 2 lat", 0.5),
        ("konie_male_zrebaki_1_2_lat", "Źrebaki od 1 roku do 2 lat", 0.35),
        ("konie_male_zrebaki_6_miesiecy_1_rok",
         "Źrebaki od 6 miesiąca do 1 roku", 0.2),
        ("konie_male_zrebieta_do_6_miesiaca", "Źrebięta do 6 miesiąca", 0.12),
    ]),
    ("bawół domowy", [
        ("bawol_powyzej_2_lat", "Bawół domowy powyżej 2 lat", 0.7),
        ("bawol_1_2_lat", "Bawół domowy od 1 roku do 2 lat", 0.4),
        ("bawol_6_miesiecy_1_rok", "Bawół domowy od 6 miesiąca do 1 roku", 0.3),
        ("bawol_do_6_miesiaca", "Bawół domowy do 6 miesiąca", 0.13),
    ]),
    ("muł", [
        ("mul_powyzej_2_lat", "Muł powyżej 2 lat", 0.6),
        ("mul_1_2_lat", "Muł od 1 roku do 2 lat", 0.3),
        ("mul_do_1_roku", "Muł do 1 roku", 0.1),
    ]),
    ("osioł", [
        ("osiol_powyzej_2_lat", "Osioł powyżej 2 lat", 0.5),
        ("osiol_1_2_lat", "Osioł od 1 roku do 2 lat", 0.25),
        ("osiol_do_1_roku", "Osioł do 1 roku", 0.07),
    ]),
    ("jelenie sika i daniele", [
        ("jelenie_sika_byki", "Byki", 0.22),
        ("jelenie_sika_lanie", "Łanie", 0.13),
        ("jelenie_sika_pozostale", "Pozostałe", 0.06),
    ]),
    ("jelenie szlachetne", [
        ("jelenie_szlachetne_byki", "Byki", 0.42),
        ("jelenie_szlachetne_lanie", "Łanie", 0.24),
        ("jelenie_szlachetne_pozostale", "Pozostałe", 0.1),
    ]),
    ("strusie", [
        ("strusie_afrykanskie", "Strusie afrykańskie", 0.2),
        ("strusie_emu_i_nandu", "Strusie Emu i Nandu", 0.1),
    ]),
    ("gołębie (mięsne)", [
        ("golebie_miesne", "Gołębie (mięsne)", 0.002),
    ]),
    ("króliki", [
        ("kroliki_samce", "Króliki samce", 0.007),
        ("kroliki_samice", "Króliki samice", 0.007),
        ("kroliki_mlode", "Króliki młode", 0.004),
    ]),
    ("lisy", [
        ("lisy_pospolite_samce", "Lisy pospolite samce", 0.017),
        ("lisy_pospolite_samice", "Lisy pospolite samice", 0.011),
        ("lisy_pospolite_mlode", "Lisy pospolite młode", 0.005),
        ("lisy_polarne_samce", "Lisy polarne samce", 0.020),
        ("lisy_polarne_samice", "Lisy polarne samice", 0.016),
        ("lisy_polarne_mlode", "Lisy polarne młode", 0.006),
    ]),
    ("jenoty", [
        ("jenoty_samce", "Jenoty samce", 0.018),
        ("jenoty_samice", "Jenoty samice", 0.016),
        ("jenoty_mlode", "Jenoty młode", 0.006),
    ]),
    ("norki", [
        ("norki_samce", "Norki samce", 0.0042),
        ("norki_samice", "Norki samice", 0.0031),
        ("norki_mlode", "Norki młode", 0.0015),
    ]),
    ("nutrie", [
        ("nutrie_samce", "Nutrie samce", 0.009),
        ("nutrie_samice", "Nutrie samice", 0.008),
        ("nutrie_mlode", "Nutrie młode", 0.004),
    ]),
    ("tchórze", [
        ("tchorze_samce", "Tchórze samce", 0.003),
        ("tchorze_samice", "Tchórze samice", 0.0016),
        ("tchorze_mlode", "Tchórze młode", 0.0008),
    ]),
    ("szynszyle", [
        ("szynszyle_samce", "Szynszyle samce", 0.0012),
        ("szynszyle_samice", "Szynszyle samice", 0.0012),
        ("szynszyle_mlode", "Szynszyle młode", 0.0007),
    ]),
    ("inne zwierzęta", [
        ("inne_zwierzeta_500_kg",
         "Inne zwierzęta o łącznej masie 500 kg, z wyłączeniem ryb", 1),
    ]),
]

def tekst_pdf(plik: Path) -> str:
    """Tekst z PDF-a w jednym ciągu — bez łamania wierszy z tabeli."""
    with pdfplumber.open(plik) as dokument:
        strony = [strona.extract_text() or "" for strona in dokument.pages]
    return re.sub(r"\s+", " ", " ".join(strony))


def zapis_dziesietny(wartosc: float) -> str:
    """Liczba tak, jak stoi w rozporządzeniu (przecinek, nie kropka)."""
    return "1" if wartosc == 1 else repr(wartosc).replace(".", ",")


def jest_w_tekscie(tekst: str, nazwa: str, wspolczynnik: float) -> bool:
    slowa = re.findall(r"\w+", nazwa.lower())
    for liczba in re.finditer(r"(?<![\d,])\d+(?:,\d+)?(?![\d,])", tekst):
        if abs(float(liczba.group(0).replace(",", ".")) - wspolczynnik) > 1e-9:
            continue
        otoczenie = tekst[
            max(0, liczba.start() - OKNO_SZUKANIA):liczba.end() + OKNO_SZUKANIA
        ].lower()
        if all(slowo in otoczenie for slowo in slowa):
            return True
    return False


def sprawdz(tekst: str) -> list[str]:
    """Grupy, których nie udało się potwierdzić w PDF."""
    braki = []
    for gatunek, grupy in TABELA:
        for _, nazwa, wspolczynnik in grupy:
            if not jest_w_tekscie(tekst, nazwa, wspolczynnik):
                braki.append(
                    f"{gatunek} / {nazwa} = {zapis_dziesietny(wspolczynnik)}"
                )
    return braki


def wspolczynniki_bez_odpowiednika(tekst: str) -> list[str]:
    """Liczby z PDF-a, których nie ma w TABELA — znak pominiętego wiersza."""
    wartosci = {w for _, grupy in TABELA for _, _, w in grupy}
    brak = []
    for liczba in sorted({d.group(0) for d in re.finditer(
        r"(?<![\d,])0,\d+(?![\d,])", tekst
    )}):
        if not any(abs(float(liczba.replace(",", ".")) - w) < 1e-12
                   for w in wartosci):
            brak.append(liczba)
    return brak


def identyfikatory_poprawne() -> list[str]:
    """Identyfikatory bez polskich znaków (CLAUDE.md, nazewnictwo)."""
    return [
        ident
        for _, grupy in TABELA
        for ident, _, _ in grupy
        if not re.fullmatch(r"[a-z0-9_]+", ident)
    ]


def zapisz(slownik: Path, sprawdzono: date) -> int:
    dane = json.loads(slownik.read_text(encoding="utf-8"))
    dane["wspolczynniki_djp"] = {
        "status_weryfikacji": "potwierdzone",
        "zrodlo": ZRODLO,
        "sprawdzono": sprawdzono.isoformat(),
        "uwagi": (
            "Pełna tabela 3 z programu działań: nazwy grup przepisane "
            "dosłownie z rozporządzenia, bo tak czyta je kontrola. Gatunki "
            "stoją w kolejności od najczęstszych w polskich gospodarstwach "
            "— ekran wyboru pokazuje pierwsze z listy, resztę po "
            "naciśnięciu „Więcej zwierząt”."
        ),
        "grupy": [
            {
                "id": ident,
                "gatunek": gatunek,
                "nazwa": nazwa,
                "wspolczynnik": wspolczynnik,
            }
            for gatunek, grupy in TABELA
            for ident, nazwa, wspolczynnik in grupy
        ],
    }
    slownik.write_text(
        json.dumps(dane, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return len(dane["wspolczynniki_djp"]["grupy"])


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Sprawdza współczynniki DJP z tabeli 3 programu działań "
            "i wpisuje je do słownika reguł."
        )
    )
    parser.add_argument(
        "--pdf",
        type=Path,
        required=True,
        help="załącznik nr 1 do programu działań (Dz.U. 2020 poz. 243)",
    )
    parser.add_argument(
        "--slownik",
        type=Path,
        default=Path("assets/dane/reguly_prawne.json"),
        help="słownik reguł prawnych aplikacji",
    )
    parser.add_argument(
        "--sprawdz-tylko",
        action="store_true",
        help="porównaj z PDF-em, ale nie zapisuj słownika",
    )
    argumenty = parser.parse_args()

    zle_identyfikatory = identyfikatory_poprawne()
    if zle_identyfikatory:
        print("Polskie znaki w identyfikatorach:", *zle_identyfikatory)
        return 1

    tekst = tekst_pdf(argumenty.pdf)
    grup = sum(len(grupy) for _, grupy in TABELA)
    print(f"grup w tabeli: {grup}, gatunków: {len(TABELA)}")

    braki = sprawdz(tekst)
    if braki:
        print("Nie znalazłem w PDF (nic nie zapisuję):")
        for brak in braki:
            print(" •", brak)
        return 1
    print('każda para „nazwa + współczynnik” odnaleziona w PDF')

    pominiete = wspolczynniki_bez_odpowiednika(tekst)
    if pominiete:
        print("Liczby z PDF bez odpowiednika w tabeli — sprawdź, czy nie "
              "brakuje wiersza:", *pominiete)
        return 1
    print("żadna liczba z PDF nie została pominięta")

    if argumenty.sprawdz_tylko:
        return 0

    zapisane = zapisz(argumenty.slownik, date.today())
    print(f"zapisano {zapisane} grup do {argumenty.slownik}")
    print('Pamiętaj o podniesieniu pola „wersja” w słowniku.')
    return 0


if __name__ == "__main__":
    sys.exit(main())
