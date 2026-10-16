import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/czytnik_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Import wniosku dopisuje działki i pola do bazy gospodarstwa, nie ruszając
/// tego, co rolnik lub ULDK już tam włożyli.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;
  late Database slowniki;
  late ImportWniosku import;
  late WniosekZPdf wniosek;

  setUpAll(() {
    wniosek = CzytnikWniosku.zBajtow(
      File('test/dane/wzorzec_wniosku.pdf').readAsBytesSync(),
    );
  });

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-10-15T08:00:00',
      'zmieniono': '2026-10-15T08:00:00',
      'urzadzenie': 'telefon',
    });

    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    // Dwie uprawy ze słownika i jedna bez kodu — tak jak w prawdziwym
    // słowniku, gdzie część nazw z wniosku nie ma odpowiednika.
    await slowniki.insert('uprawa', {
      'nazwa': 'pszenica zwyczajna ozima',
      'kod_eppo': 'TRZAW',
    });
    await slowniki.insert('uprawa', {'nazwa': 'ziemniak', 'kod_eppo': 'SOLTU'});
    await slowniki.insert('uprawa', {'nazwa': 'TUZ', 'kod_eppo': null});

    import = ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki));
  });

  tearDown(() async {
    await baza.close();
    await slowniki.close();
  });

  Future<WynikImportu> zapisz() => import.zapisz(
    wniosek: wniosek,
    gospodarstwoId: 'g1',
    urzadzenie: 'telefon',
    teraz: DateTime(2026, 10, 15, 9),
  );

  test('zapisuje wszystkie działki i pola z wniosku', () async {
    final wynik = await zapisz();

    expect(wynik.dzialkiDodane, 20);
    expect(wynik.polaDodane, 34);
    expect(wynik.sezon, 2026);
    expect(await RepozytoriumDzialek(baza).wszystkie('g1'), hasLength(20));
    expect(await RepozytoriumPol(baza).wszystkie('g1'), hasLength(34));
  });

  test(
    'działki zapisuje z pełnym numerem, żeby dały się pobrać z ULDK',
    () async {
      await zapisz();
      final dzialki = await RepozytoriumDzialek(baza).wszystkie('g1');
      for (final dzialka in dzialki) {
        expect(
          KlientUldk.wzorzecIdentyfikatora.hasMatch(dzialka.identyfikator),
          isTrue,
          reason: dzialka.identyfikator,
        );
        expect(dzialka.powierzchniaHa, isNotNull);
        expect(
          dzialka.maGranice,
          isFalse,
          reason: 'granice są z ULDK, nie z PDF',
        );
      }
    },
  );

  test('łączy pola z działkami, na których leżą', () async {
    final wynik = await zapisz();
    expect(wynik.czesciPolaczone, greaterThanOrEqualTo(34));

    final czesci = await baza.query('dzialka_rolna_czesc');
    expect(czesci, hasLength(wynik.czesciPolaczone));
    final suma = czesci.fold<int>(
      0,
      (razem, w) => razem + (w['powierzchnia_ar']! as int),
    );
    expect(suma, wniosek.powierzchniaPolAr);
  });

  test('kod EPPO bierze ze słownika, a brakującego nie zgaduje', () async {
    final wynik = await zapisz();

    final pszenica = await baza.query(
      'dzialka_rolna',
      where: 'uprawa = ?',
      whereArgs: ['pszenica zwyczajna ozima'],
      limit: 1,
    );
    expect(pszenica.first['kod_eppo'], 'TRZAW');

    final bezKodu = await baza.query(
      'dzialka_rolna',
      where: 'uprawa = ?',
      whereArgs: ['owies zwyczajny'],
      limit: 1,
    );
    expect(bezKodu.first['kod_eppo'], isNull);
    expect(wynik.uprawyBezKodu, contains('owies zwyczajny'));
    expect(wynik.uprawyBezKodu, isNot(contains('pszenica zwyczajna ozima')));
  });

  test('powtórny import nie mnoży wierszy', () async {
    await zapisz();
    final drugi = await zapisz();

    expect(drugi.dzialkiDodane, 0);
    expect(drugi.dzialkiUzupelnione, 20);
    expect(drugi.polaDodane, 0);
    expect(drugi.polaZastapione, 34);
    expect(await RepozytoriumDzialek(baza).wszystkie('g1'), hasLength(20));
    expect(await RepozytoriumPol(baza).wszystkie('g1'), hasLength(34));
    expect(
      await baza.query('dzialka_rolna_czesc'),
      hasLength(drugi.czesciPolaczone),
    );
  });

  test('import nie kasuje granic pobranych wcześniej z ULDK', () async {
    final identyfikator = wniosek.identyfikatoryDzialek.first;
    await RepozytoriumDzialek(baza).zapisz(
      gospodarstwoId: 'g1',
      zUldk: DzialkaZUldk(
        identyfikator: identyfikator,
        wkt: 'POLYGON((19.1 52.1,19.2 52.1,19.2 52.2,19.1 52.1))',
        srid: 4326,
      ),
      urzadzenie: 'telefon',
    );

    await zapisz();

    final dzialka = (await RepozytoriumDzialek(baza).wszystkie('g1'))
        .firstWhere((d) => d.identyfikator == identyfikator);
    expect(dzialka.maGranice, isTrue);
    expect(dzialka.powierzchniaHa, isNotNull);
    expect(
      dzialka.obreb,
      isNotNull,
      reason: 'opis z wniosku dochodzi do granic',
    );
  });

  test(
    'nazwa pola nadana przez rolnika zostaje po powtórnym imporcie',
    () async {
      await zapisz();
      final pole = (await RepozytoriumPol(baza).wszystkie('g1')).first;
      await baza.update(
        'dzialka_rolna',
        {'nazwa_wlasna': 'Za stodołą'},
        where: 'id = ?',
        whereArgs: [pole.id],
      );

      await zapisz();

      final poImporcie = await baza.query(
        'dzialka_rolna',
        where: 'id = ?',
        whereArgs: [pole.id],
      );
      expect(poImporcie.first['nazwa_wlasna'], 'Za stodołą');
    },
  );
}
