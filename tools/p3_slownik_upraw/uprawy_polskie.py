"""Kody EPPO dla upraw konwencjonalnych w Polsce (uzupełnienie zadania P3).

Zadanie P3 dopasowało kody tam, gdzie baza EPPO ma polską nazwę rośliny
zgodną co do znaku — to dało 44,7% zastosowań z rejestru. Reszta nazw
została bez kodu, bo baza EPPO ma polskie nazwy wyrywkowo: nie ma ich
nawet dla „grusza", „sałata" czy „burak ćwikłowy".

Ten skrypt zamyka tę lukę **bez zgadywania kodów**:

1. Dla każdej nazwy z rejestru podajemy **nazwę naukową** gatunku, który
   ta nazwa oznacza w polskim rolnictwie (tabela `UPRAWY` niżej).
2. Kod bierze się z bazy EPPO po tej nazwie naukowej — nigdy z pamięci
   i nigdy z podobieństwa napisów.
3. Gdy nazwa naukowa nie ma w bazie dokładnie jednego kodu, wiersz
   **nie dostaje kodu** i trafia do raportu błędów.

Polskie nazwy w bazie EPPO bywają mylące (kod `TRZMO`, czyli *Triticum
monococcum* — samopsza — ma w EPPO polską nazwę „pszenica płaskurka"),
dlatego wiążące jest to, co zapisane po łacinie.

Zakres: **uprawy konwencjonalne w Polsce** (decyzja właściciela projektu
z 16.10.2026). Rośliny ozdobne, leśne i tropikalne dostają stan
`poza_zakresem` — nie zaniżają pokrycia i nie czekają na decyzję.

Użycie:

    python3 tools/p3_slownik_upraw/uprawy_polskie.py \\
        --eppo dane/pobrane/p3_eppo/eppocodes_all.sqlite \\
        --rejestr dane/wynik/srodki_ochrony.sqlite
"""

from __future__ import annotations

import argparse
import csv
import sqlite3
import sys
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from wspolne.tekst import postac_porownawcza  # noqa: E402

STATUS_AKTUALNY = "A"

