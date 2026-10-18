import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/slownik_upraw.dart';
import 'package:agro_asystent/funkcje/dzialki/uprawy_dopisane.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uprawy dopisane poza rejestrem środków ochrony roślin.
///
/// Rejestr MRiRW mówi, czym wolno opryskiwać, więc trwałych użytków
/// zielonych prawie w nim nie ma — a dokumentację trzeba prowadzić i dla
/// łąk. Czego pilnują testy: dopisana uprawa jest do wyboru i da się ją
/// znaleźć, kodu EPPO nie zgadujemy, a rejestr zostaje nietknięty.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;

  late Database slowniki;

  setUp(() async {
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    await slowniki.insert('uprawa', {
      'nazwa': 'pszenica ozima',
      'kod_eppo': 'TRZAW',
      'stan': 'kod',
      'zastosowan': 120,
      'szukanie': 'pszenica ozima',
    });
    // Rejestr zna „trawy" tylko jako nazwę zbiorczą, więc na listę wyboru
    // nie wchodzą — stąd potrzeba dopisania uprawy z pliku.
    await slowniki.insert('uprawa', {
      'nazwa': 'trawy',
      'stan': 'grupa',
      'zastosowan': 23,
      'szukanie': 'trawy',
    });
    addTearDown(slowniki.close);
  });

  group('plik dopisanych upraw', () {
    late SlownikUprawDopisanych zPliku;

    setUpAll(() {
      zPliku = SlownikUprawDopisanych.zTekstuJson(
        File('assets/dane/uprawy_dopisane.json').readAsStringSync(),
      );
    });

    test('ma numer wersji i zastrzeżenie', () {
      expect(zPliku.wersja, isNotEmpty);
      expect(zPliku.zastrzezenie, contains('brak'));
    });

    test('są w nim Trawy, bez kodu EPPO', () {
      final trawy = zPliku.jedna('Trawy');

      expect(trawy, isNotNull);
      expect(trawy!.maKod, isFalse, reason: 'kodu EPPO nie zgadujemy');
      expect(trawy.kodEppo, isNull);
      expect(trawy.stan, StanUprawy.brak);
    });
  });

  group('wybór uprawy', () {
    late SlownikUpraw slownik;

    setUp(() {
      slownik = SlownikUpraw(
        slowniki,
        dopisane: SlownikUprawDopisanych.zTekstuJson(
          File('assets/dane/uprawy_dopisane.json').readAsStringSync(),
        ),
      );
    });

    test('Trawy są na liście, mimo że rejestr ich nie wymienia', () async {
      final wynik = await slownik.doWyboru();

      expect(wynik.uprawy.map((u) => u.nazwa), contains('Trawy'));
      // Dopisane uprawy stoją na początku — rolnik z łąką nie przewija
      // całego rejestru.
      expect(wynik.uprawy.first.nazwa, 'Trawy');
      // Rejestr daje jedną uprawę do wyboru („trawy" są u niego nazwą
      // zbiorczą), plik dopisuje drugą.
      expect(wynik.razem, 2);
    });

    test('szukanie bez ogonków i wielkości liter znajduje Trawy', () async {
      for (final szukane in ['traw', 'TRAWY', 'trawy']) {
        final wynik = await slownik.doWyboru(szukane: szukane);
        expect(
          wynik.uprawy.map((u) => u.nazwa),
          contains('Trawy'),
          reason: szukane,
        );
      }
    });

    test('nie podstawia się pod szukanie czegoś innego', () async {
      final wynik = await slownik.doWyboru(szukane: 'pszenica');

      expect(wynik.uprawy.map((u) => u.nazwa), ['pszenica ozima']);
    });

    test(
      'Trawy da się odczytać po nazwie, tak jak uprawę z rejestru',
      () async {
        expect((await slownik.jedna('Trawy'))!.kodEppo, isNull);
        expect((await slownik.jedna('pszenica ozima'))!.kodEppo, 'TRZAW');
      },
    );

    test('bez pliku zostaje sam rejestr', () async {
      final bezPliku = SlownikUpraw(slowniki);
      final wynik = await bezPliku.doWyboru();

      expect(wynik.uprawy.map((u) => u.nazwa), ['pszenica ozima']);
      expect(await bezPliku.jedna('Trawy'), isNull);
    });
  });
}
