# Raport etap 1, krok 10 — konta i kilka gospodarstw

15 października 2026 r. Zadanie z planu (pkt 4, krok 10):
„Konta i kilka gospodarstw". Ostatni krok etapu 1.

## Jak to działa

Dotąd aplikacja zakładała jedno gospodarstwo o nazwie „Moje gospodarstwo"
i nie dawało się jej zmienić. Teraz:

- **Dane na wydruki** — nazwa i numer producenta są do poprawienia
  z ekranu „Gospodarstwo" (przycisk na pasku ekranu głównego). Nazwa stała
  już w nagłówku rejestru; numer producenta dochodzi do nagłówka wydruku
  PDF oraz eksportu CSV i XLSX.
- **Kilka gospodarstw** — lista gospodarstw z zaznaczonym bieżącym; jedno
  dotknięcie przełącza. Wybór jest pamiętany w tabeli `ustawienia`, więc
  po włączeniu aplikacji rolnik wraca tam, gdzie skończył.
- **Konto** — nazwa właściciela danych, obejmująca jedno lub kilka
  gospodarstw (plan, pkt 7). Bez logowania i bez hasła: aplikacja nie ma
  własnego serwera, a nazwa przyda się przy kopii i synchronizacji, żeby
  wiadomo było, czyje dane są w paczce. Bez konta wszystko działa tak samo.

## Gdzie kończy się darmowa wersja

Plan (pkt 8) stawia kilka gospodarstw po stronie premium. Granicę
postawiliśmy w jednym, wąskim miejscu:

| Czynność | Darmowa |
| --- | --- |
| Pierwsze gospodarstwo | tak, zawsze |
| Poprawa nazwy i numeru producenta | tak — bez nich wydruk jest nie do użytku |
| Wpisy, rejestry, wydruk, eksport w każdym gospodarstwie | tak, zawsze |
| Przełączanie między już założonymi gospodarstwami | tak |
| **Dodanie drugiego i kolejnego** gospodarstwa | nie — premium |

Z tego wynika rzecz, którą pilnuje osobny test: **gospodarstwa założone
w premium zostają w pełni dostępne, gdy premium się skończy.** Blokujemy
zakładanie kolejnych, nigdy dostęp do dokumentacji, która już jest
(CLAUDE.md, reguła 4). Pytanie o dostęp idzie wyłącznie przez
`DostepFunkcji.czyDostepna(Funkcja.kilkaGospodarstw)` — nigdzie w nowym
kodzie nie ma warunku „czy użytkownik kupił".

Ostatniego gospodarstwa nie da się usunąć: rolnik zostałby bez miejsca na
dokumentację. Usunięcie zostawia wiersz w bazie (wpisy są dopisywane, nie
nadpisywane) i przełącza na gospodarstwo, które zostało.

## Przełączenie bez ponownego startu

`Uslugi.dlaGospodarstwa(id:, nazwa:)` zwraca ten sam zestaw usług z innym
gospodarstwem. Wszystkie repozytoria pracują na jednej bazie i same
filtrują po gospodarstwie, więc przełączenie nie otwiera bazy od nowa ani
nie rozpakowuje słowników — zmienia się identyfikator i nazwa. Nowy zestaw
wraca do `_Start` w `lib/app/aplikacja.dart`, dzięki czemu wszystkie ekrany
widzą nowe gospodarstwo.

