# Agro Asystent — wersja testowa na telefon

Ten plik jest do przekazania osobom, które będą próbować aplikacji.
Na końcu jest gotowa wiadomość do skopiowania.

## Jak zainstalować (5 minut)

1. Otwórz na telefonie:
   **https://github.com/LukaszTM/Agro_Asystent/releases/tag/apk-test**
2. Naciśnij plik `agro-asystent-0.2.0+2.apk` — zacznie się pobieranie.
   (Obok leży plik z dopiskiem `-arm64` — jest mniejszy, dla telefonów
   z ostatnich lat. Jeśli nie wiesz, który wybrać, weź ten bez dopisku.)
3. Android zapyta, czy zezwolić na instalację z tego miejsca
   („nieznane źródła"). Trzeba zezwolić — aplikacji nie ma jeszcze
   w sklepie Google Play.
4. Otwórz pobrany plik i naciśnij **Zainstaluj**. Jeśli pojawi się
   ostrzeżenie Play Protect, wybierz **Zainstaluj mimo to**.
5. Przy pierwszym uruchomieniu aplikacja zapyta o wygląd: **Prosty**
   (duże przyciski, dla osób, które nie przepadają za telefonem) albo
   **Nowoczesny**. Można to potem zmienić w ustawieniach.

**Przy nowej wersji trzeba najpierw odinstalować starą.** Tak będzie do
czasu, aż aplikacja dostanie stały podpis wydawniczy. Odinstalowanie
kasuje też wpisy — w czasie testów warto więc najpierw zrobić kopię
danych (Ustawienia → Zrób kopię).

## Co warto sprawdzić

| Rzecz | Na co patrzeć |
| --- | --- |
| **Dodanie pola** | Czy da się dodać pole bez pisania na klawiaturze? Ile dotknięć zajmuje? |
| **Działka po numerze** | Wpisz numer działki z wypisu — czy pobiera granice i czy mapka pokazuje właściwy kształt? |
| **Wpis oprysku** | Najważniejsze: czy da się zapisać zabieg w pięciu dotknięciach, stojąc w polu? |
| **Nawożenie** | Czy limit azotu i terminy zgadzają się z tym, co wiesz? |
| **Terminy** | Czy aplikacja pokazuje obowiązki, które faktycznie Cię dotyczą? |
| **Wydruk i eksport** | Czy wydruk rejestru wygląda tak, jak trzeba go pokazać przy kontroli? |
| **Czytelność** | Czy tekst jest dość duży? Czy coś ucieka poza ekran? |

Wszystko działa **bez internetu**. Zasięg jest potrzebny tylko przy
pobieraniu granic działki, pogody i wiadomości.

## O co prosimy w zgłoszeniu

1. Co robiłeś (np. „dodawałem oprysk na polu Za stodołą").
2. Co się stało i czego się spodziewałeś.
3. Numer wersji — stoi na dole ekranu Ustawienia („Agro Asystent •
   Wersja 0.2.0").
4. Model telefonu, jeśli łatwo go sprawdzić.

Zdjęcie ekranu mówi więcej niż opis — jeśli to możliwe, dołącz.

## Czego jeszcze nie ma (nie zgłaszaj tego jako usterki)

- **Cen skupu** — mechanizm jest, ale notowania nie są jeszcze wczytane.
- **Wysyłki zgłoszeń do IRZplus** i rejestru stada powiązanego z ekranami.
- **Zestawienia do wniosku** i „kompletu na kontrolę jednym przyciskiem".
- Na komputerze z Windows: wpisu zabiegu i poprawiania wpisów.

## Co aplikacja robi z danymi

Wszystko zostaje w telefonie. Nie ma konta, logowania ani serwera —
wpisy, pola i dokumenty leżą w pamięci urządzenia. Do internetu
aplikacja sięga tylko wtedy, gdy sam o to poprosisz: po granice działki
(państwowa usługa ULDK), po pogodę i po nagłówki wiadomości. Nic poza tym
nie jest nigdzie wysyłane.

## Gotowa wiadomość do wysłania

> Cześć, robię aplikację do prowadzenia dokumentacji gospodarstwa
> (zabiegi, nawożenie, terminy ARiMR) i szukam kilku osób do
> wypróbowania jej na telefonie.
>
> Instalacja: wejdź na
> https://github.com/LukaszTM/Agro_Asystent/releases/tag/apk-test
> i pobierz plik `agro-asystent-0.2.0+2.apk`. Android zapyta, czy
> zezwolić na instalację spoza sklepu — trzeba zezwolić, bo aplikacji
> nie ma jeszcze w Google Play.
>
> Wszystko działa bez internetu, nic nie trzeba zakładać ani podawać.
> Dane zostają w telefonie.
>
> Najbardziej zależy mi na jednym: spróbuj zapisać zabieg tak, jakbyś
> robił to w polu, i powiedz, co było niejasne albo za wolne. Każda
> uwaga się przyda, także „nie wiedziałem, co nacisnąć".
