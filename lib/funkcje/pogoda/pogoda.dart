import 'dart:convert';

import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/uslugi/geometria.dart';
import '../dzialki/repozytorium_dzialek.dart';

/// Pogoda o jednej godzinie.
class GodzinaPogody {
  const GodzinaPogody({
    required this.czas,
    required this.temperatura,
    required this.wiatr,
    this.porywy,
    this.wilgotnosc,
    this.zachmurzenie,
    this.opad,
    this.symbol,
  });

  factory GodzinaPogody.zJson(Map<String, dynamic> json) => GodzinaPogody(
    czas: DateTime.parse(json['czas'] as String),
    temperatura: (json['temperatura'] as num).toDouble(),
    wiatr: (json['wiatr'] as num).toDouble(),
    porywy: (json['porywy'] as num?)?.toDouble(),
    wilgotnosc: (json['wilgotnosc'] as num?)?.toDouble(),
    zachmurzenie: (json['zachmurzenie'] as num?)?.toDouble(),
    opad: (json['opad'] as num?)?.toDouble(),
    symbol: json['symbol'] as String?,
  );

  /// Czas lokalny urządzenia.
  final DateTime czas;

  /// Temperatura powietrza w stopniach Celsjusza.
  final double temperatura;

  /// Prędkość wiatru w metrach na sekundę.
  final double wiatr;

  final double? porywy;
  final double? wilgotnosc;
  final double? zachmurzenie;

  /// Opad w najbliższej godzinie, w milimetrach. `null` znaczy, że źródło
  /// nie podało tej wartości — nie wpisujemy zera (CLAUDE.md, reguła 5).
  final double? opad;

  final String? symbol;

  Map<String, dynamic> doJson() => {
    'czas': czas.toIso8601String(),
    'temperatura': temperatura,
    'wiatr': wiatr,
    if (porywy != null) 'porywy': porywy,
    if (wilgotnosc != null) 'wilgotnosc': wilgotnosc,
    if (zachmurzenie != null) 'zachmurzenie': zachmurzenie,
    if (opad != null) 'opad': opad,
    if (symbol != null) 'symbol': symbol,
  };

  String get temperaturaOpis => '${temperatura.round()}°C';

  String get wiatrOpis => '${wiatr.round()} m/s';

  String get opadOpis => opad == null
      ? 'brak danych'
      : '${opad!.toStringAsFixed(1).replaceAll('.', ',')} mm';
}

/// Pogoda jednego dnia, złożona z godzin.
class DzienPogody {
  const DzienPogody({required this.data, required this.godziny});

  final DateTime data;
  final List<GodzinaPogody> godziny;

  double get temperaturaMin =>
      godziny.map((g) => g.temperatura).reduce((a, b) => a < b ? a : b);

  double get temperaturaMax =>
      godziny.map((g) => g.temperatura).reduce((a, b) => a > b ? a : b);

  double get wiatrMax =>
      godziny.map((g) => g.wiatr).reduce((a, b) => a > b ? a : b);

  /// Suma opadu z godzin, które go podały. `null`, gdy nie podała żadna.
  double? get opadRazem {
    final zOpadem = godziny.where((g) => g.opad != null).toList();
    return zOpadem.isEmpty
        ? null
        : zOpadem.fold<double>(0, (suma, g) => suma + g.opad!);
  }

  /// Godzina najbliższa południu — od niej bierzemy obrazek dnia.
  GodzinaPogody get wPoludnie => godziny.reduce(
    (a, b) => (a.czas.hour - 12).abs() <= (b.czas.hour - 12).abs() ? a : b,
  );

  String get temperaturaOpis =>
      '${temperaturaMin.round()}° … ${temperaturaMax.round()}°C';

  String get opadOpis => opadRazem == null
      ? 'brak danych'
      : '${opadRazem!.toStringAsFixed(1).replaceAll('.', ',')} mm';
}

/// Prognoza dla jednego miejsca, z chwilą pobrania.
///
/// Chwila pobrania jest częścią danych, a nie ozdobą: bez internetu
/// pokazujemy ostatnią prognozę i mówimy wprost, z kiedy jest.
class Prognoza {
  const Prognoza({
    required this.pobrano,
    required this.szerokosc,
    required this.dlugosc,
    required this.godziny,
    required this.zrodlo,
  });

