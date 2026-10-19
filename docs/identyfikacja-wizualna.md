# Identyfikacja wizualna

Logo jest znakiem całego projektu: aplikacji na telefon, programu na Windows,
wydruków dla kontroli, repozytorium i strony w sklepie.

## Jedno źródło

Źródła są dwa, każde ma swoje zadanie:

| Plik | Co zawiera | Z czego powstaje |
| --- | --- | --- |
| `assets/logo/moj_lan.png` (1254 × 1254) | znak **i nazwa** | ekran powitalny, README |
| `assets/logo/moj_lan_znak.png` (1254 × 1254) | **sam znak** | ikony Androida i Windows, pasek ekranu głównego obok nazwy |

Oba mają przezroczyste tło. Ikony robimy ze znaku, bo w kwadracie 48 × 48 px
napis „Mój Łan" zlewa się w nieczytelną kreskę.

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
kwadratu zależnie od nakładki producenta), **warstwę jednobarwną** dla
Androida 13+, logo ekranu powitalnego i ikonę Windows z kompletem rozmiarów.

Pliki od projektanta mają wokół znaku ledwo widoczną poświatę sięgającą
krawędzi. Skrypt ją pomija przy obcinaniu marginesu (próg 32 ze 255 krycia) —
inaczej znak byłby na ikonie mniejszy, niż może być.

### Ikona jednobarwna (Android 13+)

Od Androida 13 system barwi ikonę pod tapetę użytkownika, a od Androida 16
QPR 2 robi to **także aplikacjom bez własnej warstwy** — po swojemu. Dlatego
podajemy własną: `ic_launcher_monochrome` w `mipmap-*`, wpięta przez
`<monochrome>` w `mipmap-anydpi-v26/ic_launcher.xml`.

Warunki, które spełnia (dokumentacja Androida):

| Warunek | U nas |
| --- | --- |
| Kanwa 108 × 108 dp | tak, jak pozostałe warstwy |
| Znak od 48 do 66 dp | 66 dp szerokości (górna granica) |
| Jeden kolor, bez gradientów i cienia | czarna sylwetka na przezroczystym tle; system i tak zastąpi kolor |
| Czyste krawędzie, bez własnej maski | tak |

Sylwetka powstaje z **kanału alfa znaku**: przerwy między pasami pola i w
liściu są w pliku przezroczyste, więc zostają dziurami i rysunek zachowuje
podział. W rozmiarze 48 px cienkie pasy zaczynają się zlewać — gdyby to miało
przeszkadzać, trzeba osobnej, uproszczonej sylwetki od projektanta.

## Kolory marki

Wyłuskane z pliku logo, nie dobrane z pamięci:

| Kolor | Kod | Skąd w logo | Do czego |
| --- | --- | --- | --- |
| Ciemna zieleń | `#085A30` | pasy pola | główny kolor marki, nagłówki wydruków |
| Zieleń liścia | `#78B81B` | liść | akcent, podkreślenia |
| Złoto | `#F8BA1E` | słońce i pas pola | wyróżnienia, oszczędnie |
| Biel | `#FFFFFF` | karta pod logo | tło ikony aplikacji |

### Tło ikony: biel

Tło ikony adaptacyjnej zostaje **białe** (`ic_launcher_background` w
`android/app/src/main/res/values/colors.xml`). Rozważaliśmy ciemną zieleń
marki, ale przerwy między pasami pola i w liściu są w pliku przezroczyste —
na zieleni zlałyby się z tłem i rysunek straciłby podział. Na bieli znak
wygląda tak samo jak na papierze. Decyzja z 15 października 2026 r.

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
- pasek ekranu głównego — sam znak obok nazwy (pełne logo w 40 px miałoby
  nazwę dwa razy: w obrazku i w tekście),
- stopka wydruków i eksportów — **nazwą**, nie znakiem graficznym:
  „Sporządzono … w aplikacji Mój Łan (słownik reguł …)",
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

**Mój Łan** — tak samo w aplikacji, na wydrukach, w sklepie i w stopce
dokumentów. W kodzie: `Marka.nazwa`, żeby nie rozjechała się w pięciu miejscach.

Do 19 października 2026 r. projekt nazywał się „Agro Asystent". Nazwa została
zmieniona, bo od 2009 r. istnieje komercyjny program **AgroAsystent** firmy
AgroPower dla gospodarstw roślinnych — ten sam segment, prawie ta sama nazwa
(ADR-0009). Identyfikator pakietu Androida to `pl.mojlan.app`, program na
Windows to `moj_lan.exe`; w nazwach bez polskich znaków piszemy „moj-lan".
Nazwa repozytorium i pakietu Dart (`agro_asystent`) zostają — to nazwy
techniczne, których rolnik nie widzi.
