"""Testy przygotowania notowań cen skupu."""

from __future__ import annotations

import datetime as dt
import json
import pathlib
import sys

import pytest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))

from tools.ceny.ceny_skupu import (  # noqa: E402
    DO_WERYFIKACJI,
    POTWIERDZONE,
    Notowanie,
    dopasuj_kolumny,
    liczba,
    wczytaj_csv,
    wczytaj_zsrir,
    zbuduj,
)

WZORZEC = {
    "wersja": "0",
    "zrodlo": "ZSRIR",
    "uwaga": "x",
    "zastrzezenie": "y",
    "tydzien": None,
    "produkty": [],
}


def test_liczba_czyta_polski_zapis():
    assert liczba("1 234,56") == 1234.56
    assert liczba("920,00") == 920.0


def test_proste_csv_daje_notowania():
    notowania = wczytaj_csv(
        [
            {
                "produkt": "Pszenica konsumpcyjna",
                "jednostka": "zł/t",
                "region": "Mazowieckie",
                "cena": "920,50",
            }
        ]
    )

    assert notowania[0].produkt == "Pszenica konsumpcyjna"
    assert notowania[0].region == "mazowieckie"
    assert notowania[0].cena == 920.5
    assert notowania[0].status == POTWIERDZONE


@pytest.mark.parametrize(
    "zmiana",
    [
        {"produkt": " "},
        {"jednostka": ""},
        {"region": ""},
        {"cena": "0"},
    ],
)
def test_niepelne_notowanie_jest_odrzucane(zmiana):
    wiersz = {
        "produkt": "Żyto",
        "jednostka": "zł/t",
        "region": "lubelskie",
        "cena": "700",
    }
    wiersz.update(zmiana)

    with pytest.raises(ValueError):
        wczytaj_csv([wiersz])


def test_kolumny_zsrir_rozpoznajemy_mimo_innych_nazw():
    kolumny = dopasuj_kolumny(
        ["Wyszczególnienie", "Jedn.", "Województwo", "Średnia cena", "Uwagi"]
    )

    assert kolumny["produkt"] == "Wyszczególnienie"
    assert kolumny["jednostka"] == "Jedn."
    assert kolumny["region"] == "Województwo"
    assert kolumny["cena"] == "Średnia cena"


def test_brak_kolumny_w_pliku_zsrir_to_blad():
    with pytest.raises(ValueError, match="brakuje kolumn"):
        dopasuj_kolumny(["Wyszczególnienie", "Jedn.", "Uwagi"])


def test_zsrir_pomija_tygodnie_bez_notowania():
    wiersze = [
        {
            "Wyszczególnienie": "Rzepak",
            "Jedn.": "zł/t",
            "Województwo": "wielkopolskie",
            "Średnia cena": "1 890,00",
        },
        {
            "Wyszczególnienie": "Rzepak",
            "Jedn.": "zł/t",
            "Województwo": "podlaskie",
            "Średnia cena": "-",
        },
    ]

    notowania = wczytaj_zsrir(wiersze)

    # Brak notowania zostaje brakiem — ceny z sąsiedniego regionu nie
    # przepisujemy.
    assert len(notowania) == 1
    assert notowania[0].region == "wielkopolskie"
    assert notowania[0].status == DO_WERYFIKACJI


def test_zbuduj_grupuje_po_produkcie_i_zapisuje_tydzien():
    dane = zbuduj(
        [
            Notowanie("Pszenica konsumpcyjna", "zł/t", "mazowieckie", 920.5),
            Notowanie("Pszenica konsumpcyjna", "zł/t", "lubelskie", 905.0),
            Notowanie("Żyto", "zł/t", "mazowieckie", 700.0),
        ],
        od=dt.date(2026, 10, 6),
        do=dt.date(2026, 10, 12),
        wzorzec=WZORZEC,
    )

    assert dane["tydzien"] == {"od": "2026-10-06", "do": "2026-10-12"}
    assert [p["nazwa"] for p in dane["produkty"]] == [
        "Pszenica konsumpcyjna",
        "Żyto",
    ]
    assert len(dane["produkty"][0]["ceny"]) == 2
    assert dane["wersja"] == "2026.10.12.1"


def test_tydzien_na_wspak_jest_odrzucany():
    with pytest.raises(ValueError):
        zbuduj(
            [Notowanie("Żyto", "zł/t", "mazowieckie", 700.0)],
            od=dt.date(2026, 10, 12),
            do=dt.date(2026, 10, 6),
            wzorzec=WZORZEC,
        )


def test_plik_programu_jest_pusty_i_mowi_dlaczego():
    plik = pathlib.Path(__file__).resolve().parents[2] / "assets/dane/ceny_skupu.json"
    dane = json.loads(plik.read_text(encoding="utf-8"))

    # Cen nie wolno zmyślić: dopóki nikt nie uruchomi skryptu na prawdziwym
    # pliku notowań, plik zostaje pusty.
    assert dane["produkty"] == []
    assert dane["tydzien"] is None
    assert "skrypt" in dane["uwaga"]
