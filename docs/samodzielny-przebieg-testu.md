# Samodzielny przebieg testu — zanim aplikacja trafi do ludzi

Wersja: **0.2.0+2** · słownik reguł: **2026.10.17.6**
Czas: **telefon ~40 minut, komputer ~15 minut.**

Po co osobny dokument, skoro są `docs/przypadki-testowe.md`? Tamte 70
przypadków to robota na kilka wieczorów i dla kilku osób. Tu jest jeden
przebieg od początku do końca, ułożony tak, żeby wyłapać rzeczy, które
**ośmieszyłyby aplikację przy pierwszym teście z rolnikiem**: zły
rachunek, zgubiony wpis, wydruk, którego nie da się pokazać kontroli.

Każdy krok ma **liczbę do porównania**. Jeśli aplikacja pokaże co innego —
to znalezisko, nawet jeśli ekran wygląda ładnie.

---

## Zanim zaczniesz

1. Zainstaluj plik `agro-asystent-0.2.0+2-arm64.apk` (39 MB) na swoim
   telefonie.
2. **Nie wpisuj prawdziwego numeru producenta ani prawdziwych numerów
   działek.** Zrzuty ekranu z testu będą krążyć; dane gospodarstwa
   testowego są niżej i są zmyślone.
3. Przygotuj kartkę i długopis — do zapisania numeru kroku, przy którym
   coś nie zagrało.

**Czego ja sam nie mogę sprawdzić:** w moim środowisku nie ma Androida
ani ekranu — buduję pliki i piszę testy, ale aplikacji nie widzę.
Dlatego ten przebieg jest wart tyle, ile Pana oczy. Zrzut ekranu
z numerem kroku wystarczy mi do poprawki.

## Gospodarstwo testowe (dane zmyślone)

| | Wartość |
| --- | --- |
| Nazwa | Gospodarstwo testowe |
| Numer producenta | zostaw puste |
| Powierzchnia użytków rolnych | **12,00 ha** |
| Zwierzęta | „Nie mam zwierząt" |
| Pole A | **Za stodołą**, pszenica ozima, **3,40 ha**, grunt orny, graniczy z wodą: **tak** |
| Pole B | **Przy drodze**, kukurydza, **8,60 ha**, grunt orny, graniczy z wodą: nie |

---

## Przebieg A — telefon (~40 min)

### A1. Start i wygląd
Zainstaluj, uruchom, wybierz wygląd **Prosty**.
→ Aplikacja wstaje bez pytania o konto i bez internetu.

### A2. Dane gospodarstwa
Ustawienia → dane gospodarstwa → wpisz nazwę, **12,00 ha**, „Nie mam
zwierząt".
→ Na dole ekranu Ustawień stoi **„Agro Asystent • Wersja 0.2.0 (budowa 2)"**.

### A3. Dwa pola
Pola → Dodaj pole → **Za stodołą**, pszenica ozima, **3,40 ha**.
Powtórz dla **Przy drodze**, kukurydza, **8,60 ha**.
→ Lista pokazuje dwa pola, razem **12,00 ha**.
→ **Policz dotknięcia przy drugim polu.** Jeśli wyszło więcej niż pięć
albo musiałeś pisać na klawiaturze — to znalezisko, nawet jeśli działa.

### A4. Rodzaj użytku i woda
Otwórz pole A → grunt orny → „graniczy z wodą: tak".
Pole B → grunt orny → „nie".
→ Odpowiedzi zostają po wyjściu i powrocie.

### A5. Oprysk z karencją
Dodaj zabieg → pole A → Oprysk → środek z listy → dawka → karencja
**14 dni** → Zapisz.
→ Data, godzina i powierzchnia (**3,40 ha**) uzupełniają się same.
→ **Przed zapisem musi stanąć ostrzeżenie o pasie od wody** — pole A
graniczy z wodą. Treść zaczyna się od „Pole Za stodołą graniczy z wodą,
a norma GAEC 4 zabrania tu…" i podaje pas **3 m** od brzegu (3 m
pochodzi ze słownika reguł, nie z kodu).
→ Zabieg zapisuje się **mimo ostrzeżenia**. Jeśli aplikacja zablokowała
zapis — to błąd priorytetu A.

