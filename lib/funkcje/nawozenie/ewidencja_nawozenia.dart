import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/modele/zabieg.dart';
import '../../rdzen/reguly/regula_prawna.dart';
import '../zabiegi/repozytorium_zabiegow.dart';
import 'nawoz.dart';

/// Jeden wpis nawożenia w ewidencji.
class WpisNawozenia {
  const WpisNawozenia({
    required this.zabiegId,
    required this.nawozNazwa,
    required this.naturalny,
    required this.data,
    required this.powierzchniaAr,
    this.nawozId,
    this.dawka,
    this.dawkaJednostka,
    this.azotKgHa,
  });

  final String zabiegId;
  final String? nawozId;
  final String nawozNazwa;
  final bool naturalny;
  final DateTime data;
  final int powierzchniaAr;
  final double? dawka;
  final String? dawkaJednostka;

  /// Azot wniesiony na hektar. `null`, gdy nawóz nie ma znanej zawartości —
  /// wtedy do limitu nie liczymy nic i mówimy o tym wprost.
  final double? azotKgHa;

  double get powierzchniaHa => powierzchniaAr / 100;

  /// Azot wniesiony łącznie na całą powierzchnię zabiegu.
  double? get azotKgRazem =>
      azotKgHa == null ? null : azotKgHa! * powierzchniaHa;

  static WpisNawozenia zBazy(Map<String, Object?> w) => WpisNawozenia(
    zabiegId: w['zabieg_id']! as String,
    nawozId: w['nawoz_id'] as String?,
    nawozNazwa: w['nawoz_nazwa']! as String,
    naturalny: (w['naturalny'] as int? ?? 0) == 1,
    data: DateTime.parse(w['data']! as String),
    powierzchniaAr: (w['powierzchnia_ar'] as int?) ?? 0,
    dawka: (w['dawka'] as num?)?.toDouble(),
    dawkaJednostka: w['dawka_jednostka'] as String?,
    azotKgHa: (w['azot_kg_ha'] as num?)?.toDouble(),
  );
}

/// Ile azotu z nawozów naturalnych wniesiono w sezonie i ile zostało
/// do limitu z przepisu.
class StanLimituAzotu {
  const StanLimituAzotu({
    required this.sezon,
    required this.powierzchniaUrHa,
    required this.azotNaturalnyKg,
    required this.limitKgNaHa,
    required this.wpisyBezAzotu,
    required this.limitZnany,
  });

  final int sezon;
  final double powierzchniaUrHa;

  /// Azot z nawozów naturalnych, łącznie w kilogramach.
  final double azotNaturalnyKg;

  /// Limit z przepisu (kg N/ha/rok) — ze słownika reguł, nie z kodu.
  final double limitKgNaHa;

  /// Wpisy, których nie dało się policzyć, bo nawóz nie ma zawartości azotu.
  final int wpisyBezAzotu;

  /// `false`, gdy słownik reguł nie podaje limitu — wtedy niczego nie
  /// udajemy i mówimy, że limitu nie znamy.
  final bool limitZnany;

  double get azotNaHektar =>
      powierzchniaUrHa <= 0 ? 0 : azotNaturalnyKg / powierzchniaUrHa;

  double get limitKg => limitKgNaHa * powierzchniaUrHa;

  double get pozostaloKg =>
      (limitKg - azotNaturalnyKg).clamp(0, double.infinity);

  /// Jaka część limitu jest wykorzystana (1,0 = limit wyczerpany).
  double get wykorzystanie => limitKg <= 0 ? 0 : azotNaturalnyKg / limitKg;

  bool get przekroczony => limitZnany && azotNaturalnyKg > limitKg;

  bool get blisko => limitZnany && !przekroczony && wykorzystanie >= 0.9;

  /// Czy wynik jest pewny: niepewny, gdy któryś wpis nie dał się policzyć.
  bool get pewny => wpisyBezAzotu == 0;
}

