"""Współczynniki przeliczania zwierząt na DJP (tabela 3 programu azotanowego).

Źródło: **Dz.U. 2023 poz. 244** — rozporządzenie Rady Ministrów z dnia
31 stycznia 2023 r. w sprawie „Programu działań mających na celu zmniejszenie
zanieczyszczenia wód azotanami pochodzącymi ze źródeł rolniczych oraz
zapobieganie dalszemu zanieczyszczeniu", **załącznik nr 1, tabela 3**.
Rozporządzenie z 2023 r. zastąpiło to z 2020 r. (Dz.U. 2020 poz. 243) i zmieniło
tabelę: warchlaki 0,07 → 0,04, prosięta 0,02 → 0,01, doszły lamy i alpaki.

Od liczby DJP zależy, czy gospodarstwo musi prowadzić ewidencję nawożenia
i mieć plan nawożenia azotem, dlatego wartości nie mogą być wpisane w kod
aplikacji — trafiają do `assets/dane/reguly_prawne.json` jako dane z numerem
wersji.

Skrypt **nie zgaduje**: tabela niżej jest przepisana z rozporządzenia, a PDF
czytany jest po współrzędnych, kolumna po kolumnie. Załącznik ma skład
dwukolumnowy, więc dopasowanie „liczba blisko nazwy" potwierdziłoby też błędne
przypisanie — lamy i alpaki mają identyczne nazwy grup i stoją obok siebie.
Dlatego skrypt odtwarza dwa niezależne strumienie wierszy i sprawdza
**kolejność, nazwę i wartość** każdego z nich. Gdy choć jeden wiersz się nie
zgadza, nic nie zapisuje.

Zgodnie z regułą 3 z CLAUDE.md skrypt uruchamia **deweloper na komputerze**;
aplikacja na telefonie nigdy nie pobiera stron ministerstwa.

Załącznik nr 1 do pobrania ze strony ARiMR „Program azotanowy":
https://www.gov.pl/web/arimr/program-azotanowy-2023

Użycie:

    python3 tools/djp/wspolczynniki_djp.py --pdf dane/zrodla/zal1_djp_2023.pdf
    python3 tools/djp/wspolczynniki_djp.py --pdf <plik> --sprawdz-tylko
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from datetime import date
from pathlib import Path

import pdfplumber

#: Nazwa dokumentu wpisywana do słownika jako źródło danych.
ZRODLO = (
    "Dz.U. 2023 poz. 244 — rozporządzenie Rady Ministrów z 31 stycznia 2023 r. "
    "w sprawie Programu działań mających na celu zmniejszenie zanieczyszczenia "
    "wód azotanami pochodzącymi ze źródeł rolniczych, załącznik nr 1, tabela 3"
)

#: Warstwa tekstowa załącznika gubi „ń" w jednym wyrazie — PDF ma
#: „afrykaoskie" zamiast „afrykańskie". Poprawka jest wypisana osobno, żeby
#: nie osłabiać sprawdzania po cichu.
POPRAWKI_TEKSTU = {"afrykaoskie": "afrykanskie"}

#: Kolumny ze współczynnikami są wyrównane do prawej — stąd krawędzie x1.
KRAWEDZIE_KOLUMN = {"lewa": 295.0, "prawa": 516.0}
TOLERANCJA_X = 8.0
TOLERANCJA_WIERSZA = 4.0
GORA_NAGLOWKA = 70.0
#: Numer strony stoi na dole w kolumnie z wartościami i też jest wyrównany
#: do prawej („15" przy x1≈302), więc stopkę trzeba odciąć. Ostatni wiersz
#: tabeli na stronie siedzi przy top≈764, numer strony przy top≈805.
DOL_STOPKI = 790.0

#: Wiersz „Inne zwierzęta…" biegnie przez całą szerokość tabeli, więc nie
#: należy do żadnego strumienia; sprawdzamy go w tekście strony.
KOLUMNA_POZA_TABELA = "poza"

#: Tabela 3 przepisana z rozporządzenia. `kolumna` to miejsce w dwukolumnowym
#: składzie załącznika — skrypt czyta PDF po współrzędnych i sprawdza każdy
#: strumień osobno. Bez tego nie dałoby się rozstrzygnąć lam od alpak: mają
#: te same nazwy grup i sąsiadują w tabeli.
#: Gatunki stoją w **kolejności z rozporządzenia** — inaczej nie dałoby się
#: porównać odczytu strumieniami. Kolejność dla ekranu ustala osobno
#: KOLEJNOSC_NA_EKRANIE.
TABELA = [
    ("bydło", "lewa", [
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
    ("świnie", "lewa", [
        ("swinie_knur", "Knury", 0.4),
        ("swinie_locha", "Lochy", 0.35),
        ("swinie_warchlak", "Warchlaki", 0.04),
        ("swinie_prosie", "Prosięta", 0.01),
        ("swinie_tucznik", "Tuczniki, loszki i knurki hodowlane", 0.14),
    ]),
    ("konie ras dużych", "lewa", [
        ("konie_duze_ogiery_klacze_walachy", "Ogiery, klacze, wałachy", 1.2),
        ("konie_duze_zrebaki_powyzej_2_lat", "Źrebaki powyżej 2 lat", 1),
        ("konie_duze_zrebaki_1_2_lat", "Źrebaki od 1 roku do 2 lat", 0.8),
        ("konie_duze_zrebaki_6_miesiecy_1_rok",
         "Źrebaki od 6 miesiąca do 1 roku", 0.5),
        ("konie_duze_zrebieta_do_6_miesiaca", "Źrebięta do 6 miesiąca", 0.3),
    ]),
    ("konie ras małych", "lewa", [
        ("konie_male_ogiery_klacze_walachy", "Ogiery, klacze, wałachy", 0.6),
        ("konie_male_zrebaki_powyzej_2_lat", "Źrebaki powyżej 2 lat", 0.5),
        ("konie_male_zrebaki_1_2_lat", "Źrebaki od 1 roku do 2 lat", 0.35),
        ("konie_male_zrebaki_6_miesiecy_1_rok",
         "Źrebaki od 6 miesiąca do 1 roku", 0.2),
        ("konie_male_zrebieta_do_6_miesiaca", "Źrebięta do 6 miesiąca", 0.12),
    ]),
    ("owce", "lewa", [
        ("owce_powyzej_1_5_roku", "Owce powyżej 1,5 roku", 0.1),
        ("owce_tryki_powyzej_1_5_roku", "Tryki powyżej 1,5 roku", 0.12),
        ("owce_jagnieta_do_3_5_miesiaca", "Jagnięta do 3,5 miesiąca", 0.05),
        ("owce_jarlaki_tryczki", "Jarlaki tryczki", 0.08),
        ("owce_jarlaki_maciorki", "Jarlaki maciorki", 0.1),
    ]),
    ("drób", "lewa", [
        ("drob_kury_kaczki", "Kury, kaczki", 0.004),
        ("drob_kury_do_20_tygodnia", "Kury do 20 tygodnia", 0.0014),
        ("drob_brojler", "Kurczęta brojlery", 0.0036),
        ("drob_gesi", "Gęsi", 0.008),
        ("drob_indyki_samce", "Indyki samce", 0.044),
        ("drob_indyki_samice", "Indyki samice", 0.020),
        ("drob_przepiorki", "Przepiórki", 0.0003),
        ("drob_perlice", "Perlice", 0.003),
    ]),
    ("jelenie sika i daniele", "lewa", [
        ("jelenie_sika_byki", "Byki", 0.22),
        ("jelenie_sika_lanie", "Łanie", 0.13),
        ("jelenie_sika_pozostale", "Pozostałe", 0.06),
    ]),
    ("jelenie szlachetne", "lewa", [
        ("jelenie_szlachetne_byki", "Byki", 0.42),
        ("jelenie_szlachetne_lanie", "Łanie", 0.24),
        ("jelenie_szlachetne_pozostale", "Pozostałe", 0.1),
    ]),
    ("gołębie (mięsne)", "lewa", [
        ("golebie_miesne", "Gołębie (mięsne)", 0.002),
    ]),
    ("lamy", "lewa", [
        ("lamy_samice_powyzej_1_roku", "Samice powyżej 1 roku", 0.20),
        ("lamy_samce_powyzej_1_roku", "Samce powyżej 1 roku", 0.19),
        ("lamy_mlode_od_pol_do_1_roku", "Młode od ½ do 1 roku", 0.12),
        ("lamy_cieleta_do_pol_roku", "Cielęta/cria do ½ roku", 0.05),
    ]),
    ("kozy", "prawa", [
        ("kozy_matki", "Kozy matki", 0.15),
        ("kozy_kozleta_do_3_5_miesiaca", "Koźlęta do 3,5 miesiąca", 0.05),
        ("kozy_kozleta_3_5_miesiaca_1_5_roku",
         "Koźlęta od 3,5 miesiąca do 1,5 roku", 0.08),
        ("kozy_pozostale", "Pozostałe kozy", 0.1),
    ]),
    ("tchórze", "prawa", [
        ("tchorze_samce", "Tchórze samce", 0.003),
        ("tchorze_samice", "Tchórze samice", 0.0016),
        ("tchorze_mlode", "Tchórze młode", 0.0008),
    ]),
    ("lisy", "prawa", [
        ("lisy_pospolite_samce", "Lisy pospolite samce", 0.017),
        ("lisy_pospolite_samice", "Lisy pospolite samice", 0.011),
        ("lisy_pospolite_mlode", "Lisy pospolite młode", 0.005),
        ("lisy_polarne_samce", "Lisy polarne samce", 0.020),
        ("lisy_polarne_samice", "Lisy polarne samice", 0.016),
        ("lisy_polarne_mlode", "Lisy polarne młode", 0.006),
    ]),
    ("jenoty", "prawa", [
        ("jenoty_samce", "Jenoty samce", 0.018),
        ("jenoty_samice", "Jenoty samice", 0.016),
        ("jenoty_mlode", "Jenoty młode", 0.006),
    ]),
    ("norki", "prawa", [
        ("norki_samce", "Norki samce", 0.0042),
        ("norki_samice", "Norki samice", 0.0031),
        ("norki_mlode", "Norki młode", 0.0015),
    ]),
    ("nutrie", "prawa", [
        ("nutrie_samce", "Nutrie samce", 0.009),
        ("nutrie_samice", "Nutrie samice", 0.008),
        ("nutrie_mlode", "Nutrie młode", 0.004),
    ]),
    ("króliki", "prawa", [
        ("kroliki_samce", "Króliki samce", 0.007),
        ("kroliki_samice", "Króliki samice", 0.007),
        ("kroliki_mlode", "Króliki młode", 0.004),
    ]),
    ("szynszyle", "prawa", [
        ("szynszyle_samce", "Szynszyle samce", 0.0012),
        ("szynszyle_samice", "Szynszyle samice", 0.0012),
        ("szynszyle_mlode", "Szynszyle młode", 0.0007),
    ]),
    ("strusie", "prawa", [
        ("strusie_afrykanskie", "Strusie afrykańskie", 0.2),
        ("strusie_emu_i_nandu", "Strusie Emu i Nandu", 0.1),
    ]),
    ("muł", "prawa", [
        ("mul_powyzej_2_lat", "Muł powyżej 2 lat", 0.6),
        ("mul_1_2_lat", "Muł od 1 roku do 2 lat", 0.3),
        ("mul_do_1_roku", "Muł do 1 roku", 0.1),
    ]),
    ("osioł", "prawa", [
        ("osiol_powyzej_2_lat", "Osioł powyżej 2 lat", 0.5),
        ("osiol_1_2_lat", "Osioł od 1 roku do 2 lat", 0.25),
        ("osiol_do_1_roku", "Osioł do 1 roku", 0.07),
    ]),
    ("bawół domowy", "prawa", [
        ("bawol_powyzej_2_lat", "Bawół domowy powyżej 2 lat", 0.7),
        ("bawol_1_2_lat", "Bawół domowy od 1 roku do 2 lat", 0.4),
        ("bawol_6_miesiecy_1_rok", "Bawół domowy od 6 miesiąca do 1 roku", 0.3),
        ("bawol_do_6_miesiaca", "Bawół domowy do 6 miesiąca", 0.13),
    ]),
    ("alpaki", "prawa", [
        ("alpaki_samice_powyzej_1_roku", "Samice powyżej 1 roku", 0.11),
        ("alpaki_samce_powyzej_1_roku", "Samce powyżej 1 roku", 0.12),
        ("alpaki_mlode_od_pol_do_1_roku", "Młode od ½ do 1 roku", 0.05),
        ("alpaki_cieleta_do_pol_roku", "Cielęta/cria do ½ roku", 0.03),
    ]),
    ("inne zwierzęta", "poza", [
        ("inne_zwierzeta_500_kg",
         "Inne zwierzęta o łącznej masie 500 kg, z wyłączeniem ryb", 1),
    ]),
]

#: Kolejność gatunków w słowniku, a przez to na ekranie wyboru grupy:
#: najczęstsze w polskich gospodarstwach pierwsze. To decyzja o wyglądzie,
#: nie o treści przepisu — dlatego stoi osobno od TABELA.
KOLEJNOSC_NA_EKRANIE = [
    "bydło",
    "świnie",
    "drób",
    "owce",
    "kozy",
    "konie ras dużych",
    "konie ras małych",
    "bawół domowy",
    "muł",
    "osioł",
    "lamy",
    "alpaki",
    "jelenie sika i daniele",
    "jelenie szlachetne",
    "strusie",
    "gołębie (mięsne)",
    "króliki",
    "lisy",
    "jenoty",
    "norki",
    "nutrie",
    "tchórze",
    "szynszyle",
    "inne zwierzęta",
]


def bez_ogonkow(tekst: str) -> str:
    """Tekst do porównań: bez polskich znaków, małymi literami."""
    rozlozony = unicodedata.normalize("NFKD", tekst.lower())
    bez = "".join(z for z in rozlozony if not unicodedata.combining(z))
    bez = bez.replace("ł", "l")
    for zle, dobre in POPRAWKI_TEKSTU.items():
        bez = bez.replace(zle, dobre)
    return bez


def strumienie(sciezka: Path) -> dict[str, list[tuple[str, float]]]:
    """Wiersze tabeli odczytane po współrzędnych, osobno dla każdej kolumny.

    Zwraca dla każdej kolumny listę par „tekst zebrany od poprzedniej
    wartości" → „współczynnik". Nagłówki gatunków i poprzewijane nazwy
    wpadają do tego tekstu — i o to chodzi: pierwszy wiersz gatunku ma
    w sobie także jego nagłówek.

    Tekst zbiera się **przez wszystkie strony**, bo nazwa złamana na końcu
    strony kończy się na następnej.
    """
    liczba = re.compile(r"^\d+(?:,\d+)?$")
    wynik: dict[str, list[tuple[str, float]]] = {"lewa": [], "prawa": []}
    zebrane: dict[str, list[str]] = {"lewa": [], "prawa": []}
    with pdfplumber.open(sciezka) as dokument:
        for strona in dokument.pages:
            srodek = strona.width / 2
            slowa = [
                w
                for w in strona.extract_words()
                if GORA_NAGLOWKA < w["top"] < DOL_STOPKI
            ]
            # Tabela zaczyna się pod wierszem nagłówkowym „Gatunek/grupa".
            # Wyżej stoi „Załącznik nr 1", którego „1" wyrównane do prawej
            # wyglądałoby jak współczynnik.
            naglowki = [w["top"] for w in slowa if w["text"].startswith("Gatunek")]
            if naglowki:
                slowa = [w for w in slowa if w["top"] >= min(naglowki)]
            for kolumna, krawedz in KRAWEDZIE_KOLUMN.items():
                w_kolumnie = [
                    w for w in slowa if (w["x0"] < srodek) == (kolumna == "lewa")
                ]
                wiersze: dict[int, list[dict]] = {}
                for slowo in w_kolumnie:
                    klucz = round(slowo["top"] / TOLERANCJA_WIERSZA)
                    wiersze.setdefault(klucz, []).append(slowo)
                for klucz in sorted(wiersze):
                    linia = sorted(wiersze[klucz], key=lambda w: w["x0"])
                    wartosc = None
                    for slowo in linia:
                        czy_wartosc = liczba.match(slowo["text"]) and (
                            abs(slowo["x1"] - krawedz) <= TOLERANCJA_X
                        )
                        if czy_wartosc:
                            wartosc = float(slowo["text"].replace(",", "."))
                        else:
                            zebrane[kolumna].append(slowo["text"])
                    if wartosc is not None:
                        wynik[kolumna].append(
                            (" ".join(zebrane[kolumna]), wartosc)
                        )
                        zebrane[kolumna] = []
    return wynik


def tekst_calej_strony(sciezka: Path) -> str:
    with pdfplumber.open(sciezka) as dokument:
        strony = [strona.extract_text() or "" for strona in dokument.pages]
    return re.sub(r"\s+", " ", " ".join(strony))


def oczekiwane(kolumna: str) -> list[tuple[str, str, str, float]]:
    """Wiersze z TABELA należące do danej kolumny, w kolejności tabeli."""
    return [
        (gatunek, ident, nazwa, wspolczynnik)
        for gatunek, gdzie, grupy in TABELA
        if gdzie == kolumna
        for ident, nazwa, wspolczynnik in grupy
    ]


def sprawdz_kolumne(
    kolumna: str, odczytane: list[tuple[str, float]]
) -> list[str]:
    """Porównuje odczyt PDF-a z TABELA: kolejność, nazwa i wartość."""
    bledy: list[str] = []
    spodziewane = oczekiwane(kolumna)
    if len(odczytane) != len(spodziewane):
        bledy.append(
            f"kolumna {kolumna}: PDF ma {len(odczytane)} wierszy, "
            f"tabela {len(spodziewane)}"
        )
        return bledy
    for numer, ((tekst, wartosc), (gatunek, _, nazwa, wspolczynnik)) in enumerate(
        zip(odczytane, spodziewane)
    ):
        if abs(wartosc - wspolczynnik) > 1e-9:
            bledy.append(
                f"{gatunek} / {nazwa}: PDF ma {wartosc}, tabela {wspolczynnik}"
            )
            continue
        # Nazwa bywa złamana tak, że jej koniec stoi pod wartością, czyli
        # już w tekście następnego wiersza („Jałówki od 6 miesiąca do" +
        # „1 roku"). Dlatego szukamy słów nazwy w obu.
        dalszy = odczytane[numer + 1][0] if numer + 1 < len(odczytane) else ""
        zebrany = bez_ogonkow(f"{tekst} {dalszy}")
        brakujace = [
            slowo
            for slowo in re.findall(r"\w+", bez_ogonkow(nazwa))
            if slowo not in zebrany
        ]
        if brakujace:
            bledy.append(
                f"{gatunek} / {nazwa}: w PDF przy wartości {wartosc} nie ma "
                f"słów {brakujace} (odczytano: {tekst[:60]!r})"
            )
    return bledy


def sprawdz_wiersz_poza_tabela(tekst: str) -> list[str]:
    """Wiersz „Inne zwierzęta…" — biegnie przez całą szerokość tabeli."""
    bledy = []
    for gatunek, gdzie, grupy in TABELA:
        if gdzie != KOLUMNA_POZA_TABELA:
            continue
        for _, nazwa, wspolczynnik in grupy:
            plaski = bez_ogonkow(tekst)
            slowa = re.findall(r"\w+", bez_ogonkow(nazwa))
            if not all(slowo in plaski for slowo in slowa):
                bledy.append(f"{gatunek} / {nazwa}: nie ma tej treści w PDF")
            elif wspolczynnik != 1:
                bledy.append(
                    f"{gatunek} / {nazwa}: skrypt umie sprawdzić tylko "
                    "wartość 1 dla tego wiersza"
                )
    return bledy


