"""Okresy nawożenia azotem, odstępstwa i wykazy gmin (program azotanowy).

Źródło: **Dz.U. 2023 poz. 244** — rozporządzenie Rady Ministrów z dnia
31 stycznia 2023 r. w sprawie „Programu działań mających na celu zmniejszenie
zanieczyszczenia wód azotanami pochodzącymi ze źródeł rolniczych oraz
zapobieganie dalszemu zanieczyszczeniu".

Skrypt czyta **pełny tekst rozporządzenia** (`--program`) i oba wykazy gmin
(`--zal2`, `--zal3`), a potem sprawdza w tekście każdą daną, którą ma zapisać:
wiersze tabeli 2 w całości, odstępstwa z rozdziału 1.3, limit azotu, progi
obowiązku i wzór ewidencji z tabeli 15. Gdy choć jeden wzorzec się nie znajdzie,
nic nie zapisuje. Nie czytamy liczb z układu tabeli — porównujemy to, co jest
w skrypcie, z tym, co stoi w dokumencie.

Pliki do pobrania:

- pełny tekst: <https://dziennikustaw.gov.pl/D2023000024401.pdf>
- załączniki osobno: <https://www.gov.pl/web/arimr/program-azotanowy-2023>

Zgodnie z regułą 3 z CLAUDE.md skrypt uruchamia **deweloper na komputerze**;
aplikacja na telefonie nigdy nie pobiera stron ministerstwa.

Użycie:

    python3 tools/azotany/terminy_nawozenia.py \\
        --program dane/zrodla/D2023000024401.pdf \\
        --zal2 dane/zrodla/zal2_gminy_15x.pdf \\
        --zal3 dane/zrodla/zal3_gminy_25x.pdf
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from datetime import date
from pathlib import Path

import pdfplumber

ZRODLO = (
    "Dz.U. 2023 poz. 244 — rozporządzenie Rady Ministrów z 31 stycznia 2023 r. "
    "w sprawie Programu działań mających na celu zmniejszenie zanieczyszczenia "
    "wód azotanami pochodzącymi ze źródeł rolniczych"
)

#: Warstwa tekstowa Dziennika Ustaw gubi dwie litery: „ć" czyta się jako „d"
#: („przekroczyd"), a „ń" jako „o" („dzieo", „warmiosko-mazurskie"). Zamiast
#: osłabiać sprawdzanie, dopuszczamy w tych miejscach obie litery.
ZAMIENNIKI_LITER = {"ć": "[ćcd]", "ń": "[ńno]"}

#: Okresy stosowania nawozów z tabeli 2 (rozdział 1.3 ust. 1).
#: W słowniku zapisujemy je jako termin z datą graniczną **i** początkiem
#: okresu: rolnika interesuje „do kiedy", a kalendarz pokazuje jeden dzień,
#: nie trwający pół roku okres.
TERMINY = [
    {
        "id": "azotany_naturalne_stale_grunty_orne",
        "nazwa": "Obornik na gruntach ornych",
        "okres_od": "03-01",
        "data_roczna": "10-31",
        "rodzaj_nawozu": "naturalne_stale",
        "rodzaj_gruntu": "grunty_orne",
        "co_to_za_nawoz": "obornik, pomiot ptasi",
    },
    {
        "id": "azotany_naturalne_stale_tuz",
        "nazwa": "Obornik na łąkach, pastwiskach i uprawach trwałych",
        "okres_od": "03-01",
        "data_roczna": "11-30",
        "rodzaj_nawozu": "naturalne_stale",
        "rodzaj_gruntu": "tuz_uprawy_wieloletnie_trwale",
        "co_to_za_nawoz": "obornik, pomiot ptasi",
    },
    {
        "id": "azotany_mineralne_i_plynne_grunty_orne",
        "nazwa": "Gnojowica i nawozy azotowe na gruntach ornych",
        "okres_od": "03-01",
        "data_roczna": "10-20",
        "rodzaj_nawozu": "mineralne_azotowe_i_naturalne_plynne",
        "rodzaj_gruntu": "grunty_orne",
        "co_to_za_nawoz": "nawozy azotowe mineralne, gnojowica, gnojówka",
        "warianty_gmin": "nawozy_azotowe_grunty_orne",
    },
    {
        "id": "azotany_mineralne_i_plynne_tuz",
        "nazwa": "Gnojowica i nawozy azotowe na łąkach i uprawach trwałych",
        "okres_od": "03-01",
        "data_roczna": "10-31",
        "rodzaj_nawozu": "mineralne_azotowe_i_naturalne_plynne",
        "rodzaj_gruntu": "tuz_uprawy_wieloletnie_trwale",
        "co_to_za_nawoz": "nawozy azotowe mineralne, gnojowica, gnojówka",
    },
]

#: Odstępstwa z rozdziału 1.3 ust. 8 i 9. Oba dotyczą **tylko gruntów
#: ornych** — przepis wymienia wyłącznie je.
ODSTEPSTWA = [
    {
        "id": "niekorzystna_pogoda",
        "nazwa": "Niekorzystne warunki pogodowe",
        "dotyczy_gruntow": "grunty_orne",
        "do_dnia": "11-30",
        "kiedy": "nie można było dokonać zbiorów lub nawożenia z uwagi na "
                 "niekorzystne warunki pogodowe, w szczególności nadmierne "
                 "uwilgotnienie gleby",
        "dokumentowanie": "nie_wymaga",
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "rozdział 1.3 ust. 9",
        "uwagi": "Program nie wymaga osobnych zapisów. Termin graniczny "
                 "to 30 listopada.",
    },
    {
        "id": "uprawa_po_pozno_zbieranych",
        "nazwa": "Uprawa zakładana jesienią po późno zbieranych",
        "dotyczy_gruntow": "grunty_orne",
        "do_dnia": None,
        "kiedy": "zakładanie uprawy jesienią po późno zbieranych "
                 "przedplonach, buraku cukrowym, kukurydzy lub późnych "
                 "warzywach",
        "dokumentowanie": "wymaga",
        "limit_azotu_kg_na_ha": 30,
        "limit_dotyczy": "wieloskładnikowe nawozy mineralne dla zakładanej "
                         "uprawy",
        "wymagane_zapisy": [
            "termin zbioru",
            "data stosowania nawozu",
            "zastosowane nawozy",
            "dawka nawozu",
            "termin siewu jesiennej uprawy",
        ],
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "rozdział 1.3 ust. 8",
        "uwagi": "Program nie podaje dla tego odstępstwa daty granicznej — "
                 "znosi terminy z tabeli 2. Komunikat ministerstwa mówi "
                 "o końcu listopada; potwierdź u doradcy.",
    },
]

#: Zakazy nawożenia niezależne od terminu.
ZAKAZY = [
    {
        "id": "gleby_odlogowane",
        "nazwa": "Grunty odłogowane",
        "opis": "Nie stosuje się nawożenia na glebach odłogowanych. Przed "
                "planowanym zakończeniem odłogowania wolno zastosować "
                "nawozy jesienią.",
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "rozdział 1.3 ust. 11",
    },
    {
        "id": "gleba_niezdatna",
        "nazwa": "Gleba zamarznięta, zalana, nasycona wodą albo pod śniegiem",
        "opis": "Nawożenia takich gleb dotyczą przepisy ustawy o nawozach "
                "i nawożeniu — potwierdź u doradcy, zanim wyjedziesz w pole.",
        "status_weryfikacji": "do_weryfikacji",
        "zrodlo": "rozdział 1.2.1; zakaz wynika z art. 20 ust. 1 pkt 1 "
                  "i ust. 3 ustawy z dnia 10 lipca 2007 r. o nawozach "
                  "i nawożeniu",
        "uwagi": "Treść zakazu jest w ustawie, nie w Programie — nie "
                 "czytaliśmy jej.",
    },
]

#: Czego terminy nie dotyczą (rozdział 1.3 ust. 10).
WYLACZENIA = [
    "uprawy pod osłonami (szklarnie, inspekty, namioty foliowe)",
    "uprawy kontenerowe wykorzystujące technologię zamkniętego obiegu "
    "nawozów i wody",
]

#: Wcześniejsze nawożenie wiosną (rozdział 1.3 ust. 4–7).
WCZESNIEJSZE_WIOSNA = {
    "okres_od": "02-01",
    "okres_do": "02-29",
    "opis": "Przed terminem z tabeli 2 wolno nawozić w lutym, gdy średnia "
            "dobowa temperatura powietrza przejdzie przez próg.",
    "progi_temperatury": [
        {
            "stopnie_c": 3,
            "dotyczy": "rośliny zasiane jesienią, uprawy trwałe, uprawy "
                       "wieloletnie i trwałe użytki zielone",
        },
        {"stopnie_c": 5, "dotyczy": "pozostałe uprawy"},
    ],
    "dni_powyzej_progu": 5,
    "udzial_powiatu_procent": 95,
    "kto_oglasza": "Instytut Meteorologii i Gospodarki Wodnej — Państwowy "
                   "Instytut Badawczy",
    "uwagi": "Wykazy powiatów są publikowane codziennie od 1 do ostatniego "
             "dnia lutego. Gospodarstwo na terenie dwóch lub więcej powiatów "
             "bierze termin powiatu, w którym ma większą część powierzchni.",
    "status_weryfikacji": "potwierdzone",
    "zrodlo": "rozdział 1.3 ust. 4–7",
}

#: Wzór ewidencji nawożenia azotem z tabeli 15 (załącznik nr 10).
POLA_EWIDENCJI = [
    {
        "id": "data",
        "nazwa": "Data zastosowania nawozu",
        "slowa_w_dokumencie": ["Data", "zastosowania"],
    },
    {
        "id": "pole",
        "nazwa": "Pole, na którym zastosowano nawóz",
        "slowa_w_dokumencie": ["Pole, na którym", "zastosowano"],
    },
    {
        "id": "uprawa",
        "nazwa": "Uprawa, na której zastosowano nawóz (gatunek)",
        "slowa_w_dokumencie": ["Uprawa, na", "gatunek"],
    },
    {
        "id": "powierzchnia_uprawy",
        "nazwa": "Powierzchnia uprawy (ha)",
        "slowa_w_dokumencie": ["Powierzchnia", "uprawy (ha)"],
    },
    {
        "id": "powierzchnia_nawozona",
        "nazwa": "Powierzchnia, na której zastosowano nawóz (ha)",
        "slowa_w_dokumencie": ["Powierzchnia, na", "nawóz (ha)"],
    },
    {
        "id": "rodzaj_nawozu",
        "nazwa": "Rodzaj nawozu (zawartość N)",
        "slowa_w_dokumencie": ["Rodzaj nawozu", "zawartość N"],
    },
    {
        "id": "dawka_azotu_na_ha",
        "nazwa": "Dawka zastosowanego nawozu (kg N/ha)",
        "slowa_w_dokumencie": ["Dawka", "nawozu (kg N/ha)"],
    },
    {
        "id": "dawka_azotu_razem",
        "nazwa": "Dawka zastosowanego nawozu (N na zastosowaną powierzchnię "
                 "uprawy)",
        "slowa_w_dokumencie": ["zastosowaną", "powierzchnię"],
    },
    {
        "id": "data_przyorania",
        "nazwa": "Data przyorania nawozu naturalnego",
        "kiedy_wymagane": "teren o dużym nachyleniu",
        "slowa_w_dokumencie": [
            "datę przyorania lub wymieszania nawozu naturalnego z glebą",
            "na terenie o dużym nachyleniu",
        ],
    },
]

#: Warianty gminne: załącznik → data graniczna na gruntach ornych.
WARIANTY_GMIN = [
    {
        "id": "zal2_do_15_10",
        "data_roczna": "10-15",
        "zrodlo": "załącznik nr 2 (tabela 4)",
        "opis": "gminy, w których nawozy azotowe mineralne i naturalne "
                "płynne wolno stosować na gruntach ornych tylko do 15 "
                "października",
    },
    {
        "id": "zal3_do_25_10",
        "data_roczna": "10-25",
        "zrodlo": "załącznik nr 3 (tabela 5)",
        "opis": "gminy, w których nawozy azotowe mineralne i naturalne "
                "płynne wolno stosować na gruntach ornych do 25 października",
    },
]

#: Wzorce sprawdzane w pełnym tekście rozporządzenia. Każdy musi się
#: znaleźć, inaczej skrypt nic nie zapisuje.
WZORCE = [
    (
        "tabela 2 — grunty orne",
        "Grunty orne 1 marca – 20 października 1 marca – 31 października",
    ),
    (
        "tabela 2 — grunty orne w gminach z załącznika nr 2",
        "Grunty orne na terenie 1 marca – 15 października gmin objętych "
        "wykazem określonym w tabeli 4 stanowiącej załącznik nr 2 do Programu",
    ),
    (
        "tabela 2 — grunty orne w gminach z załącznika nr 3",
        "Grunty orne na terenie 1 marca – 25 października gmin objętych "
        "wykazem określonym w tabeli 5 stanowiącej załącznik nr 3 do Programu",
    ),
    (
        "tabela 2 — uprawy trwałe, wieloletnie i trwałe użytki zielone",
        "Uprawy trwałe 1 marca – 31 października 1 marca – 30 listopada "
        "Uprawy wieloletnie Trwałe użytki zielone",
    ),
    (
        "odstępstwo: uprawa po późno zbieranych (dawka i dokumentowanie)",
        "dopuszczalna dawka azotu w wieloskładnikowych nawozach mineralnych "
        "dla zakładanych upraw nie może przekroczyć dawki 30 kg N/ha; należy "
        "szczegółowo udokumentować termin zbioru, datę stosowania nawozu, "
        "zastosowane nawozy i ich dawkę oraz termin siewu jesiennej uprawy",
    ),
    (
        "odstępstwo: niekorzystne warunki pogodowe",
        "nie mogły dokonać zbiorów lub nawożenia z uwagi na niekorzystne "
        "warunki pogodowe, w szczególności nadmierne uwilgotnienie gleby; "
        "dla tych podmiotów termin graniczny stosowania nawozów to dzień "
        "30 listopada",
    ),
    (
        "wyłączenie: uprawy pod osłonami i kontenerowe",
        "Terminów stosowania nawozów określonych w tabeli 2 nie stosuje się "
        "do nawożenia upraw pod osłonami oraz upraw kontenerowych",
    ),
    (
        "zakaz: grunty odłogowane",
        "Nie stosuje się nawożenia na glebach odłogowanych",
    ),
    (
        "zakaz: gleby zamarznięte, zalane, nasycone wodą, pod śniegiem",
        "Do stosowania nawozów na glebach zamarzniętych, zalanych wodą, "
        "nasyconych wodą lub przykrytych śniegiem stosuje się przepisy "
        "art. 20 ust. 1 pkt 1 i ust. 3 ustawy",
    ),
    (
        "wcześniejsze nawożenie w lutym: progi 3°C i 5°C",
        "jest możliwe w okresie od 1 do ostatniego dnia lutego, jeżeli "
        "w przypadku roślin zasianych jesienią, upraw trwałych, upraw "
        "wieloletnich i trwałych użytków zielonych średnia dobowa "
        "temperatura powietrza przejdzie przez próg 3°C, a dla pozostałych "
        "upraw średnia dobowa temperatura powietrza przejdzie przez próg 5°C",
    ),
    (
        "przejście przez próg: pięć dni",
        "przez 5 dni następujących po sobie, każdego dnia, średnia dobowa "
        "temperatura powietrza przekroczyła 3°C",
    ),
    (
        "przejście przez próg: 95% powierzchni powiatu",
        "osiągnięcie tego kryterium na obszarze stanowiącym 95% powierzchni "
        "danego powiatu",
    ),
    (
        "limit azotu z nawozów naturalnych",
        "nie więcej niż 170 kg N w czystym składniku na 1 ha użytków rolnych",
    ),
    (
        "progi obowiązku: 10 ha albo 10 DJP",
        "na powierzchni większej lub równej 10 ha użytków rolnych lub "
        "utrzymujące zwierzęta gospodarskie w liczbie większej lub równej "
        "10 DJP według stanu średniorocznego",
    ),
    (
        "ewidencja nawożenia: przechowywanie 3 lata",
        "przechowują dokumenty, o których mowa w pkt 1 i 2, przez okres 3 lat",
    ),
    (
        "wzór ewidencji — tabela 15",
        "Tabela 15. Ewidencja zabiegów agrotechnicznych związanych "
        "z nawożeniem azotem",
    ),
]


#: Lista upraw intensywnych (załącznik nr 7). Osiem pierwszych jest
#: warunkowych: uprawa jest intensywna dopiero powyżej podanej dawki azotu.
#: Od powierzchni tych upraw zależy obowiązek planu nawożenia (powyżej 50 ha
#: — Prawo wodne, art. 105a ust. 1 pkt 2).
UPRAWY_INTENSYWNE = [
    {"nazwa": "pszenica", "prog_azotu_kg_na_ha": 120},
    {"nazwa": "pszenżyto", "prog_azotu_kg_na_ha": 100},
    {"nazwa": "żyto mieszańcowe", "prog_azotu_kg_na_ha": 100},
    {"nazwa": "kukurydza", "prog_azotu_kg_na_ha": 160},
    {"nazwa": "rzepak", "prog_azotu_kg_na_ha": 150},
    {"nazwa": "burak cukrowy", "prog_azotu_kg_na_ha": 150},
    {"nazwa": "burak pastewny", "prog_azotu_kg_na_ha": 150},
    {"nazwa": "ziemniak późny", "prog_azotu_kg_na_ha": 120},
    {"nazwa": "kapusta głowiasta biała"},
    {"nazwa": "kalafior"},
    {"nazwa": "brokuł"},
    {"nazwa": "kapusta brukselka"},
    {"nazwa": "marchew"},
    {"nazwa": "seler korzeniowy"},
    {"nazwa": "burak ćwikłowy"},
    {"nazwa": "ogórek"},
    {"nazwa": "cukinia"},
    {"nazwa": "cebula"},
    {"nazwa": "por"},
    {"nazwa": "pomidor", "pod_oslonami": True},
    {"nazwa": "ogórek", "pod_oslonami": True},
    {"nazwa": "papryka", "pod_oslonami": True},
]

#: Odległości od wód powierzchniowych, w jakich nie stosuje się nawozów
#: (tabela 1, rozdział 1.2.2).
ODLEGLOSCI_OD_WOD = [
    {
        "id": "nawozy_bez_gnojowicy",
        "nazwa": "Nawozy z wyłączeniem gnojowicy",
        "metry": 5,
        "od_czego": "brzeg jezior i zbiorników do 50 ha, cieków naturalnych, "
                    "rowów (bez rowów do 5 m) i kanałów",
    },
    {
        "id": "gnojowica",
        "nazwa": "Gnojowica",
        "metry": 10,
        "od_czego": "brzeg jezior i zbiorników do 50 ha, cieków naturalnych, "
                    "rowów (bez rowów do 5 m) i kanałów",
    },
    {
        "id": "wszystkie_20_m",
        "nazwa": "Wszystkie rodzaje nawozów",
        "metry": 20,
        "od_czego": "ujęcia wody bez strefy ochronnej, brzeg jezior "
                    "i zbiorników powyżej 50 ha, obszar morskiego pasa "
                    "nadbrzeżnego",
    },
]

#: Kiedy odległość z tabeli 1 wolno zmniejszyć o połowę.
ZMNIEJSZENIE_ODLEGLOSCI = {
    "o_ile": "o połowę",
    "nie_mniej_niz_m": 3,
    "warunki": [
        "nawozy aplikowane urządzeniami wprost do gleby",
        "pełna dawka podzielona co najmniej na 3 równe części",
    ],
    "uwagi": "Tylko na gruntach rolnych z uprawą roślin.",
}

#: Zakazy z ustawy z dnia 10 lipca 2007 r. o nawozach i nawożeniu
#: (Dz.U. 2021 poz. 76). Program azotanowy tylko do nich odsyła.
ZAKAZY_Z_USTAWY = [
    {
        "id": "gleba_niezdatna",
        "nazwa": "Gleba zamarznięta, zalana, nasycona wodą albo pod śniegiem",
        "opis": "Nawożenia takich gleb zabrania ustawa. Za zamarzniętą nie "
                "uznaje się gleby, która rozmarza co najmniej powierzchniowo "
                "w ciągu dnia.",
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "art. 20 ust. 1 pkt 1 i ust. 3 ustawy z dnia 10 lipca "
                  "2007 r. o nawozach i nawożeniu (Dz.U. 2021 poz. 76)",
        "uwagi": "Zakaz nie dotyczy stawów do chowu lub hodowli ryb.",
    },
    {
        "id": "plynne_na_warzywa",
        "nazwa": "Gnojowica i gnojówka na rośliny do bezpośredniego spożycia",
        "opis": "Nawozów naturalnych w postaci płynnej nie stosuje się "
                "podczas wegetacji roślin przeznaczonych do bezpośredniego "
                "spożycia przez ludzi.",
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "art. 20 ust. 1 pkt 2 ustawy o nawozach i nawożeniu",
    },
    {
        "id": "nawozy_amonowo_weglanowe",
        "nazwa": "Nawozy amonowo-węglanowe",
        "opis": "Stosowanie takich nawozów jest zabronione.",
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "art. 20a ustawy o nawozach i nawożeniu",
    },
    {
        "id": "mocznik_granulowany",
        "nazwa": "Mocznik w formie granulowanej",
        "opis": "Zabroniony, chyba że zawiera inhibitor ureazy albo powłokę "
                "biodegradowalną.",
        "status_weryfikacji": "potwierdzone",
        "zrodlo": "art. 20b ustawy o nawozach i nawożeniu",
    },
]

#: Wzorce sprawdzane w ustawie o nawozach i nawożeniu.
WZORCE_USTAWA_NAWOZY = [
    (
        "art. 20 ust. 1 — zakaz na glebach niezdatnych",
        "Zabrania się stosowania nawozów: 1) na glebach zamarzniętych, "
        "zalanych wodą, nasyconych wodą, pokrytych śniegiem",
    ),
    (
        "art. 20 ust. 1 pkt 2 — nawozy płynne na rośliny do spożycia",
        "naturalnych w postaci płynnej podczas wegetacji roślin "
        "przeznaczonych do bezpośredniego spożycia przez ludzi",
    ),
    (
        "art. 20 ust. 3 — gleba rozmarzająca powierzchniowo",
        "Za glebę zamarzniętą nie uznaje się gleby, która rozmarza co "
        "najmniej powierzchniowo w ciągu dnia",
    ),
    (
        "art. 20a — nawozy amonowo-węglanowe",
        "Zabrania się stosowania nawozów amonowo-węglanowych",
    ),
    (
        "art. 20b — mocznik granulowany",
        "Zabrania się stosowania mocznika w formie granulowanej, "
        "z wyłączeniem stosowania mocznika w formie granulowanej "
        "zawierającego inhibitor ureazy albo powłokę biodegradowalną",
    ),
]

#: Wzorce sprawdzane w ustawie – Prawo wodne.
WZORCE_PRAWO_WODNE = [
    (
        "art. 105a ust. 1 pkt 2 — progi obowiązku planu nawożenia",
        "posiadają gospodarstwo rolne o powierzchni powyżej 100 ha użytków "
        "rolnych, uprawiają uprawy intensywne na gruntach ornych na "
        "powierzchni powyżej 50 ha lub utrzymują obsadę większą niż 60 "
        "dużych jednostek przeliczeniowych",
    ),
    (
        "art. 105a ust. 1 — obowiązek planu nawożenia azotem",
        "są obowiązane do opracowania planu nawożenia azotem",
    ),
    (
        "art. 105a ust. 7 — wyjątek dla niestosujących nawozów naturalnych",
        "które nie stosują nawozów naturalnych lub produktów "
        "pofermentacyjnych na działkach rolnych, których są posiadaczami, "
        "nie opracowują planu nawożenia azotem",
    ),
    (
        "art. 105a ust. 9 — przechowywanie planu 3 lata",
        "Plan nawożenia azotem przechowuje się w gospodarstwie rolnym przez "
        "3 lata",
    ),
]

#: Wzorce z programu dla listy upraw intensywnych i tabeli 1.
WZORCE_PROGRAMU_DODATKOWE = [
    (
        "załącznik nr 7 — lista upraw intensywnych w uprawie polowej",
        "Lista upraw intensywnych w uprawie polowej: 1. pszenica, powyżej "
        "120 kg N/ha; 2. pszenżyto, powyżej 100 kg N/ha; 3. żyto "
        "mieszańcowe, powyżej 100 kg N/ha; 4. kukurydza, powyżej 160 kg "
        "N/ha; 5. rzepak, powyżej 150 kg N/ha; 6. burak cukrowy, powyżej "
        "150 kg N/ha; 7. burak pastewny, powyżej 150 kg N/ha; 8. ziemniak "
        "późny, powyżej 120 kg N/ha",
    ),
    (
        "załącznik nr 7 — lista upraw intensywnych pod osłonami",
        "Lista upraw intensywnych w uprawie pod osłonami: 1. pomidor; "
        "2. ogórek; 3. papryka",
    ),
    (
        "tabela 1 — odległości od wód",
        "Tabela 1. Odległości, w jakich nie stosuje się nawozów w pobliżu "
        "wód powierzchniowych",
    ),
    (
        "tabela 1 — zmniejszenie odległości o połowę",
        "mogą zostać zmniejszone o połowę (odległość jednak nie może być "
        "mniejsza niż 3 m)",
    ),
]

#: Wiersz wykazu gmin: województwo, siedmiocyfrowy kod TERYT, nazwa.
WIERSZ_WYKAZU = re.compile(r"^\s*([a-ząćęłńóśźż-]+)\s+(\d{7})\s+(.+?)\s*$")

#: Warstwa tekstowa gubi „ń" także w nazwie województwa.
POPRAWKI_WOJEWODZTW = {"warmiosko-mazurskie": "warmińsko-mazurskie"}

WOJEWODZTWA = {
    "dolnośląskie", "kujawsko-pomorskie", "lubelskie", "lubuskie", "łódzkie",
    "małopolskie", "mazowieckie", "opolskie", "podkarpackie", "podlaskie",
    "pomorskie", "śląskie", "świętokrzyskie", "warmińsko-mazurskie",
    "wielkopolskie", "zachodniopomorskie",
}


def tekst_pdf(sciezka: Path) -> str:
    """Tekst PDF-a do przeszukiwania — razem z odwróconym wariantem stron.

    Strona z tabelą 15 (wzór ewidencji) ma warstwę tekstową złożoną
    wspak: pdfplumber zwraca „.51 alebaT" zamiast „Tabela 15.". Zamiast
    zgadywać, które strony są odwrócone, dokładamy do przeszukiwanego
    tekstu każdą stronę także odwróconą. Fałszywe trafienie jest
    niemożliwe: wzorce są długimi zdaniami z przepisu.
    """
    with pdfplumber.open(sciezka) as dokument:
        strony = [strona.extract_text() or "" for strona in dokument.pages]
    prosto = [re.sub(r"\s+", " ", strona) for strona in strony]
    wspak = [strona[::-1] for strona in prosto]
    # Dziennik Ustaw przenosi wyrazy na końcu wiersza („na grun- tach"),
    # więc doklejamy wariant bez przeniesień. Łącznik bez odstępu
    # („amonowo-węglanowych") zostaje nietknięty.
    bez_przeniesien = [
        re.sub(r"(?<=\w)-\s+(?=\w)", "", strona) for strona in prosto
    ]
    return " ".join(prosto + wspak + bez_przeniesien)


def wzorzec_tolerancyjny(fragment: str) -> re.Pattern[str]:
    """Wzorzec dopuszczający wady warstwy tekstowej Dziennika Ustaw."""
    czesci = []
    for znak in fragment:
        if znak in ZAMIENNIKI_LITER:
            czesci.append(ZAMIENNIKI_LITER[znak])
        elif znak.isspace():
            czesci.append(r"\s+")
        else:
            czesci.append(re.escape(znak))
    return re.compile("".join(czesci), re.IGNORECASE)


def sprawdz_wzorce(tekst: str) -> list[str]:
    return [
        f"{opis}: nie ma tego w rozporządzeniu"
        for opis, fragment in WZORCE
        if not wzorzec_tolerancyjny(fragment).search(tekst)
    ]


def bez_ogonkow(tekst: str) -> str:
    rozlozony = unicodedata.normalize("NFKD", tekst.lower())
    return "".join(z for z in rozlozony if not unicodedata.combining(z))


def sprawdz_pola_ewidencji(tekst: str) -> list[str]:
    """Kolumny tabeli 15 — sprawdzane po słowach z nagłówka.

    Nagłówki w tabeli są łamane i poprzeplatane między kolumnami, więc
    całych zdań tam nie ma. Słowa do szukania są wypisane wprost przy
    każdej kolumnie (`slowa_w_dokumencie`), żeby nie zgadywać odmiany.
    """
    bledy = []
    for pole in POLA_EWIDENCJI:
        brakujace = [
            slowo
            for slowo in pole["slowa_w_dokumencie"]
            if not wzorzec_tolerancyjny(slowo).search(tekst)
        ]
        if brakujace:
            bledy.append(
                f"kolumna ewidencji {pole['nazwa']!r}: brak słów {brakujace}"
            )
    return bledy


def wiersze_wykazu(sciezka: Path) -> tuple[list[tuple[str, str, str]], list[str]]:
    """Rekordy wykazu gmin i linie, których nie udało się rozczytać."""
    with pdfplumber.open(sciezka) as dokument:
        linie: list[str] = []
        for strona in dokument.pages:
            linie += (strona.extract_text() or "").splitlines()

    rekordy: list[tuple[str, str, str]] = []
    nierozczytane: list[str] = []
    for linia in linie:
        if not linia.strip():
            continue
        dopasowanie = WIERSZ_WYKAZU.match(linia)
        wojewodztwo = None
        if dopasowanie:
            wojewodztwo, kod, nazwa = dopasowanie.groups()
            # „ń" czytane jako „o": „warmiosko-mazurskie". Bez tej
            # poprawki z wykazów wypadłoby 72 gminy.
            wojewodztwo = POPRAWKI_WOJEWODZTW.get(wojewodztwo, wojewodztwo)
        if wojewodztwo in WOJEWODZTWA:
            rekordy.append((wojewodztwo, kod, nazwa))
        else:
            nierozczytane.append(linia.strip())
    return rekordy, nierozczytane


def sprawdz_wykaz(
    opis: str, rekordy: list[tuple[str, str, str]], nierozczytane: list[str]
) -> list[str]:
    """Wykaz jest dobry tylko wtedy, gdy nic się nie zgubiło po drodze."""
    bledy: list[str] = []
    if not rekordy:
        bledy.append(f"{opis}: nie odczytano ani jednej gminy")
        return bledy

    # Najważniejsza kontrola: żadna pominięta linia nie może zawierać kodu
    # gminy — inaczej zgubiliśmy wiersz wykazu.
    zgubione = [
        linia for linia in nierozczytane if re.search(r"(?<!\d)\d{7}(?!\d)", linia)
    ]
    if zgubione:
        bledy.append(
            f"{opis}: {len(zgubione)} pominiętych linii zawiera kod gminy, "
            f"np. {zgubione[0]!r}"
        )

    kody = [kod for _, kod, _ in rekordy]
    powtorki = sorted({kod for kod in kody if kody.count(kod) > 1})
    if powtorki:
        bledy.append(f"{opis}: powtórzone kody gmin: {powtorki[:5]}")
    return bledy


def zapisz_gminy(sciezka: Path, warianty: list[dict], sprawdzono: date) -> None:
    sciezka.write_text(
        json.dumps(
            {
                "wersja": sprawdzono.isoformat().replace("-", "."),
                "sprawdzono": sprawdzono.isoformat(),
                "status_weryfikacji": "potwierdzone",
                "zrodlo": ZRODLO + ", załączniki nr 2 i 3 (tabele 4 i 5)",
                "dotyczy_terminu": "azotany_mineralne_i_plynne_grunty_orne",
                "opis": "Gminy, w których graniczny termin stosowania nawozów "
                        "azotowych mineralnych i naturalnych płynnych na "
                        "gruntach ornych jest inny niż domyślny. Kody to "
                        "siedmiocyfrowe identyfikatory TERYT gmin.",
                "warianty": warianty,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def zapisz_slownik(slownik: Path, sprawdzono: date) -> int:
    dane = json.loads(slownik.read_text(encoding="utf-8"))

    dane["terminy"] = [
        termin for termin in dane["terminy"] if not termin["id"].startswith("azotany_")
    ] + [
        {
            "id": termin["id"],
            "obowiazek": "program_azotanowy_ewidencja",
            "nazwa": termin["nazwa"],
            "rodzaj": "data_roczna",
            "data_roczna": termin["data_roczna"],
            "okres_od": termin["okres_od"],
            "rodzaj_nawozu": termin["rodzaj_nawozu"],
            "rodzaj_gruntu": termin["rodzaj_gruntu"],
            "co_to_za_nawoz": termin["co_to_za_nawoz"],
            **(
                {"warianty_gmin": termin["warianty_gmin"]}
                if "warianty_gmin" in termin
                else {}
            ),
            "status_weryfikacji": "potwierdzone",
            "zrodlo": ZRODLO + ", rozdział 1.3, tabela 2",
            "uwagi": "Okres stosowania zaczyna się 1 marca; w lutym wolno "
                     "wcześniej po przejściu temperatury przez próg.",
        }
        for termin in TERMINY
    ]

    dane["zasady_nawozenia_azotem"] = {
        "status_weryfikacji": "potwierdzone",
        "zrodlo": ZRODLO + ", rozdział 1.3",
        "sprawdzono": sprawdzono.isoformat(),
        "odstepstwa": ODSTEPSTWA,
        # Zakazy z programu i z ustawy o nawozach — te drugie mają swoje
        # źródło przy każdym wpisie.
        "zakazy": [
            zakaz for zakaz in ZAKAZY if zakaz["id"] != "gleba_niezdatna"
        ]
        + ZAKAZY_Z_USTAWY,
        "nie_dotyczy": WYLACZENIA,
        "wczesniejsze_wiosna": WCZESNIEJSZE_WIOSNA,
        "odleglosci_od_wod": {
            "status_weryfikacji": "potwierdzone",
            "zrodlo": ZRODLO + ", rozdział 1.2.2, tabela 1",
            "odleglosci": ODLEGLOSCI_OD_WOD,
            "zmniejszenie": ZMNIEJSZENIE_ODLEGLOSCI,
        },
    }

    dane["uprawy_intensywne"] = {
        "status_weryfikacji": "potwierdzone",
        "zrodlo": ZRODLO + ", załącznik nr 7",
        "sprawdzono": sprawdzono.isoformat(),
        "opis": "Uprawy, których powierzchnia powyżej 50 ha na gruntach "
                "ornych włącza obowiązek planu nawożenia azotem "
                "(Prawo wodne, art. 105a ust. 1 pkt 2). Przy ośmiu "
                "pierwszych uprawa jest intensywna dopiero powyżej podanej "
                "dawki azotu.",
        "uprawy": UPRAWY_INTENSYWNE,
    }

    # Obowiązek ewidencji nawożenia: progi i wzór ewidencji są teraz
    # sprawdzone w samym rozporządzeniu.
    for obowiazek in dane["obowiazki"]:
        if obowiazek["id"] != "program_azotanowy_ewidencja":
            continue
        obowiazek["podstawa"] = ZRODLO + ", rozdział 1.6 ust. 2"
        obowiazek["wymagane_pola"] = POLA_EWIDENCJI
        obowiazek["wzor"] = "tabela 15 (załącznik nr 10 do Programu)"
        obowiazek["uwagi"] = (
            "Progi 10 ha UR i 10 DJP, trzyletnie przechowywanie i wzór "
            "ewidencji sprawdzone w rozporządzeniu. Wymagania nie dotyczą "
            "upraw pod osłonami i kontenerowych."
        )
        for limit in obowiazek.get("limity", []):
            if limit["id"] == "limit_azotu_z_nawozow_naturalnych":
                limit["zrodlo"] = ZRODLO + ", rozdział 1.5 ust. 1"

    for obowiazek in dane["obowiazki"]:
        if obowiazek["id"] != "program_azotanowy_plan":
            continue
        obowiazek["podstawa"] = (
            "ustawa z dnia 20 lipca 2017 r. – Prawo wodne, art. 105a ust. 1; "
            "lista upraw intensywnych: " + ZRODLO + ", załącznik nr 7"
        )
        obowiazek["przechowywanie_lat"] = 3
        obowiazek["uwagi"] = (
            "Progi z art. 105a ust. 1 pkt 2 sprawdzone w ustawie: powyżej "
            "100 ha UR, powyżej 50 ha upraw intensywnych na gruntach ornych "
            "albo powyżej 60 DJP. Plan wymagany jest też przy chowie drobiu "
            "powyżej 40 000 stanowisk, świń powyżej 2000 stanowisk (albo 750 "
            "stanowisk dla macior) oraz przy nabywaniu nawozu naturalnego od "
            "importera — tego aplikacja nie ocenia. Nie dotyczy podmiotów, "
            "które nie stosują nawozów naturalnych na swoich działkach "
            "(art. 105a ust. 7). Plan przechowuje się 3 lata "
            "(art. 105a ust. 9)."
        )

    slownik.write_text(
        json.dumps(dane, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return len(TERMINY)


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Wpisuje do słownika reguł okresy nawożenia azotem, odstępstwa, "
            "zakazy i wykazy gmin z programu azotanowego (Dz.U. 2023 poz. 244)."
        )
    )
    parser.add_argument(
        "--program",
        type=Path,
        required=True,
        help="pełny tekst rozporządzenia (Dz.U. 2023 poz. 244)",
    )
    parser.add_argument(
        "--zal2",
        type=Path,
        required=True,
        help="załącznik nr 2: wykaz gmin z terminem do 15 października",
    )
    parser.add_argument(
        "--zal3",
        type=Path,
        required=True,
        help="załącznik nr 3: wykaz gmin z terminem do 25 października",
    )
    parser.add_argument(
        "--ustawa-nawozy",
        type=Path,
        default=None,
        help="ustawa o nawozach i nawożeniu (Dz.U. 2021 poz. 76) — zakazy",
    )
    parser.add_argument(
        "--prawo-wodne",
        type=Path,
        default=None,
        help="ustawa – Prawo wodne (art. 105a) — progi planu nawożenia",
    )
    parser.add_argument(
        "--slownik",
        type=Path,
        default=Path("assets/dane/reguly_prawne.json"),
        help="słownik reguł prawnych aplikacji",
    )
    parser.add_argument(
        "--gminy",
        type=Path,
        default=Path("assets/dane/gminy_terminy_azotowe.json"),
        help="plik z wykazami gmin",
    )
    parser.add_argument(
        "--sprawdz-tylko",
        action="store_true",
        help="odczytaj i sprawdź, ale nie zapisuj plików",
    )
    argumenty = parser.parse_args()

    bledy: list[str] = []

    tekst = tekst_pdf(argumenty.program)
    bledy += sprawdz_wzorce(tekst)
    bledy += sprawdz_pola_ewidencji(tekst)
    bledy += [
        f"{opis}: nie ma tego w rozporządzeniu"
        for opis, fragment in WZORCE_PROGRAMU_DODATKOWE
        if not wzorzec_tolerancyjny(fragment).search(tekst)
    ]
    print(
        f"wzorców sprawdzonych w rozporządzeniu: "
        f"{len(WZORCE) + len(WZORCE_PROGRAMU_DODATKOWE)}, "
        f"kolumn ewidencji: {len(POLA_EWIDENCJI)}"
    )

    # Zakazy i progi planu są w ustawach, nie w programie — każdą wartość
    # sprawdzamy w jej własnym dokumencie.
    for opis_pliku, sciezka, wzorce in (
        ("ustawa o nawozach i nawożeniu", argumenty.ustawa_nawozy,
         WZORCE_USTAWA_NAWOZY),
        ("ustawa – Prawo wodne", argumenty.prawo_wodne, WZORCE_PRAWO_WODNE),
    ):
        if sciezka is None:
            bledy.append(
                f"{opis_pliku}: nie podano pliku, a bez niego nie wolno "
                "zapisać zakazów ani progów z tej ustawy"
            )
            continue
        tekst_ustawy = tekst_pdf(sciezka)
        brakujace = [
            f"{opis_pliku} / {opis}: nie ma tego w dokumencie"
            for opis, fragment in wzorce
            if not wzorzec_tolerancyjny(fragment).search(tekst_ustawy)
        ]
        bledy += brakujace
        if not brakujace:
            print(f"{opis_pliku}: {len(wzorce)} wzorców odnalezionych")

    warianty: list[dict] = []
    for wariant, sciezka in (
        (WARIANTY_GMIN[0], argumenty.zal2),
        (WARIANTY_GMIN[1], argumenty.zal3),
    ):
        rekordy, nierozczytane = wiersze_wykazu(sciezka)
        opis = f"{wariant['zrodlo']} ({sciezka.name})"
        bledy += sprawdz_wykaz(opis, rekordy, nierozczytane)
        wojewodztwa = {wojewodztwo for wojewodztwo, _, _ in rekordy}
        dzien = wariant["data_roczna"]
        print(
            f"{opis}: {len(rekordy)} gmin w {len(wojewodztwa)} województwach, "
            f"termin do {dzien[3:]}.{dzien[:2]}"
        )
        warianty.append(
            {
                "id": wariant["id"],
                "data_roczna": wariant["data_roczna"],
                "zrodlo": wariant["zrodlo"],
                "opis": wariant["opis"],
                "liczba_gmin": len(rekordy),
                "gminy": sorted(kod for _, kod, _ in rekordy),
            }
        )

    wspolne = set(warianty[0]["gminy"]) & set(warianty[1]["gminy"])
    if wspolne:
        bledy.append(
            f"gminy w obu wykazach naraz: {sorted(wspolne)[:5]} — "
            "termin byłby niejednoznaczny"
        )

    if bledy:
        print("Odczyt się nie broni (nic nie zapisuję):")
        for blad in bledy:
            print(" •", blad)
        return 1

    print(
        f"terminy: {len(TERMINY)}, odstępstwa: {len(ODSTEPSTWA)}, "
        f"zakazy: {len(ZAKAZY) - 1 + len(ZAKAZY_Z_USTAWY)}, "
        f"uprawy intensywne: {len(UPRAWY_INTENSYWNE)}, "
        f"odległości od wód: {len(ODLEGLOSCI_OD_WOD)}"
    )

    if argumenty.sprawdz_tylko:
        return 0

    dzisiaj = date.today()
    zapisz_gminy(argumenty.gminy, warianty, dzisiaj)
    ile = zapisz_slownik(argumenty.slownik, dzisiaj)
    print(f"zapisano {ile} terminów i zasady nawożenia do {argumenty.slownik}")
    print(f"zapisano wykazy gmin do {argumenty.gminy}")
    print("Pamiętaj o podniesieniu pola „wersja” w słowniku reguł.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
