# Etap 3: pulpit, pola na komputerze i dane z sieci

18 października 2026 r.

Zamówienie właściciela: program na PC ma dodawać pola, wczytywać wniosek
i prowadzić profil gospodarstwa, a na pierwszym ekranie pokazywać zasiewy
na wykresie, mapkę pól, pogodę, kalendarz biodynamiczny, ceny skupu
i wiadomości z branży. Siedem kroków, wszystkie zrobione — z jednym
wyjątkiem opisanym niżej uczciwie.

## Co powstało

| Krok | Stan | Co to znaczy w programie |
| --- | --- | --- |
| 1. Pulpit | ✅ | wykres kołowy zasiewów, mapka działek, skrót terminów |
| 2. Pola na PC | ✅ | „Dodaj pole", „Działka po numerze" (ULDK), „Wczytaj wniosek z PDF" |
| 3. Profil gospodarstwa | ✅ | nazwa, numer producenta, powierzchnia UR, zwierzęta — w jednym oknie |
| 4. Kalendarz biodynamiczny | ✅ | tydzień z rozwinięciem na miesiąc, liczony na urządzeniu |
| 5. Pogoda | ✅ | najbliższe godziny i cztery doby, MET Norway |
| 6. Wiadomości rolnicze | ✅ | nagłówki z kanałów RSS, pełny artykuł u wydawcy |
| 7. Ceny skupu | ⚠️ mechanizm gotowy, **notowań brak** | program dobiera cenę do województwa; plik danych czeka na uruchomienie skryptu |

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 617 | **679** |
| Testy Python | 136 | **156** |
| Migracje bazy | 9 | **11** |
| Pliki danych z wersją | 3 | **6** |
| `flutter analyze` | czysto | czysto |

Nowe pliki danych: kalendarz biodynamiczny, kanały wiadomości, ceny
skupu. Nowe migracje: pamięć podręczna pogody i wiadomości.

## Trzy rzeczy, których program nie udaje

1. **Nie zna ceny skupu za miedzą.** Pokazuje notowanie urzędowe dla
   regionu i tydzień, z którego pochodzi. Dopóki nikt nie uruchomi
   skryptu na prawdziwym pliku notowań, mówi wprost: notowań nie ma.
   Pusta karta jest uczciwsza niż wymyślona liczba, na podstawie której
   ktoś sprzedaje zboże.
2. **Nie liczy terminów z Księżyca.** Kalendarz biodynamiczny stoi na
   pulpicie z zastrzeżeniem na wierzchu: to tradycja, nie przepis.
   Terminy i karencje biorą się z rozporządzeń i etykiet.
3. **Nie podaje dopuszczalnej prędkości wiatru przy oprysku.** To wartość
   z przepisu i z etykiety środka, więc trafi do słownika reguł, a nie do
   kodu pogody. Dziś karta pokazuje liczbę i odsyła do etykiety.

## Co wymaga jednego ruchu na komputerze właściciela

| Rzecz | Dlaczego nie da się jej zrobić z tego miejsca |
| --- | --- |
| Notowania cen skupu | `python3 tools/ceny/ceny_skupu.py --csv … --od … --do … --zapisz assets/dane/ceny_skupu.json` — dane ministerstwa pobiera się na komputerze dewelopera, nie z urządzenia rolnika |
| Adresy kanałów RSS | `python3 tools/wiadomosci/sprawdz_kanaly.py --zapisz` — ze środowiska, w którym powstawał kod, portale rolnicze są nieosiągalne, więc wszystkie cztery mają status „do_weryfikacji" |
| Regulamin MET Norway | `api.met.no` też jest stąd nieosiągalny; warunki znamy z dokumentacji pośredniej, przed wydaniem trzeba je przeczytać i wpisać prawdziwy adres kontaktowy w `User-Agent` |

## Dla porządku: nowe zależności

| Paczka | Licencja | Po co |
| --- | --- | --- |
| `xml` 7.1 | MIT | czytanie kanałów RSS i Atom (była już zależnością pośrednią) |
| `url_launcher` 6.3 | BSD-3 (zespół Fluttera) | otwarcie artykułu u wydawcy |

Obie darmowe i z licencją pozwalającą na użycie komercyjne — tak jak
wymaga CLAUDE.md.
