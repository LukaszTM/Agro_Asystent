import 'package:sqflite_common/sqlite_api.dart';

/// Środek ochrony roślin dopuszczony do danej uprawy, wraz z dawką i karencją.
///
/// To, co widać na ekranie wyboru środka: nazwa, przeciw czemu, ile i jak długo
/// czekać do zbioru.
class DopuszczonySrodek {
  const DopuszczonySrodek({
    required this.srodekId,
    required this.nazwa,
    required this.nrZezwolenia,
    required this.zastosowanieId,
    this.rodzaj,
    this.agrofag,
    this.dawka,
    this.dawkaJednostka,
    this.dawkaOdniesienie,
    this.dawkaTekst,
    this.dawkaPewnosc = 'do_sprawdzenia',
    this.bbchOd,
    this.bbchDo,
    this.karencjaDni,
    this.karencjaStan,
    this.karencjaDataEtykiety,
    this.terminDoStosowania,
  });

  final int srodekId;
  final String nazwa;
  final String nrZezwolenia;
  final int zastosowanieId;
  final String? rodzaj;
  final String? agrofag;
  final double? dawka;
  final String? dawkaJednostka;
  final String? dawkaOdniesienie;
  final String? dawkaTekst;
  final String dawkaPewnosc;
  final int? bbchOd;
  final int? bbchDo;
  final int? karencjaDni;
  final String? karencjaStan;
  final String? karencjaDataEtykiety;

  /// Do kiedy wolno stosować środek wycofany z obrotu (rejestr MRiRW).
  /// `null` znaczy „rejestr nic o tym nie mówi", nie „bez ograniczeń".
  final String? terminDoStosowania;

  /// Czy dawkę można podpowiedzieć rolnikowi jako gotową liczbę.
  bool get dawkaZnana => dawka != null && dawkaPewnosc != 'do_sprawdzenia';

  /// Czy karencja jest znana i wyrażona w dniach.
  bool get karencjaZnana => karencjaStan == 'dni' && karencjaDni != null;

  /// Czy etykieta mówi wprost, że karencja nie obowiązuje.
  bool get karencjaNieDotyczy => karencjaStan == 'nie_dotyczy';

  String get dawkaOpis {
    if (!dawkaZnana) {
      return 'dawka do sprawdzenia na etykiecie';
    }
    final liczba = dawka!
        .toStringAsFixed(dawka! % 1 == 0 ? 0 : 2)
        .replaceAll('.', ',');
    return '$liczba $dawkaJednostka/$dawkaOdniesienie';
  }
}

/// Czyta słowniki dołączone do aplikacji: które środki wolno zastosować
/// na danej uprawie, w jakiej dawce i z jaką karencją.
class SlownikSrodkow {
  const SlownikSrodkow(this._baza);

  final DatabaseExecutor _baza;

  static const String _zapytanie = '''
    SELECT s.id AS srodek_id, s.nazwa, s.nr_zezwolenia, s.rodzaj,
           z.id AS zastosowanie_id, z.agrofag, z.dawka_wartosc, z.dawka_jednostka,
           z.dawka_odniesienie, z.dawka_tekst, z.dawka_pewnosc, z.bbch_od, z.bbch_do,
           s.termin_do_stosowania,
           k.dni AS karencja_dni, k.stan AS karencja_stan, k.data_etykiety
    FROM zastosowanie_uprawa zu
    JOIN zastosowanie z ON z.id = zu.zastosowanie_id
    JOIN srodek s       ON s.id = z.srodek_id
    LEFT JOIN karencja k ON k.srodek_nazwa = s.nazwa
                        AND (k.uprawa = zu.uprawa OR k.uprawa IS NULL)
    WHERE zu.uprawa = ?
  ''';

  /// Środki dopuszczone na danej uprawie. Pusta lista oznacza, że rejestr nic
  /// nie przewiduje — i tak trzeba to pokazać rolnikowi, zamiast udawać.
  Future<List<DopuszczonySrodek>> dlaUprawy(
    String uprawa, {
    int limit = 300,
  }) async {
    final wiersze = await _baza.rawQuery(
      '$_zapytanie ORDER BY s.nazwa LIMIT ?',
      [uprawa, limit],
    );
    return wiersze.map(_zWiersza).toList(growable: false);
  }

  /// Szukanie po nazwie w obrębie uprawy — rolnik zwykle wie, czym opryskuje.
  Future<List<DopuszczonySrodek>> szukaj(
    String uprawa,
    String fragment, {
    int limit = 100,
  }) async {
    final wiersze = await _baza.rawQuery(
      '$_zapytanie AND s.nazwa LIKE ? ORDER BY s.nazwa LIMIT ?',
      [uprawa, '%$fragment%', limit],
    );
    return wiersze.map(_zWiersza).toList(growable: false);
  }

  /// Do kiedy wolno stosować ten środek — z rejestru MRiRW.
  ///
  /// `null` znaczy „rejestr nie podaje terminu" (albo nie zna tego
  /// środka), a nie „wolno bez końca". Magazyn używa tego, żeby ostrzec
  /// o zapasie, którego nie wolno już wylać na pole.
  Future<DateTime?> terminDoStosowania(String nazwa) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT termin_do_stosowania FROM srodek
      WHERE nazwa = ? AND termin_do_stosowania IS NOT NULL
      ORDER BY termin_do_stosowania LIMIT 1
      ''',
      [nazwa],
    );
    if (wiersze.isEmpty) {
      return null;
    }
    return DateTime.tryParse(wiersze.first['termin_do_stosowania'] as String);
  }

  /// Uprawy, dla których rejestr cokolwiek przewiduje.
  Future<List<String>> uprawy() async {
    final wiersze = await _baza.rawQuery(
      'SELECT nazwa FROM uprawa ORDER BY nazwa',
    );
    return wiersze.map((w) => w['nazwa']! as String).toList(growable: false);
  }

  Future<String?> kodEppo(String uprawa) async {
    final wiersze = await _baza.rawQuery(
      'SELECT kod_eppo FROM uprawa WHERE nazwa = ? LIMIT 1',
      [uprawa],
    );
    return wiersze.isEmpty ? null : wiersze.first['kod_eppo'] as String?;
  }

  static DopuszczonySrodek _zWiersza(Map<String, Object?> w) =>
      DopuszczonySrodek(
        srodekId: w['srodek_id']! as int,
        nazwa: w['nazwa']! as String,
        nrZezwolenia: w['nr_zezwolenia']! as String,
        zastosowanieId: w['zastosowanie_id']! as int,
        rodzaj: w['rodzaj'] as String?,
        agrofag: w['agrofag'] as String?,
        dawka: (w['dawka_wartosc'] as num?)?.toDouble(),
        dawkaJednostka: w['dawka_jednostka'] as String?,
        dawkaOdniesienie: w['dawka_odniesienie'] as String?,
        dawkaTekst: w['dawka_tekst'] as String?,
        dawkaPewnosc: (w['dawka_pewnosc'] as String?) ?? 'do_sprawdzenia',
        bbchOd: w['bbch_od'] as int?,
        bbchDo: w['bbch_do'] as int?,
        terminDoStosowania: w['termin_do_stosowania'] as String?,
        karencjaDni: w['karencja_dni'] as int?,
        karencjaStan: w['karencja_stan'] as String?,
        karencjaDataEtykiety: w['data_etykiety'] as String?,
      );
}
