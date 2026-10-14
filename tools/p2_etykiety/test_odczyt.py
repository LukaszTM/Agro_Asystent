"""Testy odczytu karencji i pozostałych okresów z etykiety.

Fragmenty pochodzą z prawdziwych etykiet pobranych ze stron MRiRW.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from odczyt import (  # noqa: E402
    odczytaj_etykiete,
    odczytaj_karencje,
    odczytaj_liczbe_zabiegow,
    odczytaj_prewencje,
)

KARENCJA_PROSTA = (
    "Okres od ostatniego zastosowania środka do dnia zbioru rośliny uprawnej "
    "(okres karencji): 3 dni. Okres od ostatniego zastosowania środka na rośliny "
    "przeznaczone na paszę do dnia, w którym zwierzęta mogą być karmione: 7 dni"
)

KARENCJA_WG_UPRAW = (
    "Okres od ostatniego zastosowania środka do dnia zbioru rośliny uprawnej "
    "(okres karencji): Oberżyna, ogórek, papryka, pomidor, truskawka,– 3 dni; "
    "Chryzantema, gerbera, róża – nie dotyczy. Okres prewencji dla pszczół: 96 godzin. "
    "WARUNKI PRZECHOWYWANIA I BEZPIECZNEGO USUWANIA ŚRODKA"
)

KARENCJA_ZŁAMANA = (
    "Okres od ostatniego zastosowania środka do dnia zbioru rośliny uprawnej\n"
    "(okres karencji): pszenica ozima, jęczmień ozimy, pszenżyto ozime,\n"
    "żyto ozime, pszenica jara, jęczmień jary – 42 dni"
)


class TestKarencja:
    def test_jedna_wartosc_dla_calej_etykiety(self):
        karencje, _ = odczytaj_karencje(KARENCJA_PROSTA)
        assert len(karencje) == 1
        assert karencje[0].dni == 3
        assert karencje[0].stan == "dni"
        assert karencje[0].uprawy == ()

    def test_nie_bierze_karencji_dla_pasz(self):
        # Druga liczba w tekście (7 dni) dotyczy pasz — nie wolno jej pomylić
        # z karencją do zbioru.
        karencje, _ = odczytaj_karencje(KARENCJA_PROSTA)
        assert [k.dni for k in karencje] == [3]

    def test_rozne_uprawy_rozna_karencja(self):
        karencje, _ = odczytaj_karencje(KARENCJA_WG_UPRAW)
        assert len(karencje) == 2
        pierwsza, druga = karencje
        assert pierwsza.dni == 3
        assert "ogórek" in pierwsza.uprawy
        assert druga.stan == "nie_dotyczy"
        assert druga.dni is None
        assert "róża" in druga.uprawy

    def test_konczy_fragment_przed_kolejna_sekcja(self):
        _, fragment = odczytaj_karencje(KARENCJA_WG_UPRAW)
        assert "WARUNKI PRZECHOWYWANIA" not in fragment
        assert "prewencji" not in fragment

    def test_lista_upraw_zlamana_do_nowej_linii(self):
        karencje, _ = odczytaj_karencje(KARENCJA_ZŁAMANA)
        assert len(karencje) == 1
        assert karencje[0].dni == 42
        assert "żyto ozime" in karencje[0].uprawy

    def test_brak_zdania_o_karencji(self):
        karencje, fragment = odczytaj_karencje("Etykieta bez takiej informacji.")
        assert karencje == []
        assert fragment is None


class TestPrewencja:
    def test_okres_w_dniach(self):
        tekst, dni = odczytaj_prewencje(
            "(okres prewencji): 2 dni. Okres od ostatniego zastosowania…"
        )
        assert dni == 2
        assert "2 dni" in tekst

    def test_opis_slowny_bez_liczby_dni(self):
        tekst, dni = odczytaj_prewencje(
            "(okres prewencji): nie wchodzić do czasu całkowitego wyschnięcia cieczy"
        )
        assert dni is None
        assert "wyschnięcia" in tekst


class TestLiczbaZabiegow:
    def test_zapis_z_sezonem(self):
        ile, sezon, rozna = odczytaj_liczbe_zabiegow(
            "Maksymalna liczba zabiegów w sezonie wegetacyjnym: 2."
        )
        assert (ile, sezon, rozna) == (2, "wegetacyjnym", False)

    def test_zapis_skrocony(self):
        ile, sezon, rozna = odczytaj_liczbe_zabiegow("Liczba zabiegów: 2")
        assert (ile, sezon, rozna) == (2, None, False)

    def test_rozne_wartosci_dla_upraw_sa_oznaczone(self):
        ile, _, rozna = odczytaj_liczbe_zabiegow(
            "Liczba zabiegów: 2 … Maksymalna liczba zabiegów w sezonie wegetacyjnym: 4"
        )
        assert ile == 4
        assert rozna is True

    def test_brak_informacji(self):
        assert odczytaj_liczbe_zabiegow("Etykieta bez tej informacji") == (None, None, False)


class TestCalaEtykieta:
    def test_skan_bez_warstwy_tekstowej(self):
        odczyt = odczytaj_etykiete("ETYKIETA", stron=4)
        assert odczyt.stan == "skan"
        assert odczyt.karencje == []

    def test_etykieta_pelna(self):
        odczyt = odczytaj_etykiete(
            KARENCJA_WG_UPRAW + " Maksymalna liczba zabiegów w sezonie wegetacyjnym: 2."
            + " wypełniacz" * 40,
            stron=1,
        )
        assert odczyt.stan == "odczytana"
        assert odczyt.liczba_zabiegow == 2
        assert len(odczyt.karencje) == 2

    def test_sama_karencja_bez_liczby_zabiegow_to_odczyt_czesciowy(self):
        odczyt = odczytaj_etykiete(KARENCJA_PROSTA + " wypełniacz" * 40, stron=1)
        assert odczyt.stan == "czesciowa"