/// Ewidencja nawożenia i pilnowanie limitu azotu (plan, pkt 3).
class EwidencjaNawozenia {
  const EwidencjaNawozenia({
    required this.baza,
    required this.zabiegi,
    required this.reguly,
  });

  final DatabaseExecutor baza;
  final RepozytoriumZabiegow zabiegi;
  final SlownikRegul reguly;

  /// Identyfikator limitu w słowniku reguł.
  static const String idLimitu = 'limit_azotu_z_nawozow_naturalnych';
  static const String idObowiazku = 'program_azotanowy_ewidencja';

  /// Zapisuje nawożenie jako zabieg razem ze szczegółami nawozu.
  Future<String> zapisz({
    required String gospodarstwoId,
    required Nawoz nawoz,
    required List<PoleZabiegu> pola,
    required double dawka,
    required JednostkaDawki jednostka,
    required String urzadzenie,
    DateTime? kiedy,
    String? uwagi,
  }) async {
    final czas = kiedy ?? DateTime.now();
    final id = 'nawoz-${czas.microsecondsSinceEpoch}';
    final powierzchniaAr = pola.fold(0, (suma, p) => suma + p.powierzchniaAr);

    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: id,
        gospodarstwoId: gospodarstwoId,
        rodzaj: RodzajZabiegu.nawozenie,
        data: czas,
        godzina:
            '${czas.hour.toString().padLeft(2, '0')}:'
            '${czas.minute.toString().padLeft(2, '0')}',
        powierzchniaAr: powierzchniaAr,
        uwagi: uwagi,
        urzadzenie: urzadzenie,
      ),
      pola: pola,
      teraz: czas,
    );

    await baza.insert('zabieg_nawozenie', {
      'zabieg_id': id,
      'nawoz_id': nawoz.id,
      'nawoz_nazwa': nawoz.nazwa,
      'dawka': dawka,
      'dawka_jednostka': jednostka.opis,
      'azot_kg_ha': nawoz.azotKgNaHa(dawka, jednostka),
      'naturalny': nawoz.naturalny ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    return id;
  }

  /// Wpisy nawożenia z danego sezonu, od najnowszego.
  Future<List<WpisNawozenia>> wpisy(String gospodarstwoId, {int? sezon}) async {
    final warunki = <String>['z.gospodarstwo_id = ?', 'z.usuniety = 0'];
    final argumenty = <Object?>[gospodarstwoId];
    if (sezon != null) {
      warunki.add("strftime('%Y', z.data) = ?");
      argumenty.add('$sezon');
    }

    final wiersze = await baza.rawQuery('''
      SELECT n.*, z.data, z.powierzchnia_ar
      FROM zabieg_nawozenie n
      JOIN zabieg z ON z.id = n.zabieg_id
      WHERE ${warunki.join(' AND ')}
      ORDER BY z.data DESC
    ''', argumenty);
    return wiersze.map(WpisNawozenia.zBazy).toList(growable: false);
  }

  /// Stan limitu azotu z nawozów naturalnych w danym sezonie.
  Future<StanLimituAzotu> limitAzotu({
    required String gospodarstwoId,
    required double powierzchniaUrHa,
    int? sezon,
  }) async {
    final rok = sezon ?? DateTime.now().year;
    final wszystkie = await wpisy(gospodarstwoId, sezon: rok);
    final naturalne = wszystkie.where((w) => w.naturalny);

    var azot = 0.0;
    var bezAzotu = 0;
    for (final wpis in naturalne) {
      final razem = wpis.azotKgRazem;
      if (razem == null) {
        bezAzotu++;
        continue;
      }
      azot += razem;
    }

    final limit = reguly.obowiazek(idObowiazku)?.limit(idLimitu);
    return StanLimituAzotu(
      sezon: rok,
      powierzchniaUrHa: powierzchniaUrHa,
      azotNaturalnyKg: azot,
      limitKgNaHa: limit?.wartosc ?? 0,
      wpisyBezAzotu: bezAzotu,
      limitZnany: limit != null,
    );
  }
}
