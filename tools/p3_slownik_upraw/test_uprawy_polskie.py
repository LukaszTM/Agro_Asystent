"""Testy kodów EPPO dla upraw konwencjonalnych w Polsce.

Pilnują dwóch rzeczy: że kod bierze się z bazy EPPO po nazwie naukowej
(a nie z podobieństwa napisów) i że decyzji już potwierdzonej nic nie
nadpisuje po cichu.
"""

import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).parent))

import pytest  # noqa: E402

from uprawy_polskie import (  # noqa: E402
    ALIASY,
    GRUPY,
    MIEJSCA,
    POZA_ZAKRESEM,
    RODZAJOWE,
    UPRAWY,
    kod_po_nazwie_naukowej,
    scal,
    zbuduj_wiersze,
)

BAZA_EPPO = Path("dane/pobrane/p3_eppo/eppocodes_all.sqlite")
PLIK_DECYZJI = Path("assets/dane/kody_eppo_decyzje.csv")


def decyzje_z_pliku() -> dict[str, dict[str, str]]:
    """Wiersze pliku decyzji — aliasy sięgają po kody już rozstrzygnięte."""
    import csv

    from wspolne.tekst import postac_porownawcza

    if not PLIK_DECYZJI.exists():
        return {}
    with PLIK_DECYZJI.open(encoding="utf-8", newline="") as f:
        return {
            postac_porownawcza(w["nazwa_uprawy"]): w
            for w in csv.DictReader(f, delimiter=";")
        }


class TestTabele:
    def test_nazwa_trafia_do_jednej_tabeli(self):
        tabele = {
            "UPRAWY": set(UPRAWY),
            "ALIASY": set(ALIASY),
            "POZA_ZAKRESEM": set(POZA_ZAKRESEM),
            "GRUPY": set(GRUPY),
            "MIEJSCA": set(MIEJSCA),
            "RODZAJOWE": set(RODZAJOWE),
        }
        kolizje = []
        nazwy = list(tabele.items())
        for i, (nazwa_a, a) in enumerate(nazwy):
            for nazwa_b, b in nazwy[i + 1 :]:
                wspolne = a & b
                if wspolne:
                    kolizje.append(f"{nazwa_a}/{nazwa_b}: {sorted(wspolne)}")
        assert not kolizje, kolizje

    def test_alias_wskazuje_uprawe_albo_decyzje_z_pliku(self):
        plik = Path("assets/dane/kody_eppo_decyzje.csv")
        znane = set(UPRAWY)
        if plik.exists():
            import csv

            with plik.open(encoding="utf-8", newline="") as f:
                znane |= {
                    w["nazwa_uprawy"]
                    for w in csv.DictReader(f, delimiter=";")
                    if w["stan"] == "potwierdzone" and w["kod_eppo"]
                }
        brak = [w for w in ALIASY.values() if w not in znane]
        assert not brak, f"alias bez wzoru z kodem: {brak}"

    def test_miejsca_i_grupy_nie_sa_roslinami(self):
        # Nazwa zbiorcza i miejsce stosowania nigdy nie dostają kodu,
        # więc nie mogą trafić do tabeli upraw.
        assert not (set(MIEJSCA) & set(UPRAWY))
        assert not (set(GRUPY) & set(UPRAWY))


