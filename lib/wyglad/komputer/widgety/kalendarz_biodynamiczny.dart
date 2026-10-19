import 'package:flutter/material.dart';

import '../../../funkcje/biodynamika/biodynamika.dart';
import '../../../rdzen/wspolne/kalendarz_biodynamiczny.dart';
import '../motyw.dart';
import 'karta.dart';

/// Karta pulpitu z kalendarzem biodynamicznym. Sam kalendarz jest wspólny
/// z telefonem (`rdzen/wspolne/`); tu dostaje barwy programu i kartę.
class KalendarzBiodynamicznyKarta extends StatelessWidget {
  const KalendarzBiodynamicznyKarta({
    super.key,
    required this.tydzien,
    required this.miesiac,
    required this.dzis,
    required this.zastrzezenie,
  });

  final List<DzienBiodynamiczny> tydzien;
  final List<DzienBiodynamiczny> miesiac;
  final DateTime dzis;

  /// Zdanie ze słownika: czym ten kalendarz jest, a czym nie.
  final String zastrzezenie;

  @override
  Widget build(BuildContext context) {
    return KartaKomputer(
      child: KalendarzBiodynamicznyWidok(
        tydzien: tydzien,
        miesiac: miesiac,
        dzis: dzis,
        zastrzezenie: zastrzezenie,
        styl: MotywKomputer.stylKalendarza,
        tytul: 'Kalendarz biodynamiczny',
      ),
    );
  }
}
