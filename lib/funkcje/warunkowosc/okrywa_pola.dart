import 'package:sqflite_common/sqlite_api.dart';

/// Deklaracja okrywy ochronnej gleby dla jednego pola i sezonu (GAEC 6).
///
/// Formy okrywy nie da się wyczytać z uprawy w plonie głównym: po tej samej
/// pszenicy może zostać ściernisko, może stanąć międzyplon, a pole może być
/// zaorane. Dlatego **deklaruje ją rolnik**, a aplikacja tylko podpowiada
/// z wpisów. Brak wiersza znaczy „nie wiem", a nie „gleba odkryta".
class OkrywaPola {
  const OkrywaPola({
    required this.id,
    required this.poleId,
    required this.sezon,
    required this.forma,
    this.dataZbioru,
    this.przerwaDni,
    this.uwagi,
    this.zrodlo,
  });

  factory OkrywaPola.zBazy(Map<String, Object?> w) => OkrywaPola(
    id: w['id']! as String,
    poleId: w['dzialka_rolna_id']! as String,
    sezon: (w['sezon'] as num).toInt(),
    forma: (w['forma'] as String?) ?? '',
    dataZbioru: w['data_zbioru'] == null
        ? null
        : DateTime.parse(w['data_zbioru']! as String),
    przerwaDni: (w['przerwa_dni'] as num?)?.toInt(),
    uwagi: w['uwagi'] as String?,
    zrodlo: w['zrodlo'] as String?,
  );

  final String id;
  final String poleId;
  final int sezon;

  /// Identyfikator formy ze słownika reguł (`warunkowosc.formy_okrywy`).
  final String forma;

  /// Dzień zbioru plonu głównego — od niego przepis liczy okrywę.
  final DateTime? dataZbioru;

  /// Ile dni pole było bez okrywy (siew ozimin, międzyplonu).
  final int? przerwaDni;

  final String? uwagi;

  /// Skąd wiemy: `rolnik`, `podpowiedz potwierdzona`.
  final String? zrodlo;

  /// Identyfikator wyliczany, nie losowy: ta sama deklaracja z dwóch
  /// urządzeń trafia w jeden wiersz, więc scalanie danych nie robi z niej
  /// dwóch wpisów.
  static String identyfikator({required String poleId, required int sezon}) =>
      'ok-$poleId-$sezon';
}

/// Deklaracje okrywy ochronnej gleby.
class RepozytoriumOkrywyPola {
  const RepozytoriumOkrywyPola(this._baza);

  final DatabaseExecutor _baza;

  /// Deklaracja pola w danym sezonie albo `null`, gdy rolnik jej nie podał.
  Future<OkrywaPola?> dlaPola({
    required String poleId,
    required int sezon,
  }) async {
    final wiersze = await _baza.query(
      'okrywa_pola',
      where: 'dzialka_rolna_id = ? AND sezon = ? AND usuniety = 0',
      whereArgs: [poleId, sezon],
      limit: 1,
    );
    return wiersze.isEmpty ? null : OkrywaPola.zBazy(wiersze.single);
  }

  /// Wszystkie deklaracje pola, od najnowszego sezonu.
  Future<List<OkrywaPola>> historia(String poleId) async {
    final wiersze = await _baza.query(
      'okrywa_pola',
      where: 'dzialka_rolna_id = ? AND usuniety = 0',
      whereArgs: [poleId],
      orderBy: 'sezon DESC',
    );
    return wiersze.map(OkrywaPola.zBazy).toList(growable: false);
  }

