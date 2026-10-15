import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/reguly/regula_prawna.dart';

/// Rodzaj zdarzenia w życiu zwierzęcia. Nazwy w bazie są stałe, etykiety
/// dla rolnika potoczne.
enum RodzajZdarzenia {
  urodzenie('urodzenie', 'Urodzenie'),
  kupno('kupno', 'Kupno'),
  sprzedaz('sprzedaz', 'Sprzedaż'),
  padniecie('padniecie', 'Padnięcie'),
  ubojGospodarczy('uboj_gospodarczy', 'Ubój na własne potrzeby');

  const RodzajZdarzenia(this.wBazie, this.dlaRolnika);

  final String wBazie;
  final String dlaRolnika;

  /// Czy zwierzę po tym zdarzeniu nadal jest w gospodarstwie.
  bool get zostajeWStadzie =>
      this == RodzajZdarzenia.urodzenie || this == RodzajZdarzenia.kupno;

  static RodzajZdarzenia zBazy(String wartosc) =>
      RodzajZdarzenia.values.firstWhere(
        (r) => r.wBazie == wartosc,
        orElse: () => RodzajZdarzenia.kupno,
      );
}

/// Stado: grupa zwierząt jednego gatunku.
class Stado {
  const Stado({
    required this.id,
    required this.gospodarstwoId,
    required this.nazwa,
    required this.gatunek,
  });

  final String id;
  final String gospodarstwoId;
  final String nazwa;
  final String gatunek;

  static Stado zBazy(Map<String, Object?> w) => Stado(
    id: w['id']! as String,
    gospodarstwoId: w['gospodarstwo_id']! as String,
    nazwa: w['nazwa']! as String,
    gatunek: w['gatunek']! as String,
  );
}

/// Zwierzę w stadzie.
class Zwierze {
  const Zwierze({
    required this.id,
    required this.stadoId,
    this.numer,
    this.dataUrodzenia,
    this.plec,
    this.grupaDjp,
    this.wspolczynnikDjp,
  });

  final String id;
  final String stadoId;

  /// Numer kolczyka — przy zgłoszeniach do IRZplus jest najważniejszy.
  final String? numer;

  final DateTime? dataUrodzenia;
  final String? plec;

  /// Identyfikator grupy ze słownika reguł, np. „bydlo_krowa”.
  final String? grupaDjp;

  /// Współczynnik przepisany w chwili dodania zwierzęcia — gdy przepis się
  /// zmieni, stare wpisy zostają takie, jakie były.
  final double? wspolczynnikDjp;

  static Zwierze zBazy(Map<String, Object?> w) => Zwierze(
    id: w['id']! as String,
    stadoId: w['stado_id']! as String,
    numer: w['numer'] as String?,
    dataUrodzenia: w['data_urodzenia'] == null
        ? null
        : DateTime.tryParse(w['data_urodzenia']! as String),
    plec: w['plec'] as String?,
    grupaDjp: w['grupa_djp'] as String?,
    wspolczynnikDjp: (w['wspolczynnik_djp'] as num?)?.toDouble(),
  );
}

/// Zdarzenie zwierzęcia razem z informacją, czy zostało zgłoszone.
class ZdarzenieZwierzecia {
  const ZdarzenieZwierzecia({
    required this.id,
    required this.zwierzeId,
    required this.rodzaj,
    required this.data,
    this.zgloszono,
    this.numerZwierzecia,
  });

  final String id;
  final String zwierzeId;
  final RodzajZdarzenia rodzaj;
  final DateTime data;

  /// Dzień zgłoszenia do IRZplus — `null`, dopóki rolnik nie zgłosił.
  final DateTime? zgloszono;

  final String? numerZwierzecia;

  bool get zgloszone => zgloszono != null;

