"""Normy GAEC (warunkowość) jako dane z wersją — zadanie etapu 2, krok 1.

Źródło: **tekst jednolity** rozporządzenia Ministra Rolnictwa i Rozwoju Wsi
z 10 marca 2023 r. w sprawie norm oraz szczegółowych warunków ich stosowania
(Dz.U. z 2025 r. poz. 1674). Tekst z 2023 r. (Dz.U. 2023 poz. 478) jest już
w kilku miejscach nieaktualny: okrywę z § 4 i dywersyfikację z § 5 ust. 4
zmieniła nowelizacja z 26 czerwca 2024 r., a § 6 ust. 1–9 (4 % obszarów
nieprodukcyjnych) i załączniki 1–3 zostały uchylone.

Dlaczego skrypt, a nie wpisanie liczb ręcznie w JSON: **każda wartość musi
dać się odnaleźć w tekście aktu.** Treść normy jest prozą prawniczą, więc
skrypt nie próbuje jej parsować — zamiast tego trzyma wprost wypisane progi,
terminy i wyłączenia, a przy zapisie sprawdza, czy **dosłowny zwrot** z aktu
nadal w nim stoi. Gdy ministerstwo zmieni próg albo datę, kontrola się nie
zgodzi i skrypt odmówi zapisu — zamiast po cichu zostawić w aplikacji
wartość z poprzedniego brzmienia.

Użycie:

    python3 tools/warunkowosc/normy_gaec.py --sprawdz-tylko
    python3 tools/warunkowosc/normy_gaec.py \\
        --akt dane/pobrane/warunkowosc/D20251674.pdf \\
        --reguly assets/dane/reguly_prawne.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

import pdfplumber

#: Akt w brzmieniu obowiązującym.
ZRODLO = (
    "Dz.U. z 2025 r. poz. 1674 — tekst jednolity rozporządzenia Ministra "
    "Rolnictwa i Rozwoju Wsi z dnia 10 marca 2023 r. w sprawie norm oraz "
    "szczegółowych warunków ich stosowania"
)

#: Data sprawdzenia aktu — idzie do słownika razem z wartościami.
SPRAWDZONO = "2026-10-17"


def tekst_aktu(pdf: Path) -> str:
    """Tekst aktu w jednej linii, bez dzielenia wyrazów na końcach wierszy.

    Dziennik Ustaw łamie wyrazy („po-\\nwierzchni") i zdania w dowolnym
    miejscu, więc bez tego sprzątania żaden dłuższy zwrot by się nie znalazł.
    """
    with pdfplumber.open(pdf) as dokument:
        surowy = "\n".join(s.extract_text() or "" for s in dokument.pages)
    bez_podzialu = re.sub(r"-\n(?=[a-ząćęłńóśźż])", "", surowy)
    return re.sub(r"\s+", " ", bez_podzialu).strip()


#: Zwolnienia z kontroli warunkowości. Dwa pierwsze są z prawa unijnego,
#: którego z tego skryptu nie pobieramy (EUR-Lex jest niedostępny), więc
#: mają status „do weryfikacji" i źródło w komunikacie ARiMR.
ZWOLNIENIA = [
    {
        "id": "male_gospodarstwo",
        "nazwa": "Gospodarstwa do 10 ha",
        "do_ha": 10,
        "dotyczy_norm": "wszystkich",
        "opis": (
            "Rolnicy, których obszar kwalifikujący się do płatności "
            "zgłoszony we wniosku geoprzestrzennym nie przekracza 10 ha, są "
            "zwolnieni z kontroli warunkowości i kar administracyjnych."
        ),
        "zrodlo": "art. 2 rozporządzenia (UE) 2025/2649",
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": (
            "Przepisany z komunikatu ARiMR o normach GAEC obowiązujących "
            "w 2026 r.; samego rozporządzenia unijnego nie dało się "
            "pobrać. Do potwierdzenia w tekście rozporządzenia."
        ),
    },
    {
        "id": "gaec7_do_30ha",
        "nazwa": "GAEC 7 — gospodarstwa do 30 ha",
        "do_ha": 30,
        "dotyczy_norm": ["gaec_7"],
        "opis": (
            "Rolnicy, których maksymalna powierzchnia gospodarstwa nie "
            "przekracza 30 ha zadeklarowanych użytków rolnych, są zwolnieni "
            "z kontroli i kar w odniesieniu do wymogów normy GAEC 7."
        ),
        "zrodlo": "art. 2 rozporządzenia (UE) 2025/2649",
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": (
            "Jak wyżej — z komunikatu ARiMR. Zwolnienie dotyczy kontroli "
            "i kar, nie samego obowiązku zmianowania."
        ),
    },
    {
        "id": "ekologiczne",
        "nazwa": "Gospodarstwa ekologiczne z certyfikatem",
        "dotyczy_norm": [
            "gaec_1",
            "gaec_3",
            "gaec_4",
            "gaec_5",
            "gaec_6",
            "gaec_7",
        ],
        "opis": (
            "Gospodarstwa prowadzące produkcję ekologiczną z certyfikatem "
            "uznaje się za spełniające normy GAEC 1, 3, 4, 5, 6 i 7 "
            "w odniesieniu do działek ekologicznych oraz działek w okresie "
            "konwersji."
        ),
        "zrodlo": "komunikat ARiMR o normach GAEC obowiązujących w 2026 r.",
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": (
            "Rozporządzenie o normach daje przy GAEC 7 własne odstępstwo "
            "dla produkcji ekologicznej (§ 5 ust. 12); szersze uznanie "
            "pozostałych norm jest na razie tylko z komunikatu."
        ),
    },
]

#: Normy GAEC. `kontrola` to dosłowne zwroty z aktu — jeśli któregoś nie ma
#: w tekście, zapis się nie wykona.
NORMY = [
    {
        "id": "gaec_1",
        "numer": "GAEC 1",
        "nazwa": "Utrzymywanie trwałych użytków zielonych w skali kraju",
        "paragraf": None,
        "opis": (
            "Udział trwałych użytków zielonych w powierzchni użytków "
            "rolnych w skali kraju nie może zmniejszyć się o więcej niż "
            "10 % wobec wskaźnika z 2018 r."
        ),
        "aplikacja_liczy": False,
        "dlaczego_nie_liczy": (
            "Wskaźnik jest krajowy, nie gospodarstwa. Obowiązek przywrócenia "
            "TUZ powstaje dopiero po przekroczeniu progu w skali kraju "
            "i ogłasza go minister."
        ),
        "status_weryfikacji": "do_weryfikacji",
        "zrodlo": "komunikat ARiMR o normach GAEC obowiązujących w 2026 r.",
        "kontrola": [],
    },
    {
        "id": "gaec_2",
        "numer": "GAEC 2",
        "nazwa": "Ochrona torfowisk i obszarów podmokłych",
        "paragraf": "§ 1a",
        "opis": (
            "Na wyznaczonych torfowiskach i obszarach podmokłych: trwałych "
            "użytków zielonych nie przekształca się i nie zaoruje (renowacja "
            "płytką uprawą i podsiewem nie częściej niż raz na 4 lata), "
            "gruntów ornych nie zaoruje się głębiej niż 15 cm; nie wydobywa "
            "się torfu i nie buduje ani nie odnawia rowów i drenażu "
            "odwadniającego."
        ),
        "aplikacja_liczy": False,
        "dlaczego_nie_liczy": (
            "Wykaz objętych obszarów prowadzą IUNG-PIB i ARiMR "
            "(rozporządzenie z 10 marca 2025 r., Dz.U. z 2025 r. poz. 307); "
            "telefon nie wie, czy pole jest na liście."
        ),
        "status_weryfikacji": "potwierdzone",
        "kontrola": [
            "nie częściej niż raz na 4 lata",
            "głębokości 15 cm",
        ],
    },
    {
        "id": "gaec_3",
        "numer": "GAEC 3",
        "nazwa": "Zakaz wypalania gruntów rolnych",
        "paragraf": "§ 1",
        "opis": (
            "Użytków rolnych nie wypala się; ze względów zdrowia roślin "
            "dopuszcza się punktowe wypalanie roślin, ich części lub resztek "
            "pożniwnych."
        ),
        "aplikacja_liczy": False,
        "dlaczego_nie_liczy": (
            "To zakaz czynności, nie liczba do policzenia. Aplikacja pokazuje "
            "treść normy."
        ),
        "status_weryfikacji": "potwierdzone",
        "kontrola": ["Użytków rolnych nie wypala się"],
    },
    {
        "id": "gaec_4",
        "numer": "GAEC 4",
        "nazwa": "Strefy buforowe wzdłuż cieków wodnych",
        "paragraf": "§ 2",
        "opis": (
            "Nawozów, innych substancji z azotem stosowanych rolniczo ani "
            "środków ochrony roślin nie stosuje się na użytkach rolnych "
            "w odległości do 3 m od brzegu jezior i zbiorników, cieków "
            "naturalnych, rowów (z wyłączeniem rowów o szerokości do 5 m), "
            "kanałów, ujęć wody bez strefy ochronnej i pasa nadbrzeżnego."
        ),
        "aplikacja_liczy": True,
        "co_rolnik_podaje": [
            "czy pole graniczy z wodą w rozumieniu tej normy",
        ],
        "progi": [
            {
                "id": "pas_od_wody_m",
                "wartosc": 3,
                "jednostka": "m",
                "opis": "pas bez nawozów i środków ochrony roślin",
            },
            {
                "id": "row_bez_pasa_m",
                "wartosc": 5,
                "jednostka": "m",
                "opis": "rowy o szerokości do 5 m są wyłączone",
            },
        ],
        "status_weryfikacji": "potwierdzone",
        "kontrola": ["odległości do 3 m", "szerokości do 5 m"],
    },
    {
        "id": "gaec_5",
        "numer": "GAEC 5",
        "nazwa": "Uprawa na stokach",
        "paragraf": "§ 3",
        "opis": (
            "Gruntów ornych na stokach o nachyleniu co najmniej 14 % nie "
            "wykorzystuje się pod uprawy wymagające redlin wzdłuż stoku ani "
            "nie utrzymuje jako ugoru czarnego od 1 listopada do 15 lutego; "
            "w uprawach wieloletnich i sadach na takich stokach utrzymuje "
            "się w międzyrzędziach okrywę lub ściółkę."
        ),
        "aplikacja_liczy": False,
        "dlaczego_nie_liczy": (
            "Nachylenia stoku aplikacja nie zna — granice działki z ULDK nie "
            "zawierają wysokości. Nie zgadujemy."
        ),
        "progi": [
            {
                "id": "nachylenie_stoku_procent",
                "wartosc": 14,
                "jednostka": "%",
                "opis": "od tego nachylenia norma obowiązuje",
            },
        ],
        "terminy": [
            {
                "id": "ugor_czarny_zakaz",
                "od": "11-01",
                "do": "02-15",
                "opis": "zakaz utrzymywania ugoru czarnego na stoku",
            },
        ],
        "status_weryfikacji": "potwierdzone",
        "kontrola": [
            "co najmniej 14 %",
            "od dnia 1 listopada danego roku do dnia 15 lutego kolejnego roku",
        ],
    },
    {
        "id": "gaec_6",
        "numer": "GAEC 6",
        "nazwa": "Minimalna pokrywa glebowa",
        "paragraf": "§ 4",
        "opis": (
            "Okrywę ochronną gleby utrzymuje się na co najmniej 80 % gruntów "
            "ornych gospodarstwa — od dnia zbioru uprawy w plonie głównym do "
            "15 października roku zbioru — oraz w międzyrzędziach sadów od "
            "1 listopada do 15 lutego. Warunek jest spełniony także wtedy, "
            "gdy okrywy nie ma nie dłużej niż 4 tygodnie ze względu na siew "
            "ozimin lub międzyplonów."
        ),
        "aplikacja_liczy": True,
        "co_rolnik_podaje": [
            "co stanowi okrywę na polu po zbiorze",
            "datę zbioru uprawy w plonie głównym",
        ],
        "progi": [
            {
                "id": "udzial_gruntow_ornych_procent",
                "wartosc": 80,
                "jednostka": "%",
                "opis": "najmniejszy udział gruntów ornych z okrywą",
            },
            {
                "id": "przerwa_tygodnie",
                "wartosc": 4,
                "jednostka": "tygodnie",
                "opis": "dopuszczalna przerwa na siew ozimin i międzyplonów",
            },
        ],
        "terminy": [
            {
                "id": "okrywa_grunty_orne",
                "od": "zbior",
                "do": "10-15",
                "opis": "okrywa na gruntach ornych: od zbioru do 15 października",
            },
            {
                "id": "okrywa_sady",
                "od": "11-01",
                "do": "02-15",
                "opis": "okrywa w międzyrzędziach plantacji drzew owocowych",
            },
        ],
        "status_weryfikacji": "potwierdzone",
        "kontrola": [
            "co najmniej 80 %",
            "do dnia 15 października roku, w którym dokonano zbioru",
            "przez 4 tygodnie",
        ],
    },
    {
        "id": "gaec_7",
        "numer": "GAEC 7",
        "nazwa": "Zmianowanie i dywersyfikacja upraw na gruntach ornych",
        "paragraf": "§ 5",
        "opis": (
            "Przy gruntach ornych powyżej 10 ha: na co najmniej 40 % gruntów "
            "ornych inna uprawa w plonie głównym niż rok wcześniej, a na "
            "wszystkich gruntach ornych ta sama uprawa w plonie głównym nie "
            "dłużej niż 3 lata (licząc od 2023 r.). Gdy ten warunek nie jest "
            "spełniony, obowiązuje dywersyfikacja: do 30 ha co najmniej dwie "
            "uprawy i największa najwyżej 75 %, powyżej 30 ha co najmniej "
            "trzy uprawy, największa najwyżej 75 %, a dwie największe razem "
            "najwyżej 95 %."
        ),
        "aplikacja_liczy": True,
        "co_rolnik_podaje": [
            "rodzaj użytku dla każdego pola (grunty orne, TUZ, uprawy trwałe)",
            "uprawę w plonie głównym w latach poprzednich, od 2023 r.",
        ],
        "progi": [
            {
                "id": "od_ha_gruntow_ornych",
                "wartosc": 10,
                "jednostka": "ha",
                "opis": "powyżej tej powierzchni gruntów ornych norma obowiązuje",
            },
            {
                "id": "zmiana_uprawy_procent",
                "wartosc": 40,
                "jednostka": "%",
                "opis": "najmniejszy udział gruntów ornych z inną uprawą niż rok wcześniej",
            },
            {
                "id": "ta_sama_uprawa_lata",
                "wartosc": 3,
                "jednostka": "lata",
                "opis": "najdłuższy czas tej samej uprawy w plonie głównym",
                "licz_od_roku": 2023,
            },
            {
                "id": "dywersyfikacja_granica_ha",
                "wartosc": 30,
                "jednostka": "ha",
                "opis": "granica między dwoma wariantami dywersyfikacji",
            },
            {
                "id": "dywersyfikacja_do_30ha_upraw",
                "wartosc": 2,
                "jednostka": "uprawy",
                "opis": "najmniejsza liczba upraw przy gruntach ornych do 30 ha",
            },
            {
                "id": "dywersyfikacja_powyzej_30ha_upraw",
                "wartosc": 3,
                "jednostka": "uprawy",
                "opis": "najmniejsza liczba upraw przy gruntach ornych powyżej 30 ha",
            },
            {
                "id": "najwieksza_uprawa_procent",
                "wartosc": 75,
                "jednostka": "%",
                "opis": "największy udział jednej uprawy w gruntach ornych",
            },
            {
                "id": "dwie_najwieksze_uprawy_procent",
                "wartosc": 95,
                "jednostka": "%",
                "opis": "największy łączny udział dwóch upraw (powyżej 30 ha)",
            },
            {
                "id": "zwolnienie_udzial_procent",
                "wartosc": 75,
                "jednostka": "%",
                "opis": (
                    "powyżej tego udziału traw, ugorów, bobowatych albo TUZ "
                    "warunków nie stosuje się"
                ),
            },
        ],
        "wylaczenia_upraw": [
            "grunty ugorowane",
            "rośliny bobowate",
            "trawy lub inne zielne rośliny pastewne",
            "mieszanki roślin bobowatych drobnonasiennych z trawami",
            "uprawy wieloletnie",
            "plantacje nasienne kukurydzy",
        ],
        "uznanie_za_uprawe": [
            "rodzaj roślin",
            "forma jara i ozima tego samego rodzaju roślin",
            "gatunek roślin z rodzin kapustowatych, psiankowatych i dyniowatych",
            "grunt ugorowany",
            "trawy lub inne zielne rośliny pastewne",
        ],
        "spelnienie_zastepcze": (
            "Warunek 40 % uznaje się za spełniony także wtedy, gdy rolnik "
            "prowadzi rejestr zabiegów agrotechnicznych (albo ma inne "
            "dokumenty z tymi samymi informacjami) i na danej powierzchni "
            "wprowadzi wsiewkę albo po zbiorze międzyplon ozimy lub "
            "ścierniskowy."
        ),
        "status_weryfikacji": "potwierdzone",
        "kontrola": [
            "powyżej 10 ha",
            "co najmniej 40 %",
            "dłużej niż 3 lata",
            "nie wcześniej niż w 2023 r.",
            "nie więcej niż 30 ha",
            "co najmniej dwie różne uprawy",
            "co najmniej trzy różne uprawy",
            "nie może zajmować więcej niż 75 %",
            "więcej niż 95 %",
            "plantacji nasiennych kukurydzy",
        ],
    },
    {
        "id": "gaec_8",
        "numer": "GAEC 8",
        "nazwa": "Elementy krajobrazu i okres lęgowy ptaków",
        "paragraf": "§ 6 ust. 10",
        "opis": (
            "Na użytkach rolnych nie niszczy się drzew będących pomnikami "
            "przyrody, rowów o szerokości do 2 m i oczek wodnych mniejszych "
            "niż 100 m²; drzew i żywopłotów nie przycina się od 15 kwietnia "
            "do 31 lipca, z wyłączeniem wierzb, drzew owocowych i zagajników "
            "o krótkiej rotacji."
        ),
        "aplikacja_liczy": True,
        "co_rolnik_podaje": ["wpis zabiegu przycinania drzew albo żywopłotu"],
        "progi": [
            {
                "id": "row_chroniony_m",
                "wartosc": 2,
                "jednostka": "m",
                "opis": "rowy o szerokości do 2 m są chronione",
            },
            {
                "id": "oczko_wodne_m2",
                "wartosc": 100,
                "jednostka": "m²",
                "opis": "oczka wodne mniejsze niż 100 m² są chronione",
            },
        ],
        "terminy": [
            {
                "id": "zakaz_przycinania",
                "od": "04-15",
                "do": "07-31",
                "opis": "zakaz przycinania drzew i żywopłotów",
            },
        ],
        "wylaczenia_upraw": [
            "wierzby",
            "drzewa owocowe",
            "gatunki drzew, których uprawa stanowi zagajnik o krótkiej rotacji",
        ],
        "status_weryfikacji": "potwierdzone",
        "kontrola": [
            "od dnia 15 kwietnia do dnia 31 lipca",
            "nie przekracza 2 m",
            "mniejszej niż 100 m2",
        ],
    },
    {
        "id": "gaec_9",
        "numer": "GAEC 9",
        "nazwa": "Zakaz przekształcania cennych TUZ na obszarach Natura 2000",
        "paragraf": "§ 7",
        "opis": (
            "Trwałych użytków zielonych wrażliwych pod względem "
            "środowiskowym i obszarów ponownie przekształconych w trwały "
            "użytek zielony nie przekształca się i nie zaoruje."
        ),
        "aplikacja_liczy": False,
        "dlaczego_nie_liczy": (
            "Które TUZ są wyznaczone jako cenne, wie ARiMR — nie telefon."
        ),
        "status_weryfikacji": "potwierdzone",
        "kontrola": ["nie przekształca się i nie zaoruje"],
    },
]


#: Podpowiedź rodzaju użytku po nazwie uprawy.
#:
#: To **nie** jest dane z przepisu — rozporządzenie nie zawiera listy
#: „które uprawy rosną na gruntach ornych". Aplikacja podpowiada rolnikowi
#: rodzaj użytku na podstawie nazwy uprawy, a rolnik potwierdza każde pole:
#: od rodzaju użytku zależy próg 10 ha i wszystkie udziały z GAEC 7, więc
#: zgadnięta wartość dałaby zgadnięty wynik kontroli.
#:
#: Słowa są bez ogonków i małymi literami — aplikacja normalizuje nazwę
#: uprawy tą samą drogą co wyszukiwarka upraw.
RODZAJE_UZYTKU = [
    {
        "id": "grunty_orne",
        "nazwa": "Grunty orne",
        "na_wydruku": "grunty orne",
        "domyslny": True,
        "slowa": [],
    },
    {
        "id": "tuz",
        "nazwa": "Łąka lub pastwisko",
        "na_wydruku": "trwały użytek zielony",
        "domyslny": False,
        "slowa": [
            "laka",
            "laki",
            "pastwisko",
            "pastwiska",
            "tuz",
            "trwaly uzytek zielony",
            "trwale uzytki zielone",
        ],
    },
    {
        "id": "uprawy_trwale",
        "nazwa": "Sad lub uprawa trwała",
        "na_wydruku": "uprawa trwała",
        "domyslny": False,
        "slowa": [
            "sad",
            "sady",
            "plantacja",
            "chmiel",
            "szkolka",
            "jablon",
            "grusza",
            "sliwa",
            "czeresnia",
            "wisnia",
            "brzoskwinia",
            "morela",
            "orzech",
            "winorosl",
            "porzeczka",
            "malina",
            "borowka",
            "aronia",
            "agrest",
            "bez czarny",
            "miskant",
            "slazowiec",
            "wierzba energetyczna",
            "zagajnik",
        ],
    },
]


#: Wyłączenia z warunku zmianowania (§ 5 ust. 3) — jako słowa w nazwie
#: uprawy albo jako rodzaj użytku.
#:
#: Rozporządzenie wymienia kategorie („rośliny bobowate", „trawy lub inne
#: zielne rośliny pastewne"), ale **nie podaje już wykazu gatunków**:
#: załącznik nr 2 został uchylony nowelizacją z 26 czerwca 2024 r. Rodzaje
#: roślin bobowatych bierzemy więc z aktu, który taki wykaz ma i obowiązuje
#: — z tabeli 14 programu azotanowego (grupa „Bobowate" i wiersz
#: „Bobowate na zielonkę"). To **wnioskowanie**, nie cytat, dlatego każde
#: wyłączenie ma własne źródło i status; niepewne idą jako
#: „do_weryfikacji" i aplikacja mówi o tym rolnikowi.
WYLACZENIA_ZMIANOWANIA = [
    {
        "id": "grunty_ugorowane",
        "nazwa": "Grunt ugorowany",
        "slowa": ["ugor", "ugorowany", "ugorowane", "ugorowanie"],
        "po_rodzaju_uzytku": None,
        "zrodlo": "§ 5 ust. 3 — grunty ugorowane",
        "status_weryfikacji": "potwierdzone",
        "uwagi": "",
    },
    {
        "id": "bobowate",
        "nazwa": "Rośliny bobowate",
        "slowa": [
            "bobik",
            "bob",
            "groch",
            "grochy",
            "peluszka",
            "ledzwian",
            "lubin",
            "lubiny",
            "seradela",
            "soczewica",
            "soja",
            "wyka",
            "fasola",
            "ciecierzyca",
            "esparceta",
            "komonica",
            "koniczyna",
            "lucerna",
            "nostrzyk",
            "sparceta",
            "bobowate",
        ],
        "po_rodzaju_uzytku": None,
        "zrodlo": (
            "§ 5 ust. 3 pkt 1; wykaz rodzajów z tabeli 14 programu "
            "azotanowego (Dz.U. 2023 poz. 244, grupa „Bobowate” i wiersz "
            "„Bobowate na zielonkę”)"
        ),
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": (
            "Rozporządzenie o normach nie ma już wykazu gatunków — "
            "załącznik nr 2 uchylono 26 czerwca 2024 r. Lista rodzajów "
            "pochodzi z innego aktu i wymaga potwierdzenia u doradcy."
        ),
    },
    {
        "id": "trawy_pastewne",
        "nazwa": "Trawy lub inne zielne rośliny pastewne",
        "slowa": [
            "trawy",
            "trawa",
            "laka",
            "laki",
            "pastwisko",
            "pastwiska",
            "kosno-pastwiskowy",
            "zielonka",
            "zielona masa",
        ],
        "po_rodzaju_uzytku": None,
        "zrodlo": "§ 5 ust. 3 pkt 2",
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": (
            "Przepis nie wymienia gatunków traw; dopasowanie idzie po "
            "nazwie uprawy z wniosku."
        ),
    },
    {
        "id": "mieszanki_bobowatych_z_trawami",
        "nazwa": "Mieszanki bobowatych drobnonasiennych z trawami",
        "slowa": ["mieszanki bobowate z trawami", "mieszanka bobowata"],
        "po_rodzaju_uzytku": None,
        "zrodlo": "§ 5 ust. 3 pkt 3",
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": "",
    },
    {
        "id": "uprawy_wieloletnie",
        "nazwa": "Uprawy wieloletnie",
        "slowa": [],
        # Tego nie poznajemy po nazwie uprawy, a po rodzaju użytku, który
        # rolnik potwierdził przy polu.
        "po_rodzaju_uzytku": "uprawy_trwale",
        "zrodlo": "§ 5 ust. 3 pkt 4",
        "status_weryfikacji": "potwierdzone",
        "uwagi": "",
    },
    {
        "id": "plantacje_nasienne_kukurydzy",
        "nazwa": "Plantacje nasienne kukurydzy",
        "slowa": [
            "plantacja nasienna kukurydzy",
            "kukurydza nasienna",
            "kukurydza plantacja nasienna",
        ],
        "po_rodzaju_uzytku": None,
        "zrodlo": "§ 5 ust. 3 pkt 5 (od 1 stycznia 2025 r.)",
        "status_weryfikacji": "do_weryfikacji",
        "uwagi": (
            "Wniosek nie zawsze rozróżnia plantację nasienną od zwykłej "
            "kukurydzy — przy wątpliwości aplikacja pisze „do sprawdzenia”."
        ),
    },
]


#: Co przepis uznaje za **jedną uprawę** przy liczeniu zmianowania
#: i dywersyfikacji (§ 5 ust. 5).
#:
#: Przepis mówi: rodzaj roślin; forma jara i ozima tego samego rodzaju;
#: gatunek roślin z rodzin kapustowatych, psiankowatych i dyniowatych;
#: grunt ugorowany; trawy lub inne zielne rośliny pastewne. Z tego wynika
#: klucz, po którym aplikacja porównuje uprawy:
#:
#: - podstawą jest **rodzaj**, czyli pierwsze słowo nazwy („pszenica"),
#: - forma jara i ozima tego samego rodzaju to **osobne** uprawy, więc
#:   do klucza wchodzi też forma („pszenica ozima" ≠ „pszenica jara"),
#: - w trzech rodzinach liczy się **gatunek**, więc tam kluczem jest cała
#:   nazwa („kapusta biała" ≠ „kapusta pekińska").
#:
#: Wykazu gatunków tych rodzin rozporządzenie nie podaje — lista słów
#: pochodzi z klasyfikacji botanicznej, do której przepis odsyła
#: (§ 5 ust. 6). Dlatego status jest „do_weryfikacji".
KLUCZ_UPRAWY = {
    "status_weryfikacji": "do_weryfikacji",
    "opis": (
        "Jak aplikacja porównuje uprawy: po rodzaju i formie, a w trzech "
        "rodzinach po gatunku. Wynika z § 5 ust. 5 i 6; wykaz gatunków "
        "rodzin pochodzi z klasyfikacji botanicznej, nie z przepisu."
    ),
    "zrodlo": "§ 5 ust. 5 i 6",
    "formy": [
        {"id": "ozima", "slowa": ["ozima", "ozimy", "ozime", "ozimina"]},
        {"id": "jara", "slowa": ["jara", "jary", "jare", "jarzyna"]},
    ],
    "rodziny_po_gatunku": [
        {
            "id": "kapustowate",
            "nazwa": "kapustowate (Brassicaceae)",
            "slowa": [
                "kapusta",
                "brokul",
                "kalafior",
                "brukselka",
                "jarmuz",
                "kalarepa",
                "brukiew",
                "rzepak",
                "rzepik",
                "gorczyca",
                "rzodkiew",
                "rzodkiewka",
                "rzepa",
                "chrzan",
                "perko",
            ],
        },
        {
            "id": "psiankowate",
            "nazwa": "psiankowate (Solanaceae)",
            "slowa": [
                "ziemniak",
                "pomidor",
                "papryka",
                "oberzyna",
                "tyton",
            ],
        },
        {
            "id": "dyniowate",
            "nazwa": "dyniowate (Cucurbitaceae)",
            "slowa": [
                "dynia",
                "cukinia",
                "kabaczek",
                "ogorek",
                "melon",
                "arbuz",
                "patison",
            ],
        },
    ],
}


#: Co uznaje się za okrywę ochronną gleby (GAEC 6).
#:
#: Rozporządzenie mówi tylko „okrywę ochronną gleby utrzymuje się" — form
#: nie wymienia. Lista pochodzi z komunikatu ARiMR o normach GAEC
#: obowiązujących w 2026 r., dlatego ma status „do_weryfikacji", a przy
#: każdym polu decyduje **deklaracja rolnika**, nie domysł aplikacji.
FORMY_OKRYWY = [
    {
        "id": "uprawa_ozima",
        "nazwa": "Uprawa ozima",
        "opis": "Zasiana ozimina zostaje na polu przez zimę.",
        "licz_jako_okrywe": True,
        "slowa": ["ozima", "ozimy", "ozime", "ozimina", "oziminy"],
    },
    {
        "id": "miedzyplon",
        "nazwa": "Międzyplon",
        "opis": "Ozimy albo ścierniskowy, wysiany po zbiorze plonu głównego.",
        "licz_jako_okrywe": True,
        "slowa": ["miedzyplon", "miedzyplony", "poplon", "facelia"],
    },
    {
        "id": "wsiewka",
        "nazwa": "Wsiewka",
        "opis": "Wsiana w plon główny i utrzymana po zbiorze.",
        "licz_jako_okrywe": True,
        "slowa": ["wsiewka", "wsiewki"],
    },
    {
        "id": "trawy",
        "nazwa": "Trawy",
        "opis": "Trawy, bobowate drobnonasienne i ich mieszanki — na gruntach ornych.",
        "licz_jako_okrywe": True,
        "slowa": ["trawy", "trawa", "lucerna", "koniczyna"],
    },
    {
        "id": "sciernisko",
        "nazwa": "Ściernisko",
        "opis": "Pole po zbiorze, bez orki.",
        "licz_jako_okrywe": True,
        "slowa": ["sciernisko", "sciern"],
    },
    {
        "id": "resztki_pozniwne",
        "nazwa": "Resztki po zbiorze",
        "opis": "Resztki pożniwne, samosiewy albo mulcz na polu.",
        "licz_jako_okrywe": True,
        "slowa": ["resztki", "mulcz", "samosiew", "samosiewy"],
    },
    {
        "id": "ugor_zielony",
        "nazwa": "Ugór zielony",
        "opis": "Pole wyłączone z uprawy, pokryte roślinnością.",
        "licz_jako_okrywe": True,
        "slowa": ["ugor", "ugorowany", "ugorowana"],
    },
    {
        "id": "brak",
        "nazwa": "Gleba odkryta",
        "opis": "Pole zaorane albo bez okrywy — nie liczy się do 80 %.",
        "licz_jako_okrywe": False,
        # Pusta lista: gleby odkrytej nigdy nie podpowiadamy — to musi
        # powiedzieć rolnik.
        "slowa": [],
    },
]


# Litery, cyfry i znaki, jakie mogą stać w danych. Reszta to pomyłka —
# najczęściej homoglif z cyrylicy wklejony razem z tekstem ze strony.
ALFABET = "abcdefghijklmnopqrstuvwxyz" + "ąćęłńóśźż"
ZNAKI_POZA_ALFABETEM = " .,;:!?()[]{}/%+-_=\n §°²–—’„”«»"
DOZWOLONE_ZNAKI = (
    set(ALFABET)
    | set(ALFABET.upper())
    | set("0123456789")
    | set(ZNAKI_POZA_ALFABETEM)
)


def obce_znaki(dane) -> list[str]:
    """Znajduje w danych znaki, których nie ma w polskim alfabecie."""
    znalezione: list[str] = []
    if isinstance(dane, dict):
        for klucz, wartosc in dane.items():
            znalezione += obce_znaki(klucz)
            znalezione += obce_znaki(wartosc)
    elif isinstance(dane, list):
        for element in dane:
            znalezione += obce_znaki(element)
    elif isinstance(dane, str):
        for znak in dane:
            if znak not in DOZWOLONE_ZNAKI:
                znalezione.append(f"„{znak}” (U+{ord(znak):04X})")
    return sorted(set(znalezione))


def sprawdz(tekst: str) -> list[str]:
    """Kontrole negatywne: każdy zwrot z `kontrola` musi stać w akcie."""
    bledy: list[str] = []
    for norma in NORMY:
        for zwrot in norma["kontrola"]:
            if zwrot not in tekst:
                bledy.append(
                    f"{norma['numer']}: w akcie nie ma zwrotu „{zwrot}” — "
                    "sprawdź, czy przepis się nie zmienił"
                )
    # Uchylone przepisy: 4 % obszarów nieprodukcyjnych nie obowiązuje.
    # Gdyby wróciło, aplikacja musiałaby o tym mówić.
    if "§ 6. 1. (uchylony)" not in tekst:
        bledy.append(
            "w akcie nie widać uchylenia § 6 ust. 1 (4 % obszarów "
            "nieprodukcyjnych) — sprawdź brzmienie normy GAEC 8"
        )
    domyslne = [r for r in RODZAJE_UZYTKU if r["domyslny"]]
    if len(domyslne) != 1:
        bledy.append(
            "dokładnie jeden rodzaj użytku ma być podpowiedzią domyślną, "
            f"a jest ich {len(domyslne)}"
        )
    for rodzaj in RODZAJE_UZYTKU:
        for slowo in rodzaj["slowa"]:
            if slowo != slowo.lower() or any(
                znak in slowo for znak in "ąćęłńóśźż"
            ):
                bledy.append(
                    f"podpowiedź „{slowo}” ma ogonki albo wielkie litery — "
                    "aplikacja porównuje nazwy znormalizowane"
                )
    liczone = [f for f in FORMY_OKRYWY if f["licz_jako_okrywe"]]
    if len(liczone) < 2:
        bledy.append("lista form okrywy jest podejrzanie krótka")
    if not any(not f["licz_jako_okrywe"] for f in FORMY_OKRYWY):
        bledy.append(
            "brakuje formy „gleba odkryta” — rolnik musi móc powiedzieć, "
            "że okrywy nie ma"
        )
    for forma in FORMY_OKRYWY:
        for slowo in forma["slowa"]:
            if slowo != slowo.lower() or any(
                znak in slowo for znak in "ąćęłńóśźż"
            ):
                bledy.append(
                    f"forma {forma['id']}: podpowiedź „{slowo}” ma ogonki "
                    "albo wielkie litery"
                )
    bez_okrywy = [f for f in FORMY_OKRYWY if not f["licz_jako_okrywe"]]
    if any(f["slowa"] for f in bez_okrywy):
        bledy.append(
            "forma „gleba odkryta” ma podpowiedzi — tego aplikacja nie "
            "może podpowiadać sama"
        )
    idki_form = [f["id"] for f in FORMY_OKRYWY]
    if len(set(idki_form)) != len(idki_form):
        bledy.append(f"powtórzone identyfikatory form okrywy: {idki_form}")

    for formy in KLUCZ_UPRAWY["formy"]:
        for slowo in formy["slowa"]:
            if slowo != slowo.lower() or any(
                znak in slowo for znak in "ąćęłńóśźż"
            ):
                bledy.append(f"forma „{slowo}” ma ogonki albo wielkie litery")
    for rodzina in KLUCZ_UPRAWY["rodziny_po_gatunku"]:
        if not rodzina["slowa"]:
            bledy.append(f"rodzina {rodzina['id']} bez słów")
        for slowo in rodzina["slowa"]:
            if slowo != slowo.lower() or any(
                znak in slowo for znak in "ąćęłńóśźż"
            ):
                bledy.append(
                    f"rodzina {rodzina['id']}: słowo „{slowo}” ma ogonki "
                    "albo wielkie litery"
                )
    # Trzy rodziny wymienia § 5 ust. 5 pkt 3 — ani mniej, ani więcej.
    if len(KLUCZ_UPRAWY["rodziny_po_gatunku"]) != 3:
        bledy.append(
            "przepis wymienia trzy rodziny liczone po gatunku, a w danych "
            f"jest ich {len(KLUCZ_UPRAWY['rodziny_po_gatunku'])}"
        )
    for rodzina in ["kapustowatych", "psiankowatych", "dyniowatych"]:
        if rodzina not in tekst:
            bledy.append(
                f"w akcie nie ma rodziny „{rodzina}” — sprawdź § 5 ust. 5"
            )

    rodzaje = {r["id"] for r in RODZAJE_UZYTKU}
    for wylaczenie in WYLACZENIA_ZMIANOWANIA:
        po_rodzaju = wylaczenie["po_rodzaju_uzytku"]
        if po_rodzaju is not None and po_rodzaju not in rodzaje:
            bledy.append(
                f"wyłączenie {wylaczenie['id']} wskazuje nieznany rodzaj "
                f"użytku: {po_rodzaju}"
            )
        if not wylaczenie["slowa"] and po_rodzaju is None:
            bledy.append(
                f"wyłączenie {wylaczenie['id']} nie ma ani słów, ani "
                "rodzaju użytku — nic by nie dopasowało"
            )
        for slowo in wylaczenie["slowa"]:
            if slowo != slowo.lower() or any(
                znak in slowo for znak in "ąćęłńóśźż"
            ):
                bledy.append(
                    f"wyłączenie {wylaczenie['id']}: słowo „{slowo}” ma "
                    "ogonki albo wielkie litery"
                )
    # Wyłączenia z § 5 ust. 3 muszą zgadzać się z listą w normie GAEC 7.
    gaec7 = next(n for n in NORMY if n["id"] == "gaec_7")
    if len(gaec7["wylaczenia_upraw"]) != len(WYLACZENIA_ZMIANOWANIA):
        bledy.append(
            "liczba wyłączeń ze zmianowania "
            f"({len(WYLACZENIA_ZMIANOWANIA)}) nie zgadza się z listą "
            f"w normie GAEC 7 ({len(gaec7['wylaczenia_upraw'])})"
        )
    obce = obce_znaki(do_regul())
    if obce:
        bledy.append(
            "w danych są znaki z obcego alfabetu (np. cyrylicy), które "
            f"wyglądają jak polskie litery: {obce}"
        )
    idki = [n["id"] for n in NORMY]
    if len(set(idki)) != len(idki):
        bledy.append(f"powtórzone identyfikatory norm: {idki}")
    for zwolnienie in ZWOLNIENIA:
        dotyczy = zwolnienie["dotyczy_norm"]
        if isinstance(dotyczy, list):
            nieznane = [n for n in dotyczy if n not in idki]
            if nieznane:
                bledy.append(
                    f"zwolnienie {zwolnienie['id']} wskazuje nieznane normy: "
                    f"{nieznane}"
                )
    return bledy


def do_regul() -> dict:
    return {
        "status_weryfikacji": "potwierdzone",
        "zrodlo": ZRODLO,
        "sprawdzono": SPRAWDZONO,
        "opis": (
            "Normy dobrej kultury rolnej zgodnej z ochroną środowiska "
            "(GAEC). Progi, terminy i wyłączenia pochodzą z tekstu "
            "jednolitego rozporządzenia; zwolnienia z kontroli — z prawa "
            "unijnego i komunikatu ARiMR."
        ),
        "zwolnienia": ZWOLNIENIA,
        "rodzaje_uzytku": {
            "status_weryfikacji": "podpowiedz",
            "opis": (
                "Podpowiedź rodzaju użytku po nazwie uprawy. Nie pochodzi "
                "z przepisu — rolnik potwierdza rodzaj użytku dla każdego "
                "pola, bo od niego zależą wszystkie progi GAEC 7."
            ),
            "rodzaje": RODZAJE_UZYTKU,
        },
        "wylaczenia_zmianowania": {
            "status_weryfikacji": "do_weryfikacji",
            "opis": (
                "Uprawy, do których nie stosuje się warunku zmianowania "
                "(§ 5 ust. 3). Kategorie są z przepisu, a wykaz rodzajów "
                "roślin bobowatych — z tabeli 14 programu azotanowego, bo "
                "załącznik nr 2 do rozporządzenia o normach uchylono "
                "w 2024 r. Dopasowanie po nazwie uprawy jest podpowiedzią."
            ),
            "wylaczenia": WYLACZENIA_ZMIANOWANIA,
        },
        "klucz_uprawy": KLUCZ_UPRAWY,
        "formy_okrywy": {
            "status_weryfikacji": "do_weryfikacji",
            "opis": (
                "Co uznaje się za okrywę ochronną gleby. Rozporządzenie "
                "form nie wymienia — lista pochodzi z komunikatu ARiMR "
                "o normach GAEC obowiązujących w 2026 r. Formę dla każdego "
                "pola deklaruje rolnik."
            ),
            "zrodlo": "komunikat ARiMR o normach GAEC obowiązujących w 2026 r.",
            "formy": FORMY_OKRYWY,
        },
        "normy": [
            {k: v for k, v in norma.items() if k != "kontrola"}
            for norma in NORMY
        ],
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--akt",
        type=Path,
        default=Path("dane/pobrane/warunkowosc/D20251674.pdf"),
    )
    parser.add_argument(
        "--reguly", type=Path, default=Path("assets/dane/reguly_prawne.json")
    )
    parser.add_argument("--sprawdz-tylko", action="store_true")
    args = parser.parse_args(argv)

    if not args.akt.exists():
        print(f"Brak tekstu jednolitego: {args.akt}", file=sys.stderr)
        return 1

    tekst = tekst_aktu(args.akt)
    bledy = sprawdz(tekst)

    liczy = [n["numer"] for n in NORMY if n["aplikacja_liczy"]]
    print(f"Norm w słowniku: {len(NORMY)}")
    print(f"Aplikacja liczy: {', '.join(liczy)}")
    print(f"Zwolnień z kontroli: {len(ZWOLNIENIA)}")
    print(f"Rodzajów użytku: {len(RODZAJE_UZYTKU)}")
    print(f"Wyłączeń ze zmianowania: {len(WYLACZENIA_ZMIANOWANIA)}")
    print(f"Form okrywy: {len(FORMY_OKRYWY)}")
    progi = sum(len(n.get("progi", [])) for n in NORMY)
    terminy = sum(len(n.get("terminy", [])) for n in NORMY)
    print(f"Progów: {progi}, terminów: {terminy}")

    if bledy:
        print("\nDo poprawienia:", file=sys.stderr)
        for b in bledy:
            print(f"  - {b}", file=sys.stderr)
        return 1

    if args.sprawdz_tylko:
        print("\nWszystkie wartości odnalezione w akcie.")
        return 0

    reguly = json.loads(args.reguly.read_text(encoding="utf-8"))
    reguly["warunkowosc"] = do_regul()

    # Terminy GAEC 6 i GAEC 8 stoją w słowniku od etapu 1 (kalendarz czyta
    # je sam). Teraz, gdy mamy akt, dopisujemy im paragraf — żeby rolnik
    # widział, skąd data się bierze.
    podstawy = {
        "gaec6_okrywa_gruntow": (
            f"{ZRODLO}, § 4 ust. 1 pkt 1",
            "GAEC 6: okrywa na co najmniej 80 % gruntów ornych od dnia "
            "zbioru plonu głównego do 15 października. Dopuszczalna "
            "przerwa do 4 tygodni na siew ozimin albo międzyplonów.",
        ),
        "gaec8_zakaz_przycinania_drzew": (
            f"{ZRODLO}, § 6 ust. 10 pkt 2",
            "GAEC 8: okres lęgowy ptaków. Zakaz nie dotyczy wierzb, drzew "
            "owocowych i zagajników o krótkiej rotacji.",
        ),
    }
    for termin in reguly.get("terminy", []):
        if termin["id"] in podstawy:
            zrodlo, uwagi = podstawy[termin["id"]]
            termin["zrodlo"] = zrodlo
            termin["uwagi"] = uwagi
    args.reguly.write_text(
        json.dumps(reguly, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"\nZapisano do {args.reguly}")
    print("Pamiętaj o podniesieniu pola „wersja” w słowniku reguł.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
