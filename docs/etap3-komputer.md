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
2. **Pola na komputerze** — ✅ zrobione. Dodanie pola z klawiatury
   (uprawa podpowiada się ze słownika, kod EPPO tylko z wyboru),
   działka po numerze z ULDK i wczytanie wniosku PDF.
3. **Profil gospodarstwa** — ✅ zrobione. Nazwa, numer producenta,
   powierzchnia użytków rolnych i odpowiedź o zwierzętach — w jednym
   oknie, z klawiatury. Drugie gospodarstwo zostaje dodatkiem płatnym.
4. **Kalendarz biodynamiczny** — ✅ zrobione. Położenie Księżyca liczone
   na miejscu (szeregi Meeusa, dokładność ~0,1 stopnia), dzień korzenia /
   liścia / kwiatu / owocu, faza i oświetlenie tarczy, godzina zmiany
   gwiazdozbioru. Tydzień na pulpicie, rozwijany na cały miesiąc.
   **To tradycja, nie przepis** — zastrzeżenie stoi na karcie, nie
   w drobnym druku. Granice gwiazdozbiorów i przypisanie żywiołów są
   danymi (`assets/dane/kalendarz_biodynamiczny.json`), nie kodem.
5. **Pogoda** — ✅ zrobione. Najbliższe godziny i cztery doby:
   temperatura, opad, wiatr. Źródłem jest MET Norway (CC BY 4.0,
   użycie komercyjne dozwolone); Open-Meteo odpadło, bo darmowe API wolno
   używać tylko niekomercyjnie — `docs/decyzje/ADR-0008-pogoda.md`.
   Położenie liczymy z granic działek, więc rolnik nie podaje adresu.
   Bez sieci karta pokazuje ostatni odczyt **z datą**, a nie pustkę.
   Dopuszczalnej prędkości wiatru przy oprysku program nie podaje — to
   dana z przepisu i z etykiety, nie z kodu pogody.
6. **Wiadomości rolnicze** — ✅ zrobione. Kanały RSS i Atom: tytuł,
   zajawka bez znaczników, nazwa źródła i odnośnik do wydawcy. Całego
   artykułu nie pobieramy i nie pokazujemy — to cudzy tekst. Kanał, który
   nie odpowiada, jest pomijany; bez internetu zostają ostatnie nagłówki
   z datą. Adresy kanałów są danymi
   (`assets/dane/kanaly_wiadomosci.json`) ze statusem weryfikacji,
   a sprawdza je `tools/wiadomosci/sprawdz_kanaly.py` **na komputerze
   dewelopera** — nie z urządzenia rolnika (CLAUDE.md, reguła 3).
   Dziś wszystkie cztery kanały mają status `do_weryfikacji`: adresów nie
   dało się potwierdzić ze środowiska, w którym powstawał kod.
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
