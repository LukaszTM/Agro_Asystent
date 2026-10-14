"""Porównywanie nazw zapisanych na różne sposoby.

Nazwy upraw w rejestrze środków, na etykietach i we wniosku zapisuje się
niejednakowo: wielkimi literami, w liczbie mnogiej, z dopiskiem w nawiasie.
Postać porównawcza sprowadza je do wspólnego mianownika, ale **nie służy do
wyświetlania** — rolnikowi pokazujemy zawsze zapis urzędowy.
"""

from __future__ import annotations

import re
import unicodedata


def znormalizuj(nazwa: str) -> str:
    """Małe litery, bez ogonków, bez podwójnych spacji."""
    bez_ogonkow = unicodedata.normalize("NFKD", nazwa.lower())
    bez_ogonkow = "".join(z for z in bez_ogonkow if not unicodedata.combining(z))
    return re.sub(r"\s+", " ", bez_ogonkow.replace("ł", "l")).strip()


def postac_porownawcza(nazwa: str) -> str:
    """Jak ``znormalizuj``, ale dodatkowo bez dopisków, które nie zmieniają
    znaczenia nazwy uprawy: treści w nawiasach, końcowej interpunkcji
    i słów opisujących miejsce uprawy."""
    tekst = znormalizuj(nazwa)
    tekst = re.sub(r"\([^)]*\)", " ", tekst)
    tekst = re.sub(r"\b(uprawa|uprawy|uprawiane|uprawiana)\b", " ", tekst)
    tekst = re.sub(r"[.,;:]+$", "", tekst)
    return re.sub(r"\s+", " ", tekst).strip()
