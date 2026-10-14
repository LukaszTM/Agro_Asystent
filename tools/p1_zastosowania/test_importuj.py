"""Testy wykrywania wierszy rejestru z przesuniętymi kolumnami."""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from importuj import WZORZEC_DAWKI_W_AGROFAGU  # noqa: E402


class TestPrzesunieteKolumny:
    def test_opis_dawki_w_kolumnie_agrofag_jest_wykrywany(self):
        # Jeden taki wiersz jest w rejestrze MRiRW i w wydaniu z dane.gov.pl —
        # to błąd w źródle, nie w odczycie.
        assert WZORZEC_DAWKI_W_AGROFAGU.search(
            "Maksymalna dawka środka dla jednorazowego zastosowania: 1,4 l/ha"
        )

    def test_zwykly_agrofag_nie_jest_wykrywany(self):
        for agrofag in [
            "mszyca zbożowa, skrzypionka zbożowa",
            "septorioza paskowana liści",
            "zapobieganie kiełkowania bulw",
            "samosiewy zbóż, miotła zbożowa",
        ]:
            assert not WZORZEC_DAWKI_W_AGROFAGU.search(agrofag), agrofag