#: Nazwa z rejestru → (nazwa naukowa, grupa upraw).
#: Nazwa naukowa jest decyzją merytoryczną i widać ją w pliku decyzji;
#: kod do niej dobiera baza EPPO.
UPRAWY: dict[str, tuple[str, str]] = {
    # ── uprawy, którym kod nadało dopasowanie automatyczne z P3; wpisane
    #    tu po nazwie naukowej jako kontrola krzyżowa tamtego dopasowania
    "ziemniak": ("Solanum tuberosum", "okopowe"),
    "pomidor": ("Solanum lycopersicum", "warzywa"),
    "truskawka": ("Fragaria x ananassa", "jagodnik"),
    "kukurydza": ("Zea mays", "zboża"),
    "cebula": ("Allium cepa", "warzywa"),
    "burak cukrowy": ("Beta vulgaris subsp. vulgaris var. altissima", "okopowe"),
    "czereśnia": ("Prunus avium", "sad"),
    "agrest": ("Ribes uva-crispa", "jagodnik"),
    # ── zboża ────────────────────────────────────────────────────────────
    "pszenica": ("Triticum aestivum", "zboża"),
    "pszenica twarda": ("Triticum durum", "zboża"),
    "pszenica durum": ("Triticum durum", "zboża"),
    "pszenica orkisz": ("Triticum spelta", "zboża"),
    "pszenica samopsza": ("Triticum monococcum", "zboża"),
    "pszenica płaskurka": ("Triticum dicoccon", "zboża"),
    "żyto": ("Secale cereale", "zboża"),
    "pszenżyto": ("Triticosecale sp.", "zboża"),
    "jęczmień": ("Hordeum vulgare", "zboża"),
    "proso": ("Panicum miliaceum", "zboża"),
    "kukurydza cukrowa": ("Zea mays convar. saccharata", "zboża"),
    "kukurydza pękająca": ("Zea mays", "zboża"),
    "gryka": ("Fagopyrum esculentum", "zboża"),
    "sorgo": ("Sorghum bicolor", "zboża"),
    # ── rośliny oleiste, włókniste i przemysłowe ─────────────────────────
    "gorczyca biała": ("Sinapis alba", "oleiste"),
    "gorczyca sarepska": ("Brassica juncea", "oleiste"),
    "gorczyca czarna": ("Brassica nigra", "oleiste"),
    "rzepik": ("Brassica rapa subsp. oleifera", "oleiste"),
    "rzepik ozimy": ("Brassica rapa subsp. oleifera", "oleiste"),
    "rzepik jary": ("Brassica rapa subsp. oleifera", "oleiste"),
    "lnianka siewna": ("Camelina sativa", "oleiste"),
    "lnianka siewna ozima": ("Camelina sativa", "oleiste"),
    "lnianka siewna jara": ("Camelina sativa", "oleiste"),
    "len": ("Linum usitatissimum", "włókniste"),
    "len zwyczajny": ("Linum usitatissimum", "włókniste"),
    "len oleisty": ("Linum usitatissimum", "włókniste"),
    "len włóknisty": ("Linum usitatissimum", "włókniste"),
    "konopie": ("Cannabis sativa", "włókniste"),
    "konopie siewne": ("Cannabis sativa", "włókniste"),
    "mak": ("Papaver somniferum", "oleiste"),
    "mak lekarski": ("Papaver somniferum", "oleiste"),
    "słonecznik": ("Helianthus annuus", "oleiste"),
    "soja": ("Glycine max", "strączkowe"),
    "tytoń": ("Nicotiana tabacum", "przemysłowe"),
    "chmiel": ("Humulus lupulus", "przemysłowe"),
    "rzodkiew oleista": ("Raphanus sativus var. oleiformis", "oleiste"),
    "facelia": ("Phacelia tanacetifolia", "poplony"),
    # ── strączkowe i pastewne ────────────────────────────────────────────
    "fasola": ("Phaseolus vulgaris", "strączkowe"),
    "fasola szparagowa": ("Phaseolus vulgaris", "strączkowe"),
    "fasola wielokwiatowa": ("Phaseolus coccineus", "strączkowe"),
    "groch": ("Pisum sativum", "strączkowe"),
    "groch siewny": ("Pisum sativum", "strączkowe"),
    "groch zwyczajny siewny": ("Pisum sativum", "strączkowe"),
    "groch cukrowy": ("Pisum sativum", "strączkowe"),
    "groch siewny cukrowy": ("Pisum sativum", "strączkowe"),
    "groch zielony": ("Pisum sativum", "strączkowe"),
    "groch zielony cukrowy": ("Pisum sativum", "strączkowe"),
    "groch zielony łuskowy": ("Pisum sativum", "strączkowe"),
    "groch łuskowy": ("Pisum sativum", "strączkowe"),
    "groch jadalny": ("Pisum sativum", "strączkowe"),
    "groch jadalny zielony": ("Pisum sativum", "strączkowe"),
    "groch pastewny": ("Pisum sativum subsp. arvense", "strączkowe"),
    "groch zwyczajny pastewny": ("Pisum sativum subsp. arvense", "strączkowe"),
    "groch siewny pastewny": ("Pisum sativum subsp. arvense", "strączkowe"),
    "peluszka": ("Pisum sativum subsp. arvense", "strączkowe"),
    "bób": ("Vicia faba", "strączkowe"),
    "bobik": ("Vicia faba", "strączkowe"),
    "soczewica": ("Lens culinaris", "strączkowe"),
    "ciecierzyca": ("Cicer arietinum", "strączkowe"),
    "łubin biały": ("Lupinus albus", "strączkowe"),
    "łubin żółty": ("Lupinus luteus", "strączkowe"),
    "łubin wąskolistny": ("Lupinus angustifolius", "strączkowe"),
    "lędźwian siewny": ("Lathyrus sativus", "strączkowe"),
    "seradela": ("Ornithopus sativus", "pastewne"),
    "lucerna siewna": ("Medicago sativa", "pastewne"),
    "lucerna sierpowata": ("Medicago falcata", "pastewne"),
    "lucerna nerkowata": ("Medicago lupulina", "pastewne"),
    "koniczyna czerwona": ("Trifolium pratense", "pastewne"),
    "koniczyna biała": ("Trifolium repens", "pastewne"),
    "koniczyna krwistoczerwona (inkarnatka)": (
        "Trifolium incarnatum",
        "pastewne",
    ),
    "esparceta siewna": ("Onobrychis viciifolia", "pastewne"),
    "komonica zwyczajna": ("Lotus corniculatus", "pastewne"),
    "nostrzyk biały": ("Melilotus albus", "pastewne"),
    "nostrzyk żółty": ("Melilotus officinalis", "pastewne"),
    # ── okopowe ──────────────────────────────────────────────────────────
    "burak ćwikłowy": ("Beta vulgaris var. conditiva", "okopowe"),
    "burak pastewny": ("Beta vulgaris var. rapacea", "okopowe"),
    "burak liściowy": ("Beta vulgaris var. cicla", "warzywa"),
    "boćwina": ("Beta vulgaris var. cicla", "warzywa"),
    "brukiew": ("Brassica napus var. napobrassica", "okopowe"),
    "rzepa": ("Brassica rapa subsp. rapa", "okopowe"),
    "rzepa biała": ("Brassica rapa subsp. rapa", "okopowe"),
    "rzepa pastewna": ("Brassica rapa subsp. rapa", "okopowe"),
    "topinambur": ("Helianthus tuberosus", "okopowe"),
    # ── warzywa ──────────────────────────────────────────────────────────
    "sałata": ("Lactuca sativa", "warzywa"),
    "sałata głowiasta": ("Lactuca sativa", "warzywa"),
    "sałata główkowa": ("Lactuca sativa", "warzywa"),
    "sałata liściowa": ("Lactuca sativa", "warzywa"),
    "ogórek": ("Cucumis sativus", "warzywa"),
    "ogórek typu korniszon": ("Cucumis sativus", "warzywa"),
    "melon": ("Cucumis melo", "warzywa"),
    "arbuz": ("Citrullus lanatus", "warzywa"),
    "kawon": ("Citrullus lanatus", "warzywa"),
    "cukinia": ("Cucurbita pepo", "warzywa"),
    "kabaczek": ("Cucurbita pepo", "warzywa"),
    "patison": ("Cucurbita pepo", "warzywa"),
    "dynia zwyczajna": ("Cucurbita pepo", "warzywa"),
    "dynia olbrzymia": ("Cucurbita maxima", "warzywa"),
    "dynia piżmowa": ("Cucurbita moschata", "warzywa"),
    "marchew": ("Daucus carota", "warzywa"),
    "pietruszka": ("Petroselinum crispum", "warzywa"),
    "pietruszka korzeniowa": ("Petroselinum crispum", "warzywa"),
    "pietruszka naciowa": ("Petroselinum crispum", "warzywa"),
    "pasternak": ("Pastinaca sativa", "warzywa"),
    "chrzan": ("Armoracia rusticana", "warzywa"),
    "seler": ("Apium graveolens", "warzywa"),
    "seler korzeniowy": ("Apium graveolens var. rapaceum", "warzywa"),
    "seler naciowy": ("Apium graveolens", "warzywa"),
    "seler liściowy": ("Apium graveolens", "warzywa"),
    "skorzonera": ("Scorzonera hispanica", "warzywa"),
    "salsefia": ("Tragopogon porrifolius", "warzywa"),
    "czosnek": ("Allium sativum", "warzywa"),
    "czosnek askaloński": ("Allium ascalonicum", "warzywa"),
    "szalotka": ("Allium ascalonicum", "warzywa"),
    "cebula szalotka": ("Allium ascalonicum", "warzywa"),
    "szczypiorek": ("Allium schoenoprasum", "warzywa"),
    "cebula siedmiolatka": ("Allium fistulosum", "warzywa"),
    "cebula z dymki": ("Allium cepa", "warzywa"),
    "cebula z rozsady": ("Allium cepa", "warzywa"),
    "dymka": ("Allium cepa", "warzywa"),
    "por": ("Allium porrum", "warzywa"),
    "por z rozsady": ("Allium porrum", "warzywa"),
    "por z siewu": ("Allium porrum", "warzywa"),
    "papryka": ("Capsicum annuum", "warzywa"),
    "bakłażan": ("Solanum melongena", "warzywa"),
    "oberżyna": ("Solanum melongena", "warzywa"),
    "szpinak": ("Spinacia oleracea", "warzywa"),
    "rukola": ("Eruca vesicaria subsp. sativa", "warzywa"),
    "rokietta siewna": ("Eruca vesicaria subsp. sativa", "warzywa"),
    "roszponka": ("Valerianella locusta", "warzywa"),
    "roszponka warzywna": ("Valerianella locusta", "warzywa"),
    "rzeżucha ogrodowa": ("Lepidium sativum", "warzywa"),
    "pieprzyca siewna": ("Lepidium sativum", "warzywa"),
    "portulaka warzywna": ("Portulaca oleracea", "warzywa"),
    "szczaw": ("Rumex acetosa", "warzywa"),
    "rabarbar": ("Rheum rhabarbarum", "warzywa"),
    "szparagi": ("Asparagus officinalis", "warzywa"),
    "karczoch zwyczajny": ("Cynara scolymus", "warzywa"),
    "endywia": ("Cichorium endivia", "warzywa"),
    "eskariola": ("Cichorium endivia", "warzywa"),
    "cykoria": ("Cichorium intybus", "warzywa"),
    "cykoria sałatowa": ("Cichorium intybus", "warzywa"),
    "cykoria korzeniowa": ("Cichorium intybus", "warzywa"),
    "rzodkiewka": ("Raphanus sativus var. radicula", "warzywa"),
    "rzodkiew": ("Raphanus sativus", "warzywa"),
    "rzodkiew czarna": ("Raphanus sativus var. niger", "warzywa"),
    "rzodkiew japońska": ("Raphanus sativus var. longipinnatus", "warzywa"),
    "kapusta głowiasta": ("Brassica oleracea var. capitata", "warzywa"),
    "kapusta głowiasta biała": (
        "Brassica oleracea var. capitata f. alba",
        "warzywa",
    ),
    "kapusta głowiasta czerwona": (
        "Brassica oleracea var. capitata f. rubra",
        "warzywa",
    ),
    "kapusta czerwona": (
        "Brassica oleracea var. capitata f. rubra",
        "warzywa",
    ),
    "kapusta włoska": ("Brassica oleracea var. sabauda", "warzywa"),
    "kapusta brukselska": ("Brassica oleracea var. gemmifera", "warzywa"),
    "kapusta pekińska": ("Brassica rapa subsp. pekinensis", "warzywa"),
    "kapusta chińska": ("Brassica rapa subsp. chinensis", "warzywa"),
    "kapusta chińska pak-czoi": (
        "Brassica rapa subsp. chinensis",
        "warzywa",
    ),
    "jarmuż": ("Brassica oleracea var. sabellica", "warzywa"),
    "kalarepa": ("Brassica oleracea var. gongylodes", "warzywa"),
    "kalafior": ("Brassica oleracea var. botrytis", "warzywa"),
    "brokuł": ("Brassica oleracea var. italica", "warzywa"),
    "pieczarka": ("Agaricus bisporus", "grzyby uprawne"),
    # ── sady i jagodniki ─────────────────────────────────────────────────
    "grusza": ("Pyrus communis", "sad"),
    "grusza azjatycka": ("Pyrus pyrifolia", "sad"),
    "grusza chińska": ("Pyrus pyrifolia", "sad"),
    "jabłoń płonka": ("Malus sylvestris", "sad"),
    "jabłoń dzika": ("Malus sylvestris", "sad"),
    "śliwa": ("Prunus domestica", "sad"),
    "wiśnia": ("Prunus cerasus", "sad"),
    "morela": ("Prunus armeniaca", "sad"),
    "brzoskwinia": ("Prunus persica", "sad"),
    "nektarynka": ("Prunus persica var. nucipersica", "sad"),
    "pigwa": ("Cydonia oblonga", "sad"),
    "pigwowiec": ("Chaenomeles japonica", "sad"),
    "nieszpułka zwyczajna": ("Mespilus germanica", "sad"),
    "orzech włoski": ("Juglans regia", "sad"),
    "orzech laskowy": ("Corylus avellana", "sad"),
    "leszczyna": ("Corylus avellana", "sad"),
    "winorośl": ("Vitis vinifera", "sad"),
    "aktinidia": ("Actinidia arguta", "sad"),
    "malina": ("Rubus idaeus", "jagodnik"),
    "jeżyna": ("Rubus fruticosus", "jagodnik"),
    "porzeczka czarna": ("Ribes nigrum", "jagodnik"),
    "czarna porzeczka": ("Ribes nigrum", "jagodnik"),
    "porzeczka czerwona": ("Ribes rubrum", "jagodnik"),
    "porzeczka biała": ("Ribes rubrum", "jagodnik"),
    "porzeczkoagrest": ("Ribes x nidigrolaria", "jagodnik"),
    "poziomka": ("Fragaria vesca", "jagodnik"),
    "aronia": ("Aronia melanocarpa", "jagodnik"),
    "żurawina": ("Vaccinium macrocarpon", "jagodnik"),
    "borówka wysoka": ("Vaccinium corymbosum", "jagodnik"),
    "borówka amerykańska": ("Vaccinium corymbosum", "jagodnik"),
    "borówka czarna": ("Vaccinium myrtillus", "jagodnik"),
    "borówka brusznica": ("Vaccinium vitis-idaea", "jagodnik"),
    "jagoda kamczacka": ("Lonicera caerulea", "jagodnik"),
    "rokitnik": ("Hippophae rhamnoides", "jagodnik"),
    "świdośliwa": ("Amelanchier alnifolia", "jagodnik"),
    "bez czarny": ("Sambucus nigra", "jagodnik"),
    # ── zioła i przyprawy ────────────────────────────────────────────────
    "majeranek ogrodowy": ("Origanum majorana", "zielarskie"),
    "oregano": ("Origanum vulgare", "zielarskie"),
    "oregano (lebiodka pospolita)": ("Origanum vulgare", "zielarskie"),
    "tymianek właściwy": ("Thymus vulgaris", "zielarskie"),
    "tymianek właściwy (macierzanka zwyczajna)": (
        "Thymus vulgaris",
        "zielarskie",
    ),
    "rozmaryn lekarski": ("Rosmarinus officinalis", "zielarskie"),
    "rozmaryn": ("Rosmarinus officinalis", "zielarskie"),
    "szałwia lekarska": ("Salvia officinalis", "zielarskie"),
    "mięta pieprzowa": ("Mentha x piperita", "zielarskie"),
    "melisa lekarska": ("Melissa officinalis", "zielarskie"),
    "kminek zwyczajny": ("Carum carvi", "zielarskie"),
    "kolendra": ("Coriandrum sativum", "zielarskie"),
    "koper": ("Anethum graveolens", "zielarskie"),
    "koper ogrodowy": ("Anethum graveolens", "zielarskie"),
    # Fenkuł uprawny to podgatunek sativum — gatunek obejmuje też formy
    # dzikie, a rejestr mówi o uprawie.
    "koper włoski": ("Foeniculum vulgare subsp. sativum", "zielarskie"),
    "fenkuł": ("Foeniculum vulgare subsp. sativum", "zielarskie"),
    "lubczyk": ("Levisticum officinale", "zielarskie"),
    "lubczyk ogrodowy": ("Levisticum officinale", "zielarskie"),
    "cząber ogrodowy": ("Satureja hortensis", "zielarskie"),
    "bazylia pospolita": ("Ocimum basilicum", "zielarskie"),
    "estragon": ("Artemisia dracunculus", "zielarskie"),
    "estragon zwyczajny": ("Artemisia dracunculus", "zielarskie"),
    "hyzop lekarski": ("Hyssopus officinalis", "zielarskie"),
    "dziurawiec zwyczajny": ("Hypericum perforatum", "zielarskie"),
    "kozłek lekarski": ("Valeriana officinalis", "zielarskie"),
    "rumianek szlachetny": ("Chamaemelum nobile", "zielarskie"),
    "nagietek": ("Calendula officinalis", "zielarskie"),
    "ogórecznik lekarski": ("Borago officinalis", "zielarskie"),
    "trybula ogrodowa": ("Anthriscus cerefolium", "zielarskie"),
    "dzięgiel": ("Angelica archangelica", "zielarskie"),
    "pokrzywa zwyczajna": ("Urtica dioica", "zielarskie"),
    "szanta zwyczajna": ("Marrubium vulgare", "zielarskie"),
    "kocimiętka właściwa": ("Nepeta cataria", "zielarskie"),
    "rumianek pospolity": ("Matricaria chamomilla", "zielarskie"),
    "arcydzięgiel litwor": ("Angelica archangelica", "zielarskie"),
    "babka zwyczajna": ("Plantago major", "zielarskie"),
    "wyka siewna": ("Vicia sativa", "pastewne"),
    "wyka kosmata": ("Vicia villosa", "pastewne"),
    "kasztan jadalny": ("Castanea sativa", "sad"),
    "rukiew": ("Nasturtium officinale", "warzywa"),
    "przelot": ("Anthyllis vulneraria", "pastewne"),
    # ── rośliny energetyczne ─────────────────────────────────────────────
    "miskant": ("Miscanthus x giganteus", "energetyczne"),
    "wierzba wiciowa": ("Salix viminalis", "energetyczne"),
    "wierzba purpurowa": ("Salix purpurea", "energetyczne"),
}

