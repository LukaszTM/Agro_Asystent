import 'package:flutter/material.dart';

import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Po zapisie: potwierdzenie, karencja i lista dokumentów, do których wpis
/// trafił (plan, pkt 5).
class EkranZapisano extends StatelessWidget {
  const EkranZapisano({super.key, required this.dane, required this.zabieg});

  final DaneWpisu dane;
  final Zabieg zabieg;

  static const List<String> _dokumenty = [
    'Ewidencja zabiegów środkami ochrony roślin',
    'Rejestr zabiegów agrotechnicznych (ekoschematy)',
  ];

  String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';

  @override
  Widget build(BuildContext context) {
    final srodek = dane.srodek;
    final karencjaDni = srodek != null && srodek.karencjaZnana
        ? srodek.karencjaDni
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Zapisano')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                size: 48,
                color: MotywProsty.zielenAkcji,
              ),
              const SizedBox(width: MotywProsty.odstep),
              Expanded(
                child: Text(
                  'Zabieg zapisany',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            '${dane.pola.first.nazwa} • ${dane.powierzchniaOpis} • '
            '${_dzien(zabieg.data)}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MotywProsty.odstep),
          if (karencjaDni != null)
            Ostrzezenie(
              tresc:
                  'Karencja: $karencjaDni dni. '
                  'Zbiór najwcześniej ${_dzien(zabieg.data.add(Duration(days: karencjaDni)))}.',
              coZrobic: srodek?.karencjaDataEtykiety != null
                  ? 'Z etykiety z ${srodek!.karencjaDataEtykiety}. '
                        'Sprawdź opakowanie — mogło być wydane wcześniej.'
                  : null,
            )
          else if (srodek != null && srodek.karencjaNieDotyczy)
            Text(
              'Etykieta podaje: karencja nie dotyczy.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            const Ostrzezenie(
              tresc: 'Karencji nie znamy dla tego środka.',
              coZrobic: 'Sprawdź ją na etykiecie i dopisz do wpisu.',
            ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            'Wpis trafił do:',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final dokument in _dokumenty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 20)),
                  Expanded(
                    child: Text(
                      dokument,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).popUntil((trasa) => trasa.isFirst),
            child: const Text('Gotowe'),
          ),
        ],
      ),
    );
  }
}