@pytest.mark.skipif(not BAZA_EPPO.exists(), reason="brak bazy EPPO")
class TestKody:
    baza = sqlite3.connect(f"file:{BAZA_EPPO}?mode=ro", uri=True)

    def test_kazda_nazwa_naukowa_daje_jeden_kod(self):
        brak = [
            f"{nazwa} ({naukowa})"
            for nazwa, (naukowa, _) in UPRAWY.items()
            if kod_po_nazwie_naukowej(self.baza, naukowa) is None
        ]
        assert not brak, f"nazwy naukowe bez jednego kodu: {brak}"

    def test_wymyslonej_nazwy_baza_nie_potwierdza(self):
        assert kod_po_nazwie_naukowej(self.baza, "Nieistniejus wymyslonus") is None

    @pytest.mark.parametrize(
        "nazwa,kod",
        [
            ("ziemniak", "SOLTU"),
            ("grusza", "PYUCO"),
            ("marchew", "DAUCA"),
            ("burak ćwikłowy", "BEAVD"),
            # Polska nazwa w EPPO prowadziła tu na dziki gatunek
            # (Ribes spicatum); uprawna porzeczka czerwona to Ribes rubrum.
            ("porzeczka czerwona", "RIBRU"),
            # EPPO ma przy Triticum monococcum polską nazwę „pszenica
            # płaskurka" — płaskurka to Triticum dicoccon.
            ("pszenica płaskurka", "TRZDI"),
            ("pszenica samopsza", "TRZMO"),
            ("brokuł", "BRSOK"),
            ("kalafior", "BRSOB"),
        ],
    )
    def test_kody_waznych_upraw(self, nazwa, kod):
        naukowa = UPRAWY[nazwa][0]
        assert kod_po_nazwie_naukowej(self.baza, naukowa) == kod

    def test_poza_zakresem_i_miejsca_bez_kodu(self):
        wiersze, klopoty = zbuduj_wiersze(self.baza, decyzje_z_pliku())
        assert not klopoty, klopoty
        for w in wiersze:
            if w["stan"] in {
                "poza_zakresem",
                "grupa_upraw",
                "nie_uprawa",
                "do_decyzji",
            }:
                assert not w["kod_eppo"], w

    def test_rodzajowe_pytaja_o_gatunek(self):
        wiersze, _ = zbuduj_wiersze(self.baza, decyzje_z_pliku())
        rodzajowe = {
            w["nazwa_uprawy"]: w for w in wiersze if w["stan"] == "rodzajowa"
        }
        assert set(rodzajowe) == set(RODZAJOWE)
        # Zamiast kodu rodzaju aplikacja dostaje pytanie i gatunki do wyboru.
        assert rodzajowe["łubin"]["nazwa_eppo"] == "Jaki łubin?"
        assert rodzajowe["łubin"]["zamiast"].split("|") == [
            "łubin biały",
            "łubin żółty",
            "łubin wąskolistny",
        ]

    def test_kazdy_gatunek_do_wyboru_ma_kod(self):
        """Lista wyboru nie może prowadzić do uprawy bez kodu EPPO."""
        wiersze, klopoty = zbuduj_wiersze(self.baza, decyzje_z_pliku())
        z_kodem = {w["nazwa_uprawy"] for w in wiersze if w["kod_eppo"]}
        brak = {
            nazwa: [g for g in gatunki if g not in z_kodem]
            for nazwa, (_, gatunki) in RODZAJOWE.items()
            if any(g not in z_kodem for g in gatunki)
        }
        assert not brak, f"gatunki bez kodu: {brak}"
        assert not klopoty, klopoty


@pytest.mark.skipif(not BAZA_EPPO.exists(), reason="brak bazy EPPO")
class TestScalanie:
    def test_decyzji_potwierdzonej_nie_nadpisujemy(self, tmp_path):
        plik = tmp_path / "decyzje.csv"
        plik.write_text(
            "nazwa_uprawy;kod_eppo;nazwa_eppo;stan;zrodlo;data\n"
            "grusza;XXXXX;ręcznie;potwierdzone;decyzja rolnika;2026-10-16\n",
            encoding="utf-8",
        )
        baza = sqlite3.connect(f"file:{BAZA_EPPO}?mode=ro", uri=True)
        wiersze, _ = zbuduj_wiersze(baza, decyzje_z_pliku())
        _, _, spory = scal(plik, wiersze)

        import csv

        with plik.open(encoding="utf-8", newline="") as f:
            po = {w["nazwa_uprawy"]: w for w in csv.DictReader(f, delimiter=";")}
        assert po["grusza"]["kod_eppo"] == "XXXXX"
        assert any("grusza" in s for s in spory), "spór musi być widoczny"

    def test_wiersz_do_decyzji_wolno_poprawic(self, tmp_path):
        plik = tmp_path / "decyzje.csv"
        plik.write_text(
            "nazwa_uprawy;kod_eppo;nazwa_eppo;stan;zrodlo;data\n"
            "grusza;;podpowiedź;do_decyzji;podpowiedź z bazy;2026-10-16\n",
            encoding="utf-8",
        )
        baza = sqlite3.connect(f"file:{BAZA_EPPO}?mode=ro", uri=True)
        wiersze, _ = zbuduj_wiersze(baza, decyzje_z_pliku())
        scal(plik, wiersze)

        import csv

        with plik.open(encoding="utf-8", newline="") as f:
            po = {w["nazwa_uprawy"]: w for w in csv.DictReader(f, delimiter=";")}
        assert po["grusza"]["kod_eppo"] == "PYUCO"
        assert po["grusza"]["stan"] == "potwierdzone"
