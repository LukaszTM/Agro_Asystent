import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_karencja.dart';

/// Po zapisie: potwierdzenie, karencja i lista dokumentów, do których wpis
/// trafił (plan, pkt 5).
class EkranZapisano extends StatefulWidget {
  const EkranZapisano({
    super.key,
    required this.dane,
    required this.zabieg,
    this.uslugi,
  });

  final DaneWpisu dane;
  final Zabieg zabieg;

  /// Potrzebne do zapisania karencji wpisanej ręcznie; `null` w podglądzie.
  final Uslugi? uslugi;

  @override
  State<EkranZapisano> createState() => _EkranZapisanoState();
}

class _EkranZapisanoState extends State<EkranZapisano> {
  /// Karencja po poprawce rolnika — `null`, dopóki jej nie ruszał.
  int? _karencjaOdRolnika;

  static const List<String> _dokumenty = [
    'Ewidencja zabiegów środkami ochrony roślin',
    'Rejestr zabiegów agrotechnicznych (ekoschematy)',
  ];

  DaneWpisu get dane => widget.dane;
  Zabieg get zabieg => widget.zabieg;

  Future<void> _ustawKarencje({int? dniZEtykiety, String? dataEtykiety}) async {
    final uslugi = widget.uslugi;
    if (uslugi == null) {
      return;
    }
    final zapisane = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranKarencja(
          uslugi: uslugi,
          zabiegId: zabieg.id,
          dataZabiegu: zabieg.data,
          srodekNazwa: dane.srodek?.nazwa ?? 'Środek',
          dniZEtykiety: dniZEtykiety,
          dataEtykiety: dataEtykiety,
        ),
      ),
    );
    if ((zapisane ?? false) && mounted) {
      final oprysk = await uslugi.zabiegi.szczegolyOprysku(zabieg.id);
      if (mounted) {
        setState(() => _karencjaOdRolnika = oprysk?.karencjaDni);
      }
    }
  }

  String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.${data.month.toString().padLeft(2, '0')}.${data.year}';

  @override
  Widget build(BuildContext context) {
    final srodek = dane.srodek;
    final karencjaDni =
        _karencjaOdRolnika ??
        (srodek != null && srodek.karencjaZnana ? srodek.karencjaDni : null);
    final mozeZapisac = widget.uslugi != null;

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
          if (mozeZapisac && !(srodek?.karencjaNieDotyczy ?? false)) ...[
            const SizedBox(height: MotywProsty.odstep),
            DuzyPrzycisk(
              etykieta: karencjaDni == null
                  ? 'Wpisz karencję z opakowania'
                  : 'Sprawdź karencję na opakowaniu',
              opis: karencjaDni == null
                  ? 'bez niej nie policzymy dnia zbioru'
                  : 'potwierdź albo popraw liczbę dni',
              ikona: Icons.event_available_outlined,
              onTap: () => _ustawKarencje(
                dniZEtykiety: srodek != null && srodek.karencjaZnana
                    ? srodek.karencjaDni
                    : null,
                dataEtykiety: srodek?.karencjaDataEtykiety,
              ),
            ),
          ],
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
