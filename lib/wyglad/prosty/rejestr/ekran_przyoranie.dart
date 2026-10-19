import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../../../rdzen/wspolne/wybor_przyorania.dart';
import '../motyw.dart';

/// Dopisanie daty przyorania nawozu naturalnego do istniejącego wpisu —
/// rolnik często przyoruje dzień, dwa po rozrzuceniu obornika.
///
/// Poprzednia wartość zostaje w dzienniku zmian.
class EkranPrzyoranie extends StatefulWidget {
  const EkranPrzyoranie({super.key, required this.uslugi, required this.wpis});

  final Uslugi uslugi;
  final WpisRejestru wpis;

  @override
  State<EkranPrzyoranie> createState() => _EkranPrzyoranieState();
}

class _EkranPrzyoranieState extends State<EkranPrzyoranie> {
  late DateTime? _data = widget.wpis.nawozenie?.dataPrzyorania;
  bool _zapisuje = false;

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);
    await widget.uslugi.nawozenie.zapiszPrzyoranie(
      zabiegId: widget.wpis.zabieg.id,
      data: _data,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Przyoranie')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text(
            widget.wpis.nawozenie?.nawozNazwa ?? 'Nawóz naturalny',
            style: teksty.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Kiedy nawóz został przyorany albo wymieszany z glebą?',
            style: teksty.bodyLarge,
          ),
          const SizedBox(height: MotywProsty.odstep),
          WyborPrzyorania(
            dzienZabiegu: widget.wpis.zabieg.data,
            wybrana: _data,
            onZmiana: (dzien) => setState(() => _data = dzien),
          ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: const Text('Zapisz'),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            'Poprzednia wartość zostaje w dzienniku zmian — kontrola widzi '
            'każdą poprawkę.',
            style: teksty.bodyMedium,
          ),
        ],
      ),
    );
  }
}
