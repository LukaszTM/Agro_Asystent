"""Testy czytnika wniosku o płatności.

Wzorzec (`test/dane/wzorzec_wniosku.pdf`) odwzorowuje układ sprawdzony na
prawdziwym wniosku za 2026 r.; wszystkie dane w nim są zmyślone.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from czytnik import (  # noqa: E402
    CzescDzialkiRolnej,
    DzialkaRolna,
    Kontrola,
    Wniosek,
    _podsumuj,
    _rozbierz_wiersz_xi,
    czytaj,
    oczysc_uprawe,
)
from wzorzec import zbuduj  # noqa: E402

WZORZEC = Path("test/dane/wzorzec_wniosku.pdf")


@pytest.fixture(scope="module")
def wniosek() -> Wniosek:
    if not WZORZEC.exists():
        zbuduj(WZORZEC)
    return czytaj(WZORZEC)


class TestOdczyt:
    def test_liczba_dzialek(self, wniosek):
        assert len(wniosek.dzialki_ewidencyjne) == 20
        assert len(wniosek.dzialki_rolne) == 34

    def test_suma_powierzchni(self, wniosek):
        assert wniosek.kontrola.suma_z_odczytu_ar == 2891

    def test_kontrola_przechodzi(self, wniosek):
        assert wniosek.kontrola.wynik_pewny, wniosek.kontrola.ostrzezenia

    def test_dane_dzialki_ewidencyjnej(self, wniosek):
        pierwsza = wniosek.dzialki_ewidencyjne[0]
        assert pierwsza.wojewodztwo == "testowe"
        assert pierwsza.gmina == "Nowa Testowa"  # nazwa dwuczłonowa
        assert pierwsza.powierzchnia_ha is not None

    def test_dane_dzialki_rolnej(self, wniosek):
        pierwsza = wniosek.dzialki_rolne[0]
        assert pierwsza.oznaczenie == "A"
        assert pierwsza.uprawa == "TUZ"
        assert pierwsza.platnosci.startswith("ONW")


class TestPulapkiPrawdziwegoWniosku:
    def test_identyfikator_zlamany_na_dwa_wiersze_jest_sklejany(self, wniosek):
        identyfikatory = [i for d in wniosek.dzialki_rolne for i in d.identyfikatory]
        assert identyfikatory
        # Pełny identyfikator to kod gminy, obręb i numer działki.
        assert all(i.count(".") >= 2 for i in identyfikatory), identyfikatory[:3]

    def test_dzialka_rolna_na_kilku_ewidencyjnych(self, wniosek):
        wieloczesciowe = [d for d in wniosek.dzialki_rolne if len(d.czesci) > 1]
        assert wieloczesciowe, "wzorzec zawiera takie działki"

    def test_czesci_sumuja_sie_do_powierzchni_dzialki(self, wniosek):
        for dzialka in wniosek.dzialki_rolne:
            suma = sum(c.powierzchnia_ar for c in dzialka.czesci)
            assert suma == dzialka.powierzchnia_ar, dzialka.oznaczenie

    def test_nazwa_uprawy_zlamana_na_dwa_wiersze(self, wniosek):
        assert "pszenica zwyczajna ozima" in wniosek.uprawy

    def test_stopka_strony_nie_wsiaka_w_nazwe_uprawy(self, wniosek):
        assert all("Status" not in u and "PLA" not in u for u in wniosek.uprawy)

    def test_kody_platnosci_nie_wsiakaja_w_nazwe_uprawy(self, wniosek):
        assert all("ONW" not in u and "PWD" not in u for u in wniosek.uprawy)

    def test_oznaczenia_dwuliterowe(self, wniosek):
        oznaczenia = [d.oznaczenie for d in wniosek.dzialki_rolne]
        assert any(len(o) == 2 for o in oznaczenia)
        assert len(set(oznaczenia)) == len(oznaczenia)


class TestRozbiorWiersza:
    def test_pelny_wiersz(self):
        w = _rozbierz_wiersz_xi(
            ["A", "owies", "1", "23", "140100_2.0001", "1", "23", "ONW,", "PWD"]
        )
        assert w["oznaczenie"] == "A"
        assert w["uprawa"] == "owies"
        assert (w["ha"], w["ar"]) == (1, 23)
        assert w["identyfikator"] == "140100_2.0001"
        assert (w["czesc_ha"], w["czesc_ar"]) == (1, 23)
        assert w["platnosci"] == "ONW, PWD"

    def test_wiersz_kolejnej_czesci_bez_oznaczenia(self):
        w = _rozbierz_wiersz_xi(["140100_2.0002", "0", "27", "ONW,", "PWD"])
        assert w["oznaczenie"] == ""
        assert w["ha"] is None  # brak powierzchni zadeklarowanej w takim wierszu
        assert (w["czesc_ha"], w["czesc_ar"]) == (0, 27)

    def test_wiersz_bez_identyfikatora(self):
        assert _rozbierz_wiersz_xi(["ozime", ".123/4"]) is None


class TestKontrole:
    def test_czesci_niezgodne_z_powierzchnia_sa_zglaszane(self):
        wniosek = Wniosek(
            dzialki_rolne=[
                DzialkaRolna(
                    oznaczenie="A", ha=1, ar=0,
                    czesci=[CzescDzialkiRolnej("140100_2.0001.1", 0, 5)],
                )
            ]
        )
        _podsumuj(wniosek)
        assert not wniosek.kontrola.wynik_pewny
        assert "części dają" in wniosek.kontrola.ostrzezenia[0]

    def test_powtorzone_oznaczenia_sa_zglaszane(self):
        wniosek = Wniosek(
            dzialki_rolne=[DzialkaRolna(oznaczenie="A"), DzialkaRolna(oznaczenie="A")]
        )
        _podsumuj(wniosek)
        assert any("powtarzają" in o for o in wniosek.kontrola.ostrzezenia)

    def test_rozbieznosc_z_podsumowaniem_gdy_wniosek_je_zawiera(self):
        wniosek = Wniosek(
            dzialki_rolne=[DzialkaRolna(oznaczenie="A", ha=1, ar=0)],
            kontrola=Kontrola(suma_z_wniosku_ar=250),
        )
        _podsumuj(wniosek)
        assert "różni się" in wniosek.kontrola.ostrzezenia[0]

    def test_brak_podsumowania_nie_jest_bledem(self):
        # Prawdziwy wniosek nie zawiera sumy powierzchni — zastępują ją
        # kontrole wewnętrzne.
        wniosek = Wniosek(dzialki_rolne=[DzialkaRolna(oznaczenie="A", ha=1, ar=0)])
        _podsumuj(wniosek)
        assert wniosek.kontrola.wynik_pewny


class TestDrobiazgi:
    def test_odsylacz_w_nazwie_uprawy(self):
        assert oczysc_uprawe("Uprawa mieszana_") == "Uprawa mieszana"
        assert oczysc_uprawe("owies zwyczajny") == "owies zwyczajny"

    def test_wzorzec_jest_oznaczony_jako_zmyslony(self):
        import pdfplumber

        with pdfplumber.open(WZORZEC) as pdf:
            tekst = " ".join((s.extract_text() or "") for s in pdf.pages)
        assert "zmyślone" in tekst.lower()
