import 'package:sqflite_common/sqlite_api.dart';

/// Dostęp do słowników dołączonych do aplikacji: środki ochrony roślin,
/// zastosowania, karencje, uprawy i kody EPPO.
///
/// Plik jest **tylko do odczytu** i wymienia się go w całości przy aktualizacji
/// danych (ADR-0004). Aplikacja pokazuje rolnikowi, z jakiej daty są dane.
class BazaSlownikow {
  const BazaSlownikow(this._baza);

  static const String nazwaPliku = 'slowniki.sqlite';

  final Database _baza;

  static Future<BazaSlownikow> otworz({
    required DatabaseFactory fabryka,
    required String sciezka,
  }) async {
    final baza = await fabryka.openDatabase(
      sciezka,
      options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
    );
    return BazaSlownikow(baza);
  }

  /// Z jakiej daty są dane, z których korzysta rolnik. Puste, gdy plik
  /// słowników pochodzi sprzed wprowadzenia tej tabeli — wtedy nie zgadujemy.
  Future<List<WersjaDanych>> wersje() async {
    final tabela = await _baza.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='zrodlo_danych'",
    );
    if (tabela.isEmpty) {
      return const [];
    }
    final wiersze = await _baza.rawQuery(
      'SELECT plik, licencja, data_pliku, data_importu FROM zrodlo_danych '
      'ORDER BY data_pliku DESC',
    );
    return wiersze
        .map(
          (w) => WersjaDanych(
            plik: w['plik'] as String? ?? '',
            licencja: w['licencja'] as String?,
            dataPliku: w['data_pliku'] as String?,
            dataImportu: w['data_importu'] as String?,
          ),
        )
        .toList(growable: false);
  }

  Future<void> zamknij() => _baza.close();
}

/// Opis jednego źródła danych w słownikach — do pokazania rolnikowi
/// i na wydrukach.
class WersjaDanych {
  const WersjaDanych({
    required this.plik,
    required this.licencja,
    required this.dataPliku,
    required this.dataImportu,
  });

  final String plik;
  final String? licencja;
  final String? dataPliku;
  final String? dataImportu;
}
