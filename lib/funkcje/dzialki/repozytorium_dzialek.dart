import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/uslugi/geometria.dart';
import 'klient_uldk.dart';

/// Działka ewidencyjna zapisana na urządzeniu — z granicami, więc mapa działa
/// bez internetu.
class DzialkaEwidencyjna {
  const DzialkaEwidencyjna({
    required this.id,
    required this.identyfikator,
    this.wojewodztwo,
    this.powiat,
    this.gmina,
    this.obreb,
    this.nrDzialki,
    this.powierzchniaHa,
    this.geometriaWkt,
    this.pobrano,
  });

  final String id;
  final String identyfikator;
  final String? wojewodztwo;
  final String? powiat;
  final String? gmina;
  final String? obreb;
  final String? nrDzialki;
  final double? powierzchniaHa;
  final String? geometriaWkt;
  final String? pobrano;

  bool get maGranice => geometriaWkt != null && geometriaWkt!.isNotEmpty;

  List<Pierscien> get obrysy =>
      maGranice ? Geometria.zWkt(geometriaWkt!) : const [];

  String get polozenie =>
      [obreb, gmina].whereType<String>().where((c) => c.isNotEmpty).join(', ');

  String get powierzchniaOpis => powierzchniaHa == null
      ? 'powierzchnia nieznana'
      : '${powierzchniaHa!.toStringAsFixed(2).replaceAll('.', ',')} ha';

  static DzialkaEwidencyjna zBazy(Map<String, Object?> w) => DzialkaEwidencyjna(
    id: w['id']! as String,
    identyfikator: w['identyfikator']! as String,
    wojewodztwo: w['wojewodztwo'] as String?,
    powiat: w['powiat'] as String?,
    gmina: w['gmina'] as String?,
    obreb: w['obreb'] as String?,
    nrDzialki: w['nr_dzialki'] as String?,
    powierzchniaHa: (w['powierzchnia_ha'] as num?)?.toDouble(),
    geometriaWkt: w['geometria_wkt'] as String?,
    pobrano: w['pobrano'] as String?,
  );
}

class RepozytoriumDzialek {
  const RepozytoriumDzialek(this._baza);

  final DatabaseExecutor _baza;

  Future<List<DzialkaEwidencyjna>> wszystkie(String gospodarstwoId) async {
    final wiersze = await _baza.query(
      'dzialka_ewidencyjna',
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
      orderBy: 'obreb, nr_dzialki',
    );
    return wiersze.map(DzialkaEwidencyjna.zBazy).toList(growable: false);
  }

  Future<bool> czyJuzJest(String gospodarstwoId, String identyfikator) async {
    final wiersze = await _baza.query(
      'dzialka_ewidencyjna',
      where: 'gospodarstwo_id = ? AND identyfikator = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId, identyfikator],
      limit: 1,
    );
    return wiersze.isNotEmpty;
  }

  /// Zapisuje działkę pobraną z ULDK razem z granicami i źródłem, bo rolnik
  /// ma widzieć, skąd wzięły się dane (plan, pkt 5).
  Future<DzialkaEwidencyjna> zapisz({
    required String gospodarstwoId,
    required DzialkaZUldk zUldk,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final id = 'dz-${zUldk.identyfikator}';
    await _baza.insert('dzialka_ewidencyjna', {
      'id': id,
      'gospodarstwo_id': gospodarstwoId,
      'identyfikator': zUldk.identyfikator,
      'wojewodztwo': zUldk.wojewodztwo,
      'powiat': zUldk.powiat,
      'gmina': zUldk.gmina,
      'obreb': zUldk.obreb,
      'nr_dzialki': zUldk.nrDzialki,
      'powierzchnia_ha': zUldk.powierzchniaHa,
      'geometria_wkt': zUldk.wkt,
      'srid': zUldk.srid,
      'zrodlo_geometrii': 'ULDK (GUGiK)',
      'pobrano': czas,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return DzialkaEwidencyjna(
      id: id,
      identyfikator: zUldk.identyfikator,
      wojewodztwo: zUldk.wojewodztwo,
      powiat: zUldk.powiat,
      gmina: zUldk.gmina,
      obreb: zUldk.obreb,
      nrDzialki: zUldk.nrDzialki,
      powierzchniaHa: zUldk.powierzchniaHa,
      geometriaWkt: zUldk.wkt,
      pobrano: czas,
    );
  }
}
