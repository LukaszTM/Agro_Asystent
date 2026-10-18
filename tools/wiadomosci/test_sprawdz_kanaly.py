"""Testy sprawdzania kanałów RSS — bez wychodzenia do sieci."""

from __future__ import annotations

import json
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[2]))

from tools.wiadomosci.sprawdz_kanaly import (  # noqa: E402
    DO_WERYFIKACJI,
    POTWIERDZONE,
    policz_wpisy,
    sprawdz_kanal,
    sprawdz_wszystkie,
    zastosuj_wyniki,
)

RSS = b"""<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <item><title>Doplaty</title><link>https://przyklad.test/a</link></item>
  <item><title>Ceny</title><link>https://przyklad.test/b</link></item>
</channel></rss>"""

ATOM = b"""<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <entry><title>Susza</title><link href="https://drugi.test/s"/></entry>
</feed>"""

KANAL = {
    "nazwa": "Portal",
    "adres": "https://przyklad.test/rss",
    "strona": "https://przyklad.test",
    "status": "do_weryfikacji",
}


def test_liczy_wpisy_w_rss_i_atom():
    assert policz_wpisy(RSS) == 2
    assert policz_wpisy(ATOM) == 1


def test_kanal_ktory_odpowiada_jest_potwierdzony():
    wynik = sprawdz_kanal(KANAL, pobierz=lambda adres, limit: RSS)

    assert wynik.status == POTWIERDZONE
    assert wynik.wpisow == 2


def test_kanal_ktory_milczy_zostaje_do_weryfikacji():
    def nie_odpowiada(adres, limit):
        raise TimeoutError("brak odpowiedzi")

    wynik = sprawdz_kanal(KANAL, pobierz=nie_odpowiada)

    assert wynik.status == DO_WERYFIKACJI
    assert "nie odpowiada" in wynik.opis


def test_strona_html_to_nie_kanal():
    wynik = sprawdz_kanal(KANAL, pobierz=lambda adres, limit: b"<html>cos</html>")

    assert wynik.status == DO_WERYFIKACJI


def test_pusty_kanal_tez_nie_przechodzi():
    pusty = b'<?xml version="1.0"?><rss version="2.0"><channel></channel></rss>'
    wynik = sprawdz_kanal(KANAL, pobierz=lambda adres, limit: pusty)

    assert wynik.status == DO_WERYFIKACJI
    assert "bez czytelnych wpisów" in wynik.opis


def test_adres_bez_https_odrzucamy_bez_pytania_sieci():
    pytano = []

    def pobierz(adres, limit):
        pytano.append(adres)
        return RSS

    wynik = sprawdz_kanal({**KANAL, "adres": "http://przyklad.test/rss"}, pobierz=pobierz)

    assert wynik.status == DO_WERYFIKACJI
    assert pytano == []


def test_zastosuj_wyniki_zmienia_tylko_status():
    dane = {"wersja": "1", "kanaly": [dict(KANAL)]}
    wyniki = sprawdz_wszystkie(dane, pobierz=lambda adres, limit: RSS)

    nowe = zastosuj_wyniki(dane, wyniki)

    assert nowe["kanaly"][0]["status"] == POTWIERDZONE
    assert nowe["kanaly"][0]["nazwa"] == KANAL["nazwa"]
    assert nowe["wersja"] == "1"
    # Pierwotne dane zostają nietknięte.
    assert dane["kanaly"][0]["status"] == DO_WERYFIKACJI


def test_plik_programu_ma_wymagane_pola():
    plik = pathlib.Path(__file__).resolve().parents[2] / "assets/dane/kanaly_wiadomosci.json"
    dane = json.loads(plik.read_text(encoding="utf-8"))

    assert dane["kanaly"]
    for kanal in dane["kanaly"]:
        assert set(kanal) >= {"nazwa", "adres", "strona", "status"}
        assert kanal["adres"].startswith("https://")
