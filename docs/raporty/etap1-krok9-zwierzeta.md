# Raport etap 1, krok 9 — zwierzęta: rejestr stada, DJP i zgłoszenia

15 października 2026 r. Zadanie z planu (pkt 4, krok 9):
„Zwierzęta: rejestr stada, terminy zgłoszeń, DJP".

## Po co to w aplikacji

Od liczby **DJP** (dużych jednostek przeliczeniowych) zależy, czy
gospodarstwo musi prowadzić ewidencję nawożenia i mieć plan nawożenia
azotem. Dotąd profil gospodarstwa podawał `djp = 0`, więc silnik reguł
nie mógł włączyć obowiązków zależnych od zwierząt. Teraz DJP liczy się
z rzeczywistego stanu stada.

Drugi powód: **zgłoszenia do IRZplus**. Urodzenie i kupno zwierzęcia
trzeba zgłosić w terminie ze słownika (dziś 7 dni od urodzenia).
Aplikacja nie wysyła zgłoszeń — pilnuje terminu i odhacza to, co rolnik
już zgłosił.

## Co powstało

| Plik | Zadanie |
| --- | --- |
| `lib/funkcje/zwierzeta/stado.dart` | stada, zwierzęta, zdarzenia, stan stada i wyliczenie DJP |
| `lib/wyglad/prosty/zwierzeta/ekran_zwierzeta.dart` | karta DJP, lista „Do zgłoszenia w IRZplus", stan stada |
| `lib/wyglad/prosty/zwierzeta/ekran_nowe_zwierze.dart` | dodanie zwierzęcia: skąd, numer kolczyka, grupa |
| `assets/dane/reguly_prawne.json` | nowy dział `wspolczynniki_djp` (16 grup, 6 gatunków) + pole `zdarzenie` przy terminie IRZplus |
| `lib/rdzen/reguly/regula_prawna.dart` | `GrupaDjp`, `WspolczynnikiDjp`, `Termin.zdarzenie` |
| `lib/rdzen/baza/migracje.dart` | migracja 3: kolumna `grupa_djp` przy zwierzęciu |
| `lib/funkcje/terminy/kalendarz_terminow.dart` | terminy ze zdarzeń zwierząt; `ProfilZBazy` podaje DJP i „posiadacz zwierząt" |

## Przeliczniki DJP są danymi, nie kodem

Grupy i przeliczniki stoją w słowniku reguł. Kod Dart nie zna żadnej
liczby z przepisu — pobiera ją po identyfikatorze grupy (`bydlo_krowa`,
`trzoda_tucznik`, …). Współczynnik jest **przepisywany do wiersza
zwierzęcia w chwili dodania**: gdy przepis się zmieni, stare wpisy
zostają takie, jakie były, a kontrola widzi to, co obowiązywało wtedy.

Termin zgłoszenia też jest danymi: termin `irzplus_urodzenie_cielecia`
ma teraz pole `"zdarzenie": "urodzenie"`, i to ono wiąże zdarzenie
w bazie z liczbą dni z przepisu. Dodanie kolejnego zgłoszenia (np. kupna)
to wpis w słowniku, nie zmiana w kodzie.

## Czego nie zgadujemy

- **Zwierzę bez grupy** zapisuje się normalnie, ale nie wchodzi do DJP.
  Ekran mówi wprost: „1 sztuk bez grupy — te nie są policzone".
- **Przeliczniki czekają na sprawdzenie w przepisie.** Słownik ma
  `"status_weryfikacji": "do_weryfikacji"`, więc karta DJP pokazuje
  ostrzeżenie „Przeliczniki na DJP czekają na sprawdzenie w przepisie"
  razem ze źródłem do potwierdzenia. Dopóki status jest inny niż
  „potwierdzone", wynik nie udaje pewnego.

## Liczby

| Miara | Wartość |
| --- | --- |
| Grupy zwierząt w słowniku | 16 (6 gatunków) — po weryfikacji 85 (22 gatunki) |
| Nowe pliki kodu | 3 (+ zmiany w pięciu) |
| Nowe pliki testów | 2 |
| Testy dodane w tym kroku | 14 (9 logiki + 5 ekranów) |
| Testy w całym projekcie | 235 (było 221) |
| Nowa migracja bazy | 3 (`zwierze.grupa_djp`) |
| `flutter analyze` | bez ostrzeżeń |

## Czego pilnują testy

- Słownik przeliczników podaje źródło i status; gdy status nie jest
  „potwierdzone", ekran pokazuje ostrzeżenie (po weryfikacji z 15.10.2026
  testem jest to, że sprawdzony słownik ostrzeżenia **nie** pokazuje).
- Zwierzę sprzedane, padłe albo ubite wychodzi ze stanu stada; urodzone
  i kupione w nim zostaje.
- 2 krowy + cielę = 2,15 DJP (przeliczniki ze słownika).
- Zwierzęta bez grupy są liczone osobno i nie podbijają DJP.
- Po przekroczeniu progu DJP silnik reguł włącza ewidencję nawożenia.
- Urodzenie 10.05 + 7 dni ze słownika = termin zgłoszenia 17.05.
- Zdarzenie oznaczone jako zgłoszone znika z listy do zgłoszenia.

## Rzeczy świadomie odłożone

- **Rejestr zwierząt do wydruku** — trzeci z rejestrów z planu wymaga
  urzędowego układu kolumn; wejdzie razem z resztą dokumentów zwierzęcych.
- **Ubycie zwierzęcia z ekranu** — sprzedaż, padnięcie i ubój są w bazie
  i w wyliczeniach, ale nie mają jeszcze przycisku; dochodzą w etapie 2
  razem z historią pojedynczego zwierzęcia.
- **Waga i wiek** zamiast grupy wybranej ręcznie: przeliczniki zależą od
  wieku, więc po potwierdzeniu przepisu grupa może wynikać z daty
  urodzenia sama.

## Do zrobienia przed wydaniem — **sprawa zamknięta 15.10.2026**

Przeliczniki DJP zostały sprawdzone w rozporządzeniu i wymienione na
urzędowe: **Dz.U. 2020 poz. 243, załącznik nr 1, tabela 3**. Szczegóły
i wykaz poprawionych wartości: `docs/raporty/djp-weryfikacja.md`.
Słownik ma teraz `status_weryfikacji: "potwierdzone"`, więc karta DJP nie
pokazuje już ostrzeżenia „do sprawdzenia".

Pierwotna treść tej sekcji: wartości wpisane w kroku 9 służyły uruchomieniu
modułu i czekały na sprawdzenie w przepisie. Pięć z nich było błędnych —
dlatego były oznaczone jako niepewne.
