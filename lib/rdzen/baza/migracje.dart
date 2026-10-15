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
];