Gdy zapisany wybór zniknął (gospodarstwo usunięte, kopia z innego
telefonu), aplikacja bierze pierwsze gospodarstwo z listy. Nigdy nie
zostaje bez gospodarstwa.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/ustawienia/gospodarstwa.dart` | gospodarstwa, wybór bieżącego, konto, granica premium |
| `lib/wyglad/prosty/ustawienia/ekran_gospodarstwa.dart` | ekran „Gospodarstwo" i ekran danych gospodarstwa |
| `lib/app/uslugi.dart` | `gospodarstwa` + `dlaGospodarstwa(...)` |
| `lib/app/start.dart`, `lib/app/aplikacja.dart` | bieżące gospodarstwo przy starcie i podmiana po przełączeniu |
| `lib/wyglad/prosty/ekran_glowny.dart` | wejście na ekran gospodarstwa |
| `lib/funkcje/dokumenty/*` | numer producenta w nagłówku PDF, CSV i XLSX |

## Liczby

| Miara | Wartość |
| --- | --- |
| Nowe pliki kodu | 2 (+ zmiany w ośmiu) |
| Nowe pliki testów | 2 |
| Testy dodane w tym kroku | 22 (14 logiki, 6 ekranów, 2 dokumentów) |
| Testy w całym projekcie | 257 (było 235) |
| Nowe tabele w bazie | 0 — `konto` i `konto_gospodarstwo` były w schemacie od migracji 1 |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Pierwsze gospodarstwo powstaje bez premium, drugie wymaga premium.
- Gospodarstwa z premium zostają dostępne po jego końcu.
- Poprawa nazwy i numeru producenta działa zawsze; puste pole znaczy
  „brak", nie zgadujemy numeru.
- Wybór gospodarstwa przetrwa ponowne uruchomienie; zniknięty wybór nie
  zostawia aplikacji bez gospodarstwa.
- Ostatniego gospodarstwa nie da się usunąć; usunięcie przełącza na to,
  które zostało.
- Konto jest opcjonalne, obejmuje wszystkie gospodarstwa z telefonu i nie
  mnoży się przy zmianie nazwy.
- Numer producenta wychodzi w CSV, XLSX i na wydruku PDF; bez numeru
  w nagłówku stoi „brak".

## Rzeczy świadomie odłożone

- **Usunięcie gospodarstwa z ekranu** — jest w logice i w testach, ale nie
  ma przycisku: usuwa się rzadko, a pomyłka boli. Dojdzie z ekranem
  „Kopia danych", gdzie najpierw powstaje kopia.
- **Powierzchnia użytków rolnych wpisywana ręcznie** — dziś liczy się
  z pól, a kolumna `powierzchnia_ur_ha` czeka na gospodarstwa, w których
  nie wszystkie pola są jeszcze wpisane.
- **Konto przy synchronizacji** — nazwa konta jest przygotowana, ale samo
  przenoszenie danych między telefonem i komputerem to etap „Windows
  i synchronizacja".

## Etap 1 zamknięty

Wszystkie dziesięć kroków z planu (pkt 4) jest zrobione:

| Krok | Raport |
| --- | --- |
| 1. Działki i mapa | `etap1-krok1-dzialki-i-mapa.md` |
| 2. Import działek i upraw z PDF wniosku | `etap1-krok2-import-wniosku.md` |
| 3. Rejestr zabiegów | `etap1-krok3-rejestr-zabiegow.md` |
| 4. Dokumenty: podgląd, PDF, CSV/XLSX | `etap1-krok4-dokumenty.md` |
| 5. Terminy i przypomnienia | `etap1-krok5-terminy.md` |
| 6. Nawożenie: ewidencja, limit N, plan | `etap1-krok6-nawozenie.md` |
| 7. Odczyt zdjęć: etykieta, worek nawozu | `etap1-krok7-odczyt-zdjec.md` |
| 8. Karencja z bazy etykiet | `etap1-krok8-karencja.md` |
| 9. Zwierzęta: stado, terminy, DJP | `etap1-krok9-zwierzeta.md` |
| 10. Konta i kilka gospodarstw | ten raport |

### Co trzeba zrobić przed wydaniem

1. ~~**Przeliczniki DJP** — sprawdzić w załączniku do przepisów
   o nawozach.~~ **Zrobione 15.10.2026**: tabela 3 z programu działań
   (Dz.U. 2020 poz. 243) — `docs/raporty/djp-weryfikacja.md`.
2. **Terminy nawożenia** pochodzą ze strony ARiMR z 2019 r. — sprawdzić
   w aktualnym rozporządzeniu (plan, pkt 3).
3. **Uprawy bez decyzji o kodzie EPPO** —
   `dane/wynik/uprawy_eppo_do_decyzji.csv` z zadania P3.
4. **Pytanie do ministerstwa** o hurtowy dostęp do etykiet (P2) wciąż bez
   odpowiedzi; dziś baza wchodzi z wersją aplikacji.
5. **Format „maszynowo odczytywalny"** wymagany od 1.01.2027 nie jest
   jeszcze ogłoszony — eksport CSV/XLSX powstał tak, żeby dało się dołożyć
   kolejny format bez zmian w logice.
