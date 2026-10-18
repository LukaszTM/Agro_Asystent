# Wydanie na Androida: podpis i plik do wgrania

Plik `.apk` buduje się sam po każdej zmianie kodu (przepływ
`.github/workflows/apk.yml`) i trafia do wydania **`apk-test`**
w repozytorium — stąd pobiera się go wprost na telefon, bez komputera.

## Dwa rodzaje podpisu

Każdy plik aplikacji na Androida musi być podpisany. Aplikacja ma dwa
tryby, a wybiera je `android/app/build.gradle.kts` sam, po tym, czy
klucz jest dostępny.

| | Klucz debugowy (dziś) | Klucz wydawniczy (docelowo) |
| --- | --- | --- |
| Skąd | tworzy go Flutter przy każdym budowaniu | plik `.jks`, który robi się **raz** |
| Instalacja nowszej wersji | trzeba odinstalować poprzednią (inny podpis) | wgrywa się na wierzch |
| Google Play | **nie przyjmie** | przyjmie |
| Co trzeba zrobić | nic | niżej |

Przy budowaniu bez klucza wydawniczego w logu staje ostrzeżenie:
„brak klucza podpisującego — wydanie podpisuję kluczem debugowym".
Plik nadaje się do testów na telefonie i tylko do nich.

## Jak dodać klucz wydawniczy

**Klucz robi właściciel aplikacji i nikt inny go nie widzi.** Nie
wysyłaj go w rozmowie, nie wkładaj do repozytorium — `.gitignore`
blokuje `*.jks`, `*.keystore` i `android/key.properties`, ale sprawdź
przed `git add`. Zgubiony klucz znaczy, że do Google Play nie da się już
wysłać aktualizacji tej samej aplikacji. Zrób jego kopię w dwóch
miejscach (np. menedżer haseł i pendrive w szufladzie).

### 1. Zrób plik klucza (potrzebny komputer, raz w życiu)

```bash
keytool -genkey -v -keystore agro-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

`keytool` jest w każdej instalacji Javy (JDK 17). Program zapyta
o hasło do pliku, hasło do klucza i dane właściciela. Zapisz oba hasła
tam, gdzie trzymasz hasła.

Ważność 10000 dni (27 lat) nie jest kaprysem — Google Play wymaga klucza
ważnego co najmniej do 2033 r.

### 2. Budowanie na komputerze

Utwórz `android/key.properties` (jest w `.gitignore`):

```properties
storeFile=/pelna/sciezka/do/agro-upload.jks
storePassword=hasło do pliku
keyAlias=upload
keyPassword=hasło do klucza
```

Od tej pory `flutter build apk --release` podpisuje wydanie tym kluczem.

### 3. Budowanie na GitHubie (tak powstaje plik na telefon)

W repozytorium: **Settings → Secrets and variables → Actions → New
repository secret**. Cztery sekrety:

| Sekret | Co wpisać |
| --- | --- |
| `AGRO_KEYSTORE_BASE64` | plik `.jks` zakodowany base64 (niżej) |
| `AGRO_KEYSTORE_HASLO` | hasło do pliku `.jks` |
| `AGRO_KLUCZ_ALIAS` | `upload` (albo własny alias) |
| `AGRO_KLUCZ_HASLO` | hasło do klucza |

Base64 z pliku:

```bash
base64 -w0 agro-upload.jks > agro-upload.jks.base64
```

Zawartość tego pliku wkleja się jako wartość `AGRO_KEYSTORE_BASE64`.
Sekretów GitHub nie pokazuje po zapisaniu nikomu, także właścicielowi.

Po dodaniu sekretów następny build podpisze plik kluczem wydawniczym
i wydanie `apk-test` napisze o tym w opisie. **Nic więcej nie trzeba
zmieniać w kodzie.**

## Jak wgrać plik na telefon

1. W repozytorium: **Releases → „Agro Asystent — APK do testów"**.
2. Dotknij pliku `agro-asystent-<wersja>.apk` — telefon go pobierze.
3. Przy pierwszej instalacji Android zapyta o zgodę na instalację
   z nieznanych źródeł. Zgoda dotyczy przeglądarki, z której plik
   pobrano.
4. Przy kluczu debugowym: przed wgraniem nowszego pliku odinstaluj
   poprzednią wersję. **Odinstalowanie usuwa dane aplikacji** — zrób
   najpierw kopię danych (Ustawienia → „Zrób kopię").

## Czego jeszcze nie ma

- Konta w Google Play (opłata jednorazowa, weryfikacja tożsamości).
- Pliku `.aab` (App Bundle) — Google Play przyjmuje tylko taki format;
  przepływ buduje dziś `.apk`, bo ten wgrywa się wprost na telefon.
  Dodanie `flutter build appbundle` to jeden krok więcej, gdy konto
  w Play będzie gotowe.
- Regulaminu i polityki prywatności — wymaga ich Google Play, a treść
  powinien zobaczyć prawnik (podsumowanie etapu 1, pkt 14).

## Przed rozdaniem aplikacji testerom

Lista do odhaczenia, zanim plik pójdzie do ludzi:

1. **Zrób klucz wydawniczy i wpisz cztery sekrety** (opis wyżej). Bez
   niego każdy build jest podpisany innym kluczem debugowym, więc przy
   każdej nowej wersji tester musi odinstalować poprzednią — razem
   z wpisami, które zdążył zrobić. To największa niewygoda testów i jedyna,
   którą da się usunąć w pięć minut.
2. Sprawdź, czy wydanie `apk-test` ma oba pliki: uniwersalny i `-arm64`.
3. Przeczytaj `docs/instrukcja-dla-testerow.md` i zmień w niej numer
   wersji, jeśli zdążył się zmienić. Na końcu jest gotowa wiadomość do
   wysłania.
4. Ustal, gdzie mają trafiać uwagi (telefon, e-mail, grupa) — i wpisz to
   w wiadomości do testerów.

Repozytorium jest publiczne, więc link do wydania działa bez konta na
GitHubie. Jeśli kiedyś stanie się prywatne, testerzy przestaną móc
pobierać plik i trzeba będzie rozdawać go inaczej.

## Wydanie testowe a wydanie dla rolnika

Pliki rozdawane testerom budują się z flagą
`--dart-define=AGRO_WYDANIE_TESTOWE=true`. Włącza ona **tylko dodatki**:
wczytanie wniosku z PDF, odczyt zdjęcia, magazyn, plan nawożenia, kilka
gospodarstw. Decyzję, co jest dodatkiem, podejmuje nadal jedno miejsce
w kodzie — `lib/rdzen/dostep/` — a flaga mówi jej, że to wydanie
testowe.

Bez flagi (czyli przy budowaniu lokalnym, w testach i w wydaniu dla
rolnika) program zachowuje się tak jak u rolnika. Pilnuje tego test
`test/rdzen/dostep/dostep_funkcji_test.dart`: gdyby ktoś przestawił to
na stałe, test padnie.

Plik zachowujący się jak u rolnika zbudujesz tak: Actions → „Zbuduj
APK" → Run workflow → odznacz **„Wydanie testowe — wszystkie dodatki
odblokowane"**. Przyda się do sprawdzenia, czy wersja darmowa nadal
wystarcza do prowadzenia dokumentacji.
