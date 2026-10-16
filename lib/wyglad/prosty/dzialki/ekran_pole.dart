import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/slownik_upraw.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_wybor_uprawy.dart';

/// Jedno pole: co na nim rośnie i jaki ma kod EPPO.
///
/// Uprawa zmienia się co sezon, a wpisy zabiegów zostają przy tym samym
/// polu — dlatego zmiana uprawy idzie do dziennika zmian, a kontrola widzi,
/// co było wcześniej.
class EkranPole extends StatefulWidget {
  const EkranPole({super.key, required this.uslugi, required this.pole});

  final Uslugi uslugi;
  final Pole pole;

  @override
  State<EkranPole> createState() => _EkranPoleState();
}

class _EkranPoleState extends State<EkranPole> {
  late Pole _pole = widget.pole;
  bool _zmienione = false;
  bool _pracuje = false;

  Future<void> _zmienUprawe() async {
    if (_pracuje) {
      return;
    }
    final wybrana = await Navigator.of(context).push<UprawaDoWyboru>(
      MaterialPageRoute<UprawaDoWyboru>(
        builder: (_) => EkranWyborUprawy(uslugi: widget.uslugi),
      ),
    );
    if (wybrana == null || !mounted) {
      return;
    }
    setState(() => _pracuje = true);
    await widget.uslugi.pola.zmienUprawe(
      poleId: _pole.id,
      uprawa: wybrana.nazwa,
      kodEppo: wybrana.kodEppo,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    final swieze = await widget.uslugi.pola.jedno(_pole.id);
    if (!mounted) {
      return;
    }
    setState(() {
      _pole = swieze ?? _pole;
      _zmienione = true;
      _pracuje = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Zmieniono uprawę na „${wybrana.nazwa}". Poprzednia została '
          'w dzienniku zmian.',
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: MotywProsty.powierzchnia),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (juzZdjety, _) {
        if (!juzZdjety) {
          Navigator.of(context).pop(_zmienione);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_pole.nazwa)),
        body: ListView(
          padding: const EdgeInsets.all(MotywProsty.odstep),
          children: [
            Text('Uprawa', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _pole.uprawa.isEmpty ? 'nie podano' : _pole.uprawa,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _pole.kodEppo == null
                  ? 'Kod EPPO: brak — w ewidencji wyjdzie „brak"'
                  : 'Kod EPPO: ${_pole.kodEppo}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: MotywProsty.odstep),
            Text(
              'Powierzchnia: ${_pole.powierzchniaOpis}'
              '${_pole.sezon == null ? '' : ' • sezon ${_pole.sezon}'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: MotywProsty.odstep * 2),
            if (_pracuje)
              const Center(child: CircularProgressIndicator())
            else
              DuzyPrzycisk(
                etykieta: 'Zmień uprawę',
                opis: 'po zbiorze albo gdy wpisałeś coś innego',
                ikona: Icons.grass_outlined,
                wyrozniony: true,
                onTap: _zmienUprawe,
              ),
            const SizedBox(height: MotywProsty.odstep),
            Text(
              'Zabiegi zapisane na tym polu zostają bez zmian. Zmiana '
              'uprawy nie wpływa na to, co już wpisałeś.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
