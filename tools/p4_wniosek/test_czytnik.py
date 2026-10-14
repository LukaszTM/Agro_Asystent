"""Testy czytnika wniosku o płatności na zanonimizowanym wzorcu.

Wzorzec (`test/dane/wzorzec_wniosku.pdf`) odtwarza układ tabel X i XI opisany
w planie wraz z jego pułapkami. Wszystkie dane w nim są zmyślone.
"""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from czytnik import DzialkaRolna, Kontrola, Wniosek, _podsumuj, czytaj  # noqa: E402
from wzorzec import zbuduj  # noqa: E402

WZORZEC = Path("test/dane/wzorzec_wniosku.pdf")


@pytest.fixture(scope="module")
def wniosek() -> Wniosek:
    if not WZORZEC.exists():
        zbuduj(WZORZEC)
    return czytaj(WZORZEC)


class TestOdczyt:
    def test_liczba_dzialek_ewidencyjnych(self, wniosek):
        assert len(wniosek.dzialki_ewidencyjne) == 20

    def test_liczba_dzialek_rolnych(self, wniosek):
        assert len(wniosek.dzialki_rolne) == 34

    def test_suma_powierzchni_zgadza_sie_z_podsumowaniem(self, wniosek):
        assert wniosek.kontrola.suma_z_odczytu_ar == 2891
        assert wniosek.kontrola.suma_zgodna
        assert wniosek.kontrola.wynik_pewny

    def test_dane_dzialki_ewidencyjnej(self, wniosek):
        pierwsza = wniosek.dzialki_ewidencyjne[0]
        assert pierwsza.wojewodztwo == "MAZOWIECKIE"
        assert pierwsza.gmina == "Mokobody"
        assert pierwsza.nr_dzialki == "100/1"
        assert pierwsza.powierzchnia_ha == 0.84

    def test_dane_dzialki_rolnej(self, wniosek):
        pierwsza = wniosek.dzialki_rolne[0]
        assert pierwsza.oznaczenie == "A"
        assert pierwsza.uprawa == "pszenica ozima"
        assert pierwsza.powierzchnia_ar == 60
        assert pierwsza.platnosci == "PB, ONW"


class TestPulapkiWniosku:
    def test_nazwa_uprawy_zlamana_na_kilka_wierszy_jest_sklejana(self, wniosek):
        dluga = "mieszanka zbożowo-strączkowa na nasiona z przeznaczeniem na paszę"
        assert dluga in wniosek.uprawy

    def test_jedna_dzialka_rolna_na_kilku_ewidencyjnych(self, wniosek):
        wieloczesciowe = [d for d in wniosek.dzialki_rolne if len(d.identyfikatory) > 1]
        assert wieloczesciowe, "wzorzec zawiera takie działki"
        assert all(len(set(d.identyfikatory)) == len(d.identyfikatory) for d in wieloczesciowe)

    def test_kazda_dzialka_rolna_ma_identyfikator(self, wniosek):
        assert all(d.identyfikatory for d in wniosek.dzialki_rolne)

    def test_naglowek_strony_nie_wsiaka_w_nazwe_uprawy(self, wniosek):
        # Tabela przechodzi przez strony; nagłówek strony nie jest daną.
        assert all("WZORZEC" not in u for u in wniosek.uprawy)
        assert wniosek.kontrola.wiersze_pominiete >= 1

    def test_oznaczenia_dwuliterowe_sa_czytane(self, wniosek):
        oznaczenia = [d.oznaczenie for d in wniosek.dzialki_rolne]
        assert "Z" in oznaczenia
        assert any(len(o) == 2 for o in oznaczenia), "wniosek używa oznaczeń AA, AB…"


class TestKontrolaSumy:
    def test_rozbieznosc_sumy_jest_zglaszana(self):
        wniosek = Wniosek(
            dzialki_rolne=[DzialkaRolna(oznaczenie="A", ha=1, ar=0)],
            kontrola=Kontrola(suma_z_wniosku_ar=250),
        )
        _podsumuj(wniosek)
        assert not wniosek.kontrola.suma_zgodna
        assert not wniosek.kontrola.wynik_pewny
        assert "różni się" in wniosek.kontrola.ostrzezenia[0]

    def test_brak_podsumowania_tez_jest_zglaszany(self):
        wniosek = Wniosek(dzialki_rolne=[DzialkaRolna(oznaczenie="A", ha=1, ar=0)])
        _podsumuj(wniosek)
        assert not wniosek.kontrola.wynik_pewny
        assert "nie znaleziono podsumowania" in wniosek.kontrola.ostrzezenia[0]

    def test_niezgodna_liczba_dzialek_jest_zglaszana(self):
        wniosek = Wniosek(
            dzialki_rolne=[DzialkaRolna(oznaczenie="A", ha=1, ar=0)],
            kontrola=Kontrola(suma_z_wniosku_ar=100, liczba_z_wniosku=5),
        )
        _podsumuj(wniosek)
        assert any("działek rolnych" in o for o in wniosek.kontrola.ostrzezenia)


class TestWzorzec:
    def test_wzorzec_jest_oznaczony_jako_zmyslony(self, wniosek):
        import pdfplumber

        with pdfplumber.open(WZORZEC) as pdf:
            tekst = pdf.pages[0].extract_text() or ""
        assert "DANE ZMYŚLONE" in tekst
