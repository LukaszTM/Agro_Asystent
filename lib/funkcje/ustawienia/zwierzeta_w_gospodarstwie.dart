import 'package:sqflite_common/sqlite_api.dart';

/// Czy w gospodarstwie są zwierzęta gospodarskie.
///
/// Aplikacja **nie prowadzi rejestru stada** — produkcja zwierzęca jest poza
/// zakresem tej wersji (plan, pkt 2) i czeka jako ścieżka rozwoju. Ale od
/// liczby DJP zależą obowiązki z programu azotanowego, więc aplikacja nie
/// może udawać, że zwierząt nie ma: pyta o to raz rolnika.
enum OdpowiedzZwierzeta {
  /// Rolnik jeszcze nie odpowiedział — obowiązki od DJP są „do sprawdzenia".
  nieWiem('nie_wiem'),

  /// Gospodarstwo bez zwierząt: DJP wynosi zero i to jest pewne.
  nie('nie'),

  /// Są zwierzęta, ale aplikacja nie zna ich liczby — DJP nieznane.
  tak('tak');

  const OdpowiedzZwierzeta(this.wBazie);

  final String wBazie;

  static OdpowiedzZwierzeta zBazy(String? wartosc) =>
      OdpowiedzZwierzeta.values.firstWhere(
        (o) => o.wBazie == wartosc,
        orElse: () => OdpowiedzZwierzeta.nieWiem,
      );

  /// Liczba DJP do profilu gospodarstwa. `null` znaczy „nie wiadomo" —
  /// wtedy silnik reguł oznacza obowiązek jako do sprawdzenia, a nie jako
  /// niedotyczący (CLAUDE.md, reguła 5).
  double? get djp => this == OdpowiedzZwierzeta.nie ? 0 : null;

  /// `null`, dopóki rolnik nie odpowiedział.
  bool? get posiadaczZwierzat => switch (this) {
    OdpowiedzZwierzeta.nieWiem => null,
    OdpowiedzZwierzeta.nie => false,
    OdpowiedzZwierzeta.tak => true,
  };
}

/// Odpowiedź rolnika zapisana w ustawieniach gospodarstwa.
class ZwierzetaWGospodarstwie {
  const ZwierzetaWGospodarstwie(this._baza);

  final DatabaseExecutor _baza;

  static const String klucz = 'zwierzeta_w_gospodarstwie';

  Future<OdpowiedzZwierzeta> odczytaj() async {
    final wiersze = await _baza.query(
      'ustawienia',
      where: 'klucz = ?',
      whereArgs: [klucz],
      limit: 1,
    );
    return OdpowiedzZwierzeta.zBazy(
      wiersze.isEmpty ? null : wiersze.first['wartosc'] as String?,
    );
  }

  Future<void> zapisz(OdpowiedzZwierzeta odpowiedz) async {
    await _baza.insert('ustawienia', {
      'klucz': klucz,
      'wartosc': odpowiedz.wBazie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