#: Nazwy z rejestru, które są innym zapisem uprawy już rozstrzygniętej.
#: Kod kopiujemy z tamtego wiersza — bez drugiej decyzji merytorycznej.
ALIASY: dict[str, str] = {
    "pszenica ozima durum": "pszenica twarda ozima",
    "pszenica jara durum": "pszenica twarda jara",
    "pszenica orkisz ozima": "pszenica orkisz",
    "pszenica orkisz jara": "pszenica orkisz",
    "pszenica samopsza ozima": "pszenica samopsza",
    "pszenica samopsza jara": "pszenica samopsza",
    "pszenica płaskurka ozima": "pszenica płaskurka",
    "pszenica płaskurka jara": "pszenica płaskurka",
    "pomidor w uprawie polowej": "pomidor",
    "pomidor pod osłonami": "pomidor",
    "fasola uprawiana na suche nasiona": "fasola",
    "Fasola uprawiana na świeże nasiona": "fasola",
    "groch na suche nasiona": "groch",
    "groch siewny uprawiany na świeże nasiona": "groch",
    "groch uprawiany na zielone nasiona": "groch",
    "cebula dymka": "cebula",
    "brukiew jadalna": "brukiew",
    "burak ćwikłowy biały": "burak ćwikłowy",
    "burak ćwikłowy żółty": "burak ćwikłowy",
    "cykoria liściasta": "cykoria",
    "dynia makaronowa": "dynia zwyczajna",
    "kapusta pak choi": "kapusta chińska",
    "kapusta galicyjska": "kapusta włoska",
    "kapusta sitowata": "gorczyca sarepska",
    "sałata rzymska": "sałata",
    "sałata kędzierzawa": "sałata",
    "sałata długolistna": "sałata",
    "ogórek krótki": "ogórek",
    "mini kiwi": "aktinidia",
    "kukurydza paszowa": "kukurydza",
    "orkisz": "pszenica orkisz",
    "pigwowiec japoński": "pigwowiec",
    "gruszki": "grusza",
    "jabłka": "jabłoń",
}

