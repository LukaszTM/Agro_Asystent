import 'package:sqflite_common/sqlite_api.dart';

/// Czy rolnik chce przypomnień — zapisane w bazie, żeby przetrwało
/// zamknięcie aplikacji.
class UstawieniaPrzypomnien {
  const UstawieniaPrzypomnien(this._baza);

  final DatabaseExecutor _baza;

  static const String klucz = 'przypomnienia_wlaczone';

  Future<bool> czyWlaczone() async {
    final wiersze = await _baza.query(
      'ustawienia',
      where: 'klucz = ?',
      whereArgs: [klucz],
      limit: 1,
    );
    return wiersze.isNotEmpty && wiersze.first['wartosc'] == 'tak';
  }

  Future<void> zapisz({required bool wlaczone}) async {
    await _baza.insert('ustawienia', {
      'klucz': klucz,
      'wartosc': wlaczone ? 'tak' : 'nie',
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
