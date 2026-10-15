# ADR-0004. Budowa bazy danych aplikacji

- Stan: **przyjęte** (15 października 2026 r., zadanie P6)
- Dotyczy: plan, pkt 7 (model danych) i pkt 2 (offline-first, synchronizacja bez serwera)

## Trzy rozstrzygnięcia

### 1. Dwie bazy zamiast jednej

| Baza | Zawartość | Kto zapisuje |
| --- | --- | --- |
| `gospodarstwo.sqlite` | dane rolnika: działki, pola, zabiegi, nawozy, zwierzęta | wyłącznie aplikacja |
| `slowniki.sqlite` | środki ochrony roślin, zastosowania, karencje, uprawy, kody EPPO | wyłącznie aktualizacja danych |

Powód: aktualizacja danych (nowy rejestr środków, nowe etykiety) sprowadza się
do **podmiany jednego pliku**, bez dotykania wpisów rolnika i bez migracji jego
bazy. Odwrotnie też: kopia zapasowa gospodarstwa nie wlecze za sobą 12 MB
słowników, które i tak da się pobrać ponownie.

Słowniki są tylko do odczytu. Wpis zabiegu **kopiuje** z nich to, co musi
zostać na zawsze (nazwa środka, numer zezwolenia, dawka, karencja), zamiast
wskazywać na wiersz, który po aktualizacji może zniknąć. Ewidencja ma pokazywać
stan z dnia zabiegu, a nie dzisiejszy.

### 2. Identyfikatory tekstowe (UUID), nie liczniki

Telefon i komputer mają pełne, niezależne kopie danych i synchronizują się bez
serwera (plan, pkt 2). Przy licznikach `AUTOINCREMENT` dwa urządzenia nadałyby
ten sam numer dwóm różnym zabiegom. Dlatego klucz główny każdej tabeli danych
rolnika to **UUID w kolumnie `TEXT`**, nadawany na urządzeniu.

### 3. Wpisy są dopisywane, nie nadpisywane

Każda zmiana w tabelach `zabieg*` trafia do `historia_zmian` — automatycznie,
wyzwalaczami w bazie, a nie dobrą wolą kodu. Usunięcie zabiegu jest oznaczeniem
(`usuniety = 1`), nie skasowaniem wiersza.

Powód jest potrójny: kontrola może sięgnąć wstecz, rolnik musi móc cofnąć
pomyłkę, a synchronizacja bez serwera potrzebuje dziennika zmian, żeby złożyć
dwie kopie w jedną.

## Następstwa

- Migracje piszemy ręcznie w SQL, z numerem wersji — bez generatora kodu.
- Każda tabela danych rolnika ma `utworzono`, `zmieniono` i `urzadzenie`;
  bez tego nie da się rozstrzygnąć konfliktu przy synchronizacji.
- `slowniki.sqlite` ma tabelę `wersja_danych`; aplikacja pokazuje rolnikowi datę
  danych, z których korzysta (wymóg z P2: „pokazywać datę etykiety").
- Klucze obce włączone na stałe (`PRAGMA foreign_keys = ON`) — baza ma pilnować
  spójności sama, bo to ostatnia linia obrony przed błędem w dokumentacji.
