# Plan testów manualnych

Wersja testowana: **0.2.0+2** (Android i Windows)
Data planu: 18 października 2026 r.

## Po co ten plan

Kod pilnuje się sam: **681 testów Flutter i 156 testów Pythona** chodzi przy
każdej zmianie. Sprawdzają rachunki (limit azotu, DJP, zmianowanie,
okrywa, karencje), zapis do bazy, scalanie kopii, układ ekranów i to, czy
progi z przepisów nie wyciekły do kodu.

Testy manualne mają **inne zadanie** — mają dotknąć tego, czego automat
nie dotknie:

| Czego automat nie sprawdzi | Dlaczego |
| --- | --- |
| Prawdziwy telefon w polu | palec w rękawicy, słońce w ekran, zasięg jeden kreskę |
| Prawdziwy wniosek z eWniosekPlus | każdy wniosek wygląda inaczej; wzorzec w `test/dane/` to jeden przypadek |
| Granice działek z ULDK | usługa państwowa, odpowiada różnie i bywa niedostępna |
| Wydruk i udostępnienie pliku | zależy od drukarki, aplikacji i systemu |
| Powiadomienia | zależą od ustawień oszczędzania energii w telefonie |
| Pogoda i wiadomości z sieci | prawdziwe serwisy, prawdziwe awarie |
| Ergonomia dla rolnika 60+ | czy wie, co nacisnąć — tego nie da się zmierzyć testem |
| Aktualizacja i dwa urządzenia | przeniesienie danych telefon → komputer na żywym sprzęcie |

Zasada: **jeśli coś da się sprawdzić automatem — ma być automat.** Czas
testera jest drogi i marnowanie go na klikanie rachunków jest błędem.

## Zakres tej rundy

**Testujemy:** instalację, pola i działki, wpis zabiegu, nawożenie,
terminy, warunkowość, dokumenty (wydruk i eksport), magazyn, kopię
i scalanie, tryb offline, program na Windows, ergonomię obu wyglądów
telefonu.

**Wydanie dla testerów ma odblokowane wszystkie dodatki** (flaga
budowania `AGRO_WYDANIE_TESTOWE`). Dzięki temu tester ogląda całość —
ale przypadki z grupy **PRE** (co darmowe, co płatne) wymagają osobnego
pliku, zbudowanego bez odblokowania: Actions → „Zbuduj APK" → Run
workflow → odznaczyć „Wydanie testowe". Tę samą granicę pilnują testy
automatyczne w `test/rdzen/dostep/`.

**Nie testujemy** (jeszcze nie istnieje — zgłoszenia na ten temat
odrzucamy jako „poza zakresem", nie jako błąd):

- cen skupu z prawdziwymi notowaniami (plik danych jest pusty),
- wysyłki zgłoszeń do IRZplus i rejestru stada spiętego z ekranami,
- zestawienia do wniosku i „kompletu na kontrolę jednym przyciskiem",
- wpisu zabiegu i poprawiania wpisów na komputerze.

## Środowisko

| | Wymaganie |
| --- | --- |
| Android | 7.0 (API 24) i nowszy — niżej aplikacja się nie zainstaluje |
| Telefony | minimum trzy: jeden nowy, jeden 4–6-letni, jeden z małym ekranem (≤ 5,5") |
| Windows | 10 albo 11, 64-bit |
| Sieć | część przypadków wymaga **wyłączenia** internetu (tryb samolotowy) |
| Pliki | wzorzec wniosku: `test/dane/wzorzec_wniosku.pdf`; prawdziwy wniosek — tylko na urządzeniu testera, **nigdy do repozytorium ani do zgłoszenia** |

## Kto testuje — dwie role

**Rolnik (2–5 osób).** Dostaje zadania z życia, nie listę kroków:
„zapisz oprysk, który robiłeś w zeszłym tygodniu". Patrzymy, gdzie się
zatrzyma. To jedyny sposób, żeby sprawdzić, czy język aplikacji jest
językiem rolnika.

**Tester techniczny (właściciel albo osoba obyta).** Przechodzi
przypadki z `docs/przypadki-testowe.md` po kolei, łącznie z brzegowymi:
brak sieci, pusta baza, przerwana instalacja, dwa urządzenia naraz.

## Sesja z rolnikiem — jak ją prowadzić

1. **Nie tłumacz z góry.** Daj telefon i zadanie. Pierwsze zawahanie jest
   najcenniejszą informacją w całej sesji.
2. **Proś o myślenie na głos** („co teraz szukasz?").
3. **Nie podpowiadaj**, dopóki tester sam nie poprosi. Zapisz, po ilu
   sekundach poprosił.
4. **Mierz dotknięcia** przy wpisie zabiegu. Cel z planu: **najwyżej pięć,
   bez klawiatury.**
5. Sesja 40–50 minut, nie dłużej. Na koniec jedno pytanie:
   *„Czy użyłbyś tego jutro w polu?"* — i prośba o uzasadnienie.

## Priorytety błędów

| Priorytet | Co to znaczy | Przykład | Termin |
| --- | --- | --- | --- |
| **A — blokujący** | dokumentacja jest zła albo giną dane; rolnik mógłby pokazać kontroli nieprawdę | zły limit azotu, zgubiony wpis po scaleniu, karencja policzona bez potwierdzenia | przed rozesłaniem kolejnej wersji |
| **B — poważny** | zadania nie da się dokończyć albo trzeba je obejść | nie zapisuje się oprysk na polu bez uprawy, wydruk nie otwiera się na telefonie | w następnej wersji |
| **C — niewygoda** | da się zrobić, ale źle się robi | za mały odstęp przycisków, niejasne słowo, zbędne potwierdzenie | gdy nie ma A i B |

Osobno notujemy **U — uwagi rolnika**: „nie wiedziałem, co nacisnąć".
To nie są błędy, tylko materiał na zmianę ekranu.

## Kryteria wyjścia rundy

Wersję wolno rozesłać szerzej, gdy:

1. Żadnego błędu **A** otwartego.
2. Wszystkie przypadki priorytetu A w `docs/przypadki-testowe.md`
   zaliczone na **co najmniej dwóch różnych telefonach**.
3. Wpis oprysku i wpis nawożenia zrobione przez **co najmniej dwóch
   rolników bez podpowiedzi**.
4. Wydruk rejestru obejrzany przez kogoś, kto widział prawdziwą kontrolę.
5. Komplet: instalacja → wpis → wydruk → kopia → odtworzenie kopii
   przeszedł raz od początku do końca.

## Zgłaszanie błędów

Szablon (do skopiowania):

```
Co robiłem:
Co się stało:
Czego się spodziewałem:
Wersja (Ustawienia, na dole):   0.2.0
Telefon / Windows:
Priorytet (A/B/C):
Zrzut ekranu: tak/nie
```

**Zasada o danych osobowych.** Zrzuty ekranu i opisy nie mogą zawierać
numeru producenta, numerów prawdziwych działek ani nazwisk. Przed
wysłaniem zasłoń je palcem albo zamaluj. W repozytorium takich danych
nie wolno umieszczać nigdy (CLAUDE.md, reguła 2) — do odtworzenia błędu
wystarczy opis.

## Ewidencja przebiegu

Dla każdej rundy prowadzimy prostą tabelkę (arkusz albo kartka):

| ID przypadku | Telefon / PC | Wynik (OK / błąd) | Nr zgłoszenia | Uwagi |
| --- | --- | --- | --- | --- |

Przypadki są w `docs/przypadki-testowe.md`. Tabelkę najłatwiej zrobić,
kopiując z niego kolumnę z identyfikatorami.
