import 'package:sqflite_common/sqlite_api.dart';

/// Nawóz z własnego spisu rolnika.
///
/// Zawartości składników **nie zgadujemy** — rolnik przepisuje je z worka
/// albo z analizy nawozu naturalnego (CLAUDE.md, reguła 5). Odczyt z
/// opakowania zdjęciem dojdzie w kroku 7 etapu 1.
class Nawoz {
  const Nawoz({
    required this.id,
    required this.gospodarstwoId,
    required this.nazwa,
    required this.naturalny,
    this.azotProcent,
    this.fosforProcent,
    this.potasProcent,
    this.zrodlo,
  });

  final String id;
  final String gospodarstwoId;
  final String nazwa;

  /// Nawóz naturalny (obornik, gnojowica, gnojówka) podlega limitowi azotu.
  final bool naturalny;

  final double? azotProcent;
  final double? fosforProcent;
  final double? potasProcent;

  /// Skąd wzięły się zawartości: „worek", „analiza", „wpisane ręcznie".
  final String? zrodlo;

  bool get azotZnany => azotProcent != null;

  String get skladOpis {
    if (!azotZnany) {
      return 'zawartość azotu do uzupełnienia';
    }
    final czesci = [
      'N ${_liczba(azotProcent!)}%',
      if (fosforProcent != null) 'P ${_liczba(fosforProcent!)}%',
      if (potasProcent != null) 'K ${_liczba(potasProcent!)}%',
    ];
    return czesci.join(' • ');
  }

  /// Ile azotu niesie dawka [dawka] w jednostce [jednostka] na hektar.
  /// `null`, gdy zawartość azotu nie jest znana — wtedy nic nie liczymy.
  double? azotKgNaHa(double dawka, JednostkaDawki jednostka) {
    final procent = azotProcent;
    if (procent == null) {
      return null;
    }
    return dawka * jednostka.kilogramy * procent / 100;
  }

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(wartosc % 1 == 0 ? 0 : 1).replaceAll('.', ',');

  static Nawoz zBazy(Map<String, Object?> w) => Nawoz(
    id: w['id']! as String,
    gospodarstwoId: w['gospodarstwo_id']! as String,
    nazwa: w['nazwa']! as String,
    naturalny: (w['naturalny'] as int? ?? 0) == 1,
    azotProcent: (w['azot_procent'] as num?)?.toDouble(),
    fosforProcent: (w['fosfor_procent'] as num?)?.toDouble(),
    potasProcent: (w['potas_procent'] as num?)?.toDouble(),
    zrodlo: w['zrodlo'] as String?,
  );
}

/// Jednostka dawki nawozu — przeliczana na kilogramy.
enum JednostkaDawki {
  kilogramyNaHektar('kg/ha', 1),
  tonyNaHektar('t/ha', 1000),
  metrySzescienneNaHektar('m³/ha', 1000);

  const JednostkaDawki(this.opis, this.kilogramy);

  final String opis;

  /// Ile kilogramów (albo kilogramów masy) mieści jednostka. Dla gnojowicy
  /// przyjmujemy gęstość wody — i tak liczy się zawartość azotu z analizy.
  final double kilogramy;

  static JednostkaDawki zOpisu(String? opis) =>
      JednostkaDawki.values.firstWhere(
        (j) => j.opis == opis,
        orElse: () => JednostkaDawki.kilogramyNaHektar,
      );
}

class RepozytoriumNawozow {
  const RepozytoriumNawozow(this._baza);

  final DatabaseExecutor _baza;

  Future<List<Nawoz>> wszystkie(String gospodarstwoId) async {
    final wiersze = await _baza.query(
      'nawoz',
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
      orderBy: 'naturalny DESC, nazwa',
    );
    return wiersze.map(Nawoz.zBazy).toList(growable: false);
  }

  Future<Nawoz?> jeden(String id) async {
    final wiersze = await _baza.query(
      'nawoz',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return wiersze.isEmpty ? null : Nawoz.zBazy(wiersze.first);
  }

  Future<void> zapisz({
    required Nawoz nawoz,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    await _baza.insert('nawoz', {
      'id': nawoz.id,
      'gospodarstwo_id': nawoz.gospodarstwoId,
      'nazwa': nawoz.nazwa,
      'azot_procent': nawoz.azotProcent,
      'fosfor_procent': nawoz.fosforProcent,
      'potas_procent': nawoz.potasProcent,
      'naturalny': nawoz.naturalny ? 1 : 0,
      'zrodlo': nawoz.zrodlo,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> usun({
    required String id,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    await _baza.update(
      'nawoz',
      {
        'usuniety': 1,
        'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
        'urzadzenie': urzadzenie,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