#: Rośliny spoza zakresu aplikacji (decyzja z 16.10.2026): nazwa → powód.
#: Nie dostają kodu i nie czekają na decyzję — aplikacja prowadzi
#: dokumentację produkcji roślinnej konwencjonalnej w Polsce.
POZA_ZAKRESEM: dict[str, str] = {
    **{
        nazwa: "roślina ozdobna — poza zakresem aplikacji"
        for nazwa in [
            "rośliny ozdobne",
            "rośliny ozdobne wieloletnie",
            "rośliny ozdobne bulwiaste",
            "rośliny szkółkarskie ozdobne",
            "szkółki roślin ozdobnych",
            "szkółki drzew ozdobnych",
            "drzewa i krzewy ozdobne",
            "drzewa ozdobne",
            "krzewy ozdobne",
            "trawy ozdobne",
            "byliny",
            "kwiaty",
            "rośliny doniczkowe",
            "rośliny jednoroczne",
            "rośliny kwiatowe rabatowe",
            "drzewka bożonarodzeniowe",
            "plantacje drzewek bożonarodzeniowych",
            "róża",
            "chryzantema",
            "aksamitka",
            "pelargonia",
            "gerbera",
            "tulipan",
            "narcyz",
            "lilie",
            "lilia",
            "piwonia",
            "funkia",
            "aster",
            "aster chiński",
            "złocień",
            "begonia",
            "bukszpan",
            "lewkonia",
            "petunia",
            "cyklamen",
            "dalia",
            "floks",
            "forsycja",
            "goździk",
            "irys",
            "kalia",
            "krokus",
            "lobelia",
            "łyszczec",
            "magnolia",
            "mieczyk",
            "nasturcja",
            "niecierpek",
            "oleander",
            "pierwiosnek",
            "portulaka",
            "rojnik",
            "różanecznik",
            "azalia",
            "sępolia",
            "tawułka",
            "werbena",
            "wyżlin",
            "zawilec",
            "berberys",
            "bluszcz",
            "cynia",
            "ligustr",
            "laurowiśnia",
            "jaśmin",
            "lawenda",
            "wawrzyn szlachetny",
            "szczodrzeniec",
            "żarnowiec",
            "wilczomlecz",
            "krwawnik",
            "głóg",
            "jarząb pospolity",
            "czeremcha",
            "morwa",
            "mietlica",
            "rajgras",
            "fuksja",
            "lantana pospolita",
            "aster letni",
            "poinsecja",
            "bratek",
            "rośliny ozdobne cebulowe",
            "cebulowe rośliny ozdobne",
            "bulwiaste rośliny ozdobne",
            "szkółki krzewów ozdobnych",
            "rośliny ozdobne w uprawie na kwiat cięty",
        ]
    },
    **{
        nazwa: "gatunek leśny albo zadrzewieniowy — poza zakresem aplikacji"
        for nazwa in [
            "szkółki leśne",
            "szkółki drzew leśnych",
            "rośliny szkółkarskie leśne",
            "uprawy leśne",
            "odnowienia, zalesienia",
            "zalesienia",
            "plantacje nasienne drzew leśnych",
            "siewki leśnych gatunków drzew",
            "siewki leśnych gatunków drzew liściastych",
            "siewki leśnych gatunków drzew iglastych",
            "sadzonki leśnych gatunków drzew liściastych",
            "sadzonki leśnych gatunków drzew iglastych",
            "sadzonki drzew iglastych i liściastych",
            "szkółki drzew iglastych",
            "szkółki drzew liściastych",
            "szkółki krzewów iglastych i liściastych",
            "szkółki drzew i krzewów",
            "drzewa liściaste",
            "drzewa iglaste",
            "krzewy iglaste",
            "krzewy liściaste",
            "krzewy",
            "sosna",
            "świerk",
            "jodła",
            "modrzew",
            "dąb",
            "buk",
            "cis",
            "cyprysik",
            "jałowiec",
            "żywotnik",
            "wierzba",
            "wiklina",
            "topola",
            "drzewa leśne",
            "odnowienia leśne",
            "plantacje drzew leśnych",
            "drzewostany liściaste",
            "drzewostany sosnowe",
            "tereny leśne",
            "sadzonki leśnych gatunków drzew",
        ]
    },
    **{
        nazwa: "roślina nieuprawiana w Polsce — poza zakresem aplikacji"
        for nazwa in ["banan", "kawa", "cytryna", "pomarańcza", "lukrecja"]
    },
}

