# Program na komputer (Windows)

18 października 2026 r.

Plan (pkt 5) mówi krótko: „Program na Windows ma jeden wygląd, z ustawieniem
wielkości tekstu". Do tej pory na komputerze wstawała baza i słowniki (to
sprawdzał test `start_komputer_test.dart`), ale ekrany były telefonowe —
duże kafelki na monitorze 24 cale. Teraz komputer ma własną warstwę ekranów.

## Co powstało

`lib/wyglad/komputer/` — trzecia warstwa ekranów obok „Prostego"
i „Nowoczesnego". Ten sam rdzeń: baza, reguły, dokumenty i silniki
warunkowości są wspólne; różni się tylko to, co widać.

| Element | Jak jest zrobiony |
| --- | --- |
| Nawigacja | stała, po lewej, wszystkie siedem zakładek naraz — bez ukrytego menu, tak samo jak cztery kafelki na telefonie |
| Zakładki | Pola, Rejestr zabiegów, Terminy, Warunkowość, Dokumenty, Magazyn, Ustawienia |
| Dane | tabele z nagłówkiem (`widgety/tabela.dart`) zamiast kafelków — na monitorze rolnik porównuje wiersze, a nie dotyka celów |
| Wąskie okno | poniżej 1000 px nawigacja zwija się do ikon, widok zostaje |
| Wielkość tekstu | Normalny / Duży / Bardzo duży (100 / 120 / 145 %), zapisane w ustawieniach gospodarstwa, działa od razu w całym programie |

Okno programu startuje w 1280×720 (`windows/runner/main.cpp`), a układ jest
sprawdzony testami także przy 1000×700 i przy bardzo dużym tekście.

## Co komputer robi lepiej niż telefon

- **Rejestr zabiegów w tabeli**: cały sezon naraz, filtr rodzaju zabiegu
  i roku, szukanie po środku, nawozie i polu. Wpisy bez pól wymaganych
  przepisem są wyróżnione — ten sam rachunek co w telefonie
  (`KompletnoscEwidencji`), więc wynik nie może się rozjechać.
- **Uzupełnianie danych pól hurtem**: rodzaj użytku i odpowiedź „czy pole
  graniczy z wodą" ustawia się z panelu obok tabeli. Przy monitorze rolnik
  siada do tego raz dla całego gospodarstwa, a bez tych dwóch odpowiedzi
  warunkowość zostaje „do sprawdzenia".
- **Dokumenty**: podgląd rejestru kolumnami z przepisu, wydruk i eksport
  CSV/XLSX jednym kliknięciem; braki widać w wierszu, nie dopiero na
  wydruku.
- **Magazyn**: zakupy wpisuje się z klawiatury (faktury przepisuje się przy
  komputerze), a nie przyciskami „+" i „−".

## Czego program na komputerze nie robi — i mówi to wprost

| Czego nie ma | Dlaczego |
| --- | --- |
| Odczyt zdjęcia etykiety i worka | ML Kit i aparat nie mają wersji na Windows — `CzytnikTylkoWTelefonie` odmawia z wyjaśnieniem, zamiast dawać przycisk, który nic nie robi |
| Przypomnienia | powiadomienia wysyła telefon; komputer pokazuje te same terminy, ale nie dzwoni |
| Poprawianie i cofanie wpisów | wpisy poprawia się tam, gdzie powstały; na komputerze to dojdzie razem z wpisem zabiegu na PC |
| Wpis zabiegu | pierwszy wpis nadal robi się w telefonie — na komputerze dojdzie w następnym kroku |
| Zmiana nazwy gospodarstwa i numeru producenta | stoją na każdym wydruku, więc zmienia je jedno miejsce: telefon |

Dane z telefonu dołącza się w Ustawieniach plikiem kopii — to samo scalanie
co na telefonie („nowszy wpis wygrywa, starszy zostaje w dzienniku zmian").
Kopia z komputera działa w drugą stronę.

## Architektura

Nowy wygląd nie importuje niczego z dwóch pozostałych i odwrotnie — test
architektury sprawdza teraz **wszystkie trzy** warstwy ekranów parami
(wcześniej tylko prosty ↔ nowoczesny). Wspólny kod ekranów leży
w `lib/rdzen/wspolne/`.

Platformę wybiera `main.dart` (`Platforma.biezaca()`), a `AplikacjaAgroAsystent`
przyjmuje ją jako parametr — dzięki temu program na komputer da się
sprawdzić testami bez prawdziwego Windowsa, a testy telefonowe nie zmieniają
się ani o linię.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 601 | **617** |
| Testy programu na komputer | 1 (start bazy) | **17** |
| Warstwy ekranów | 2 | **3** |
| `flutter analyze` | czysto | czysto |

Nowe testy obejmują: nawigację i przełączanie zakładek, zwinięcie
nawigacji na wąskim oknie, tabelę pól z wyróżnieniem braków, zapis rodzaju
użytku i odpowiedzi o wodzie, filtr i szukanie w rejestrze, skalowanie
tekstu (motyw i zapis w bazie), magazyn z premium i bez, start programu
w obu platformach oraz przewinięcie każdej zakładki do końca przy 1280×800,
1000×700 i przy bardzo dużym tekście.

## Jak zrobić plik .exe

Program buduje darmowa maszyna GitHuba (`.github/workflows/windows.yml`).
Uruchamia ją znacznik zaczynający się od `pc-`:

```bash
git tag pc-0.1.0 && git push origin pc-0.1.0
```

Wynik to wydanie (Releases) z plikiem `agro-asystent-windows.zip` —
link stały, bez logowania, do wysłania dalej. Przy ręcznym uruchomieniu
(Actions → Run workflow) powstaje tylko artefakt na 14 dni.

Przycisku **Run workflow** nie było widać, bo pokazuje się dopiero dla
przepływów leżących na gałęzi głównej, a cała praca stoi na gałęzi
roboczej. Stąd wyzwalacz na znaczniku — działa z gałęzi roboczej od razu.

Program nie jest podpisany, więc Windows pokaże ostrzeżenie SmartScreen
(„Więcej informacji" → „Uruchom mimo to"). Budowanie jest ręczne, bo
maszyny z Windows liczą się w darmowym limicie GitHuba podwójnie,
a budżet projektu to zero.

Budowanie u siebie wymaga Visual Studio 2022 Build Tools z zestawem
„Desktop development with C++" — bez niego `flutter run -d windows`
kończy się zdaniem „Unable to find suitable Visual Studio toolchain".
Cała procedura: `docs/wydanie-windows.md`.

## Co dalej na komputerze

1. **Wpis zabiegu na PC** — największa brakująca rzecz; na dużym ekranie
   może być jednym formularzem z klawiaturą, bez pięciu kroków.
2. **Poprawianie i cofanie wpisów** w tabeli rejestru.
3. **Program na Windows jest w planie funkcją płatną** (pkt 8). Dziś nic nie
   jest płatne w praktyce, bo nie ma jeszcze zakupu w sklepie; gdy dojdzie,
   brama jest jedną linią w `lib/rdzen/dostep/` i jednym warunkiem przy
   starcie programu.
