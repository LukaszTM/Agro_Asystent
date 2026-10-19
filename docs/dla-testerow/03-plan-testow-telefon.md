# Plan testów — telefon (Android)

**Tester:** …………………………… **Model telefonu:** …………………………… **Android:** ………
**Wersja aplikacji** (Ustawienia → „Agro Asystent • Wersja …"): ……………
**Wygląd:** Prosty / Nowoczesny (zakreśl) **Data:** ……………

Jak zakreślać: **TAK** — stało się to, co w kolumnie „Co powinno się stać".
**NIE** — stało się coś innego; napisz co w „Uwagach". **–** — nie robiłem.
Nie musisz robić wszystkiego. Punkty z gwiazdką ★ są najważniejsze.

## A. Instalacja i start

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| A1 ★ | Zainstaluj aplikację według instrukcji 01 i uruchom | Aplikacja wstaje, pyta o wygląd (Prosty / Nowoczesny), po wyborze pokazuje ekran główny. Nie żąda logowania ani internetu | TAK / NIE | |
| A2 | Zamknij aplikację z listy ostatnich aplikacji i otwórz od nowa | Ten sam wygląd, bez pytania od nowa | TAK / NIE | |
| A3 | Ustawienia → Wygląd → wybierz drugi wygląd | Cała aplikacja zmienia wygląd od razu; pola i wpisy zostają | TAK / NIE | |
| A4 | Ustawienia → znajdź numer wersji | Widać „Agro Asystent • Wersja … (budowa …)" i zdanie, że to wydanie testowe | TAK / NIE | |

## B. Gospodarstwo i pola

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| B1 ★ | Ustawienia → dotknij nazwy gospodarstwa → wpisz nazwę, właściciela, numer producenta, powierzchnię → zapisz | Dane widać na ekranie Ustawień; pusty właściciel pokazuje się jako „nie podano" | TAK / NIE | |
| B2 ★ | Pola → Dodaj pole: nazwa „Za stodołą", powierzchnia przyciskami + / −, uprawa z listy (np. pszenica ozima) → Zapisz pole | Pole jest na liście z nazwą, powierzchnią i uprawą; przy uprawie widać kod EPPO | TAK / NIE | |
| B3 | Dodaj pole z uprawą, której nie ma na liście (wpisz własną nazwę) | Program przyjmuje nazwę i mówi, że kodu EPPO nie ma — na wydruku będzie „brak" | TAK / NIE | |
| B4 | Dodaj pole, szukając uprawy „traw" | Na liście są „Trawy", bez kodu EPPO | TAK / NIE | |
| B5 | Otwórz pole → Zmień nazwę pola → „Pod lasem" → Zapisz nazwę | Nowa nazwa w nagłówku i na liście pól | TAK / NIE | |
| B6 | Otwórz pole → ustaw rodzaj użytku i odpowiedz na pytanie o wodę przy polu | Wybór zapisuje się od razu; program nie odpowiada za Ciebie | TAK / NIE | |
| B7 | Otwórz pole → Zmień uprawę → wybierz inną | Nowa uprawa widoczna; poprzednia zostaje w historii upraw (lista lat) | TAK / NIE | |

## C. Działki i mapa

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| C1 ★ | Pola → Działki i mapa → Dodaj działkę → „Mam pełny numer z wniosku" → wpisz numer działki (z wypisu albo wniosku) → Znajdź działkę | Pojawia się mapa z granicą i pytanie „Czy to ta działka?"; po „Tak, to moja działka" działka jest na liście i na mapie | TAK / NIE | |
| C2 ★ | Dodaj działkę → „Znajdź działkę po miejscowości": dotknij województwa, wpisz nazwę wsi i numer działki → Znajdź działkę | Jedna taka działka → od razu mapa; kilka → lista gmin do wyboru (program nie wybiera sam); po wyborze mapa | TAK / NIE | |
| C3 | Wpisz numer działki z błędną cyfrą | Jedno zdanie, że działki nie znaleziono, i podpowiedź co sprawdzić; nic się nie zapisuje | TAK / NIE | |
| C4 | Włącz tryb samolotowy i spróbuj C2 | Jedno zdanie o braku internetu i rada, co zrobić; aplikacja się nie zawiesza | TAK / NIE | |
| C5 ★ | Przy włączonym trybie samolotowym otwórz Pola → Działki i mapa | Mapa z dodanymi działkami rysuje się bez internetu | TAK / NIE | |
| C6 | Pola → Wczytaj wniosek z PDF → wskaż plik wniosku (tylko własny, na próbę) | Program pokazuje, ile działek i pól wczyta, i prosi o potwierdzenie; po potwierdzeniu pola i działki są na listach | TAK / NIE | |

## D. Wpis zabiegu — najważniejsze

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| D1 ★ | Ekran główny → Dodaj zabieg → pole → Oprysk → środek z listy → Zapisz. **Policz dotknięcia** | Zabieg zapisany w najwyżej pięciu dotknięciach, bez pisania; data, godzina i powierzchnia uzupełnione same | TAK / NIE | dotknięć: …… |
| D2 ★ | Przy wyborze środka zwiększ dawkę przyciskiem + powyżej dopuszczalnej | Ostrzeżenie, że dawka przekracza dopuszczalną, i co zrobić; zapis nadal możliwy | TAK / NIE | |
| D2a ★ | Przy dawce dotknij liczby → wpisz na klawiaturze np. 1,5 → Gotowe | Dawka ustawiona od razu na 1,50, bez klikania „+"; przecinek działa; „Anuluj" nic nie zmienia | TAK / NIE | |
| D3 ★ | Wybierz środek, przy którym program pisze, że rejestr nie podaje dawki | Można wpisać dawkę z etykiety: liczba od zera, jednostka z listy (l/ha, kg/ha…) | TAK / NIE | |
| D4 | W sytuacji D3 ustaw dawkę, ale nie wybieraj jednostki | Ostrzeżenie, że nie wiadomo, w czym podana jest dawka | TAK / NIE | |
| D5 | W sytuacji D3 zapisz zabieg z dawką zero | Zabieg zapisuje się bez dawki (dokumentacja nie jest blokowana) | TAK / NIE | |
| D6 ★ | Po zapisie oprysku obejrzyj ekran „Zapisano" | Widać karencję w dniach, najwcześniejszy dzień zbioru i datę etykiety; gdy karencji nie ma w rejestrze — zdanie „sprawdź etykietę", bez żadnej liczby | TAK / NIE | |
| D7 ★ | Przejdź cały wpis oprysku i patrz na ekrany | Ani razu nie pojawia się oferta wersji płatnej ani słowo o opłacie | TAK / NIE | |
| D8 | Przy wyborze środka naciśnij „Rozpoznaj etykietę" i zrób zdjęcie opakowania | Program rozpoznaje nazwę środka albo mówi, że nie rozpoznał — nie zgaduje | TAK / NIE | |
| D9 | Zacznij wpis i wyjdź w połowie (Wstecz, potem lista zadań) | Nie powstaje żaden wpis; po powrocie można zacząć od nowa | TAK / NIE | |
| D10 | Dodaj zabieg → pole → Siew (albo Zbiór) → Zapisz | Wpis zapisuje się bez środka i bez dawki | TAK / NIE | |
| D11 | Dodaj zabieg → pole → Inny → „przycinanie drzew" (w okresie wiosennym) | Ostrzeżenie o okresie lęgowym ptaków z radą; zapis możliwy | TAK / NIE | |

## E. Nawożenie

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| E1 ★ | Pola → Nawożenie → Nawozy → Dodaj nawóz (np. saletra, azot 34 %) → Zapisz; potem Dodaj zabieg → pole → Nawożenie → ten nawóz → dawka → Zapisz | Program liczy azot na hektar i pokazuje, ile zostało do limitu | TAK / NIE | |
| E2 | Dodaj nawóz bez podania zawartości azotu i wpisz nim nawożenie | Program mówi wprost, że azotu nie policzy — nie wstawia liczby | TAK / NIE | |
| E3 | Wpisz nawożenie azotowe z datą po terminie granicznym dla Twojej gminy (np. grudzień) | Ostrzeżenie o terminie z radą; zapis możliwy | TAK / NIE | |
| E4 ★ | Dodaj nawóz naturalny (obornik) → Dodaj zabieg → pole → Nawożenie → obornik → przy „Przyoranie" wybierz „Nazajutrz" → Zapisz | Wpis zapisany; w Dokumentach w podglądzie wpisu „Data przyorania" to dzień po zabiegu | TAK / NIE | |
| E5 | Wpisz nawożenie obornikiem z „Jeszcze nie" → Dokumenty → ten wpis → Dopisz datę przyorania (Nowoczesny: Popraw wpis) → Tego samego dnia → Zapisz | Data pojawia się w ewidencji; wcześniej pole było oznaczone jako brak | TAK / NIE | |
| E6 | Wpisz nawożenie saletrą (nawóz mineralny) i obejrzyj wpis w Dokumentach | Program nie pyta o przyoranie; w ewidencji przy dacie przyorania stoi „nie dotyczy" | TAK / NIE | |

## F. Rejestr, poprawki, wydruk

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| F1 ★ | Dokumenty → dotknij wpisu → Popraw wpis → zmień dawkę → Zapisz poprawkę | Wpis pokazuje nową dawkę; w dzienniku zmian widać poprzednią | TAK / NIE | |
| F2 | Dokumenty → dotknij wpisu → Cofnij wpis → potwierdź | Wpis oznaczony jako cofnięty, nie znika bez śladu | TAK / NIE | |
| F3 ★ | Dokumenty → Wydruk i eksport → rok → Plik PDF | Plik powstaje; otwarty w czytniku ma polskie znaki, nagłówek z nazwą gospodarstwa, właścicielem i numerem producenta; brak kodu EPPO wychodzi jako „brak" | TAK / NIE | |
| F4 ★ | To samo → Plik CSV i Plik XLSX | Pliki powstają; po otwarciu w arkuszu kolumny się zgadzają | TAK / NIE | |
| F5 | Zrób wpis bez dawki i otwórz Wydruk i eksport | Przed wydrukiem widać, czego brakuje w ewidencji | TAK / NIE | |

## G. Terminy i warunkowość

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| G1 ★ | Otwórz Terminy po wpisaniu oprysku z karencją | Lista odpowiada gospodarstwu; karencja z własnego zabiegu jest na liście; termin po czasie wyróżniony | TAK / NIE | |
| G2 ★ | Terminy → Warunkowość | Każda norma GAEC ma stan; ta, której program nie umie policzyć, mówi „do sprawdzenia" | TAK / NIE | |
| G3 | Warunkowość → Zapisz PDF | Plik powstaje i da się otworzyć | TAK / NIE | |

## H. Kalendarz biodynamiczny

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| H1 ★ | Ekran główny → Kalendarz (Nowoczesny: zakładka Kalendarz) | Widać tydzień od dziś: przy każdym dniu rączka siewna (jedna — dobry, dwie — bardzo dobry, przekreślona — zły) i ikona liść/owoc/korzeń albo szpadel; zastrzeżenie „tradycja, nie przepis" | TAK / NIE | |
| H2 | Pokaż miesiąc | Cały miesiąc w kratkach, dziś obramowane; nic nie wychodzi za ekran; legenda pod spodem | TAK / NIE | |
| H3 | Kalendarz bez internetu | Działa tak samo | TAK / NIE | |

## I. Magazyn, kopia, słowniczek, bez internetu

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| I1 | Ustawienia → Magazyn → Dodaj środek → Zakup; potem zapisz nim zabieg | Stan magazynu maleje o zużycie; wpis w ewidencji bez zmian | TAK / NIE | |
| I2 ★ | Ustawienia → Kopia danych → Zrób kopię → zapisz plik; odinstaluj aplikację, zainstaluj od nowa, Wczytaj kopię | Wszystkie pola, wpisy i ustawienia wracają | TAK / NIE | |
| I3 | Zrób kopię na drugim telefonie i na pierwszym „Dołącz dane z drugiego urządzenia" | Nic nie znika; program mówi, ile wpisów doszło | TAK / NIE | |
| I4 | Ustawienia → Słowniczek → dotknij „TUZ" | Hasło rozwija się z wyjaśnieniem i gdzie je spotkasz | TAK / NIE | |
| I5 ★ | Włącz tryb samolotowy i przejdź: pole, zabieg, rejestr, wydruk, kopia | Wszystko działa bez sieci; pogoda i wiadomości mówią o braku internetu jednym zdaniem | TAK / NIE | |

## J. Czytelność i wygoda (wygląd Prosty)

| Nr | Co zrobić | Co powinno się stać | Udało się? | Uwagi |
| --- | --- | --- | --- | --- |
| J1 ★ | Ustaw w Androidzie największą czcionkę i przejrzyj ekrany | Nic nie jest ucięte, nic na siebie nie nachodzi, przyciski nadal duże | TAK / NIE | |
| J2 | Spróbuj obsłużyć aplikację w rękawicy roboczej | Da się trafić w przyciski | TAK / NIE | |
| J3 | Wyjdź z telefonem na słońce | Tekst czytelny | TAK / NIE | |
| J4 | Przy każdym ostrzeżeniu sprawdź, czy mówi, co zrobić | Każde ostrzeżenie = jedno zdanie + co zrobić | TAK / NIE | |

## Na koniec — trzy pytania

1. Co było najbardziej niejasne? ……………………………………………………………
2. Czego zabrakło? ……………………………………………………………
3. Czy zapisałbyś tak zabieg, stojąc w polu? TAK / NIE — dlaczego: ……………………
