import 'dart:convert';

/// Wariant gminny granicznego terminu stosowania nawozów azotowych.
///
/// Program azotanowy daje jedną datę domyślną dla gruntów ornych, ale dla
/// części gmin — wymienionych w załącznikach do rozporządzenia — jest ona
/// inna. Wykazy są danymi (`assets/dane/gminy_terminy_azotowe.json`),
/// a nie listą w kodzie.
class WariantGminny {
  const WariantGminny({
    required this.id,
    required this.dataRoczna,
    required this.zrodlo,
    required this.opis,
    required this.gminy,
  });

  final String id;

  /// „MM-DD" — graniczny dzień dla gmin z tego wykazu.
  final String dataRoczna;

  final String zrodlo;
  final String opis;

  /// Siedmiocyfrowe identyfikatory TERYT gmin.
  final Set<String> gminy;

  static WariantGminny zJson(Map<String, dynamic> json) => WariantGminny(
    id: json['id'] as String,
    dataRoczna: json['data_roczna'] as String,
    zrodlo: json['zrodlo'] as String? ?? '',
    opis: json['opis'] as String? ?? '',
    gminy: ((json['gminy'] as List<dynamic>?) ?? const [])
        .map((g) => g as String)
        .toSet(),
  );
}

/// Wykazy gmin z załączników do programu azotanowego.
class SlownikGminTerminow {
  const SlownikGminTerminow({
    required this.wersja,
    required this.zrodlo,
    required this.statusWeryfikacji,
    required this.warianty,
  });

  static const SlownikGminTerminow pusty = SlownikGminTerminow(
    wersja: '',
    zrodlo: '',
    statusWeryfikacji: 'brak',
    warianty: [],
  );

  factory SlownikGminTerminow.zTekstuJson(String tekst) =>
      SlownikGminTerminow.zJson(jsonDecode(tekst) as Map<String, dynamic>);

  factory SlownikGminTerminow.zJson(Map<String, dynamic> json) =>
      SlownikGminTerminow(
        wersja: json['wersja'] as String? ?? '',
        zrodlo: json['zrodlo'] as String? ?? '',
        statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
        warianty: ((json['warianty'] as List<dynamic>?) ?? const [])
            .map((w) => WariantGminny.zJson(w as Map<String, dynamic>))
            .toList(growable: false),
      );

  final String wersja;
  final String zrodlo;
  final String statusWeryfikacji;
  final List<WariantGminny> warianty;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  /// Wariant dla gminy albo `null`, gdy gmina ma termin domyślny.
  WariantGminny? dlaGminy(String kodGminy) {
    for (final wariant in warianty) {
      if (wariant.gminy.contains(kodGminy)) {
        return wariant;
      }
    }
    return null;
  }

  /// Kod gminy z identyfikatora działki ewidencyjnej.
  ///
  /// Identyfikator ma postać `061506_2.0007.138`: sześć cyfr gminy, znak
  /// podkreślenia, cyfra rodzaju gminy. Kod TERYT to te siedem cyfr razem.
  /// Zwraca `null`, gdy identyfikator ma inny kształt — wtedy nie zgadujemy.
  static String? kodGminy(String identyfikatorDzialki) {
    final dopasowanie = RegExp(r'^(\d{6})_(\d)')
        .firstMatch(identyfikatorDzialki.trim());
    if (dopasowanie == null) {
      return null;
    }
    return '${dopasowanie.group(1)}${dopasowanie.group(2)}';
  }
}
