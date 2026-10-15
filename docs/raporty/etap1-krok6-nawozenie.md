# Raport etap 1, krok 6 — nawożenie, limit azotu, plan

15 października 2026 r. Zadanie z planu (pkt 4, krok 6):
„Nawożenie: ewidencja, limit N, plan nawożenia azotem od progu".

## Co rolnik może zrobić

**Wpis nawożenia** idzie tą samą ścieżką co oprysk: **Dodaj zabieg → pole →
Nawożenie → nawóz z własnego spisu → dawka → Zapisz**. Przy dawce od razu
widać, ile to azotu na hektar i ile na całe pole, a po zapisie — ile zostało
do limitu.

**Pola → Nawożenie** pokazuje trzy rzeczy:

1. **Limit azotu z nawozów naturalnych**: pasek „ile z ilu kg N/ha" dla
   bieżącego sezonu, ile zostało na całe gospodarstwo, a po przekroczeniu —
   jedno zdanie „nie stosuj więcej nawozów naturalnych w tym roku".
2. **Azot na polach**: ile kg N/ha trafiło na każde pole.
3. **Czy przepis wymaga planu nawożenia azotem** — wraz z progiem i uwagą,
   że plan układa doradca.

**Pola → Nawożenie → Nawozy** to własny spis nawozów: nazwa, mineralny czy
naturalny, zawartość azotu.

## Czego nie zgadujemy

Zawartości azotu **nie wpisujemy za rolnika**. Nawóz dodany bez niej zostaje
w spisie z adnotacją „zawartość azotu do uzupełnienia", a jego wpisy nie
wchodzą do limitu — zamiast tego limit pokazuje: „2 wpisy mają nawóz bez
znanej zawartości azotu, te nie są policzone". Limit byłby wtedy fałszywie
niski i to jest ważniejsze niż ładna liczba (CLAUDE.md, reguła 5).

Odczyt składu z opakowania zdjęciem to krok 7 etapu 1.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/nawozenie/nawoz.dart` | spis nawozów, jednostki dawki i przeliczenie na azot |
| `lib/funkcje/nawozenie/ewidencja_nawozenia.dart` | zapis nawożenia jako zabiegu i stan limitu azotu |
| `lib/funkcje/nawozenie/plan_nawozenia.dart` | azot na polach i sprawdzenie progu planu |
| `lib/wyglad/prosty/nawozenie/ekran_nawozenie.dart` | limit, azot na polach, ostatnie wpisy |
| `lib/wyglad/prosty/nawozenie/ekran_nawozy.dart` | spis nawozów i dodawanie |
| `lib/wyglad/prosty/nawozenie/ekran_wybor_nawozu.dart` | wybór nawozu w ścieżce wpisu |
| `lib/wyglad/prosty/nawozenie/ekran_dawka_nawozu.dart` | dawka, jednostka i azot na hektar |
| `lib/wyglad/prosty/nawozenie/ekran_zapisano_nawozenie.dart` | potwierdzenie i stan limitu po zapisie |

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 8 |
| Nowe pliki testów | 2 |
| Testy dodane w tym kroku | 19 |
| Testy w całym projekcie | 200 (było 181) — w tym 7 testów ekranów |
| Limit azotu | 170 kg N/ha/rok — **ze słownika reguł**, nie z kodu |
| Nowe zależności | brak |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- **Przeliczenie azotu**: 30 t/ha obornika o zawartości 0,5% N = 150 kg N/ha;
  100 kg/ha saletry 34% = 34 kg N/ha.
- **Do limitu liczy się tylko azot z nawozów naturalnych** — saletra nie.
- **Przekroczenie limitu** jest widoczne, a „pozostało" nie schodzi poniżej zera.
- **Nawóz bez zawartości azotu** czyni wynik niepewnym i jest policzony
  osobno, zamiast cicho wypaść z rachunku.
- **Wpisy z innego sezonu** nie mieszają się.
- **Nawożenie trafia do wspólnego rejestru zabiegów** — ten sam wpis widać
  w rejestrze, wydruku i eksporcie z kroków 3 i 4.
- **Plan nawożenia** włącza się dopiero po przekroczeniu progu ze słownika
  (powyżej 100 ha UR, 50 ha upraw intensywnych albo 60 DJP).
- Strażnik architektury pilnuje, że limit 170 nie trafił do kodu Dart —
  przeliczenia jednostek (ary na hektary) są opisane komentarzem.

## Rzeczy świadomie odłożone

- **Terminy nawożenia** (okresy, w których nie wolno stosować nawozów) czekają
  na sprawdzenie w aktualnym rozporządzeniu — plan, pkt 10. Gdy wejdą do
  słownika reguł, kalendarz z kroku 5 pokaże je bez zmiany kodu.
- **Prawdziwy plan nawożenia azotem** (dawki pod potrzeby pokarmowe na
  podstawie analizy gleby) — aplikacja daje zestawienie dla doradcy i mówi
  wprost, że planu nie zastępuje.
- **Odczyt składu nawozu ze zdjęcia opakowania** — krok 7.
- **DJP ze zwierząt** w progach planu — krok 9.