def identyfikatory_z_polskimi_znakami() -> list[str]:
    """Identyfikatory muszą być bez polskich znaków (CLAUDE.md)."""
    return [
        ident
        for _, _, grupy in TABELA
        for ident, _, _ in grupy
        if not re.fullmatch(r"[a-z0-9_]+", ident)
    ]


def powtorzone_identyfikatory() -> list[str]:
    widziane: set[str] = set()
    powtorki = []
    for _, _, grupy in TABELA:
        for ident, _, _ in grupy:
            if ident in widziane:
                powtorki.append(ident)
            widziane.add(ident)
    return powtorki


def grupy_gatunku(gatunek: str) -> list[tuple[str, str, float]]:
    for nazwa_gatunku, _, grupy in TABELA:
        if nazwa_gatunku == gatunek:
            return grupy
    raise KeyError(f"nie ma gatunku {gatunek} w TABELA")


def zapisz(slownik: Path, sprawdzono: date) -> int:
    dane = json.loads(slownik.read_text(encoding="utf-8"))
    dane["wspolczynniki_djp"] = {
        "status_weryfikacji": "potwierdzone",
        "zrodlo": ZRODLO,
        "sprawdzono": sprawdzono.isoformat(),
        "uwagi": (
            "Pełna tabela 3 z programu azotanowego: nazwy grup przepisane "
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
            for gatunek in KOLEJNOSC_NA_EKRANIE
            for ident, nazwa, wspolczynnik in grupy_gatunku(gatunek)
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
            "Sprawdza współczynniki DJP z tabeli 3 programu azotanowego "
            "(Dz.U. 2023 poz. 244) i wpisuje je do słownika reguł."
        )
    )
    parser.add_argument(
        "--pdf",
        type=Path,
        required=True,
        help="załącznik nr 1 do programu azotanowego (Dz.U. 2023 poz. 244)",
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

    gatunki_tabeli = {gatunek for gatunek, _, _ in TABELA}
    for opis, znalezione in (
        ("polskie znaki w identyfikatorach", identyfikatory_z_polskimi_znakami()),
        ("powtórzone identyfikatory", powtorzone_identyfikatory()),
        ("gatunki tylko w TABELA",
         sorted(gatunki_tabeli - set(KOLEJNOSC_NA_EKRANIE))),
        ("gatunki tylko w KOLEJNOSC_NA_EKRANIE",
         sorted(set(KOLEJNOSC_NA_EKRANIE) - gatunki_tabeli)),
    ):
        if znalezione:
            print(f"{opis}:", *znalezione)
            return 1

    grup = sum(len(grupy) for _, _, grupy in TABELA)
    gatunkow = len(TABELA)
    print(f"grup w tabeli: {grup}, gatunków: {gatunkow}")

    odczyt = strumienie(argumenty.pdf)
    bledy: list[str] = []
    for kolumna in KRAWEDZIE_KOLUMN:
        bledy += sprawdz_kolumne(kolumna, odczyt[kolumna])
    bledy += sprawdz_wiersz_poza_tabela(tekst_calej_strony(argumenty.pdf))

    if bledy:
        print("Odczyt PDF nie zgadza się z tabelą (nic nie zapisuję):")
        for blad in bledy:
            print(" •", blad)
        return 1

    for kolumna in KRAWEDZIE_KOLUMN:
        print(f"kolumna {kolumna}: {len(odczyt[kolumna])} wierszy zgodnych "
              "co do kolejności, nazwy i wartości")

    if argumenty.sprawdz_tylko:
        return 0

    zapisane = zapisz(argumenty.slownik, date.today())
    print(f"zapisano {zapisane} grup do {argumenty.slownik}")
    print("Pamiętaj o podniesieniu pola „wersja” w słowniku.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
