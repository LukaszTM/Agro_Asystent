"""Testy czytania odpowiedzi ULDK o województwie — bez sieci."""

import pytest

from wojewodztwa import KODY, odczytaj


def test_szesnascie_kodow_parzystych():
    assert len(KODY) == 16
    assert KODY[0] == "02" and KODY[-1] == "32"
    assert all(int(kod) % 2 == 0 for kod in KODY)


def test_odczytuje_nazwe_z_odpowiedzi():
    assert odczytaj("0\n06|lubelskie\n", "06") == "lubelskie"


def test_bledna_odpowiedz_nie_zgaduje_nazwy():
    with pytest.raises(ValueError):
        odczytaj("-1 brak wyników", "06")
    with pytest.raises(ValueError):
        odczytaj("0\n08|lubuskie\n", "06")
