# ADR-0007 — produkcja zwierzęca poza zakresem aplikacji

Data: 16 października 2026 r. Status: **przyjęta**.

## Decyzja

Aplikacja obsługuje **produkcję roślinną**. Produkcja zwierzęca — rejestr
stada, liczenie DJP, terminy zgłoszeń do IRZplus — wychodzi z zakresu
i wraca jako **ścieżka rozwoju** po ukończeniu aplikacji.

Zmienia to decyzję „Profil: produkcja roślinna i zwierzęca" z pkt 2 planu.

## Dlaczego nie usuwamy kodu

Moduł zwierząt powstał w kroku 9 etapu 1 i jest skończony: rejestr stada,
zdarzenia, DJP z urzędowych przeliczników (Dz.U. 2023 poz. 244), terminy
zgłoszeń, dwa ekrany i 14 testów. Usunięcie tego to wyrzucenie gotowej,
sprawdzonej pracy, którą właściciel projektu chce mieć później.

Dlatego moduł **zostaje w repozytorium, ale jest odłączony od ekranów**:

- `lib/funkcje/zwierzeta/` i `lib/wyglad/prosty/zwierzeta/` zostają razem
  z testami — te testy nadal przechodzą i pilnują, żeby moduł nie zgnił;
- z ekranu „Pola" zniknął przycisk „Zwierzęta" — to jedyne wejście, jakie
  było, więc moduł jest nieosiągalny dla rolnika;
- tabele `stado`, `zwierze`, `zdarzenie_zwierzecia` i kolumna `grupa_djp`
  zostają w schemacie. Usuwanie tabel migracją nic nie daje, a psuje bazy,
  które już je mają;
- `wspolczynniki_djp` zostają w słowniku reguł — są sprawdzone
  w rozporządzeniu i przydadzą się bez zmian.

Powrót modułu to przywrócenie jednego przycisku.

## Czego aplikacja nie może udawać

Od liczby DJP zależą obowiązki z programu azotanowego: ewidencja nawożenia
od **10 ha UR albo 10 DJP**, plan nawożenia od **60 DJP**. Gdyby profil
gospodarstwa podawał `djp = 0`, aplikacja twierdziłaby, że obowiązek nie
dotyczy gospodarstwa — a dla rolnika z oborą byłoby to nieprawdą, i to
w sprawie, za którą płaci się kary.

Dlatego:

- `ProfilGospodarstwa.djp` może być `null` — „aplikacja nie wie";
- silnik reguł zwraca wtedy `Ocena.nieWiadomo`, a ekran pisze „Nie wiemy,
  czy ten obowiązek dotyczy Twojego gospodarstwa — sprawdź u doradcy"
  (ten mechanizm istniał od kroku 5, tylko nie był używany dla DJP);
- aplikacja **pyta raz**, na ekranie „Gospodarstwo": *nie mam zwierząt* /
  *mam zwierzęta*. Odpowiedź „nie" daje pewne zero i obowiązki od DJP
  znikają; odpowiedź „mam" zostawia DJP nieznane i mówi wprost, że rejestru
  stada ta wersja nie prowadzi, więc liczbę DJP trzeba sprawdzić u doradcy;
- dopóki rolnik nie odpowie, obowiązki od DJP są „do sprawdzenia". Lepiej
  jedno pytanie na ekranie ustawień niż cicha nieprawda na wydruku.

## Konsekwencje

- Zakres aplikacji jest węższy i szybciej doprowadzimy ją do wydania.
- Jedno pytanie więcej w ustawieniach gospodarstwa.
- Gospodarstwo ze zwierzętami dostaje uczciwą odpowiedź „nie wiemy" zamiast
  błędnej „nie dotyczy".
- Z listy luk wypada „rejestr stada do wydruku" — razem z całym modułem
  wraca później.