#: Nazwy zbiorcze: oznaczają grupę upraw, nie gatunek. Jedna uprawa
#: z grupy ma własną nazwę i własny kod, więc grupa kodu nie potrzebuje.
GRUPY: dict[str, str] = {
    nazwa: "nazwa zbiorcza — gatunek wskazuje konkretna uprawa"
    for nazwa in [
        "zboża",
        "ziarno zbóż",
        "warzywa liściowe",
        "warzywa kapustne",
        "warzywa dyniowate",
        "dyniowate",
        "rośliny warzywne",
        "rośliny warzywne uprawiane na młode liście",
        "rośliny warzywne bulwiaste",
        "rośliny sadownicze",
        "rośliny jagodowe",
        "rośliny zielarskie",
        "zioła",
        "rośliny energetyczne",
        "rośliny strączkowe",
        "trawy",
        "trawy nasienne",
        "użytki zielone",
        "plantacje nasienne traw",
        "plantacje traw nasiennych",
        "rośliny szkółkarskie sadownicze",
        "szkółki drzew owocowych",
        "rośliny rolnicze",
        "uprawy rolnicze",
        "rośliny przyprawowe",
        "rośliny warzywne okopowe",
        "rośliny kwitnące",
        "mieszanki zbożowe",
        "łąki",
        "pastwiska",
        "łąki, pastwiska",
    ]
}

