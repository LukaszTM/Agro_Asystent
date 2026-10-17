/// Migracje bazy danych gospodarstwa.
///
/// Zasady (ADR-0004):
/// - klucze główne to UUID w kolumnach TEKSTOWYCH — telefon i komputer nadają
///   je niezależnie i nie mogą sobie wejść w drogę przy synchronizacji,
/// - każda tabela ma `utworzono`, `zmieniono` i `urzadzenie`,
/// - wpisów nie kasujemy: `usuniety = 1` zostawia ślad,
/// - zmiany zabiegów zapisują się same, wyzwalaczami, do `historia_zmian`.
///
/// Migracji nigdy nie zmieniamy po wydaniu — dopisujemy następną.
library;

/// Jedna migracja: numer wersji i polecenia SQL wykonywane po kolei.
class Migracja {
  const Migracja({
    required this.wersja,
    required this.polecenia,
    required this.opis,
  });

  final int wersja;
  final String opis;
  final List<String> polecenia;
}

/// Najwyższa wersja schematu — baza nowo zakładana dostaje właśnie tę.
int get najnowszaWersja =>
    migracje.map((m) => m.wersja).reduce((a, b) => a > b ? a : b);

const List<Migracja> migracje = [
  Migracja(
    wersja: 1,
    opis: 'Pierwszy schemat: gospodarstwo, działki, zabiegi, nawozy, zwierzęta',
    polecenia: [
      // ── gospodarstwo i konto ──────────────────────────────────────────
      '''
      CREATE TABLE gospodarstwo (
        id                TEXT PRIMARY KEY,
        nazwa             TEXT NOT NULL,
        numer_producenta  TEXT,
        powierzchnia_ur_ha REAL NOT NULL DEFAULT 0,
        utworzono         TEXT NOT NULL,
        zmieniono         TEXT NOT NULL,
        urzadzenie        TEXT NOT NULL,
        usuniety          INTEGER NOT NULL DEFAULT 0
      )
      ''',
      '''
      CREATE TABLE konto (
        id         TEXT PRIMARY KEY,
        nazwa      TEXT NOT NULL,
        utworzono  TEXT NOT NULL,
        zmieniono  TEXT NOT NULL,
        urzadzenie TEXT NOT NULL
      )
      ''',
      '''
      CREATE TABLE konto_gospodarstwo (
        konto_id       TEXT NOT NULL REFERENCES konto(id),
        gospodarstwo_id TEXT NOT NULL REFERENCES gospodarstwo(id),
        PRIMARY KEY (konto_id, gospodarstwo_id)
      )
      ''',

      // ── działki ───────────────────────────────────────────────────────
      '''
      CREATE TABLE dzialka_ewidencyjna (
        id              TEXT PRIMARY KEY,
        gospodarstwo_id TEXT NOT NULL REFERENCES gospodarstwo(id),
        identyfikator   TEXT NOT NULL,
        wojewodztwo     TEXT,
        powiat          TEXT,
        gmina           TEXT,
        obreb           TEXT,
        nr_dzialki      TEXT,
        powierzchnia_ha REAL,
        geometria_wkt   TEXT,
        srid            INTEGER,
        zrodlo_geometrii TEXT,
        pobrano         TEXT,
        utworzono       TEXT NOT NULL,
        zmieniono       TEXT NOT NULL,
        urzadzenie      TEXT NOT NULL,
        usuniety        INTEGER NOT NULL DEFAULT 0,
        UNIQUE (gospodarstwo_id, identyfikator)
      )
      ''',
      '''
      CREATE TABLE dzialka_rolna (
        id                  TEXT PRIMARY KEY,
        gospodarstwo_id     TEXT NOT NULL REFERENCES gospodarstwo(id),
        nazwa_wlasna        TEXT,
        oznaczenie_z_wniosku TEXT,
        sezon               INTEGER NOT NULL,
        uprawa              TEXT,
        kod_eppo            TEXT,
        powierzchnia_ar     INTEGER NOT NULL DEFAULT 0,
        utworzono           TEXT NOT NULL,
        zmieniono           TEXT NOT NULL,
        urzadzenie          TEXT NOT NULL,
        usuniety            INTEGER NOT NULL DEFAULT 0
      )
      ''',
      // Jedna działka rolna leży na kilku ewidencyjnych — z powierzchnią części
      // (potwierdzone na prawdziwym wniosku w zadaniu P4).
      '''
      CREATE TABLE dzialka_rolna_czesc (
        dzialka_rolna_id      TEXT NOT NULL REFERENCES dzialka_rolna(id),
        dzialka_ewidencyjna_id TEXT NOT NULL REFERENCES dzialka_ewidencyjna(id),
        powierzchnia_ar       INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (dzialka_rolna_id, dzialka_ewidencyjna_id)
      )
      ''',

      // ── zabiegi ───────────────────────────────────────────────────────
      '''
      CREATE TABLE zabieg (
        id              TEXT PRIMARY KEY,
        gospodarstwo_id TEXT NOT NULL REFERENCES gospodarstwo(id),
        typ             TEXT NOT NULL CHECK (typ IN
                          ('oprysk','nawozenie','siew','zbior','uprawa_gleby','inny')),
        data            TEXT NOT NULL,
        godzina         TEXT,
        powierzchnia_ar INTEGER NOT NULL DEFAULT 0,
        uwagi           TEXT,
        utworzono       TEXT NOT NULL,
        zmieniono       TEXT NOT NULL,
        urzadzenie      TEXT NOT NULL,
        usuniety        INTEGER NOT NULL DEFAULT 0
      )
      ''',
      '''
      CREATE TABLE zabieg_pole (
        zabieg_id       TEXT NOT NULL REFERENCES zabieg(id),
        dzialka_rolna_id TEXT NOT NULL REFERENCES dzialka_rolna(id),
        powierzchnia_ar INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (zabieg_id, dzialka_rolna_id)
      )
      ''',
      // Szczegóły oprysku przepisujemy ze słownika w chwili zabiegu — ewidencja
      // ma pokazywać stan z dnia zabiegu, a nie dzisiejszy (ADR-0004).
      '''
      CREATE TABLE zabieg_oprysk (
        zabieg_id          TEXT PRIMARY KEY REFERENCES zabieg(id),
        srodek_nazwa       TEXT NOT NULL,
        nr_zezwolenia      TEXT NOT NULL,
        dawka              REAL,
        dawka_jednostka    TEXT,
        dawka_odniesienie  TEXT,
        przyczyna          TEXT,
        agrofag            TEXT,
        bbch_od            INTEGER,
        bbch_do            INTEGER,
        kod_eppo           TEXT,
        rodzaj_zastosowania TEXT,
        karencja_dni       INTEGER,
        karencja_zrodlo    TEXT,
        karencja_data_etykiety TEXT,
        karencja_potwierdzona INTEGER NOT NULL DEFAULT 0
      )
      ''',
      '''
      CREATE TABLE zabieg_nawozenie (
        zabieg_id       TEXT PRIMARY KEY REFERENCES zabieg(id),
        nawoz_id        TEXT REFERENCES nawoz(id),
        nawoz_nazwa     TEXT NOT NULL,
        dawka           REAL,
        dawka_jednostka TEXT,
        azot_kg_ha      REAL,
        naturalny       INTEGER NOT NULL DEFAULT 0
      )
      ''',

      // ── nawozy (własny słownik rolnika) ───────────────────────────────
      '''
      CREATE TABLE nawoz (
        id              TEXT PRIMARY KEY,
        gospodarstwo_id TEXT NOT NULL REFERENCES gospodarstwo(id),
        nazwa           TEXT NOT NULL,
        azot_procent    REAL,
        fosfor_procent  REAL,
        potas_procent   REAL,
        naturalny       INTEGER NOT NULL DEFAULT 0,
        zrodlo          TEXT,
        utworzono       TEXT NOT NULL,
        zmieniono       TEXT NOT NULL,
        urzadzenie      TEXT NOT NULL,
        usuniety        INTEGER NOT NULL DEFAULT 0
      )
      ''',

      // ── zwierzęta ─────────────────────────────────────────────────────
      '''
      CREATE TABLE stado (
        id              TEXT PRIMARY KEY,
        gospodarstwo_id TEXT NOT NULL REFERENCES gospodarstwo(id),
        nazwa           TEXT NOT NULL,
        gatunek         TEXT NOT NULL,
        utworzono       TEXT NOT NULL,
        zmieniono       TEXT NOT NULL,
        urzadzenie      TEXT NOT NULL,
        usuniety        INTEGER NOT NULL DEFAULT 0
      )
      ''',
      '''
      CREATE TABLE zwierze (
        id             TEXT PRIMARY KEY,
        stado_id       TEXT NOT NULL REFERENCES stado(id),
        numer          TEXT,
        data_urodzenia TEXT,
        plec           TEXT,
        wspolczynnik_djp REAL,
        utworzono      TEXT NOT NULL,
        zmieniono      TEXT NOT NULL,
        urzadzenie     TEXT NOT NULL,
        usuniety       INTEGER NOT NULL DEFAULT 0
      )
      ''',
      '''
      CREATE TABLE zdarzenie_zwierzecia (
        id          TEXT PRIMARY KEY,
        zwierze_id  TEXT NOT NULL REFERENCES zwierze(id),
        rodzaj      TEXT NOT NULL,
        data        TEXT NOT NULL,
        zgloszono   TEXT,
        utworzono   TEXT NOT NULL,
        zmieniono   TEXT NOT NULL,
        urzadzenie  TEXT NOT NULL,
        usuniety    INTEGER NOT NULL DEFAULT 0
      )
      ''',

      // ── dziennik zmian i ustawienia ───────────────────────────────────
      '''
      CREATE TABLE historia_zmian (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        tabela      TEXT NOT NULL,
        wiersz_id   TEXT NOT NULL,
        operacja    TEXT NOT NULL CHECK (operacja IN ('dodanie','zmiana','usuniecie')),
        dane_json   TEXT,
        czas        TEXT NOT NULL,
        urzadzenie  TEXT
      )
      ''',
      '''
      CREATE TABLE ustawienia (
        klucz    TEXT PRIMARY KEY,
        wartosc  TEXT
      )
      ''',

      // ── indeksy pod zapytania ekranów ─────────────────────────────────
      'CREATE INDEX idx_zabieg_data ON zabieg(gospodarstwo_id, data)',
      'CREATE INDEX idx_zabieg_typ ON zabieg(gospodarstwo_id, typ, data)',
      'CREATE INDEX idx_zabieg_pole_pole ON zabieg_pole(dzialka_rolna_id)',
      'CREATE INDEX idx_dzialka_rolna_sezon ON dzialka_rolna(gospodarstwo_id, sezon)',
      'CREATE INDEX idx_historia_wiersz ON historia_zmian(tabela, wiersz_id)',

      // ── wyzwalacze: zabiegu nie da się zmienić po cichu ───────────────
      '''
      CREATE TRIGGER historia_zabieg_dodanie AFTER INSERT ON zabieg
      BEGIN
        INSERT INTO historia_zmian (tabela, wiersz_id, operacja, dane_json, czas, urzadzenie)
        VALUES ('zabieg', NEW.id, 'dodanie',
                json_object('typ', NEW.typ, 'data', NEW.data, 'godzina', NEW.godzina,
                            'powierzchnia_ar', NEW.powierzchnia_ar, 'uwagi', NEW.uwagi),
                NEW.utworzono, NEW.urzadzenie);
      END
      ''',
      '''
      CREATE TRIGGER historia_zabieg_zmiana AFTER UPDATE ON zabieg
      WHEN OLD.usuniety = 0 AND NEW.usuniety = 0
      BEGIN
        INSERT INTO historia_zmian (tabela, wiersz_id, operacja, dane_json, czas, urzadzenie)
        VALUES ('zabieg', NEW.id, 'zmiana',
                json_object('poprzednio',
                  json_object('typ', OLD.typ, 'data', OLD.data, 'godzina', OLD.godzina,
                              'powierzchnia_ar', OLD.powierzchnia_ar, 'uwagi', OLD.uwagi)),
                NEW.zmieniono, NEW.urzadzenie);
      END
      ''',
      '''
      CREATE TRIGGER historia_zabieg_usuniecie AFTER UPDATE OF usuniety ON zabieg
      WHEN OLD.usuniety = 0 AND NEW.usuniety = 1
      BEGIN
        INSERT INTO historia_zmian (tabela, wiersz_id, operacja, dane_json, czas, urzadzenie)
        VALUES ('zabieg', NEW.id, 'usuniecie',
                json_object('typ', OLD.typ, 'data', OLD.data,
                            'powierzchnia_ar', OLD.powierzchnia_ar),
                NEW.zmieniono, NEW.urzadzenie);
      END
      ''',
    ],
  ),

  // Poprawka wpisu zmienia dawkę w `zabieg_oprysk`, a tam nie było wyzwalacza:
  // poprzednia dawka przepadałaby bez śladu. Ewidencja musi pokazywać, co
  // zostało poprawione (CLAUDE.md: wpisy są dopisywane, nie nadpisywane).
  Migracja(
    wersja: 2,
    opis: 'Dziennik zmian dla szczegółów oprysku',
    polecenia: [
      '''
      CREATE TRIGGER historia_oprysk_zmiana AFTER UPDATE ON zabieg_oprysk
      BEGIN
        INSERT INTO historia_zmian (tabela, wiersz_id, operacja, dane_json, czas, urzadzenie)
        VALUES ('zabieg_oprysk', NEW.zabieg_id, 'zmiana',
                json_object('poprzednio',
                  json_object('srodek_nazwa', OLD.srodek_nazwa, 'dawka', OLD.dawka,
                              'dawka_jednostka', OLD.dawka_jednostka,
                              'przyczyna', OLD.przyczyna)),
                (SELECT zmieniono FROM zabieg WHERE id = NEW.zabieg_id),
                (SELECT urzadzenie FROM zabieg WHERE id = NEW.zabieg_id));
      END
      ''',
    ],
  ),

  // Zwierzę trzyma teraz identyfikator grupy ze słownika reguł, a nie tylko
  // sam współczynnik: dzięki temu widać, do której grupy zostało przypisane,
  // nawet gdy współczynniki w przepisie się zmienią.
  Migracja(
    wersja: 3,
    opis: 'Grupa DJP przy zwierzęciu',
    polecenia: ['ALTER TABLE zwierze ADD COLUMN grupa_djp TEXT'],
  ),

  // Uprawa pola zmienia się co sezon, a wpisy zabiegów zostają przy tym
  // samym polu. Kontrola musi widzieć, jaka uprawa była wtedy, gdy zabieg
  // był wykonywany — więc zmiana uprawy idzie do dziennika zmian
  // (CLAUDE.md: wpisy są dopisywane, nie nadpisywane).
  Migracja(
    wersja: 4,
    opis: 'Dziennik zmian dla uprawy pola',
    polecenia: [
      '''
      CREATE TRIGGER historia_dzialka_rolna_zmiana AFTER UPDATE ON dzialka_rolna
      WHEN OLD.uprawa IS NOT NEW.uprawa
        OR OLD.kod_eppo IS NOT NEW.kod_eppo
        OR OLD.nazwa_wlasna IS NOT NEW.nazwa_wlasna
        OR OLD.powierzchnia_ar IS NOT NEW.powierzchnia_ar
      BEGIN
        INSERT INTO historia_zmian (tabela, wiersz_id, operacja, dane_json, czas, urzadzenie)
        VALUES ('dzialka_rolna', NEW.id, 'zmiana',
                json_object('poprzednio',
                  json_object('nazwa_wlasna', OLD.nazwa_wlasna, 'uprawa', OLD.uprawa,
                              'kod_eppo', OLD.kod_eppo, 'sezon', OLD.sezon,
                              'powierzchnia_ar', OLD.powierzchnia_ar)),
                NEW.zmieniono, NEW.urzadzenie);
      END
      ''',
    ],
  ),

  // Warunkowość (etap 2) pyta o rzeczy, których baza nie miała: norma GAEC 7
  // liczy progi **gruntów ornych**, a nie całej powierzchni, i porównuje
  // uprawę w plonie głównym rok po roku, licząc od 2023 r. Dlatego pole
  // dostaje rodzaj użytku, a uprawy dostają własną tabelę z sezonem —
  // kolumna `uprawa` w `dzialka_rolna` mówi tylko, co rośnie teraz.
  //
  // Identyfikator wiersza uprawy jest wyliczany („up-<pole>-<sezon>-g"),
  // a nie losowy: dwa urządzenia dopisujące to samo dostaną ten sam
  // identyfikator, więc scalanie danych nie zrobi z tego dwóch wpisów.
  Migracja(
    wersja: 5,
    opis: 'Rodzaj użytku pola i uprawy pola po sezonach',
    polecenia: [
      'ALTER TABLE dzialka_rolna ADD COLUMN rodzaj_uzytku TEXT',
      '''
      CREATE TABLE uprawa_pola (
        id               TEXT PRIMARY KEY,
        dzialka_rolna_id TEXT NOT NULL REFERENCES dzialka_rolna(id),
        sezon            INTEGER NOT NULL,
        uprawa           TEXT NOT NULL,
        kod_eppo         TEXT,
        plon_glowny      INTEGER NOT NULL DEFAULT 1,
        zrodlo           TEXT,
        utworzono        TEXT NOT NULL,
        zmieniono        TEXT NOT NULL,
        urzadzenie       TEXT NOT NULL,
        usuniety         INTEGER NOT NULL DEFAULT 0
      )
      ''',
      'CREATE INDEX idx_uprawa_pola ON uprawa_pola(dzialka_rolna_id, sezon)',

      // Co rośnie teraz — przepisane z pola, żeby rolnik nie wpisywał
      // tego, co aplikacja już wie.
      '''
      INSERT OR IGNORE INTO uprawa_pola
        (id, dzialka_rolna_id, sezon, uprawa, kod_eppo, plon_glowny,
         zrodlo, utworzono, zmieniono, urzadzenie)
      SELECT 'up-' || r.id || '-' || r.sezon || '-g', r.id, r.sezon,
             r.uprawa, r.kod_eppo, 1, 'pole', r.utworzono, r.zmieniono,
             r.urzadzenie
      FROM dzialka_rolna r
      WHERE r.usuniety = 0 AND r.uprawa IS NOT NULL AND TRIM(r.uprawa) <> ''
      ''',

      // Co rosło wcześniej — z dziennika zmian, ale tylko wtedy, gdy
      // zapisana poprzednia uprawa dotyczy **innego** sezonu niż obecny.
      // Poprawka uprawy w tym samym sezonie to nie historia plonów.
      '''
      INSERT OR IGNORE INTO uprawa_pola
        (id, dzialka_rolna_id, sezon, uprawa, kod_eppo, plon_glowny,
         zrodlo, utworzono, zmieniono, urzadzenie)
      SELECT 'up-' || h.wiersz_id || '-'
               || json_extract(h.dane_json, '\$.poprzednio.sezon') || '-g',
             h.wiersz_id,
             json_extract(h.dane_json, '\$.poprzednio.sezon'),
             json_extract(h.dane_json, '\$.poprzednio.uprawa'),
             json_extract(h.dane_json, '\$.poprzednio.kod_eppo'),
             1, 'dziennik zmian', h.czas, h.czas,
             COALESCE(h.urzadzenie, 'nieznane')
      FROM historia_zmian h
      JOIN dzialka_rolna r ON r.id = h.wiersz_id
      WHERE h.tabela = 'dzialka_rolna'
        AND h.operacja = 'zmiana'
        AND json_extract(h.dane_json, '\$.poprzednio.uprawa') IS NOT NULL
        AND TRIM(json_extract(h.dane_json, '\$.poprzednio.uprawa')) <> ''
        AND json_extract(h.dane_json, '\$.poprzednio.sezon') IS NOT NULL
        AND json_extract(h.dane_json, '\$.poprzednio.sezon') <> r.sezon
      ''',

      // Uprawa z pola wpisuje się do historii sama, wyzwalaczem — a nie
      // z kodu, który o tym pamięta. Pola wstawia nie tylko ekran „Nowe
      // pole": robi to też import wniosku i scalanie danych z drugiego
      // urządzenia. Jedno miejsce w bazie zamiast trzech w kodzie.
      '''
      CREATE TRIGGER uprawa_pola_z_dzialki AFTER INSERT ON dzialka_rolna
      WHEN NEW.uprawa IS NOT NULL AND TRIM(NEW.uprawa) <> ''
      BEGIN
        INSERT OR IGNORE INTO uprawa_pola
          (id, dzialka_rolna_id, sezon, uprawa, kod_eppo, plon_glowny,
           zrodlo, utworzono, zmieniono, urzadzenie)
        VALUES ('up-' || NEW.id || '-' || NEW.sezon || '-g', NEW.id,
                NEW.sezon, NEW.uprawa, NEW.kod_eppo, 1, 'pole',
                NEW.utworzono, NEW.zmieniono, NEW.urzadzenie);
      END
      ''',

      // Zmiana uprawy na polu też musi dojść do historii. Przy nowym
      // sezonie powstaje nowy wiersz, a ten z poprzedniego roku zostaje —
      // właśnie o niego pyta zmianowanie. Poprzednią treść zapisuje
      // wyzwalacz `historia_dzialka_rolna_zmiana`, więc nic nie ginie.
      '''
      CREATE TRIGGER uprawa_pola_z_dzialki_zmiana
      AFTER UPDATE OF uprawa, kod_eppo, sezon ON dzialka_rolna
      WHEN NEW.uprawa IS NOT NULL AND TRIM(NEW.uprawa) <> ''
      BEGIN
        INSERT OR REPLACE INTO uprawa_pola
          (id, dzialka_rolna_id, sezon, uprawa, kod_eppo, plon_glowny,
           zrodlo, utworzono, zmieniono, urzadzenie)
        VALUES ('up-' || NEW.id || '-' || NEW.sezon || '-g', NEW.id,
                NEW.sezon, NEW.uprawa, NEW.kod_eppo, 1, 'pole',
                NEW.utworzono, NEW.zmieniono, NEW.urzadzenie);
      END
      ''',

      // Uprawy pola też są dopisywane, nie nadpisywane: poprawka wpisu
      // o roku 2024 musi zostawić ślad, bo od niej zależy wynik GAEC 7.
      '''
      CREATE TRIGGER historia_uprawa_pola_zmiana AFTER UPDATE ON uprawa_pola
      WHEN OLD.uprawa IS NOT NEW.uprawa
        OR OLD.kod_eppo IS NOT NEW.kod_eppo
        OR OLD.sezon IS NOT NEW.sezon
        OR OLD.usuniety IS NOT NEW.usuniety
      BEGIN
        INSERT INTO historia_zmian (tabela, wiersz_id, operacja, dane_json, czas, urzadzenie)
        VALUES ('uprawa_pola', NEW.id,
                CASE WHEN NEW.usuniety = 1 THEN 'usuniecie' ELSE 'zmiana' END,
                json_object('poprzednio',
                  json_object('sezon', OLD.sezon, 'uprawa', OLD.uprawa,
                              'kod_eppo', OLD.kod_eppo,
                              'plon_glowny', OLD.plon_glowny)),
                NEW.zmieniono, NEW.urzadzenie);
      END
      ''',
    ],
  ),
];
