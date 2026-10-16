import 'package:sqflite_common/sqlite_api.dart';

/// Wygląd aplikacji na telefonie (plan, pkt 5).
///
/// Oba wyglądy pokazują te same dane i funkcje — różni się tylko warstwa
/// ekranów. Wybór jest w ustawieniach i da się go zmienić w każdej chwili.
enum Wyglad {
  /// Duże przyciski, tekst od 18 px — dla osób starszych.
  prosty('prosty', 'Prosty', 'duże przyciski, tekst od 18 px'),

  /// Gęstszy układ z dolnym paskiem — dla osób obytych ze smartfonem.
  nowoczesny('nowoczesny', 'Nowoczesny', 'podsumowanie sezonu, dolny pasek');

  const Wyglad(this.wBazie, this.nazwa, this.opis);

  final String wBazie;
  final String nazwa;
  final String opis;

  static Wyglad zBazy(String? wartosc) => Wyglad.values.firstWhere(
    (w) => w.wBazie == wartosc,
    // Domyślnie prosty: aplikacja jest przede wszystkim dla rolników 60+.
    orElse: () => Wyglad.prosty,
  );
}

/// Wybrany wygląd, zapisany w ustawieniach gospodarstwa.
class WyborWygladu {
  const WyborWygladu(this._baza);

  final DatabaseExecutor _baza;

  static const String klucz = 'wyglad';

  Future<Wyglad> odczytaj() async {
    final wiersze = await _baza.query(
      'ustawienia',
      where: 'klucz = ?',
      whereArgs: [klucz],
      limit: 1,
    );
    return Wyglad.zBazy(
      wiersze.isEmpty ? null : wiersze.first['wartosc'] as String?,
    );
  }

  Future<void> zapisz(Wyglad wyglad) async {
    await _baza.insert('ustawienia', {
      'klucz': klucz,
      'wartosc': wyglad.wBazie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
