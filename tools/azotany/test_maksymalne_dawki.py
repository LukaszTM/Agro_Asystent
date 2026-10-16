"""Testy odczytu tabeli 14 (maksymalne dawki azotu).

Samego PDF rozporządzenia nie ma w repozytorium (`dane/` jest w
.gitignore), więc tutaj sprawdzamy to, co da się sprawdzić bez niego:
sprzątanie nazw z warstwy tekstowej i kontrole negatywne, które mają
przerwać zapis, gdy odczyt się rozjedzie.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from maksymalne_dawki import (  # noqa: E402
    NAZWY_OGOLNE,
    do_regul,
    oczysc_nazwe,
    popraw,
    sprawdz,
)

PELNA_TABELA = [
    ("Zboża", "Pszenica ozima", 200),
    ("Zboża", "Kukurydza na ziarno", 240),
    ("Oleiste", "Rzepak", 240),
    ("Pastewne", "Rzepak", 200),
    ("Okopowe", "Burak cukrowy", 180),
    ("Okopowe", "Ziemniak późny", 180),
    ("Warzywa polowe", "Kalafior", 350),
    ("Rośliny sadownicze", "Truskawka", 60),
    ("Inne, w tym uprawy trwałe", "Chmiel", 350),
    ("Warzywa wieloletnie", "Rabarbar", 200),
    ("Warzywa wieloletnie", "Szczaw", 150),
    ("Warzywa wieloletnie", "Szparag", 150),
]

BOBOWATE = [
    "Bobik",
    "Grochy",
    "Lędźwian",
    "Łubiny",
    "Seradela",
    "Soczewica",
    "Soja",
    "Wyka",
]


def przyklad():
    """Odczyt, który powinien przejść kontrole: wszystkie wiersze z checków
    plus tyle wypełniaczy, żeby wyjść powyżej stu."""
    uprawy = [
        {"grupa": g, "uprawa": u, "kg_n_ha": kg, "bobowate": False}
        for g, u, kg in PELNA_TABELA
    ]
    uprawy += [
        {"grupa": g, "uprawa": u, "kg_n_ha": kg, "bobowate": False}
        for g, u in NAZWY_OGOLNE
        for kg in [160]
    ]
    uprawy += [
        {"grupa": "Bobowate", "uprawa": n, "kg_n_ha": None, "bobowate": True}
        for n in BOBOWATE
    ]
    uprawy += [
        {
            "grupa": "Rośliny ozdobne",
            "uprawa": f"Kwiat {i}",
            "kg_n_ha": 100,
            "bobowate": False,
        }
        for i in range(120)
    ]
    return uprawy, {"bobowate_kg": [30, 50], "nierozpoznane": []}


def test_popraw_naprawia_warstwe_tekstowa():
    assert popraw("Jęczmieo ozimy 140") == "Jęczmień ozimy 140"
    assert popraw("Burak dwikłowy") == "Burak ćwikłowy"
    assert popraw("Żyto mieszaocowe") == "Żyto mieszańcowe"


def test_oczysc_nazwe_zdejmuje_resztki_ukladu_tabeli():
    # Prawa kolumna tabeli wchodzi w nazwę: „Grochy lub 50 kg…".
    assert oczysc_nazwe("Grochy lub") == "Grochy"
    # Zawinięta lista w jednej komórce: „Warzywa: rabarbar, szczaw…".
    assert oczysc_nazwe("Warzywa: rabarbar") == "Rabarbar"
    assert oczysc_nazwe("szczaw") == "Szczaw"
    assert oczysc_nazwe("Pszenica ozima") == "Pszenica ozima"


def test_poprawny_odczyt_przechodzi_kontrole():
    uprawy, dodatki = przyklad()
    assert sprawdz(uprawy, dodatki) == []


def test_brakujacy_wiersz_zatrzymuje_zapis():
    uprawy, dodatki = przyklad()
    uprawy = [u for u in uprawy if u["uprawa"] != "Kalafior"]
    assert any("Kalafior" in b for b in sprawdz(uprawy, dodatki))


def test_pomylone_grupy_zatrzymuja_zapis():
    # Rzepak ma dwa limity; zamiana grup musi się wydać.
    uprawy, dodatki = przyklad()
    for u in uprawy:
        if u["uprawa"] == "Rzepak":
            u["kg_n_ha"] = 240 if u["grupa"] == "Pastewne" else 200
    assert len(sprawdz(uprawy, dodatki)) >= 2


def test_nieprzeczytana_linia_zatrzymuje_zapis():
    uprawy, dodatki = przyklad()
    dodatki["nierozpoznane"] = ["Jakaś uprawa bez liczby"]
    assert any("nie umiem przeczytać" in b for b in sprawdz(uprawy, dodatki))


def test_nazwa_z_resztka_ukladu_zatrzymuje_zapis():
    uprawy, dodatki = przyklad()
    uprawy[0]["uprawa"] = "warzywa: rabarbar"
    bledy = sprawdz(uprawy, dodatki)
    assert any("resztk" in b or "małej litery" in b for b in bledy)


def test_blok_do_regul_ma_podstawe_i_obnizki():
    uprawy, _ = przyklad()
    blok = do_regul(uprawy)
    assert "tabela 14" in blok["zrodlo"]
    assert blok["status_weryfikacji"] == "potwierdzone"
    assert {o["rodzaj_gleby"]: o["procent"] for o in blok["obnizki"]} == {
        "bardzo_lekka": 20,
        "lekka": 10,
    }
    assert blok["bobowate"]["kg_n_ha_mineralne"] == 30
    assert blok["bobowate"]["kg_n_ha_naturalne"] == 50
    # Wiersze zbiorcze muszą być oznaczone — inaczej aplikacja łapałaby
    # „inne" w dowolnej nazwie pola.
    ogolne = {(u["grupa"], u["uprawa"]) for u in blok["uprawy"] if u.get("ogolna")}
    assert ogolne == NAZWY_OGOLNE
    bobowate = [u for u in blok["uprawy"] if u.get("bobowate")]
    assert len(bobowate) == len(BOBOWATE)
    assert all("kg_n_ha" not in u for u in bobowate)
