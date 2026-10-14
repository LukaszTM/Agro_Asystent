"""Testy dopasowywania nazw upraw do nazw urzędowych z rejestru."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).parent))

from slownik import SlownikUpraw  # noqa: E402
from wspolne.tekst import postac_porownawcza, znormalizuj  # noqa: E402

NAZWY = [
    "pszenica ozima",
    "jęczmień jary",
    "ogórek",
    "oberżyna",
    "łąki, pastwiska",
    "uprawa w szklarni",
    "kukurydza",
]


class TestDopasowanie:
    slownik = SlownikUpraw(NAZWY)

    def test_zapis_wielka_litera_to_dopasowanie_dokladne(self):
        d = self.slownik.dopasuj("Pszenica ozima", "etykieta")
        assert d.nazwa_urzedowa == "pszenica ozima"
        assert d.sposob == "dokladne"
        assert not d.wymaga_decyzji

    def test_roznice_w_odstepach_i_ogonkach(self):
        d = self.slownik.dopasuj("JĘCZMIEŃ   JARY", "etykieta")
        assert d.nazwa_urzedowa == "jęczmień jary"
        assert d.sposob == "dokladne"

    def test_dopisek_w_nawiasie_nie_przeszkadza(self):
        d = self.slownik.dopasuj("ogórek (pod osłonami)", "wniosek")
        assert d.nazwa_urzedowa == "ogórek"
        assert d.sposob == "zblizone"
        assert not d.wymaga_decyzji

    def test_literowka_trafia_do_recznej_decyzji(self):
        d = self.slownik.dopasuj("pszenica ozimna", "wniosek")
        assert d.nazwa_urzedowa == "pszenica ozima"
        assert d.sposob == "podobienstwo"
        assert d.wymaga_decyzji
        assert d.podobienstwo >= 0.86

    def test_nazwa_zupelnie_inna_nie_dostaje_propozycji(self):
        # Lepiej brak podpowiedzi niż podpowiedź myląca.
        d = self.slownik.dopasuj("tereny nieużytkowane rolniczo", "etykieta")
        assert d.nazwa_urzedowa is None
        assert d.sposob == "brak"
        assert d.wymaga_decyzji

    def test_zdanie_z_etykiety_nie_jest_uprawa(self):
        d = self.slownik.dopasuj("Etykieta środka ochrony roślin ATRIUM -X", "etykieta")
        assert d.sposob == "brak"

    def test_zrodlo_jest_zachowane(self):
        assert self.slownik.dopasuj("ogórek", "wniosek").zrodlo == "wniosek"


class TestPostacPorownawcza:
    def test_usuwa_nawiasy_i_slowo_uprawa(self):
        assert postac_porownawcza("Pomidor (uprawa w tunelu)") == "pomidor"

    def test_rozne_zapisy_daja_ten_sam_wynik(self):
        assert postac_porownawcza("ŻYTO  OZIME.") == postac_porownawcza("żyto ozime")

    def test_normalizacja_nie_gubi_wieloczlonowych_nazw(self):
        assert znormalizuj("Łąki, pastwiska") == "laki, pastwiska"


class TestPodpowiedzPoCzlonie:
    slownik = SlownikUpraw(NAZWY + ["cebula"])

    def test_dopisek_daje_propozycje_do_zatwierdzenia(self):
        d = self.slownik.dopasuj("cebula uprawiana na zielony szczypior", "rejestr")
        assert d.nazwa_urzedowa == "cebula"
        assert d.sposob == "podobienstwo"
        # Dopisek może zmieniać dawkę i karencję, więc człowiek musi potwierdzić.
        assert d.wymaga_decyzji

    def test_nie_proponuje_gdy_poczatek_nie_jest_uprawa(self):
        d = self.slownik.dopasuj("inne narzędzia i drobny sprzęt", "rejestr")
        assert d.nazwa_urzedowa is None
        assert d.sposob == "brak"
