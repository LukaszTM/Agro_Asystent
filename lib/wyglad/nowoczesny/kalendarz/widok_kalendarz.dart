import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/biodynamika/biodynamika.dart';
import '../../../rdzen/wspolne/kalendarz_biodynamiczny.dart';
import '../motyw.dart';
import '../widgety/karta.dart';

/// Zakładka „Kalendarz" wyglądu nowoczesnego — kalendarz biodynamiczny.
/// Sam kalendarz jest wspólny z komputerem (`rdzen/wspolne/`).
class WidokKalendarz extends StatelessWidget {
  const WidokKalendarz({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, od którego liczymy tydzień. W aplikacji „dzisiaj"; testy podają
  /// stałą datę.
  final DateTime? teraz;

  @override
  Widget build(BuildContext context) {
    final slownik = uslugi.biodynamika;
    final dzis = teraz ?? DateTime.now();
    if (slownik == null) {
      return Padding(
        padding: const EdgeInsets.all(MotywNowoczesny.odstep),
        child: Text(
          'Kalendarza nie udało się wczytać. Uruchom aplikację jeszcze raz.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    final kalendarz = KalendarzBiodynamiczny(slownik);
    return ListView(
      padding: const EdgeInsets.all(MotywNowoczesny.odstep),
      children: [
        Karta(
          child: KalendarzBiodynamicznyWidok(
            tydzien: kalendarz.tydzien(dzis),
            miesiac: kalendarz.miesiac(dzis.year, dzis.month),
            dzis: dzis,
            zastrzezenie: slownik.zastrzezenie,
            styl: MotywNowoczesny.stylKalendarza,
          ),
        ),
      ],
    );
  }
}
