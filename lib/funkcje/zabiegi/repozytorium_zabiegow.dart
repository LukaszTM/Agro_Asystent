import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/modele/zabieg.dart';

/// Zapis i odczyt zabiegów. Cały wpis — zabieg, pola i szczegóły — powstaje
/// w jednej transakcji, żeby w ewidencji nie został zabieg bez pola albo
/// oprysk bez środka.
class RepozytoriumZabiegow {
  const RepozytoriumZabiegow(this._baza);

  final DatabaseExecutor _baza;

  Future<void> zapisz({
    required Zabieg zabieg,
    required List<PoleZabiegu> pola,
    SzczegolyOprysku? oprysk,
    DateTime? teraz,
  }) async {
    final czas = teraz ?? DateTime.now();
    Future<void> zapiszW(DatabaseExecutor wykonawca) async {
      await wykonawca.insert(
        'zabieg',
        zabieg.doBazy(teraz: czas),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await wykonawca.delete(
        'zabieg_pole',
        where: 'zabieg_id = ?',
        whereArgs: [zabieg.id],
      );
      for (final pole in pola) {
        await wykonawca.insert('zabieg_pole', {
          'zabieg_id': zabieg.id,
          'dzialka_rolna_id': pole.dzialkaRolnaId,
          'powierzchnia_ar': pole.powierzchniaAr,
        });
      }
      if (oprysk != null) {
        await wykonawca.insert(
          'zabieg_oprysk',
          oprysk.doBazy(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    final baza = _baza;
    if (baza is Database) {
      await baza.transaction(zapiszW);
    } else {
      await zapiszW(baza);
    }
  }

  /// Zabiegi gospodarstwa, od najnowszego. Usunięte wpisy zostają w bazie,
  /// ale nie trafiają do ewidencji.
  Future<List<Zabieg>> wszystkie(String gospodarstwoId) async {
    final wiersze = await _baza.query(
      'zabieg',
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
      orderBy: 'data DESC, godzina DESC',
    );
    return wiersze.map(Zabieg.zBazy).toList(growable: false);
  }

  Future<SzczegolyOprysku?> szczegolyOprysku(String zabiegId) async {
    final wiersze = await _baza.query(
      'zabieg_oprysk',
      where: 'zabieg_id = ?',
      whereArgs: [zabiegId],
      limit: 1,
    );
    return wiersze.isEmpty ? null : SzczegolyOprysku.zBazy(wiersze.first);
  }

  /// Cofnięcie wpisu: wiersz zostaje, dziennik zmian odnotowuje usunięcie.
  /// Rolnik zawsze może wrócić do tego, co wpisał (plan, pkt 5).
  Future<void> oznaczUsuniety({
    required String zabiegId,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    await _baza.update(
      'zabieg',
      {
        'usuniety': 1,
        'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
        'urzadzenie': urzadzenie,
      },
      where: 'id = ?',
      whereArgs: [zabiegId],
    );
  }

  /// Zapis dziennika zmian dla jednego wpisu — do pokazania przy kontroli
  /// i do synchronizacji między urządzeniami.
  Future<List<Map<String, Object?>>> historia(String zabiegId) => _baza.query(
    'historia_zmian',
    where: 'tabela = ? AND wiersz_id = ?',
    whereArgs: ['zabieg', zabiegId],
    orderBy: 'id',
  );
}