  static ZdarzenieZwierzecia zBazy(Map<String, Object?> w) =>
      ZdarzenieZwierzecia(
        id: w['id']! as String,
        zwierzeId: w['zwierze_id']! as String,
        rodzaj: RodzajZdarzenia.zBazy(w['rodzaj']! as String),
        data: DateTime.parse(w['data']! as String),
        zgloszono: w['zgloszono'] == null
            ? null
            : DateTime.tryParse(w['zgloszono']! as String),
        numerZwierzecia: w['numer'] as String?,
      );
}

/// Stan stada w DJP.
class StanDjp {
  const StanDjp({
    required this.djp,
    required this.sztuk,
    required this.bezWspolczynnika,
    required this.doWeryfikacji,
    required this.zrodlo,
  });

  final double djp;
  final int sztuk;

  /// Sztuki bez współczynnika — nie liczymy ich i mówimy o tym wprost.
  final int bezWspolczynnika;

  /// Współczynniki ze słownika nie są jeszcze sprawdzone w przepisie.
  final bool doWeryfikacji;

  final String zrodlo;

  bool get pewny => bezWspolczynnika == 0 && !doWeryfikacji;
}

/// Rejestr stada: zwierzęta, zdarzenia i przeliczenie na DJP.
class RepozytoriumStada {
  const RepozytoriumStada({required this.baza, required this.reguly});

  final DatabaseExecutor baza;
  final SlownikRegul reguly;

  Future<List<Stado>> stada(String gospodarstwoId) async {
    final wiersze = await baza.query(
      'stado',
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
      orderBy: 'nazwa',
    );
    return wiersze.map(Stado.zBazy).toList(growable: false);
  }

