import 'package:sqflite_common/sqlite_api.dart';

import 'migracje.dart';

/// Otwiera i migruje bazę z danymi gospodarstwa.
///
/// Fabrykę bazy podaje się z zewnątrz: na telefonie `sqflite`, na komputerze
/// i w testach `sqflite_common_ffi`. Dzięki temu ten sam kod i te same migracje
/// obsługują oba wyglądy i obie platformy.
class BazaGospodarstwa {
  const BazaGospodarstwa._();

  /// Nazwa pliku bazy danych rolnika. Słowniki leżą osobno (ADR-0004).
  static const String nazwaPliku = 'gospodarstwo.sqlite';

  static Future<Database> otworz({
    required DatabaseFactory fabryka,
    required String sciezka,
  }) {
    return fabryka.openDatabase(
      sciezka,
      options: OpenDatabaseOptions(
        version: najnowszaWersja,
        onConfigure: (baza) async {
          // Baza ma sama pilnować spójności — to ostatnia linia obrony przed
          // błędem w dokumentacji rolnika (ADR-0004).
          await baza.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (baza, wersja) => _zastosuj(baza, od: 0, do_: wersja),
        onUpgrade: (baza, poprzednia, nowa) =>
            _zastosuj(baza, od: poprzednia, do_: nowa),
      ),
    );
  }

  static Future<void> _zastosuj(
    Database baza, {
    required int od,
    required int do_,
  }) async {
    for (final migracja in migracje) {
      if (migracja.wersja <= od || migracja.wersja > do_) {
        continue;
      }
      for (final polecenie in migracja.polecenia) {
        await baza.execute(polecenie);
      }
    }
  }
}
