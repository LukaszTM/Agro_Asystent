import 'package:agro_asystent/app/platforma.dart';
import 'package:agro_asystent/funkcje/odczyt/czytnik_zdjecia.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Jeden kod na telefon i komputer (plan, pkt 1), ale SQLite dostaje się
/// do nich inaczej. Bez tego wyboru program na Windows nie wstaje wcale:
/// `sqflite` nie ma tam natywnej bazy, a `databaseFactory` zostaje pusty.
void main() {
  group('wybór fabryki bazy', () {
    test('komputer dostaje bazę z biblioteki dołączonej do programu', () {
      final fabryka = fabrykaBazy(Platforma.komputer);
      expect(fabryka, same(databaseFactoryFfi));
    });

    test('nazwa urządzenia idzie do wpisów i rozróżnia je po scaleniu', () {
      expect(Platforma.telefon.nazwaUrzadzenia, 'telefon');
      expect(Platforma.komputer.nazwaUrzadzenia, 'komputer');
    });

    test('baza z fabryki komputera naprawdę się otwiera', () async {
      final baza = await fabrykaBazy(Platforma.komputer)
          .openDatabase(inMemoryDatabasePath);
      addTearDown(baza.close);

      await baza.execute('CREATE TABLE proba (id INTEGER PRIMARY KEY)');
      await baza.insert('proba', {'id': 1});
      expect(await baza.query('proba'), hasLength(1));
    });
  });

  group('odczyt zdjęć', () {
    test('na komputerze mówi wprost, że działa tylko w telefonie', () async {
      final czytnik = czytnikZdjecia(Platforma.komputer);
      expect(czytnik, isA<CzytnikTylkoWTelefonie>());

      await expectLater(
        czytnik.tekst(ZrodloZdjecia.aparat),
        throwsA(
          isA<BladOdczytuZdjecia>().having(
            (b) => b.wiadomosc,
            'wiadomość',
            contains('tylko w telefonie'),
          ),
        ),
      );
    });
  });
}
