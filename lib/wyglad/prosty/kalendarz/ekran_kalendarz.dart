import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/biodynamika/biodynamika.dart';
import '../../../rdzen/wspolne/kalendarz_biodynamiczny.dart';
import '../motyw.dart';

/// Kalendarz biodynamiczny na telefonie — osobny ekran z kafelka
/// „Kalendarz". Sam kalendarz jest wspólny z komputerem (`rdzen/wspolne/`).
class EkranKalendarz extends StatelessWidget {
  const EkranKalendarz({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, od którego liczymy tydzień. W aplikacji „dzisiaj"; testy podają
  /// stałą datę.
  final DateTime? teraz;

  @override
  Widget build(BuildContext context) {
    final slownik = uslugi.biodynamika;
    final dzis = teraz ?? DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Kalendarz')),
      body: SafeArea(
        child: slownik == null
            ? Padding(
                padding: const EdgeInsets.all(MotywProsty.odstep),
                child: Text(
                  'Kalendarza nie udało się wczytać. Uruchom aplikację '
                  'jeszcze raz.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(MotywProsty.odstep),
                children: [
                  KalendarzBiodynamicznyWidok(
                    tydzien: KalendarzBiodynamiczny(slownik).tydzien(dzis),
                    miesiac: KalendarzBiodynamiczny(slownik)
                        .miesiac(dzis.year, dzis.month),
                    dzis: dzis,
                    zastrzezenie: slownik.zastrzezenie,
                    styl: MotywProsty.stylKalendarza,
                  ),
                ],
              ),
      ),
    );
  }
}