  factory Prognoza.zJson(Map<String, dynamic> json) => Prognoza(
    pobrano: DateTime.parse(json['pobrano'] as String),
    szerokosc: (json['szerokosc'] as num).toDouble(),
    dlugosc: (json['dlugosc'] as num).toDouble(),
    zrodlo: json['zrodlo'] as String,
    godziny: [
      for (final wpis in json['godziny'] as List<dynamic>)
        GodzinaPogody.zJson(wpis as Map<String, dynamic>),
    ],
  );

  final DateTime pobrano;
  final double szerokosc;
  final double dlugosc;
  final List<GodzinaPogody> godziny;

  /// Kto podaje dane — musi stać na ekranie (licencja CC BY 4.0).
  final String zrodlo;

  Map<String, dynamic> doJson() => {
    'pobrano': pobrano.toIso8601String(),
    'szerokosc': szerokosc,
    'dlugosc': dlugosc,
    'zrodlo': zrodlo,
    'godziny': [for (final godzina in godziny) godzina.doJson()],
  };

  /// Godziny pogrupowane w dni kalendarzowe.
  List<DzienPogody> get dni {
    final poDniach = <DateTime, List<GodzinaPogody>>{};
    for (final godzina in godziny) {
      final dzien = DateTime(
        godzina.czas.year,
        godzina.czas.month,
        godzina.czas.day,
      );
      poDniach.putIfAbsent(dzien, () => []).add(godzina);
    }
    final dni =
        poDniach.entries
            .map((wpis) => DzienPogody(data: wpis.key, godziny: wpis.value))
            .toList()
          ..sort((a, b) => a.data.compareTo(b.data));
    return dni;
  }

  /// Godziny od teraz w przód — przeszłości rolnikowi nie prognozujemy.
  List<GodzinaPogody> najblizszeGodziny(DateTime teraz, {int ile = 12}) =>
      godziny
          .where(
            (g) => !g.czas.isBefore(teraz.subtract(const Duration(hours: 1))),
          )
          .take(ile)
          .toList();

  bool starsza(DateTime teraz, {Duration niz = const Duration(hours: 3)}) =>
      teraz.difference(pobrano) > niz;
}

/// Gdzie leży gospodarstwo — liczone z granic działek, bez pytania rolnika
/// i bez wysyłania czegokolwiek do sieci.
abstract final class PolozenieGospodarstwa {
  /// Środek wszystkich działek z granicami. `null`, gdy żadna ich nie ma.
  static Punkt? zDzialek(List<DzialkaEwidencyjna> dzialki) {
    final srodki = <Punkt>[
      for (final dzialka in dzialki)
        if (dzialka.obrysy.isNotEmpty) Geometria.srodek(dzialka.obrysy.first),
    ];
    if (srodki.isEmpty) {
      return null;
    }
    final dlugosc =
        srodki.fold<double>(0, (suma, p) => suma + p.dlugosc) / srodki.length;
    final szerokosc =
        srodki.fold<double>(0, (suma, p) => suma + p.szerokosc) / srodki.length;
    return (dlugosc: dlugosc, szerokosc: szerokosc);
  }
}

/// Ostatnia prognoza zapisana na urządzeniu.
///
/// Pogoda nie jest dokumentacją gospodarstwa, więc nie jedzie w kopii
/// danych — na drugim urządzeniu pobierze się własna, a stara tylko
/// wprowadzałaby w błąd.
class RepozytoriumPogody {
  const RepozytoriumPogody(this._baza);

  final DatabaseExecutor _baza;

  Future<Prognoza?> ostatnia(String gospodarstwoId) async {
    final wiersze = await _baza.query(
      'pogoda_zapis',
      where: 'gospodarstwo_id = ?',
      whereArgs: [gospodarstwoId],
      limit: 1,
    );
    if (wiersze.isEmpty) {
      return null;
    }
    try {
      return Prognoza.zJson(
        jsonDecode(wiersze.first['dane_json']! as String)
            as Map<String, dynamic>,
      );
    } on Object {
      // Zapis z innej wersji programu — lepiej pobrać od nowa niż pokazać
      // połowę danych.
      return null;
    }
  }

  Future<void> zapisz({
    required String gospodarstwoId,
    required Prognoza prognoza,
  }) async {
    await _baza.insert('pogoda_zapis', {
      'gospodarstwo_id': gospodarstwoId,
      'pobrano': prognoza.pobrano.toIso8601String(),
      'szerokosc': prognoza.szerokosc,
      'dlugosc': prognoza.dlugosc,
      'dane_json': jsonEncode(prognoza.doJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
