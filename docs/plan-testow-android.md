# Plan testów – Mój Łan (Android)

Plan i 37 przypadków testowych dla aplikacji Mój Łan (dokumentacja
gospodarstwa wymagana przez ARiMR i inspekcje: pola, zabiegi, nawożenie,
trzy rejestry, wydruk i eksport — wszystko bez internetu). Oczekiwane wyniki
wynikają z planu projektu i `CLAUDE.md`; tam, gdzie dokumentacja nie precyzuje
zachowania, zapisz w kolumnie Wynik, co zobaczyłeś na telefonie.

Wersja rozbudowana, z warunkami wstępnymi i pełnym opisem kroków:
`docs/przypadki-testowe.md`. Zasady prowadzenia sesji z rolnikiem:
`docs/plan-testow-manualnych.md`.

## Zakres i środowisko

- **Przedmiot testów:** aplikacja Mój Łan na Androida, repozytorium
  github.com/LukaszTM/Agro_Asystent, plik APK z wydania `apk-test`
- **W zakresie:** pola i działki (w tym działka spoza wniosku szukana po
  województwie, miejscowości i numerze, własna nazwa pola), wpis zabiegu
  (oprysk, nawożenie, siew, zbiór), karencje, nawożenie azotem, terminy,
  warunkowość (normy GAEC), trzy rejestry, wydruk PDF i eksport CSV/XLSX,
  magazyn, kopia danych i scalanie z drugiego urządzenia, słowniczek pojęć,
  praca bez internetu, oba wyglądy telefonu („Prosty" i „Nowoczesny"),
  dostępność (czcionki, kontrast, obsługa w rękawicy)
- **Poza zakresem:** program na Windows (osobny plan: `docs/przypadki-testowe.md`,
  obszar PC), rejestr stada i liczenie DJP (ta wersja ich nie prowadzi),
  automatyczne pobieranie etykiet ze stron ministerstwa (robi to skrypt na
  komputerze dewelopera), notowania cen skupu (plik danych jest celowo pusty,
  dopóki nikt nie uruchomi skryptu), zakup wersji płatnej (w wydaniu testowym
  wszystkie dodatki są odblokowane), testy wydajnościowe na dużej bazie
