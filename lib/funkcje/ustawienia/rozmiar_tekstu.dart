import 'package:sqflite_common/sqlite_api.dart';

/// Wielkość tekstu w programie na komputer (plan, pkt 5: „Program na
/// Windows ma jeden wygląd, z ustawieniem wielkości tekstu").
///
/// Na telefonie wielkość tekstu wynika z wybranego wyglądu — na komputerze
/// wygląd jest jeden, a monitory bywają i małe, i duże, i stojące dwa
/// metry od biurka. Dlatego skalę wybiera rolnik.
enum RozmiarTekstu {
  normalny('normalny', 'Normalny', 1),
  duzy('duzy', 'Duży', 1.2),
  bardzoDuzy('bardzo_duzy', 'Bardzo duży', 1.45);

  const RozmiarTekstu(this.wBazie, this.nazwa, this.skala);

  final String wBazie;
  final String nazwa;

  /// Mnożnik wielkości tekstu w motywie programu.
  final double skala;

  String get opis => 'tekst ${(skala * 100).round()} %';

  static RozmiarTekstu zBazy(String? wartosc) => RozmiarTekstu.values
      .firstWhere((r) => r.wBazie == wartosc, orElse: () => normalny);
}

/// Wybrana wielkość tekstu, zapisana w ustawieniach gospodarstwa — tak samo
/// jak wybór wyglądu telefonu.
class WyborRozmiaruTekstu {
  const WyborRozmiaruTekstu(this._baza);

  final DatabaseExecutor _baza;

  static const String klucz = 'rozmiar_tekstu';

  Future<RozmiarTekstu> odczytaj() async {
    final wiersze = await _baza.query(
      'ustawienia',
      where: 'klucz = ?',
      whereArgs: [klucz],
      limit: 1,
    );
    return RozmiarTekstu.zBazy(
      wiersze.isEmpty ? null : wiersze.first['wartosc'] as String?,
    );
  }

  Future<void> zapisz(RozmiarTekstu rozmiar) async {
    await _baza.insert('ustawienia', {
      'klucz': klucz,
      'wartosc': rozmiar.wBazie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
