import 'package:sqflite_common/sqlite_api.dart';

import 'rodzaj_uzytku.dart';

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
    this.rodzajUzytku = RodzajUzytku.nieznany,
  });

  final String id;
  final String gospodarstwoId;
  final String nazwa;
  final String uprawa;
  final int powierzchniaAr;
  final String? oznaczenieZWniosku;
  final String? kodEppo;
  final int? sezon;

  /// Grunty orne, trwały użytek zielony czy uprawa trwała — od tego zależą
  /// progi normy GAEC 7. [RodzajUzytku.nieznany] znaczy „rolnik jeszcze
  /// nie powiedział"; wtedy warunkowość pisze „do sprawdzenia".
  final RodzajUzytku rodzajUzytku;

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
    rodzajUzytku: RodzajUzytku.zBazy(w['rodzaj_uzytku'] as String?),
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

  /// Zmiana uprawy pola — co sezon rolnik sieje coś innego.
  ///
  /// Kod EPPO zapisujemy razem z uprawą, bo bierze się z wyboru rolnika
  /// (ze słownika albo z własnej nazwy — wtedy jest pusty). Poprzednią
  /// uprawę zapisuje wyzwalacz bazy, więc kontrola widzi, co było wcześniej.
  Future<void> zmienUprawe({
    required String poleId,
    required String uprawa,
    required String urzadzenie,
    String? kodEppo,
    int? sezon,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    await _baza.update(
      'dzialka_rolna',
      {
        'uprawa': uprawa,
        'kod_eppo': kodEppo,
        'sezon': ?sezon,
        'zmieniono': czas,
        'urzadzenie': urzadzenie,
      },
      where: 'id = ?',
      whereArgs: [poleId],
    );

    // Do historii upraw (z niej liczy się GAEC 7) wpisuje tę zmianę
    // wyzwalacz bazy `uprawa_pola_z_dzialki_zmiana` — tak samo jak przy
    // imporcie wniosku i scalaniu danych.
  }

  /// Rodzaj użytku ustawia **rolnik** — aplikacja go tylko podpowiada.
  Future<void> ustawRodzajUzytku({
    required String poleId,
    required RodzajUzytku rodzaj,
    required String urzadzenie,
    DateTime? teraz,
  }) => _baza.update(
    'dzialka_rolna',
    {
      'rodzaj_uzytku': rodzaj.wBazie,
      'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
      'urzadzenie': urzadzenie,
    },
    where: 'id = ?',
    whereArgs: [poleId],
  );

  /// Jedno pole — po zmianie uprawy ekran czyta je od nowa.
  Future<Pole?> jedno(String id) async {
    final wiersze = await _baza.query(
      'dzialka_rolna',
      where: 'id = ? AND usuniety = 0',
      whereArgs: [id],
      limit: 1,
    );
    return wiersze.isEmpty ? null : Pole.zBazy(wiersze.first);
  }

  /// Numery działek ewidencyjnych, na których leży to pole — z wniosku
  /// (jedna działka rolna leży zwykle na kilku ewidencyjnych).
  Future<List<String>> dzialkiReferencyjne(String poleId) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT de.identyfikator
      FROM dzialka_rolna_czesc c
      JOIN dzialka_ewidencyjna de ON de.id = c.dzialka_ewidencyjna_id
      WHERE c.dzialka_rolna_id = ?
      ORDER BY de.identyfikator
      ''',
      [poleId],
    );
    return [for (final wiersz in wiersze) wiersz['identyfikator'] as String];
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
      'rodzaj_uzytku': pole.rodzajUzytku.znany
          ? pole.rodzajUzytku.wBazie
          : null,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
