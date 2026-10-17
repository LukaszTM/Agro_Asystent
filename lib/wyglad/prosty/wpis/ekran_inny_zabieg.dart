import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/warunkowosc/okres_legowy.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Siew, zbiór, uprawa gleby i inne prace — wpis bez środka i bez dawki.
///
/// Rejestr zabiegów agrotechnicznych obejmuje nie tylko oprysk i nawożenie.
/// Dzień zbioru potrzebuje też norma GAEC 6 (okrywa liczy się od zbioru),
/// więc bez tego wpisu aplikacja nie miałaby skąd go wziąć.
///
/// Przy pracy „inny" rolnik wybiera z listy, co robił — stąd aplikacja wie,
/// kiedy ostrzec o okresie lęgowym ptaków (GAEC 8), zamiast odgadywać
/// z uwag.
class EkranInnyZabieg extends StatefulWidget {
  const EkranInnyZabieg({super.key, required this.uslugi, required this.dane});

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranInnyZabieg> createState() => _EkranInnyZabiegState();
}

class _EkranInnyZabiegState extends State<EkranInnyZabieg> {
  PracaKrajobrazowa? _praca;
  bool _zapisuje = false;
  bool _zapisany = false;

  DaneWpisu get dane => widget.dane;

  OkresLegowy get okresLegowy => widget.uslugi.okresLegowy;

  bool get _pytacOPrace =>
      dane.rodzaj == RodzajZabiegu.inny && !okresLegowy.prace.pusta;

  bool get _gotowy => !_pytacOPrace || _praca != null;

  Future<void> _zapisz() async {
    if (_zapisuje || !_gotowy) {
      return;
    }
    setState(() => _zapisuje = true);
    final id = 'z-${dane.kiedy.microsecondsSinceEpoch}-${dane.pola.first.id}';
    await widget.uslugi.zabiegi.zapisz(
      zabieg: Zabieg(
        id: id,
        gospodarstwoId: dane.gospodarstwoId,
        rodzaj: dane.rodzaj ?? RodzajZabiegu.inny,
        data: dane.kiedy,
        godzina:
            '${dane.kiedy.hour.toString().padLeft(2, '0')}:'
            '${dane.kiedy.minute.toString().padLeft(2, '0')}',
        powierzchniaAr: dane.powierzchniaAr,
        uwagi: _praca?.nazwa,
        podrodzaj: _praca?.id,
        urzadzenie: dane.urzadzenie,
      ),
      pola: [
        for (final pole in dane.pola)
          PoleZabiegu(
            dzialkaRolnaId: pole.id,
            powierzchniaAr: pole.powierzchniaAr,
          ),
      ],
      teraz: dane.kiedy,
    );
    if (mounted) {
      setState(() {
        _zapisuje = false;
        _zapisany = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final rodzaj = dane.rodzaj ?? RodzajZabiegu.inny;
    final pole = dane.pola.first;
    final ostrzezenie = okresLegowy.ostrzezeniePrzedZapisem(
      idPracy: _praca?.id,
      kiedy: dane.kiedy,
    );

    return Scaffold(
      appBar: AppBar(title: Text(rodzaj.dlaRolnika)),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          if (_zapisany) ...[
            Text('Zabieg zapisany', style: teksty.headlineMedium),
            const SizedBox(height: MotywProsty.odstep),
            Text(
              '${rodzaj.dlaRolnika} na polu ${pole.nazwa}, '
              '${Daty.krotko(dane.kiedy)}.',
              style: teksty.bodyLarge,
            ),
            const SizedBox(height: MotywProsty.odstep),
            Text(
              'Wpis trafił do rejestru zabiegów agrotechnicznych. '
              'Możesz go poprawić albo cofnąć w rejestrze.',
              style: teksty.bodyMedium,
            ),
            const SizedBox(height: MotywProsty.odstep * 2),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).popUntil((trasa) => trasa.isFirst),
              child: const Text('Gotowe'),
            ),
          ] else ...[
            Text(
              '${pole.nazwa} • ${pole.powierzchniaOpis}',
              style: teksty.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Data: ${Daty.krotko(dane.kiedy)} — uzupełniona sama.',
              style: teksty.bodyLarge,
            ),
            const SizedBox(height: MotywProsty.odstep),
            if (_pytacOPrace) ...[
              Text('Co robisz?', style: teksty.titleLarge),
              const SizedBox(height: 8),
              for (final praca in okresLegowy.prace.prace) ...[
                DuzyPrzycisk(
                  etykieta: praca.nazwa,
                  opis: praca.id == _praca?.id ? 'wybrane' : praca.opis,
                  ikona: praca.id == _praca?.id
                      ? Icons.check_circle_outline
                      : Icons.circle_outlined,
                  wyrozniony: praca.id == _praca?.id,
                  onTap: () => setState(() => _praca = praca),
                ),
                const SizedBox(height: 10),
              ],
            ],
            if (ostrzezenie != null) ...[
              const SizedBox(height: 8),
              Ostrzezenie(
                tresc: ostrzezenie.tresc,
                coZrobic: ostrzezenie.coZrobic,
              ),
            ],
            const SizedBox(height: MotywProsty.odstep * 2),
            if (_zapisuje)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton(
                onPressed: _gotowy ? _zapisz : null,
                child: const Text('Zapisz'),
              ),
            if (!_gotowy) ...[
              const SizedBox(height: 8),
              Text('Wybierz z listy, co robisz.', style: teksty.bodyMedium),
            ],
          ],
        ],
      ),
    );
  }
}
