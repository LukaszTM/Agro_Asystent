import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/ewidencja_nawozenia.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Po zapisie nawożenia: potwierdzenie i stan limitu azotu — rolnik od razu
/// wie, ile mu jeszcze wolno.
class EkranZapisanoNawozenie extends StatefulWidget {
  const EkranZapisanoNawozenie({
    super.key,
    required this.uslugi,
    required this.dane,
  });

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranZapisanoNawozenie> createState() => _EkranZapisanoNawozenieState();
}

class _EkranZapisanoNawozenieState extends State<EkranZapisanoNawozenie> {
  late final Future<StanLimituAzotu> _limit = _policz();

  Future<StanLimituAzotu> _policz() async {
    final profil = await widget.uslugi.profil.policz(
      widget.uslugi.gospodarstwoId,
    );
    return widget.uslugi.nawozenie.limitAzotu(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      powierzchniaUrHa: profil.powierzchniaUrHa,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dane = widget.dane;
    final azot = dane.azotKgNaHa;

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
                  'Nawożenie zapisane',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            '${dane.nawoz?.nazwa ?? 'Nawóz'} • '
            '${dane.dawka?.toStringAsFixed(0) ?? '?'} ${dane.jednostkaDawki.opis} • '
            '${dane.powierzchniaOpis}',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          if (azot != null) ...[
            const SizedBox(height: 8),
            Text(
              'Azot: ${azot.toStringAsFixed(0)} kg N/ha',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          const SizedBox(height: MotywProsty.odstep),
          FutureBuilder<StanLimituAzotu>(
            future: _limit,
            builder: (context, stan) {
              if (!stan.hasData) {
                return const SizedBox.shrink();
              }
              final limit = stan.data!;
              if (!limit.limitZnany || !(dane.nawoz?.naturalny ?? false)) {
                return const SizedBox.shrink();
              }
              if (limit.przekroczony) {
                return const Ostrzezenie(
                  tresc: 'Limit azotu z nawozów naturalnych jest przekroczony.',
                  coZrobic: 'Nie stosuj więcej nawozów naturalnych w tym roku.',
                );
              }
              return Text(
                'Do limitu zostało ${limit.pozostaloKg.toStringAsFixed(0)} kg '
                'azotu na całe gospodarstwo.',
                style: Theme.of(context).textTheme.bodyLarge,
              );
            },
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
