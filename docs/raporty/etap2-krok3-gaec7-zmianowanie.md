# Etap 2, krok 3: GAEC 7 — zmianowanie i dywersyfikacja

17 października 2026 r.

Aplikacja liczy teraz normę, która dotyczy niemal każdego gospodarstwa
powyżej 10 ha gruntów ornych — i ostrzega **przed** zapisem uprawy, która
byłaby czwartym rokiem z rzędu.

## Co liczy silnik

| Warunek | Przepis | Jak liczymy |
| --- | --- | --- |
| Inna uprawa niż rok wcześniej na ≥ 40 % gruntów ornych | § 5 ust. 1 pkt 1 | udział powierzchni pól, na których uprawa zmieniła się wobec poprzedniego sezonu |
| Ta sama uprawa nie dłużej niż 3 lata | § 5 ust. 1 pkt 2 | najdłuższy ciąg lat z tą samą uprawą, licząc od 2023 r. |
| Dywersyfikacja, gdy pierwszy warunek nie wyszedł | § 5 ust. 4 | do 30 ha: 2 uprawy, największa ≤ 75 %; powyżej 30 ha: 3 uprawy, ≤ 75 % i dwie ≤ 95 % |
| Wyłączenia upraw | § 5 ust. 3 | ugór, bobowate, trawy, mieszanki z trawami, uprawy trwałe, plantacje nasienne kukurydzy |
| Zwolnienie przy > 75 % traw, ugorów i bobowatych | § 5 ust. 11 | udział wyłączonych upraw w gruntach ornych |
| Zwolnienia z kontroli (10 ha, 30 ha) | rozp. (UE) 2025/2649 | pokazywane, ale **nie** wyłączają liczenia |

W kodzie Dart nie ma ani jednej z tych liczb — wszystkie przychodzą ze
słownika reguł, razem z rokiem, od którego przepis każe liczyć (2023).

## Najtrudniejsze: co jest „tą samą uprawą"

Od tego zależy każdy wynik, a przepis (§ 5 ust. 5) mówi trzy rzeczy
naraz: uprawą jest **rodzaj** rośliny; **forma jara i ozima** tego samego
rodzaju; **gatunek** z rodzin kapustowatych, psiankowatych i dyniowatych.
Stąd klucz, po którym aplikacja porównuje uprawy:

| Nazwa z wniosku | Klucz | Dlaczego |
| --- | --- | --- |
| pszenica zwyczajna ozima | `pszenica ozima` | rodzaj + forma; „pszenica ozima" to ta sama uprawa |
| pszenica jara | `pszenica jara` | forma jara to osobna uprawa niż ozima |
| rzepak ozimy | `rzepak ozimy` | kapustowate — liczy się gatunek, więc cała nazwa |
| kapusta biała / kapusta pekińska | `kapusta biala` / `kapusta pekinska` | dwa gatunki kapustowatych to dwie uprawy |

Słowa form („ozima", „jara") i rozpoznanie trzech rodzin są **danymi** ze
słownika, ze statusem `do_weryfikacji`: przepis odsyła do klasyfikacji
botanicznej, ale wykazu gatunków nie podaje. Aplikacja mówi o tym
rolnikowi wprost przy każdym wyniku — jedno zdanie o tym, jak porównuje
uprawy, i żeby przy wątpliwości sprawdził u doradcy.

## Czego nie udajemy

| Sytuacja | Co robi aplikacja |
| --- | --- |
| Pole bez potwierdzonego rodzaju użytku | nie wlicza go do gruntów ornych i **nie orzeka, że jest dobrze** — cały wynik schodzi na „do sprawdzenia" |
| Brak uprawy z roku wcześniej | „do sprawdzenia" dla tego warunku, z liczbą pól i zakresem lat, których brakuje |
| Dziura w historii przy regule trzech lat | „do sprawdzenia"; nie zakładamy, że w brakującym roku było coś innego |
| Wyłączenie z § 5 ust. 3 oparte na liście gatunków | wykaz z rozporządzenia o normach **uchylono** w 2024 r., więc rodzaje roślin bobowatych bierzemy z tabeli 14 programu azotanowego (akt obowiązujący) i oznaczamy jako „do weryfikacji" |

Zasada w jednym zdaniu: **brak danych nigdy nie daje „norma spełniona"**.
Stan całej normy to najgorszy ze składników, bo kontrola patrzy na całość.

## Ostrzeżenie, które rolnik zobaczy

Przy zmianie uprawy, **przed** zapisem:

> **Czwarty rok tej samej uprawy**
> Na polu Za stodołą „kukurydza" byłaby wtedy 4 rok z rzędu, a norma
> GAEC 7 pozwala najwyżej 3 lata.
> Zapisać możesz — dokumentacja ma być prawdziwa. Ale przy kontroli liczy
> się to jako złamanie normy, więc lepiej zasiać coś innego albo sprawdzić
> u doradcy.
>
> [Wybiorę inną] [Zapisz mimo to]

Ostrzeżenie nie blokuje zapisu: jeśli kukurydza już rośnie, dokumentacja
musi to pokazać. Treść stoi w jednym miejscu (`OstrzezenieOZmianowaniu`),
więc oba wyglądy mówią to samo. Ostrzeżenia nie ma, gdy pole nie jest
gruntem ornym, uprawa jest wyłączona albo w historii brakuje roku — nie
straszymy na podstawie danych, których nie ma.

## Liczby

| Miara | Przed | Po |
| --- | --- | --- |
| Testy Flutter | 453 | **478** |
| Testy silnika GAEC 7 | — | 23 |
| Wersja słownika reguł | 2026.10.17.2 → **2026.10.17.3** |
| `flutter analyze` | czysto | czysto |

Testy obejmują przypadki graniczne, na których łatwo się pomylić: 39 %
wobec 40 %, trzy lata wobec czterech, ozimina wobec jarzyny, dwa gatunki
kapustowatych, 30 ha wobec 31 ha, łąka i sad nie powiększające gruntów
ornych, cztery lata łubinu (wyłączone, więc bez naruszenia).

## Następny krok

Krok 4: GAEC 6 — okrywa ochronna gleby na 80 % gruntów ornych od zbioru
do 15 października, z przerwą do 4 tygodni na siew ozimin. Daty zbioru
aplikacja ma z wpisów zabiegów; formy okrywy musi zadeklarować rolnik.
