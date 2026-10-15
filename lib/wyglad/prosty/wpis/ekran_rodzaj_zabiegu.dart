import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_wybor_srodka.dart';

/// Krok 2: co robimy na tym polu. Kafelki, jedna decyzja na ekranie.
class EkranRodzajZabiegu extends StatelessWidget {
  const EkranRodzajZabiegu({
    super.key,
    required this.uslugi,
    required this.dane,
  });

  final Uslugi uslugi;
  final DaneWpisu dane;

  static const List<(RodzajZabiegu, IconData)> _rodzaje = [
    (RodzajZabiegu.oprysk, Icons.water_drop_outlined),
    (RodzajZabiegu.nawozenie, Icons.grass_outlined),
    (RodzajZabiegu.siew, Icons.scatter_plot_outlined),
    (RodzajZabiegu.zbior, Icons.agriculture_outlined),
    (RodzajZabiegu.uprawaGleby, Icons.landscape_outlined),
  ];

  void _wybierz(BuildContext context, RodzajZabiegu rodzaj) {
    dane.rodzaj = rodzaj;
    if (rodzaj == RodzajZabiegu.oprysk) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EkranWyborSrodka(uslugi: uslugi, dane: dane),
        ),
      );
      return;
    }
    // Pozostałe rodzaje zabiegów dojdą w kolejnych krokach etapu 1.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${rodzaj.dlaRolnika}: ta część jeszcze nie działa.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pole = dane.pola.first;
    return Scaffold(
      appBar: AppBar(title: Text(pole.nazwa)),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text(
            '${pole.uprawa} • ${pole.powierzchniaOpis}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MotywProsty.odstep),
          for (final (rodzaj, ikona) in _rodzaje) ...[
            DuzyPrzycisk(
              etykieta: rodzaj.dlaRolnika,
              ikona: ikona,
              wyrozniony: rodzaj == RodzajZabiegu.oprysk,
              onTap: () => _wybierz(context, rodzaj),
            ),
            const SizedBox(height: MotywProsty.odstep),
          ],
        ],
      ),
    );
  }
}