#: Miejsca stosowania, przedmioty i określenia agrotechniczne z kolumny
#: „uprawa" rejestru. Roślinami nie są i kodu nigdy nie dostaną.
MIEJSCA: list[str] = [
    "uprawa w polu",
    "uprawa w gruncie",
    "uprawa na nasiona",
    "uprawa na suche nasiona",
    "uprawa na świeże nasiona",
    "uprawa na kiszonkę",
    "na nasiona",
    "na włókno",
    "uprawiane na włókno",
    "po zbiorze",
    "przed rozpoczęciem upraw pożniwnych",
    "ściernisko",
    "pola uprawne",
    "plantacje nasienne",
    "plantacje produkcyjne",
    "sadzonki",
    "szkółki",
    "tereny nieużytkowane rolniczo",
    "ścieżki",
    "chodniki",
    "trawniki",
    "boiska",
    "pola golfowe",
    "pobocza dróg",
    "drogi",
    "drogi dojazdowe",
    "podjazdy",
    "place",
    "place magazynowe",
    "rowy",
    "tory kolejowe",
    "torowiska tramwajowe",
    "lotniska",
    "tereny przemysłowe",
    "pomieszczenia",
    "puste pomieszczenia",
    "uprawa w pomieszczeniach",
    "uprawa w systemie bezglebowym",
    "magazyny",
    "silosy",
    "kontenery",
    "taras",
    "ogrody",
    "sady",
    "sady jabłoniowe",
    "rozsadniki",
    "produkcja nasienna",
    "produkcja rozsady warzyw",
    "siewki i sadzonki",
    "sadzonki drzew",
    "sadzonki krzewów",
    "siewki krzewów",
    "uprawa na ziarno",
    "na olej",
    "nasiona",
    "nasiona roślin oleistych",
    "ziarno",
    "owoce",
    "suszone owoce",
    "stacje beznynowe",
    "torowiska kolejowe",
    "lasy",
]

#: Nazwy rodzajowe: rejestr nie mówi, o który gatunek chodzi, a gatunki
#: mają różne kody. Kodu rodzaju **nie wpisujemy na wydruk** — aplikacja
#: pokazuje rolnikowi gatunki do wyboru, a gdy jego uprawy nie ma na
#: liście, rolnik wpisuje własną nazwę (decyzja z 16.10.2026).
#:
#: Nazwa z rejestru → (o co pytamy rolnika, gatunki do wyboru).
#: Gatunki muszą mieć kod — pilnuje tego test.
RODZAJOWE: dict[str, tuple[str, list[str]]] = {
    "gorczyca": (
        "Jaka gorczyca?",
        ["gorczyca biała", "gorczyca sarepska", "gorczyca czarna"],
    ),
    "łubin": (
        "Jaki łubin?",
        ["łubin biały", "łubin żółty", "łubin wąskolistny"],
    ),
    "wyka": ("Jaka wyka?", ["wyka siewna", "wyka kosmata"]),
    "lucerna": (
        "Jaka lucerna?",
        ["lucerna siewna", "lucerna sierpowata", "lucerna nerkowata"],
    ),
    "koniczyna": (
        "Jaka koniczyna?",
        [
            "koniczyna czerwona",
            "koniczyna biała",
            "koniczyna krwistoczerwona (inkarnatka)",
        ],
    ),
    "nostrzyk": ("Jaki nostrzyk?", ["nostrzyk biały", "nostrzyk żółty"]),
    "dynia": (
        "Jaka dynia?",
        ["dynia zwyczajna", "dynia olbrzymia", "dynia piżmowa"],
    ),
    "kapusta": (
        "Jaka kapusta?",
        [
            "kapusta głowiasta biała",
            "kapusta głowiasta czerwona",
            "kapusta włoska",
            "kapusta pekińska",
            "kapusta chińska",
            "kapusta brukselska",
            "jarmuż",
            "kalarepa",
            "kalafior",
            "brokuł",
        ],
    ),
    "kapusta choy-sum": ("Jaka kapusta?", ["kapusta chińska"]),
    "burak": (
        "Jaki burak?",
        [
            "burak cukrowy",
            "burak ćwikłowy",
            "burak pastewny",
            "burak liściowy",
        ],
    ),
    "botwinka": ("Z czego botwinka?", ["burak ćwikłowy", "boćwina"]),
    "porzeczka": (
        "Jaka porzeczka?",
        ["porzeczka czarna", "porzeczka czerwona", "porzeczka biała"],
    ),
    "malinojeżyna": ("Malina czy jeżyna?", ["malina", "jeżyna"]),
    "orzech": ("Jaki orzech?", ["orzech włoski", "orzech laskowy"]),
    "komonica": ("Jaka komonica?", ["komonica zwyczajna"]),
    "mięta": ("Jaka mięta?", ["mięta pieprzowa"]),
    "szałwia": ("Jaka szałwia?", ["szałwia lekarska"]),
    "tymianek": ("Jaki tymianek?", ["tymianek właściwy"]),
    "sorgo zwisłe": ("Jakie sorgo?", ["sorgo"]),
    "rzepa czarna": ("Co to za roślina?", ["rzodkiew czarna", "rzepa"]),
    "wierzba energetyczna": (
        "Jaka wierzba?",
        ["wierzba wiciowa", "wierzba purpurowa"],
    ),
    # Gatunku topoli energetycznej i róży na owoce słownik nie zna —
    # rolnik wpisze własną nazwę, a pole kodu EPPO zostanie puste.
    "topola energetyczna": ("Jaka topola?", []),
    "róża uprawiana na jadalne owoce": ("Jaka róża?", []),
}


