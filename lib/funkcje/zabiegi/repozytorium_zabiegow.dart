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

  /// Zabiegi wybranych podrodzajów (prac przy elementach krajobrazu)
  /// w danym roku — stąd przegląd warunkowości wie, czy w okresie zakazu
  /// był wpis przycinania.
  Future<List<Zabieg>> poPodrodzaju({
    required String gospodarstwoId,
    required List<String> podrodzaje,
    int? rok,
  }) async {
    if (podrodzaje.isEmpty) {
      return const [];
    }
    final znaki = List.filled(podrodzaje.length, '?').join(', ');
    final wiersze = await _baza.query(
      'zabieg',
      where: [
        'gospodarstwo_id = ?',
        'usuniety = 0',
        'podrodzaj IN ($znaki)',
        if (rok != null) 'data LIKE ?',
      ].join(' AND '),
      whereArgs: [gospodarstwoId, ...podrodzaje, if (rok != null) '$rok-%'],
      orderBy: 'data DESC',
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

  /// Poprawka wpisu: godzina, dawka, powód i uwagi.
  ///
  /// Zmiany idą do dziennika same, wyzwalaczami — poprzednia wartość zostaje
  /// w bazie, bo kontrola musi widzieć, co było wpisane wcześniej.
  Future<void> popraw({
    required String zabiegId,
    required String urzadzenie,
    String? godzina,
    String? uwagi,
    double? dawka,
    String? przyczyna,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();

    Future<void> poprawW(DatabaseExecutor wykonawca) async {
      await wykonawca.update(
        'zabieg',
        {
          if (godzina case final String nowaGodzina) 'godzina': nowaGodzina,
          if (uwagi case final String noweUwagi) 'uwagi': noweUwagi,
          'zmieniono': czas,
          'urzadzenie': urzadzenie,
        },
        where: 'id = ?',
        whereArgs: [zabiegId],
      );
      if (dawka != null || przyczyna != null) {
        await wykonawca.update(
          'zabieg_oprysk',
          {
            if (dawka case final double nowaDawka) 'dawka': nowaDawka,
            if (przyczyna case final String nowaPrzyczyna)
              'przyczyna': nowaPrzyczyna,
          },
          where: 'zabieg_id = ?',
          whereArgs: [zabiegId],
        );
      }
    }

    final baza = _baza;
    if (baza is Database) {
      await baza.transaction(poprawW);
    } else {
      await poprawW(baza);
    }
  }

  /// Dopisanie albo potwierdzenie karencji przy wpisie oprysku.
  ///
  /// Karencja z bazy etykiet jest propozycją — dopóki rolnik jej nie
  /// potwierdzi, wpis mówi „z etykiety MRiRW". Gdy jej nie znamy, rolnik
  /// przepisuje ją z opakowania i wtedy źródłem jest on sam (plan, pkt 5).
  Future<void> zapiszKarencje({
    required String zabiegId,
    required int? dni,
    required String zrodlo,
    required bool potwierdzona,
    String? dataEtykiety,
    String urzadzenie = 'telefon',
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    Future<void> zapiszW(DatabaseExecutor wykonawca) async {
      await wykonawca.update(
        'zabieg_oprysk',
        {
          'karencja_dni': dni,
          'karencja_zrodlo': zrodlo,
          'karencja_potwierdzona': potwierdzona ? 1 : 0,
          if (dataEtykiety case final String data)
            'karencja_data_etykiety': data,
        },
        where: 'zabieg_id = ?',
        whereArgs: [zabiegId],
      );
      // Dziennik zmian wisi na tabeli zabiegu, więc dotykamy też jej —
      // inaczej poprawka karencji nie zostawiłaby śladu.
      await wykonawca.update(
        'zabieg',
        {'zmieniono': czas, 'urzadzenie': urzadzenie},
        where: 'id = ?',
        whereArgs: [zabiegId],
      );
    }

    final baza = _baza;
    if (baza is Database) {
      await baza.transaction(zapiszW);
    } else {
      await zapiszW(baza);
    }
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