  /// Deklaracje wszystkich pól gospodarstwa w danym sezonie.
  ///
  /// Zapytanie idzie przez `dzialka_rolna`, bo gospodarstwo wisi na polu,
  /// nie na deklaracji.
  Future<List<OkrywaPola>> wSezonie({
    required String gospodarstwoId,
    required int sezon,
  }) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT o.*
      FROM okrywa_pola o
      JOIN dzialka_rolna r ON r.id = o.dzialka_rolna_id
      WHERE r.gospodarstwo_id = ? AND r.usuniety = 0
        AND o.usuniety = 0 AND o.sezon = ?
      ''',
      [gospodarstwoId, sezon],
    );
    return wiersze.map(OkrywaPola.zBazy).toList(growable: false);
  }

  /// Dopisanie albo poprawienie deklaracji.
  ///
  /// Poprawka nie nadpisuje historii po cichu: wyzwalacz bazy zapisuje
  /// poprzednią treść do dziennika zmian.
  Future<void> zapisz({
    required String poleId,
    required int sezon,
    required String forma,
    required String urzadzenie,
    DateTime? dataZbioru,
    int? przerwaDni,
    String? uwagi,
    String zrodlo = 'rolnik',
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final id = OkrywaPola.identyfikator(poleId: poleId, sezon: sezon);
    final dzien = dataZbioru?.toIso8601String().split('T').first;
    final istnieje = await _baza.query(
      'okrywa_pola',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (istnieje.isEmpty) {
      await _baza.insert('okrywa_pola', {
        'id': id,
        'dzialka_rolna_id': poleId,
        'sezon': sezon,
        'forma': forma,
        'data_zbioru': dzien,
        'przerwa_dni': przerwaDni,
        'uwagi': uwagi,
        'zrodlo': zrodlo,
        'utworzono': czas,
        'zmieniono': czas,
        'urzadzenie': urzadzenie,
      });
      return;
    }
    await _baza.update(
      'okrywa_pola',
      {
        'forma': forma,
        'data_zbioru': dzien,
        'przerwa_dni': przerwaDni,
        'uwagi': uwagi,
        'zrodlo': zrodlo,
        'zmieniono': czas,
        'urzadzenie': urzadzenie,
        'usuniety': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cofnięcie deklaracji — wiersz zostaje w bazie ze śladem.
  Future<void> usun({
    required String poleId,
    required int sezon,
    required String urzadzenie,
    DateTime? teraz,
  }) => _baza.update(
    'okrywa_pola',
    {
      'usuniety': 1,
      'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
      'urzadzenie': urzadzenie,
    },
    where: 'id = ?',
    whereArgs: [OkrywaPola.identyfikator(poleId: poleId, sezon: sezon)],
  );

  /// Dzień zbioru plonu głównego z wpisów zabiegów — fakt, nie domysł.
  ///
  /// Gdy zbiorów w sezonie było kilka (podział pola, dwa pokosy), liczy
  /// się ostatni: od niego przepis mierzy okrywę.
  Future<DateTime?> dzienZbioruZWpisow({
    required String poleId,
    required int sezon,
  }) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT MAX(z.data) AS data
      FROM zabieg z
      JOIN zabieg_pole zp ON zp.zabieg_id = z.id
      WHERE zp.dzialka_rolna_id = ? AND z.typ = 'zbior'
        AND z.usuniety = 0 AND z.data LIKE ?
      ''',
      [poleId, '$sezon-%'],
    );
    final data = wiersze.single['data'] as String?;
    return data == null ? null : DateTime.parse(data);
  }

  /// Co rolnik zapisał po zbiorze — siewy i uprawa gleby z tego sezonu.
  ///
  /// Z tego powstaje **podpowiedź** formy okrywy; wybór zostaje przy
  /// rolniku.
  Future<List<String>> wpisyPoZbiorze({
    required String poleId,
    required int sezon,
    DateTime? odDnia,
  }) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT z.typ, z.uwagi, z.data
      FROM zabieg z
      JOIN zabieg_pole zp ON zp.zabieg_id = z.id
      WHERE zp.dzialka_rolna_id = ? AND z.usuniety = 0
        AND z.typ IN ('siew', 'uprawa_gleby')
        AND z.data LIKE ?
        AND z.data >= ?
      ORDER BY z.data
      ''',
      [
        poleId,
        '$sezon-%',
        odDnia?.toIso8601String().split('T').first ?? '$sezon-01-01',
      ],
    );
    return [
      for (final wiersz in wiersze)
        '${wiersz['typ']} ${(wiersz['uwagi'] as String?) ?? ''}'.trim(),
    ];
  }
}