#: Nazwy naukowe wczytane raz na połączenie: baza ma 580 tysięcy nazw
#: i zapytanie o każdą osobno trwałoby minuty.
_NAZWY_NAUKOWE: dict[int, dict[str, set[str]]] = {}


def _nazwy_naukowe(baza: sqlite3.Connection) -> dict[str, set[str]]:
    zapamietane = _NAZWY_NAUKOWE.get(id(baza))
    if zapamietane is not None:
        return zapamietane
    mapa: dict[str, set[str]] = {}
    for nazwa, kod in baza.execute(
        """
        SELECT n.fullname, c.eppocode
        FROM t_names n
        JOIN t_codes c ON c.codeid = n.codeid
        WHERE n.codelang = 'la' AND n.status = ?
        """,
        (STATUS_AKTUALNY,),
    ):
        mapa.setdefault(nazwa.strip().lower(), set()).add(kod)
    _NAZWY_NAUKOWE[id(baza)] = mapa
    return mapa


def kod_po_nazwie_naukowej(baza: sqlite3.Connection, nazwa: str) -> str | None:
    """Kod EPPO dla nazwy naukowej — tylko gdy baza wskazuje dokładnie jeden.

    Bierzemy nazwy aktualne (`status = 'A'`) w dowolnej postaci zapisu,
    bo ta sama roślina bywa w bazie i jako gatunek, i jako odmiana.
    """
    kody = _nazwy_naukowe(baza).get(nazwa.strip().lower(), set())
    return next(iter(kody)) if len(kody) == 1 else None


def nazwa_polska(baza: sqlite3.Connection, kod: str) -> str:
    nazwy = [
        nazwa
        for (nazwa,) in baza.execute(
            """
            SELECT n.fullname
            FROM t_names n
            JOIN t_codes c ON c.codeid = n.codeid
            WHERE c.eppocode = ? AND n.codelang = 'pl' AND n.status = ?
            """,
            (kod, STATUS_AKTUALNY),
        )
    ]
    return "; ".join(dict.fromkeys(nazwy))


def zbuduj_wiersze(
    baza: sqlite3.Connection, istniejace: dict[str, dict[str, str]]
) -> tuple[list[dict[str, str]], list[str]]:
    """Nowe wiersze pliku decyzji i lista rzeczy do poprawienia."""
    dzisiaj = date.today().isoformat()
    wynik: list[dict[str, str]] = []
    klopoty: list[str] = []

    def wiersz(nazwa, kod, nazwa_eppo, stan, zrodlo, zamiast=""):
        return {
            "nazwa_uprawy": nazwa,
            "kod_eppo": kod,
            "nazwa_eppo": nazwa_eppo,
            "stan": stan,
            "zrodlo": zrodlo,
            "zamiast": zamiast,
            "data": dzisiaj,
        }

    kody_upraw: dict[str, str] = {}
    for nazwa, (naukowa, grupa) in UPRAWY.items():
        kod = kod_po_nazwie_naukowej(baza, naukowa)
        if kod is None:
            klopoty.append(
                f"{nazwa}: nazwa naukowa \u201e{naukowa}\u201d nie daje "
                f"w bazie EPPO dokładnie jednego kodu — wiersz bez kodu"
            )
            continue
        kody_upraw[nazwa] = kod
        wynik.append(
            wiersz(
                nazwa,
                kod,
                nazwa_polska(baza, kod) or naukowa,
                "potwierdzone",
                f"{naukowa} → kod z bazy EPPO; uprawa konwencjonalna "
                f"w Polsce ({grupa})",
            )
        )

    for nazwa, wzor in ALIASY.items():
        kod = kody_upraw.get(wzor) or (istniejace.get(
            postac_porownawcza(wzor), {}
        ).get("kod_eppo") or "")
        if not kod:
            klopoty.append(
                f"{nazwa}: brak kodu dla wzoru \u201e{wzor}\u201d"
            )
            continue
        wynik.append(
            wiersz(
                nazwa,
                kod,
                istniejace.get(postac_porownawcza(wzor), {}).get(
                    "nazwa_eppo", ""
                ),
                "potwierdzone",
                f"ta sama roślina co \u201e{wzor}\u201d — inny zapis "
                "w rejestrze",
            )
        )

    for nazwa, powod in POZA_ZAKRESEM.items():
        wynik.append(wiersz(nazwa, "", "", "poza_zakresem", powod))
    for nazwa, powod in GRUPY.items():
        wynik.append(wiersz(nazwa, "", "", "grupa_upraw", powod))
    for nazwa in MIEJSCA:
        wynik.append(
            wiersz(
                nazwa,
                "",
                "",
                "nie_uprawa",
                "miejsce stosowania albo określenie agrotechniczne, "
                "nie roślina",
            )
        )
    for nazwa, (pytanie, gatunki) in RODZAJOWE.items():
        nieznane = [g for g in gatunki if g not in kody_upraw]
        if nieznane:
            klopoty.append(f"{nazwa}: gatunki bez kodu — {nieznane}")
        wynik.append(
            wiersz(
                nazwa,
                "",
                pytanie,
                "rodzajowa",
                "rejestr nie podaje gatunku; aplikacja pokazuje gatunki "
                "do wyboru, a gdy rolnik ma inną uprawę — wpisuje własną "
                "nazwę i kod EPPO zostaje pusty",
                zamiast="|".join(gatunki),
            )
        )
    return wynik, klopoty


