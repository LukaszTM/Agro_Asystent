import 'package:sqflite_common/sqlite_api.dart';

/// Pole, czyli działka rolna w rozumieniu wniosku: własna nazwa, uprawa
/// i powierzchnia. Numer działki ewidencyjnej widać obok (plan, pkt 5).
class Pole {
  const Pole({
    required this.id,
    required this.gospodarstwoId,
    required this.nazwa,
    required this.uprawa,
    required this.powierzchniaAr,
    this.oznaczenieZWniosku,
    this.kodEppo,
    this.sezon,
  });

  final String id;
  final String gospodarstwoId;
  final String nazwa;
  final String uprawa;
  final int powierzchniaAr;
  final String? oznaczenieZWniosku;
  final String? kodEppo;
  final int? sezon;

  double get powierzchniaHa => powierzchniaAr / 100;

  String get powierzchniaOpis =>
      '${powierzchniaHa.toStringAsFixed(2).replaceAll('.', ',')} ha';

  static Pole zBazy(Map<String, Object?> w) => Pole(
    id: w['id']! as String,
    gospodarstwoId: w['gospodarstwo_id']! as String,
    nazwa: (w['nazwa_wlasna'] as String?) ?? 'Pole bez nazwy',
    uprawa: (w['uprawa'] as String?) ?? '',
    powierzchniaAr: (w['powierzchnia_ar'] as int?) ?? 0,
    oznaczenieZWniosku: w['oznaczenie_z_wniosku'] as String?,
    kodEppo: w['kod_eppo'] as String?,
    sezon: w['sezon'] as int?,
  );
}

class RepozytoriumPol {
  const RepozytoriumPol(this._baza);

  final DatabaseExecutor _baza;

  Future<List<Pole>> wszystkie(String gospodarstwoId) async {
    final wiersze = await _baza.query(
      'dzialka_rolna',
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
      orderBy: 'nazwa_wlasna',
    );
    return wiersze.map(Pole.zBazy).toList(growable: false);
  }

  Future<void> dodaj({
    required Pole pole,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    await _baza.insert('dzialka_rolna', {
      'id': pole.id,
      'gospodarstwo_id': pole.gospodarstwoId,
      'nazwa_wlasna': pole.nazwa,
      'oznaczenie_z_wniosku': pole.oznaczenieZWniosku,
      'sezon': pole.sezon ?? DateTime.now().year,
      'uprawa': pole.uprawa,
      'kod_eppo': pole.kodEppo,
      'powierzchnia_ar': pole.powierzchniaAr,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
