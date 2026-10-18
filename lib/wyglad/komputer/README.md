# komputer
Program na Windows: **jeden wygląd dla wszystkich**, z ustawieniem wielkości
tekstu (plan, pkt 5). Stała nawigacja po lewej (bez ukrytego menu), tabele
zamiast kafelków, obszar treści na szerokość monitora.

Te same dane, reguły i dokumenty co na telefonie — tu jest tylko warstwa
ekranów. Ten katalog nie importuje niczego z `lib/wyglad/prosty/` ani
`lib/wyglad/nowoczesny/`; wspólny kod ekranów leży w `lib/rdzen/wspolne/`
(pilnuje tego `test/architektura_test.dart`).

Czego program na komputerze nie robi: nie czyta zdjęć (ML Kit nie ma wersji
na Windows — `CzytnikTylkoWTelefonie` mówi o tym wprost) i nie wysyła
przypomnień. Wpisy poprawia się tam, gdzie powstały; dane z telefonu
dołącza się plikiem kopii („nowszy wpis wygrywa, starszy zostaje
w dzienniku zmian").
