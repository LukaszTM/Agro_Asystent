# Etap 3: program na komputer — pulpit, pola, pogoda, rynek

Zamówienie właściciela (18 października 2026 r.): program na PC ma umieć
dodawać pola, wczytywać wniosek i prowadzić profil gospodarstwa, a na
pierwszym ekranie pokazywać zasiewy na wykresie kołowym, mapkę pól,
pogodę, kalendarz biodynamiczny (tydzień z rozwinięciem na miesiąc),
lokalne ceny skupu i wiadomości z branży.

Poniżej podział na kroki, w kolejności od rzeczy, które działają **bez
internetu**, do tych, które go wymagają. Każdy krok kończy się działającym
programem (plan, pkt 4).

## Co jest czym

| | Działa offline | Wymaga sieci | Uwaga |
| --- | --- | --- | --- |
| Pulpit: zasiewy, mapka, terminy | ✅ | — | liczone z własnej bazy |
| Dodawanie pól, wniosek, profil | ✅ | wniosek: nie; działka po numerze: ULDK | tak samo jak na telefonie |
| Kalendarz biodynamiczny | ✅ | — | rachunek astronomiczny, liczony na miejscu |
| Pogoda | ostatni odczyt z pamięci | ✅ | potrzebne źródło z licencją na użytek komercyjny |
| Ceny skupu | ✅ (dane z paczki) | — | ministerstwa **nie** pobieramy z komputera rolnika (CLAUDE.md, pkt 3) |
| Wiadomości rolnicze | ostatnie pobrane | ✅ | tytuł, zajawka i odnośnik — nie cała treść (prawo autorskie) |

## Kroki

1. **Pulpit** — ✅ zrobione. Wykres kołowy zasiewów (udział upraw
   w powierzchni, pola bez uprawy osobno, nie doliczane do żadnej),
   mapka działek z granicami, skrót najbliższych terminów.
2. **Pola na komputerze** — dodanie pola z klawiatury, wczytanie wniosku
   PDF, dodanie działki po numerze (ULDK), poprawianie pola.
3. **Profil gospodarstwa** — nazwa, numer producenta, powierzchnia UR,
   zwierzęta i DJP, konto, drugie gospodarstwo. Dziś na PC tylko do
   odczytu, bo te dane stoją na każdym wydruku.
4. **Kalendarz biodynamiczny** — faza Księżyca i znak zodiaku liczone na
   miejscu, dzień korzenia / liścia / kwiatu / owocu, widok tygodnia
   z rozwinięciem na miesiąc. **To tradycja, nie przepis** — program
   mówi to wprost i nigdy nie miesza tego z obowiązkami prawnymi ani
   z terminami z rozporządzeń.
5. **Pogoda** — co najmniej trzy doby, godzinowo na dziś i jutro:
   temperatura, opad, wiatr (ważny przy oprysku), wilgotność. Potrzebna
   decyzja o źródle i **sprawdzenie licencji pod kątem użytku
   komercyjnego** (budżet = 0): kandydaci to MET Norway, IMGW-PIB
   i Open-Meteo. Wynik trafi do ADR. Bez sieci program pokazuje ostatni
   odczyt z datą, a nie pustkę.
6. **Wiadomości rolnicze** — kanały RSS branżowe, tytuł + zajawka +
   odnośnik do źródła. Pobierane rzadko i zapisywane lokalnie.
7. **Ceny skupu** — zboża, rzepak, mleko, żywiec. Źródłem są notowania
   Zintegrowanego Systemu Rolniczej Informacji Rynkowej (ministerstwo).
   Tych stron **nie wolno pobierać z urządzenia rolnika**, więc dane
   przygotowuje skrypt w `tools/` i jadą do programu jako paczka
   z datą i numerem wersji. Program pokazuje, z którego tygodnia są
   notowania — nigdy nie udaje, że cena jest dzisiejsza.
   „Lokalne" znaczy tu: makroregion / województwo gospodarstwa, bo
   notowania krajowe publikuje się w takim podziale.

## Czego program nie zrobi i powie o tym wprost

- **Nie policzy ceny dla konkretnego skupu za miedzą.** Pokaże notowania
  urzędowe dla regionu i datę — reszta to rozmowa z kupującym.
- **Nie oprze terminu zabiegu na kalendarzu biodynamicznym.** Terminy
  i karencje biorą się z przepisów i etykiet, nie z Księżyca.
- **Nie obieca pogody bez internetu.** Pokaże ostatni odczyt i kiedy go
  pobrał.
