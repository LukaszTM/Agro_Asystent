# Identyfikacja wizualna

Logo jest znakiem całego projektu: aplikacji na telefon, programu na Windows,
wydruków dla kontroli, repozytorium i strony w sklepie.

## Jedno źródło

Źródła są dwa, każde ma swoje zadanie:

| Plik | Co zawiera | Z czego powstaje |
| --- | --- | --- |
| `assets/logo/agro_asystent.png` (1331 × 1331) | znak **i nazwa** | ekran powitalny, pasek ekranu głównego, README |
| `assets/logo/agro_asystent_znak.png` (1238 × 1238) | **sam znak** | ikony Androida i Windows |

Oba mają przezroczyste tło. Ikony robimy ze znaku, bo w kwadracie 48 × 48 px
napis „Agro Asystent" zlewa się w nieczytelną kreskę.

| | |
| --- | --- |
| Skrypt wytwarzający warianty | `tools/zbuduj_ikony.py` |
| Stałe w kodzie | `lib/rdzen/marka/marka.dart` (`Marka.logo`, `Marka.znak`) |

Każdy plik źródłowy musi być **kwadratowy i mieć przezroczyste tło** — skrypt
skaluje go wprost do boku ikony, więc obrazek prostokątny zostałby ściśnięty,
a białe tło dałoby biały kwadrat w rogach ikony adaptacyjnej. Nowe logo
przygotowujemy tak: obcinamy przezroczysty margines, a potem dokładamy
przezroczysty zapas do kwadratu.

**Wariantów logo nie rysujemy ręcznie.** Zmiana logo to podmiana pliku
źródłowego i jedno uruchomienie skryptu:

```bash
python3 tools/zbuduj_ikony.py
```

Skrypt wytwarza: ikony Androida w pięciu gęstościach, pierwszy plan ikony
adaptacyjnej (z zapasem przy krawędziach, bo Android przycina ją do koła albo
kwadratu zależnie od nakładki producenta), logo ekranu powitalnego i ikonę
Windows z kompletem rozmiarów.

## Kolory marki

Wyłuskane z pliku logo, nie dobrane z pamięci:

| Kolor | Kod | Skąd w logo | Do czego |
| --- | --- | --- | --- |
| Ciemna zieleń | `#0A3C20` | litera „A" i napis | główny kolor marki, nagłówki wydruków |
| Zieleń liścia | `#69A31E` | liść | akcent, podkreślenia |
| Złoto | `#C3912E` | pas pola | wyróżnienia, oszczędnie |
| Biel | `#FFFFFF` | karta pod logo | tło ikony |

## Kolory marki a kolory ekranów — to dwie różne rzeczy

Ekrany aplikacji mają **własną paletę** z makiety (plan, pkt 5): tło `#F4F6F0`,
tekst `#10230F`, zieleń akcji `#1E5B2E`, ostrzeżenia `#FFF1D6` z obramowaniem
`#8A4B00`. Jest dobrana pod czytelność w słońcu i wysoki kontrast dla osób 60+,
i **ma pierwszeństwo wszędzie tam, gdzie rolnik coś czyta albo naciska**.

Kolory marki służą do oznaczania, nie do budowania ekranów. Zasada jest prosta:
w `lib/wyglad/*/motyw.dart` kolory ekranów, w `Marka` kolory znaku.

## Gdzie logo jest, a gdzie go nie ma

**Jest:**

- ikona aplikacji na telefonie i na pulpicie Windows — **sam znak**,
- ekran powitalny (zanim aplikacja się wczyta) — pełne logo z nazwą,
- pasek ekranu głównego — pełne logo z nazwą,
- stopka wydruków i eksportów — **nazwą**, nie znakiem graficznym:
  „Sporządzono … w Agro Asystencie (słownik reguł …)",
- `README.md` repozytorium.

**Nie ma go:**

- na ekranach ścieżki wpisu zabiegu — tam liczy się pole, środek i dawka,
  a każdy element bez zadania zabiera miejsce przyciskom (plan, pkt 5),
- w ostrzeżeniach i komunikatach o błędach,
- na wydrukach jako znak graficzny: dokument wystawia rolnik, a nie my,
  więc w stopce wystarczy nazwa programu, którym go sporządzono.

## Czego z logo nie robimy

- nie rozciągamy i nie zmieniamy proporcji,
- nie zmieniamy kolorów ani nie robimy wersji jednobarwnej „na szybko"
  (ikona jednobarwna Androida 13+ wymaga osobnej, uproszczonej sylwetki —
  dopóki jej nie ma, nie podajemy jej systemowi),
- nie wycinamy nazwy z pełnego logo własnoręcznie — wersja bez nazwy jest
  osobnym plikiem od projektanta,
- nie używamy logo jako tła pod tekstem,
- nie dodajemy do niego napisów ani odznak.

## Nazwa

**Agro Asystent** — tak samo w aplikacji, na wydrukach, w sklepie i w stopce
dokumentów. W kodzie: `Marka.nazwa`, żeby nie rozjechała się w pięciu miejscach.