### A6. Karencja w terminach
Terminy.
→ Jest pozycja z dniem **14 dni po dacie oprysku**, przypisana do pola
**Za stodołą**.

### A7. Oprysk bez karencji
Dodaj zabieg → pole B → Oprysk → ten sam środek → **nie podawaj
karencji** → Zapisz.
→ W rejestrze przy tym wpisie karencja jest **pusta albo „do
potwierdzenia"**. Jeśli aplikacja wstawiła tam 14 dni z poprzedniego
wpisu albo jakąkolwiek liczbę — **błąd A, zgadywanie**.

### A8. Własny nawóz naturalny
Nawożenie → Nawozy → Nowy nawóz → nazwa **Obornik bydlęcy**, rodzaj
**Naturalny**, azot **0,5 %** → Zapisz.

### A9. Pierwsze nawożenie — liczba do sprawdzenia
Dodaj zabieg → pole A (**3,40 ha**) → Nawożenie → Obornik bydlęcy →
dawka **30 t/ha** → Zapisz. Otwórz ekran Nawożenie.

Rachunek na kartce: 30 t × 1000 kg × 0,5 % = **150 kg N/ha**;
150 × 3,40 ha = **510 kg N**; 510 ÷ 12,00 ha = **42,5 kg N/ha**.

→ Zestawienie azotu ma pokazać **42,5 kg N/ha** przy limicie **170**.

### A10. Drugie nawożenie — blisko limitu
To samo na polu B (**8,60 ha**), dawka **30 t/ha**.

Rachunek: 150 × 8,60 = 1290 kg; razem 1800 kg ÷ 12,00 = **150,0 kg N/ha**.

→ Zestawienie pokazuje **150,0** — wciąż poniżej 170, **bez ostrzeżenia
o przekroczeniu**.

### A11. Trzecie nawożenie — przekroczenie limitu
Nowy nawóz: **Gnojowica bydlęca**, naturalny, azot **0,4 %**.
Zabieg na polu A, dawka **20 m³/ha**.

Rachunek: 20 × 1000 × 0,4 % = 80 kg N/ha; 80 × 3,40 = 272 kg;
razem 2072 kg ÷ 12,00 = **172,7 kg N/ha**.

→ Zestawienie pokazuje **172,7** i **wyraźne przekroczenie limitu 170**.
→ Wpis **i tak się zapisał** — dokumentujemy rzeczywistość.

### A12. Poprawka zostawia ślad
Rejestr zabiegów → pierwszy oprysk → Popraw → zmień dawkę → Zapisz.
→ Rejestr pokazuje nową dawkę.
→ Otwórz ten wpis jeszcze raz: **poprzednia wersja ma być widoczna
w historii zmian**, a nie skasowana.

### A13. Trzy rejestry i wydruk
Dokumenty → kolejno **Opryski**, **Nawożenie azotem**, **Ekoschematy**.
→ Wszystkie trzy otwierają się **bez jednego okna o płatności**.
→ Opryski → **Wydrukuj**: otwiera się podgląd systemowy, polskie znaki
są poprawne, w nagłówku stoi „Gospodarstwo testowe".
→ **Plik CSV** → zapisz i otwórz w arkuszu: liczba wierszy zgadza się
z rejestrem, przecinki dziesiętne na miejscu.

### A14. Warunkowość
Terminy → Warunkowość.
→ **GAEC 7** (zmianowanie) jest liczone, bo gruntów ornych jest 12,00 ha,
a norma obowiązuje **powyżej 10 ha**.
→ **GAEC 4** (pas od wody) odnosi się do pola A.

### A15. Okrywa — druga liczba do sprawdzenia
Pola → **Przy drodze** → zjedź do pytania o okrywę po zbiorze → wybierz
formę okrywy. **Pola A nie ruszaj** — ma zostać bez odpowiedzi.
Wróć do Terminy → Warunkowość → GAEC 6.

Rachunek: 80 % z 12,00 ha = 9,60 ha; zadeklarowane 8,60 ha →
**brakuje 1,00 ha**.

→ Aplikacja ma napisać wprost: **Do normy brakuje okrywy na 1,00 ha.**
Samo „nie spełniono", bez liczby, to znalezisko.

### A16. Tryb samolotowy
Włącz tryb samolotowy i powtórz: dodanie pola, wpis oprysku, otwarcie
rejestru, wydruk PDF, eksport CSV.
→ **Wszystko działa, ani jednego komunikatu o braku sieci.**