def scal(
    plik: Path, nowe: list[dict[str, str]]
) -> tuple[int, int, list[str]]:
    """Dopisuje i poprawia wiersze; decyzji `potwierdzone` nie nadpisuje."""
    istniejace: list[dict[str, str]] = []
    if plik.exists():
        with plik.open(encoding="utf-8", newline="") as f:
            istniejace = list(csv.DictReader(f, delimiter=";"))
    wedlug_nazwy = {postac_porownawcza(w["nazwa_uprawy"]): w for w in istniejace}

    dopisane = zmienione = 0
    spory: list[str] = []
    for w in nowe:
        klucz = postac_porownawcza(w["nazwa_uprawy"])
        stary = wedlug_nazwy.get(klucz)
        if stary is None:
            wedlug_nazwy[klucz] = w
            istniejace.append(w)
            dopisane += 1
            continue
        if stary["stan"] == "potwierdzone":
            if w["kod_eppo"] and stary["kod_eppo"] != w["kod_eppo"]:
                spory.append(
                    f"{w['nazwa_uprawy']}: w pliku jest potwierdzony kod "
                    f"{stary['kod_eppo']}, skrypt proponuje {w['kod_eppo']} "
                    f"— zostawiam ten z pliku"
                )
            continue
        if stary != w:
            stary.update(w)
            zmienione += 1

    istniejace.sort(key=lambda w: postac_porownawcza(w["nazwa_uprawy"]))
    with plik.open("w", encoding="utf-8", newline="") as f:
        zapis = csv.DictWriter(
            f,
            fieldnames=[
                "nazwa_uprawy",
                "kod_eppo",
                "nazwa_eppo",
                "stan",
                "zrodlo",
                "zamiast",
                "data",
            ],
            delimiter=";",
        )
        zapis.writeheader()
        zapis.writerows(istniejace)
    return dopisane, zmienione, spory


def pokrycie(rejestr: Path, plik: Path) -> None:
    """Ile zastosowań z rejestru ma uprawę z gotowym kodem."""
    if not rejestr.exists():
        return
    with plik.open(encoding="utf-8", newline="") as f:
        decyzje = {
            postac_porownawcza(w["nazwa_uprawy"]): w
            for w in csv.DictReader(f, delimiter=";")
        }
    baza = sqlite3.connect(f"file:{rejestr}?mode=ro", uri=True)
    uzycia = dict(
        baza.execute(
            "SELECT uprawa, COUNT(*) FROM zastosowanie_uprawa GROUP BY uprawa"
        )
    )
    razem = sum(uzycia.values())
    stany: dict[str, int] = {}
    for nazwa, ile in uzycia.items():
        w = decyzje.get(postac_porownawcza(nazwa))
        stan = w["stan"] if w else "bez decyzji"
        if stan == "potwierdzone" and not w["kod_eppo"]:
            stan = "bez decyzji"
        stany[stan] = stany.get(stan, 0) + ile
    print("\nZastosowania z rejestru według stanu uprawy:")
    for stan, ile in sorted(stany.items(), key=lambda p: -p[1]):
        print(f"  {stan:16} {ile:6}  ({100 * ile / max(razem, 1):5.1f}%)")

    brak = sorted(
        (
            (ile, nazwa)
            for nazwa, ile in uzycia.items()
            if (decyzje.get(postac_porownawcza(nazwa)) or {}).get("stan")
            not in {
                "potwierdzone",
                "poza_zakresem",
                "grupa_upraw",
                "nie_uprawa",
                "rodzajowa",
            }
            or not (decyzje.get(postac_porownawcza(nazwa)) or {}).get("kod_eppo")
            and (decyzje.get(postac_porownawcza(nazwa)) or {}).get("stan")
            == "potwierdzone"
        ),
        reverse=True,
    )[:15]
    if brak:
        print("\nNajwiększe uprawy wciąż bez kodu:")
        for ile, nazwa in brak:
            print(f"  {nazwa[:40]:40} {ile:5} zastosowań")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--eppo",
        type=Path,
        default=Path("dane/pobrane/p3_eppo/eppocodes_all.sqlite"),
    )
    parser.add_argument(
        "--plik", type=Path, default=Path("assets/dane/kody_eppo_decyzje.csv")
    )
    parser.add_argument(
        "--rejestr",
        type=Path,
        default=Path("dane/wynik/srodki_ochrony.sqlite"),
    )
    parser.add_argument(
        "--sprawdz-tylko",
        action="store_true",
        help="policz i wypisz, ale nie zapisuj pliku decyzji",
    )
    args = parser.parse_args(argv)

    if not args.eppo.exists():
        print(f"Brak bazy EPPO: {args.eppo}", file=sys.stderr)
        return 1

    baza = sqlite3.connect(f"file:{args.eppo}?mode=ro", uri=True)
    istniejace: dict[str, dict[str, str]] = {}
    if args.plik.exists():
        with args.plik.open(encoding="utf-8", newline="") as f:
            istniejace = {
                postac_porownawcza(w["nazwa_uprawy"]): w
                for w in csv.DictReader(f, delimiter=";")
            }

    wiersze, klopoty = zbuduj_wiersze(baza, istniejace)
    z_kodem = sum(1 for w in wiersze if w["kod_eppo"])
    print(f"Uprawy z nazwą naukową:       {len(UPRAWY)}")
    print(f"Kody wzięte z bazy EPPO:      {z_kodem}")
    print(f"Poza zakresem (ozdobne, leśne, tropikalne): {len(POZA_ZAKRESEM)}")
    print(f"Nazwy zbiorcze:               {len(GRUPY)}")
    print(f"Miejsca i przedmioty:         {len(MIEJSCA)}")
    print(f"Nazwy rodzajowe (gatunek z listy): {len(RODZAJOWE)}")

    if klopoty:
        print("\nDo poprawienia:")
        for k in klopoty:
            print(f"  - {k}")

    if args.sprawdz_tylko:
        return 1 if klopoty else 0

    dopisane, zmienione, spory = scal(args.plik, wiersze)
    print(f"\nPlik decyzji: {args.plik}")
    print(f"  dopisane wiersze:  {dopisane}")
    print(f"  poprawione wiersze: {zmienione}")
    for s in spory:
        print(f"  ! {s}")

    pokrycie(args.rejestr, args.plik)
    return 1 if klopoty else 0


if __name__ == "__main__":
    raise SystemExit(main())
