"""Testy odczytu dawek, faz BBCH i list upraw."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from parsery import odczytaj_bbch, odczytaj_dawke, rozbij_uprawy, znormalizuj


class TestDawka:
    def test_zwykla_dawka(self):
        d = odczytaj_dawke(
            "Maksymalna/zalecana dawka dla jednorazowego zastosowania: 0,14 kg/ha."
        )
        assert (d.wartosc, d.jednostka, d.odniesienie) == (0.14, "kg", "ha")
        assert d.pewnosc == "odczytana"

    def test_zakres_daje_gorna_granice(self):
        d = odczytaj_dawke("Maksymalna/zalecana dawka: 0,1-0,2 l/ha.")
        assert d.wartosc == 0.2
        assert d.pewnosc == "zakres"

    def test_dawka_maksymalna_wazniejsza_niz_zalecana(self):
        # Opis podaje najpierw maksymalną, potem zalecany zakres —
        # do bazy trafia maksymalna, bo jej nie wolno przekroczyć.
        d = odczytaj_dawke(
            "Maksymalna dawka dla jednorazowego zastosowania: 2,0 l/ha_x000D_ "
            "Zalecana dawka dla jednorazowego zastosowania: 1,0 - 1,5 l/ha"
        )
        assert d.wartosc == 2.0
        assert d.pewnosc == "odczytana"

    def test_stezenie_procentowe(self):
        d = odczytaj_dawke("Maksymalna / zalecana dawka: 0,05% (50 ml w 100 l wody).")
        assert (d.wartosc, d.jednostka, d.odniesienie) == (0.05, "%", "stezenie")

    def test_dawka_na_wielokrotnosc_jednostki(self):
        d = odczytaj_dawke("Maksymalna/zalecana dawka: 20 g/10 m2")
        assert (d.wartosc, d.jednostka, d.odniesienie) == (20.0, "g", "10 m2")

    def test_dawka_na_mase_ziarna(self):
        d = odczytaj_dawke("Maksymalna dawka: 50 ml środka/100 kg ziarna z wodą")
        assert (d.wartosc, d.jednostka, d.odniesienie) == (50.0, "ml", "100 kg ziarna")

    @pytest.mark.parametrize("tekst", ["", None, "   ", "według zaleceń doradcy"])
    def test_brak_dawki_nie_jest_zgadywany(self, tekst):
        d = odczytaj_dawke(tekst)
        assert d.wartosc is None
        assert d.pewnosc == "do_sprawdzenia"
        assert not d.znana


class TestBBCH:
    def test_pojedyncza_faza(self):
        assert odczytaj_bbch("Środek zastosować po zbiorze (BBCH 99)") == (99, 99)

    def test_zakres_faz(self):
        assert odczytaj_bbch("Opryskiwać w fazie BBCH 30-39") == (30, 39)

    def test_kilka_zakresow_daje_skrajne(self):
        assert odczytaj_bbch("od BBCH 13 do BBCH 19, powtórzyć BBCH 51-59") == (13, 59)

    def test_brak_fazy(self):
        assert odczytaj_bbch("Opryskiwać wiosną") == (None, None)


class TestUprawy:
    SLOWNIK = {
        "oberżyna",
        "ogórek",
        "papryka",
        "pomidor",
        "uprawa w szklarni",
        "odnowienia, zalesienia",
        "pszenica ozima",
    }

    def test_rozbija_liste(self):
        w = rozbij_uprawy("oberżyna, ogórek, papryka, uprawa w szklarni", self.SLOWNIK)
        assert w.rozpoznane == ["oberżyna", "ogórek", "papryka", "uprawa w szklarni"]
        assert w.do_sprawdzenia == []

    def test_nazwa_z_przecinkiem_w_srodku(self):
        w = rozbij_uprawy("odnowienia, zalesienia", self.SLOWNIK)
        assert w.rozpoznane == ["odnowienia, zalesienia"]

    def test_nieznana_uprawa_trafia_do_sprawdzenia(self):
        w = rozbij_uprawy("ogórek, babka zwyczajna", self.SLOWNIK)
        assert w.rozpoznane == ["ogórek"]
        assert w.do_sprawdzenia == ["babka zwyczajna"]

    def test_pusta_komorka(self):
        assert rozbij_uprawy(None, self.SLOWNIK).wszystkie == []

    def test_rozny_zapis_tej_samej_nazwy(self):
        # Różnice w wielkości liter i odstępach nie mogą gubić uprawy.
        w = rozbij_uprawy("PSZENICA  OZIMA ,  ogórek", self.SLOWNIK)
        assert w.rozpoznane == ["pszenica ozima", "ogórek"]

    def test_normalizacja(self):
        assert znormalizuj("Pszenica  Ozima") == "pszenica ozima"
        assert znormalizuj("żyto") == znormalizuj("ŻYTO")