### A17. Kopia danych
Ustawienia → Kopia danych → **Zrób kopię** → zapisz plik tam, gdzie
znajdziesz go z komputera (dysk, poczta, chmura).
→ Plik powstaje w wersji darmowej, bez żadnej opłaty.

---

## Przebieg B — komputer (~15 min)

### B1. Uruchomienie
Rozpakuj **cały** folder z paczki `.zip` → `agro_asystent.exe` →
SmartScreen → „Więcej informacji" → „Uruchom mimo to".
→ Program otwiera się na **Pulpicie**.

### B2. Dołączenie danych z telefonu
Ustawienia → **Dołącz dane z telefonu** → wskaż plik kopii z kroku A17.
→ Podsumowanie mówi, ile pól i zabiegów doszło. **Nic nie ginie.**

### B3. Pulpit — trzecia liczba do sprawdzenia
→ Wykres „Co rośnie": **pszenica ozima 28 %**, **kukurydza 72 %**,
w środku **12,00 ha**.
  (3,40 ÷ 12,00 = 28 %; 8,60 ÷ 12,00 = 72 %.)
→ „Co mnie goni": ta sama karencja co w telefonie.

### B4. Pogoda bez sieci
Odetnij internet → odśwież pulpit.
→ Karta pogody pokazuje **ostatni odczyt z datą i godziną** albo mówi,
że nie wie, gdzie leży gospodarstwo (bo nie dodałeś działki z ULDK).
Żadnych zmyślonych liczb.

### B5. Ceny skupu
→ Karta mówi wprost, że **notowań nie wczytano**. Żadnej liczby.

### B6. Kalendarz biodynamiczny
→ Na karcie stoi, że to **tradycja, nie przepis**.
→ „Pokaż miesiąc" rozwija siatkę na cały miesiąc.

### B7. Wydruk z komputera
Dokumenty → Opryski → Wydrukuj i Eksport CSV.
→ Ten sam dokument co z telefonu, te same wiersze.

### B8. Wielkość tekstu
Ustawienia → **Bardzo duży** → przejdź wszystkie osiem zakładek.
→ Nic nie jest ucięte, nic nie wychodzi poza okno.

---

## Wszystkie liczby w jednym miejscu

| Krok | Co ma pokazać aplikacja |
| --- | --- |
| A3 | razem **12,00 ha**, dwa pola |
| A5 | ostrzeżenie o pasie **3 m**, zapis mimo ostrzeżenia |
| A7 | karencja **pusta / do potwierdzenia** (nigdy zgadnięta) |
| A9 | **42,5 kg N/ha** (limit 170) |
| A10 | **150,0 kg N/ha**, bez ostrzeżenia |
| A11 | **172,7 kg N/ha**, **przekroczenie limitu** |
| A14 | GAEC 7 liczone (12,00 ha > **10 ha**) |
| A15 | zdanie z liczbą: brakuje okrywy na **1,00 ha** |
| B3 | **28 % / 72 %**, w środku **12,00 ha** |

Jeśli którakolwiek liczba się nie zgadza — to **błąd priorytetu A**:
dokumentacja pokazywałaby nieprawdę. Wtedy zatrzymaj test i wyślij mi
zrzut ekranu z numerem kroku.

## Czego nie zgłaszać (wiem o tym)

- Brak prawdziwych notowań cen skupu.
- Brak wpisu zabiegu i poprawiania wpisów na komputerze.
- Brak zestawienia do wniosku i „kompletu na kontrolę".
- Wiadomości rolnicze mogą nie przyjść — adresy kanałów są nieprawdzone.
- Przy nowej wersji trzeba odinstalować poprzednią (brak klucza
  wydawniczego).

## Co zrobić po przebiegu

1. Wszystko zgadza się → rozsyłaj testerom
   (`docs/instrukcja-dla-testerow.md`, gotowa wiadomość na końcu).
2. Coś nie zagrało → numer kroku + zrzut ekranu. Poprawka i nowy plik
   wychodzą tym samym linkiem.
3. Przed rozesłaniem rozważ zrobienie klucza wydawniczego
   (`docs/wydanie-android.md`) — inaczej każdy tester przy każdej nowej
   wersji traci swoje wpisy.
