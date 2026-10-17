"""Testy danych norm GAEC.

Pilnują dwóch rzeczy: że każda wartość w słowniku ma dosłowne oparcie
w tekście aktu i że kontrola naprawdę przerywa zapis, gdy przepis się
zmieni. Samego PDF nie ma w repozytorium (`dane/` jest w .gitignore), więc
testy wymagające aktu pomijają się, gdy go nie ma.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

import pytest  # noqa: E402

from normy_gaec import (  # noqa: E402
    FORMY_OKRYWY,
    PRACE_KRAJOBRAZOWE,
    NORMY,
    ZWOLNIENIA,
    do_regul,
    obce_znaki,
    sprawdz,
    tekst_aktu,
)

AKT = Path("dane/pobrane/warunkowosc/D20251674.pdf")


def test_kazda_norma_ma_numer_opis_i_status():
    for norma in NORMY:
        assert norma["numer"].startswith("GAEC "), norma
        assert norma["opis"], norma["numer"]
        assert norma["status_weryfikacji"] in {"potwierdzone", "do_weryfikacji"}


def test_norma_liczona_mowi_czego_potrzebuje_od_rolnika():
    for norma in NORMY:
        if norma["aplikacja_liczy"]:
            assert norma["co_rolnik_podaje"], norma["numer"]
        else:
            assert norma["dlaczego_nie_liczy"], norma["numer"]


def test_progi_i_terminy_maja_identyfikatory_bez_powtorzen():
    for norma in NORMY:
        idki = [p["id"] for p in norma.get("progi", [])]
        assert len(set(idki)) == len(idki), norma["numer"]
        terminy = [t["id"] for t in norma.get("terminy", [])]
        assert len(set(terminy)) == len(terminy), norma["numer"]


def test_zwolnienia_wskazuja_istniejace_normy():
    idki = {n["id"] for n in NORMY}
    for zwolnienie in ZWOLNIENIA:
        dotyczy = zwolnienie["dotyczy_norm"]
        if isinstance(dotyczy, list):
            assert set(dotyczy) <= idki, zwolnienie["id"]
        else:
            assert dotyczy == "wszystkich", zwolnienie["id"]


def test_zwolnienia_z_prawa_unijnego_sa_do_weryfikacji():
    # EUR-Lex jest niedostępny z komputera, na którym to powstało, więc
    # wartość pochodzi z komunikatu ARiMR i musi o tym mówić.
    unijne = [
        z
        for z in ZWOLNIENIA
        if z["id"] in {"male_gospodarstwo", "gaec7_do_30ha"}
    ]
    assert len(unijne) == 2
    for zwolnienie in unijne:
        assert zwolnienie["status_weryfikacji"] == "do_weryfikacji"
        assert "2025/2649" in zwolnienie["zrodlo"]


def test_blok_do_regul_nie_wynosi_kontroli_do_slownika():
    blok = do_regul()
    assert "poz. 1674" in blok["zrodlo"]
    for norma in blok["normy"]:
        assert "kontrola" not in norma, norma["numer"]


def test_formy_okrywy_maja_wariant_bez_okrywy_i_wlasne_identyfikatory():
    # Rolnik musi móc powiedzieć „nic tu nie rośnie" — bez tego aplikacja
    # liczyłaby każde pole jako pokryte.
    bez_okrywy = [f for f in FORMY_OKRYWY if not f["licz_jako_okrywe"]]
    assert len(bez_okrywy) == 1
    liczone = [f for f in FORMY_OKRYWY if f["licz_jako_okrywe"]]
    assert len(liczone) >= 2
    idki = [f["id"] for f in FORMY_OKRYWY]
    assert len(set(idki)) == len(idki)
    for forma in FORMY_OKRYWY:
        assert forma["nazwa"] and forma["opis"], forma["id"]


def test_formy_okrywy_ida_do_slownika_jako_do_weryfikacji():
    # Rozporządzenie form nie wymienia — lista jest z komunikatu ARiMR,
    # więc nie wolno jej podawać jako potwierdzonej.
    blok = do_regul()["formy_okrywy"]
    assert blok["status_weryfikacji"] == "do_weryfikacji"
    assert "ARiMR" in blok["zrodlo"]
    assert len(blok["formy"]) == len(FORMY_OKRYWY)


def test_obce_znaki_lapia_homoglif_z_cyrylicy():
    # Cyrylickie \u0430 wygląda jak polskie „a”, a psuje porównania nazw.
    assert obce_znaki({"opis": "ozimin\u0430"}) == ["„\u0430” (U+0430)"]
    assert obce_znaki(["dobry opis", {"a": 1, "b": None}]) == []
    assert obce_znaki(do_regul()) == []


def test_prace_krajobrazowe_wskazuja_istniejacy_termin_normy():
    # Praca nie trzyma własnych dat — wskazuje termin normy, więc zmiana
    # okresu w przepisie przechodzi do aplikacji bez zmiany kodu.
    przycinanie = next(
        p for p in PRACE_KRAJOBRAZOWE if p["id"] == "przycinanie_drzew"
    )
    gaec8 = next(n for n in NORMY if n["id"] == przycinanie["norma"])
    terminy = [t["id"] for t in gaec8["terminy"]]
    assert przycinanie["zakaz_w_okresie"] in terminy


def test_prace_krajobrazowe_maja_wariant_wylaczony_i_zawsze_ostrzegany():
    idki = {p["id"]: p for p in PRACE_KRAJOBRAZOWE}
    # Wierzby i drzewa owocowe przepis wyłącza z zakazu okresowego.
    assert idki["przycinanie_wylaczone"]["zakaz_w_okresie"] is None
    # Niszczenie elementów krajobrazu jest zabronione cały rok.
    assert idki["usuwanie_elementu"]["zawsze_ostrzegaj"] is True
    assert idki["inna"]["norma"] is None


def test_prace_krajobrazowe_ida_do_slownika_jako_podpowiedz():
    blok = do_regul()["prace_krajobrazowe"]
    assert blok["status_weryfikacji"] == "podpowiedz"
    assert len(blok["prace"]) == len(PRACE_KRAJOBRAZOWE)


@pytest.mark.skipif(not AKT.exists(), reason="brak tekstu jednolitego")
class TestWobecAktu:
    def test_wszystkie_wartosci_stoja_w_akcie(self):
        assert sprawdz(tekst_aktu(AKT)) == []

    def test_akt_bez_jednego_zwrotu_przerywa_zapis(self):
        # Tak zachowa się skrypt, gdy ministerstwo zmieni próg.
        tekst = tekst_aktu(AKT).replace("co najmniej 40 %", "co najmniej 50 %")
        bledy = sprawdz(tekst)
        assert any("co najmniej 40 %" in b for b in bledy)

    def test_powrot_uchylonego_przepisu_tez_przerywa_zapis(self):
        tekst = tekst_aktu(AKT).replace("§ 6. 1. (uchylony)", "§ 6. 1. ")
        assert any("uchylenia § 6 ust. 1" in b for b in sprawdz(tekst))

    def test_tekst_aktu_sklada_wyrazy_lamane_na_koncu_wiersza(self):
        # „po-\nwierzchni" musi wrócić jako jedno słowo, inaczej żaden
        # dłuższy zwrot by się nie znalazł.
        tekst = tekst_aktu(AKT)
        assert "powierzchni" in tekst
        assert "po- wierzchni" not in tekst
        assert "\n" not in tekst