- **Środowisko:** model telefonu: ……, wersja Androida: ……, wersja aplikacji:
  przepisz z Ustawień („Mój Łan • Wersja 0.2.0 (budowa 2)"), plik APK:
  `moj-lan-0.2.0+2-arm64.apk` (40 MB, na telefony z ostatnich lat) albo
  `moj-lan-0.2.0+2.apk` (106 MB, na każdy telefon)
- **Gdzie są ustawienia:** w wyglądzie Nowoczesnym zakładka „Ustawienia"; w wyglądzie
  Prostym ikona ciągnika w prawym górnym rogu ekranu głównego → ekran
  „Gospodarstwo". W krokach piszemy krótko „Ustawienia"
- **Typ testów:** manualne, funkcjonalne, eksploracyjne i regresyjne po poprawkach
- **Kryteria zakończenia:** wykonane wszystkie przypadki o priorytecie Wysoki,
  wszystkie defekty zgłoszone jako Issues na GitHubie, retest po poprawkach,
  żaden defekt o priorytecie Wysoki nie zostaje otwarty

## Przypadki testowe

**Legenda wyników:** **P** – Passed (zaliczony) · **F** – Failed (niezaliczony,
dopisz numer Issue, np. F #4) · **B** – Blocked (zablokowany, dopisz powód) ·
**S** – Skipped (pominięty, dopisz powód) · pusta komórka – nie wykonano

| ID | Obszar | Kroki | Oczekiwany wynik | Prior. | Wynik |
| --- | --- | --- | --- | --- | --- |
| TC-01 | Instalacja | Pobierz APK w Chrome (nie w przeglądarce wbudowanej w Messengera czy Facebooka), otwórz plik, zezwól na instalację z nieznanych źródeł, przy ostrzeżeniu Play Protect wybierz „Zainstaluj mimo to", uruchom aplikację | Aplikacja wstaje, pyta o wygląd (Prosty / Nowoczesny), po wyborze pokazuje ekran główny; nie żąda logowania ani internetu | Wysoki |  |
| TC-02 | Instalacja | Wybierz wygląd Prosty, zamknij aplikację z listy ostatnich aplikacji, otwórz od nowa | Ten sam wygląd, bez pytania od nowa | Średni |  |
| TC-03 | Instalacja | Ustawienia → Wygląd → wybierz drugi wygląd | Cała aplikacja przechodzi na nowy wygląd od razu; pola, wpisy i ustawienia zostają bez zmian | Niski |  |
| TC-04 | Instalacja | Ustawienia → znajdź wiersz z wersją (w wyglądzie Prostym pod danymi gospodarstwa, w Nowoczesnym na samym dole) | Widoczny numer wersji i budowy — bez niego nie wiadomo, którego pliku dotyczy zgłoszenie | Średni |  |
| TC-05 | Pola | Pola → Dodaj pole: wpisz nazwę, ustaw powierzchnię przyciskami „+"/„−", wybierz uprawę z listy, zapisz | Pole na liście z nazwą, powierzchnią i uprawą; przy uprawie ze słownika widać kod EPPO | Wysoki |  |
| TC-06 | Pola | Dodaj pole i wpisz uprawę, której nie ma w słowniku (np. „mieszanka na zielonkę") | Aplikacja przyjmuje własną nazwę i mówi wprost, że kodu EPPO nie ma; na wydruku wyjdzie „brak", nic nie jest zgadywane | Średni |  |
| TC-07 | Pola | Dodaj pole i wybierz uprawę „Trawy" (szukaj „traw") | „Trawy" są na liście mimo braku w rejestrze środków; widać, że są bez kodu EPPO | Średni |  |
| TC-08 | Pola | Pola → Działki i mapa → Dodaj działkę → „Mam pełny numer z wniosku": wpisz numer działki z wniosku | Działka dodana, granica rysuje się na mapie; numer zostaje taki, jaki wpisałeś | Wysoki |  |
| TC-09 | Pola | Dodaj działkę → „Znajdź działkę po miejscowości": dotknij swojego województwa, wpisz nazwę wsi (obrębu) z umowy dzierżawy i numer działki, naciśnij „Znajdź działkę" | Gdy w województwie jest jedna taka działka — od razu mapa do potwierdzenia; gdy kilka (ta sama nazwa wsi w kilku gminach) — lista gmin do wyboru, aplikacja nie wybiera sama; po potwierdzeniu działka widoczna na mapie | Wysoki |  |
| TC-10 | Pola | Powtórz TC-09 z włączonym trybem samolotowym | Jedno zdanie o braku internetu i rada, co zrobić (wpisać pełny numer z wniosku); aplikacja nie zawiesza się i nie gubi wpisanych danych | Średni |  |
| TC-10a | Pola | W TC-09 wpisz nazwę wsi, której w wybranym województwie nie ma (np. wieś z sąsiedniego województwa) | Komunikat, że w tym województwie takiej działki nie ma, z liczbą znalezionych w kraju; aplikacja nie podstawia działki z innego województwa | Średni |  |
| TC-11 | Pola | Wpisz numer działki, której nie ma (np. z błędną cyfrą) | Jedno zdanie, że takiej działki nie znaleziono, i podpowiedź, co sprawdzić; nic nie zapisuje się „na próbę" | Średni |  |
| TC-12 | Pola | Otwórz pole wczytane z wniosku („Pole A") → Zmień nazwę pola → wpisz „Za stodołą" → Zapisz nazwę | Nazwa zmieniona na liście i w nagłówku; oznaczenie z wniosku („We wniosku: A") zostaje widoczne, wpisy zabiegów zostają przy tym polu | Wysoki |  |
| TC-13 | Pola | Przy włączonym trybie samolotowym otwórz Pola → Działki i mapa | Mapa rysuje się z danych w telefonie, bez ani jednego zapytania do sieci | Wysoki |  |
| TC-14 | Pola | Otwórz pole → ustaw rodzaj użytku („Łąka lub pastwisko") i odpowiedz na pytanie o wodę przy polu | Wybór zapisuje się od razu; aplikacja nie podstawia odpowiedzi za rolnika, a podpowiedź (jeśli jest) jest oznaczona jako podpowiedź | Średni |  |
| TC-15 | Wpis zabiegu | Ekran główny → Dodaj zabieg → pole → Oprysk → środek z listy → Zapisz; licz dotknięcia | Zabieg zapisany w najwyżej pięciu dotknięciach, bez pisania na klawiaturze; data, godzina i powierzchnia uzupełnione same | Wysoki |  |
| TC-16 | Wpis zabiegu | Wybierz środek, dla którego rejestr podaje dawkę; zwiększ dawkę przyciskiem „+" powyżej dopuszczalnej | Ostrzeżenie, że dawka przekracza dopuszczalną z rejestru, i co zrobić; zapis nie jest blokowany, bo dokumentacja ma być prawdziwa | Wysoki |  |
| TC-17 | Wpis zabiegu | Wybierz środek, przy którym rejestr nie podaje dawki w jednoznacznej postaci | Aplikacja mówi to wprost i daje wpisać dawkę z etykiety: liczba startuje od zera (nic nie jest podpowiedziane), jednostkę wybiera się z listy („l/ha", „kg/ha" …) | Wysoki |  |
| TC-18 | Wpis zabiegu | W sytuacji z TC-17 ustaw dawkę, ale nie wybieraj jednostki | Ostrzeżenie, że nie wiadomo, w czym podana jest dawka, i polecenie wybrania jednostki | Średni |  |
| TC-19 | Wpis zabiegu | W sytuacji z TC-17 zapisz zabieg bez dawki (zero) | Zabieg zapisuje się; dokumentacji nie blokujemy, dawkę można dopisać później | Średni |  |
| TC-20 | Wpis zabiegu | Zapisz oprysk środkiem z karencją, zobacz ekran po zapisie | Widoczna karencja w dniach, najwcześniejszy dzień zbioru i data etykiety, z której karencja pochodzi | Wysoki |  |
| TC-21 | Wpis zabiegu | Zapisz oprysk środkiem bez karencji w rejestrze | Aplikacja mówi wprost, że karencji nie zna, i każe sprawdzić etykietę; nie wstawia żadnej liczby | Wysoki |  |
| TC-22 | Wpis zabiegu | Przejdź cały wpis oprysku i obserwuj ekrany | Ani razu nie pojawia się okno z ofertą wersji płatnej ani słowo o opłacie | Wysoki |  |
| TC-23 | Wpis zabiegu | Zapisz zabieg, potem popraw go (inna dawka) i cofnij inny wpis | Poprawka i cofnięcie działają; w dzienniku zmian widać poprzednią wersję — nic nie jest nadpisywane bez śladu | Wysoki |  |
| TC-24 | Wpis zabiegu | Zacznij wpis zabiegu i wyjdź z aplikacji w połowie (przycisk Wstecz, potem lista zadań) | Nie powstaje wpis-niewypałek; po powrocie można zacząć od nowa, dane gospodarstwa bez zmian | Średni |  |
| TC-25 | Nawożenie | Dodaj nawóz z zawartością azotu i wpisz nawożenie na polu | Aplikacja liczy azot na hektar i pokazuje, ile zostało do limitu z przepisu; przy nawozie bez znanej zawartości azotu mówi, że nie policzy | Wysoki |  |
| TC-26 | Nawożenie | Wpisz nawożenie azotowe z datą po granicznym terminie dla swojej gminy | Ostrzeżenie o terminie z jednym zdaniem i radą; zapis możliwy, bo ewidencja ma być zgodna z tym, co się stało | Średni |  |
| TC-27 | Terminy | Otwórz Terminy po wpisaniu oprysku z karencją | Lista terminów odpowiada temu gospodarstwu (powierzchnia, uprawy); karencja z własnego zabiegu jest na liście, termin po czasie wyróżniony | Wysoki |  |
| TC-28 | Warunkowość | Otwórz Warunkowość i przejrzyj normy GAEC | Każda norma ma stan; norma, której aplikacja nie umie policzyć, mówi to wprost („do sprawdzenia") i nie udaje spełnionej | Wysoki |  |
| TC-29 | Dokumenty | Dokumenty → przejrzyj trzy rejestry, zrób wydruk PDF i eksport CSV oraz XLSX | Wszystko działa bez żadnej opłaty; w nagłówku stoi nazwa gospodarstwa, numer producenta i właściciel; braki w ewidencji widać przed wydrukiem | Wysoki |  |
| TC-30 | Dokumenty | Otwórz wydruk PDF zapisany na telefonie w czytniku PDF | Polskie znaki są poprawne, tabela się nie rozjeżdża, karencje i kody EPPO zgadzają się z wpisami (brak kodu wychodzi jako „brak") | Wysoki |  |
| TC-31 | Magazyn | Ustawienia → Magazyn: wpisz zakup środka, potem zapisz nim zabieg | Stan magazynu zmniejsza się o zużycie z zabiegu; magazyn nie zmienia ani jednej liczby w ewidencji zabiegu | Średni |  |
| TC-32 | Kopia danych | Ustawienia → Kopia danych → Zrób kopię, zapisz plik, odinstaluj aplikację, zainstaluj od nowa i wczytaj kopię | Wszystkie pola, zabiegi i ustawienia wracają; kopia jest darmowa i nie pyta o opłatę | Wysoki |  |
| TC-33 | Kopia danych | Zrób kopię na drugim telefonie i na pierwszym wybierz „Dołącz dane z drugiego urządzenia" | Nic nie znika: nowszy wpis wygrywa, starszy zostaje w dzienniku zmian; podsumowanie mówi, ile wpisów doszło | Wysoki |  |
| TC-34 | Bez internetu | Włącz tryb samolotowy i przejdź całą dokumentację: pole, zabieg, rejestr, wydruk, eksport, kopia | Wszystko działa bez sieci; miejsca, które sieci wymagają (pogoda, wiadomości, pobranie granicy działki), mówią o tym jednym zdaniem i nie blokują reszty | Wysoki |  |
| TC-35 | Słowniczek | Ustawienia → Słowniczek → dotknij hasła „TUZ" | Hasło rozwija się i wyjaśnia pojęcie językiem rolnika, z informacją, gdzie się je spotyka; pod listą stoi zastrzeżenie i numer wersji słowniczka | Średni |  |
| TC-36 | Dostępność | Ustaw w Androidzie największą czcionkę, przejrzyj wszystkie ekrany wyglądu Prostego; spróbuj obsłużyć aplikację w rękawicy roboczej i przy słońcu | Brak uciętych tekstów i nakładających się elementów, przyciski nadal duże (min. 48 px) i czytelne, każde ostrzeżenie mówi, co zrobić | Wysoki |  |

## Zgłaszanie defektów

Każdy błąd zgłoś jako Issue w repozytorium w tym układzie:

```markdown
**Tytuł:** krótki opis problemu
**Przypadek testowy:** TC-xx
**Środowisko:** model telefonu, wersja Androida, wersja aplikacji (z Ustawień)
**Kroki do odtworzenia:**
1. ...
2. ...
**Wynik rzeczywisty:** ...
**Wynik oczekiwany:** ...
**Priorytet:** Wysoki / Średni / Niski
**Załączniki:** zrzut ekranu lub nagranie
```

Po poprawce wykonaj retest tego samego przypadku i dopisz wynik w Issue.

**Czego nie wkleja się do zgłoszenia:** numerów działek realnego
gospodarstwa, nazwisk, numeru producenta ani plików wniosku. Zrzut ekranu
z takimi danymi zasłoń albo opisz problem słowami — dane osobowe nie wchodzą
do repozytorium (`CLAUDE.md`, reguła 2).
