"""Testy klienta ULDK i rysowania granic — bez łączenia się z siecią."""

import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
from klient import BladUldk, adres_zapytania, odczytaj_odpowiedz  # noqa: E402
from mapa import Ksztalt, rysuj_svg, wczytaj_wkt, zasieg  # noqa: E402

ODPOWIEDZ_POPRAWNA = (
    "0\n"
    "POLYGON((22.1 51.8,22.2 51.8,22.2 51.9,22.1 51.9,22.1 51.8))|"
    "140100_2.0001.123|lubelskie|radzyński|Radzyń Podlaski|BRZOSTÓWIEC\n"
)


class TestAdres:
    def test_zapytanie_zawiera_identyfikator_i_uklad(self):
        adres = adres_zapytania("140100_2.0001.123", srid=4326)
        assert "request=GetParcelById" in adres
        assert "id=140100_2.0001.123" in adres
        assert "srid=4326" in adres
        assert "geom_wkt" in adres


class TestOdpowiedz:
    def test_poprawna_odpowiedz(self):
        dzialka = odczytaj_odpowiedz(ODPOWIEDZ_POPRAWNA, "140100_2.0001.123", 4326)
        assert dzialka.wkt.startswith("POLYGON")
        assert dzialka.srid == 4326

    def test_status_bledu_konczy_wyjatkiem(self):
        with pytest.raises(BladUldk):
            odczytaj_odpowiedz("-1 nie znaleziono dzialki\n", "140100_2.0001.1", 4326)

    def test_brak_geometrii_konczy_wyjatkiem(self):
        with pytest.raises(BladUldk):
            odczytaj_odpowiedz("0\nlubelskie|radzyński\n", "140100_2.0001.1", 4326)

    def test_pusta_odpowiedz(self):
        with pytest.raises(BladUldk):
            odczytaj_odpowiedz("", "140100_2.0001.1", 4326)


class TestGeometria:
    def test_polygon(self):
        pierscienie = wczytaj_wkt("POLYGON((0 0,1 0,1 1,0 1,0 0))")
        assert len(pierscienie) == 1
        assert len(pierscienie[0]) == 5

    def test_multipolygon(self):
        pierscienie = wczytaj_wkt(
            "MULTIPOLYGON(((0 0,1 0,1 1,0 0)),((2 2,3 2,3 3,2 2)))"
        )
        assert len(pierscienie) == 2

    def test_polygon_z_wycieciem(self):
        pierscienie = wczytaj_wkt(
            "POLYGON((0 0,4 0,4 4,0 4,0 0),(1 1,2 1,2 2,1 2,1 1))"
        )
        assert len(pierscienie) == 2

    def test_nieobslugiwana_geometria(self):
        with pytest.raises(ValueError):
            wczytaj_wkt("POINT(1 2)")

    def test_zasieg(self):
        ksztalt = Ksztalt("a", wczytaj_wkt("POLYGON((1 2,3 2,3 5,1 5,1 2))"))
        assert zasieg([ksztalt]) == (1.0, 2.0, 3.0, 5.0)


class TestRysunek:
    def test_svg_zawiera_obrys_kazdej_dzialki(self):
        ksztalty = [
            Ksztalt("140100_2.0001.123", wczytaj_wkt("POLYGON((22.1 51.8,22.2 51.8,22.2 51.9,22.1 51.9,22.1 51.8))")),
            Ksztalt("140100_2.0001.124", wczytaj_wkt("POLYGON((22.2 51.8,22.3 51.8,22.3 51.9,22.2 51.9,22.2 51.8))")),
        ]
        svg = rysuj_svg(ksztalty)
        assert svg.count("<path") == 2
        assert svg.startswith("<svg")
        assert "123" in svg and "124" in svg  # podpisy numerami działek

    def test_rysunek_nie_jest_rozciagniety(self):
        # Kwadrat w stopniach jest na naszej szerokości geograficznej prostokątem;
        # po poprawce na południk powinien być zbliżony do kwadratu.
        ksztalt = Ksztalt("a", wczytaj_wkt("POLYGON((22.0 51.0,22.1 51.0,22.1 51.1,22.0 51.1,22.0 51.0))"))
        svg = rysuj_svg([ksztalt], szerokosc=400)
        wysokosc = int(svg.split('height="')[1].split('"')[0])
        assert 300 < wysokosc < 700

    def test_brak_danych_konczy_wyjatkiem(self):
        with pytest.raises(ValueError):
            rysuj_svg([])


class TestFormatEwkt:
    """Prawdziwa usługa zwraca geometrię z przedrostkiem układu współrzędnych."""

    ODPOWIEDZ_EWKT = (
        "0\n"
        "SRID=4326;POLYGON((22.5777 51.8354,22.5778 51.8356,22.5730 51.8364,22.5777 51.8354))"
        "|061506_2.0007.138|lubelskie|powiat radzyński|Radzyń Podlaski|Brzostówiec|138\n"
    )

    def test_przedrostek_srid_jest_odczytywany(self):
        from klient import rozbierz_geometrie

        wkt, srid = rozbierz_geometrie("SRID=4326;POLYGON((0 0,1 0,1 1,0 0))")
        assert wkt.startswith("POLYGON")
        assert srid == 4326

    def test_odpowiedz_z_prawdziwej_uslugi(self):
        dzialka = odczytaj_odpowiedz(self.ODPOWIEDZ_EWKT, "061506_2.0007.138", 4326)
        assert dzialka.wkt.startswith("POLYGON")
        assert dzialka.srid == 4326
        assert dzialka.wojewodztwo == "lubelskie"
        assert dzialka.powiat == "powiat radzyński"
        assert dzialka.gmina == "Radzyń Podlaski"
        assert dzialka.obreb == "Brzostówiec"  # „region" w ULDK to obręb, nie województwo

    def test_geometria_z_odpowiedzi_daje_sie_narysowac(self):
        dzialka = odczytaj_odpowiedz(self.ODPOWIEDZ_EWKT, "061506_2.0007.138", 4326)
        svg = rysuj_svg([Ksztalt(dzialka.identyfikator, wczytaj_wkt(dzialka.wkt))])
        assert "<path" in svg