  Future<String> dodajStado({
    required String gospodarstwoId,
    required String nazwa,
    required String gatunek,
    required String urzadzenie,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final id = 'stado-${(teraz ?? DateTime.now()).microsecondsSinceEpoch}';
    await baza.insert('stado', {
      'id': id,
      'gospodarstwo_id': gospodarstwoId,
      'nazwa': nazwa,
      'gatunek': gatunek,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    });
    return id;
  }

  Future<List<Zwierze>> zwierzeta(String stadoId) async {
    final wiersze = await baza.query(
      'zwierze',
      where: 'stado_id = ? AND usuniety = 0',
      whereArgs: [stadoId],
      orderBy: 'numer',
    );
    return wiersze.map(Zwierze.zBazy).toList(growable: false);
  }

  /// Dodaje zwierzę razem ze zdarzeniem, od którego zaczyna się jego pobyt
  /// w gospodarstwie (urodzenie albo kupno) — bo od niego liczy się termin
  /// zgłoszenia do IRZplus.
  Future<String> dodajZwierze({
    required String stadoId,
    required RodzajZdarzenia zdarzenie,
    required String urzadzenie,
    String? numer,
    DateTime? dataUrodzenia,
    String? plec,
    String? grupaDjp,
    DateTime? dataZdarzenia,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final znacznik = (teraz ?? DateTime.now()).microsecondsSinceEpoch;
    final id = 'zwierze-$znacznik';
    final wspolczynnik = reguly.wspolczynnikiDjp.grupa(grupaDjp ?? '');

    await baza.insert('zwierze', {
      'id': id,
      'stado_id': stadoId,
      'numer': numer,
      'data_urodzenia': dataUrodzenia?.toIso8601String().split('T').first,
      'plec': plec,
      'grupa_djp': grupaDjp,
      'wspolczynnik_djp': wspolczynnik?.wspolczynnik,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    });

    await dodajZdarzenie(
      zwierzeId: id,
      rodzaj: zdarzenie,
      data: dataZdarzenia ?? dataUrodzenia ?? (teraz ?? DateTime.now()),
      urzadzenie: urzadzenie,
      teraz: teraz,
    );
    return id;
  }

  Future<String> dodajZdarzenie({
    required String zwierzeId,
    required RodzajZdarzenia rodzaj,
    required DateTime data,
    required String urzadzenie,
    DateTime? zgloszono,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final id =
        'zdarzenie-${(teraz ?? DateTime.now()).microsecondsSinceEpoch}'
        '-${rodzaj.wBazie}';
    await baza.insert('zdarzenie_zwierzecia', {
      'id': id,
      'zwierze_id': zwierzeId,
      'rodzaj': rodzaj.wBazie,
      'data': data.toIso8601String().split('T').first,
      'zgloszono': zgloszono?.toIso8601String().split('T').first,
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return id;
  }

  /// Oznacza zdarzenie jako zgłoszone do IRZplus.
  Future<void> oznaczZgloszone({
    required String zdarzenieId,
    required DateTime kiedy,
    required String urzadzenie,
  }) async {
    await baza.update(
      'zdarzenie_zwierzecia',
      {
        'zgloszono': kiedy.toIso8601String().split('T').first,
        'zmieniono': kiedy.toIso8601String(),
        'urzadzenie': urzadzenie,
      },
      where: 'id = ?',
      whereArgs: [zdarzenieId],
    );
  }

  /// Zdarzenia gospodarstwa, od najnowszego.
  Future<List<ZdarzenieZwierzecia>> zdarzenia(
    String gospodarstwoId, {
    RodzajZdarzenia? rodzaj,
    bool tylkoNiezgloszone = false,
  }) async {
    final warunki = <String>[
      's.gospodarstwo_id = ?',
      'z.usuniety = 0',
      'w.usuniety = 0',
    ];
    final argumenty = <Object?>[gospodarstwoId];
    if (rodzaj != null) {
      warunki.add('z.rodzaj = ?');
      argumenty.add(rodzaj.wBazie);
    }
    if (tylkoNiezgloszone) {
      warunki.add('z.zgloszono IS NULL');
    }

    final wiersze = await baza.rawQuery('''
      SELECT z.*, w.numer
      FROM zdarzenie_zwierzecia z
      JOIN zwierze w ON w.id = z.zwierze_id
      JOIN stado s ON s.id = w.stado_id
      WHERE ${warunki.join(' AND ')}
      ORDER BY z.data DESC
    ''', argumenty);
    return wiersze.map(ZdarzenieZwierzecia.zBazy).toList(growable: false);
  }

  /// Zwierzęta, które są w gospodarstwie teraz: mają zdarzenie wejścia
  /// i nie mają późniejszego zdarzenia wyjścia.
  Future<List<Zwierze>> wStadzie(String gospodarstwoId) async {
    final wiersze = await baza.rawQuery(
      '''
      SELECT w.*
      FROM zwierze w
      JOIN stado s ON s.id = w.stado_id
      WHERE s.gospodarstwo_id = ? AND w.usuniety = 0 AND s.usuniety = 0
        AND NOT EXISTS (
          SELECT 1 FROM zdarzenie_zwierzecia z
          WHERE z.zwierze_id = w.id AND z.usuniety = 0
            AND z.rodzaj IN ('sprzedaz', 'padniecie', 'uboj_gospodarczy')
        )
    ''',
      [gospodarstwoId],
    );
    return wiersze.map(Zwierze.zBazy).toList(growable: false);
  }

  /// Przelicza stado na DJP. Sztuki bez współczynnika są policzone osobno.
  Future<StanDjp> djp(String gospodarstwoId) async {
    final zwierzeta = await wStadzie(gospodarstwoId);
    var suma = 0.0;
    var bez = 0;
    for (final zwierze in zwierzeta) {
      final wspolczynnik = zwierze.wspolczynnikDjp;
      if (wspolczynnik == null) {
        bez++;
        continue;
      }
      suma += wspolczynnik;
    }
    final slownik = reguly.wspolczynnikiDjp;
    return StanDjp(
      djp: suma,
      sztuk: zwierzeta.length,
      bezWspolczynnika: bez,
      doWeryfikacji: slownik.doWeryfikacji,
      zrodlo: slownik.zrodlo,
    );
  }
}
