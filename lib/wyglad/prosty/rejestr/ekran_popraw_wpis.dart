import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/wybor_liczby.dart';

/// Poprawka wpisu: dawka i godzina. „Każdy wpis da się cofnąć i poprawić"
/// (plan, pkt 5) — bez klawiatury, przyciskami „+" i „−".
///
/// Poprzednie wartości zostają w dzienniku zmian, więc poprawka jest jawna.
class EkranPoprawWpis extends StatefulWidget {
  const EkranPoprawWpis({super.key, required this.uslugi, required this.wpis});

  final Uslugi uslugi;
  final WpisRejestru wpis;

  @override
  State<EkranPoprawWpis> createState() => _EkranPoprawWpisState();
}

class _EkranPoprawWpisState extends State<EkranPoprawWpis> {
  /// Godzinę przesuwamy kwadransami — rolnik pamięta „około dziesiątej".
  static const int krokMinut = 15;

  late double? _dawka;
  late int _minuty;
  bool _zapisuje = false;

  @override
  void initState() {
    super.initState();
    _dawka = widget.wpis.oprysk?.dawka;
    _minuty = _zGodziny(widget.wpis.zabieg.godzina);
  }

  static int _zGodziny(String? godzina) {
    final czesci = (godzina ?? '').split(':');
    if (czesci.length != 2) {
      return 12 * 60;
    }
    final h = int.tryParse(czesci[0]) ?? 12;
    final m = int.tryParse(czesci[1]) ?? 0;
    return (h * 60 + m).clamp(0, 24 * 60 - 1);
  }

  String get _godzina =>
      '${(_minuty ~/ 60).toString().padLeft(2, '0')}:'
      '${(_minuty % 60).toString().padLeft(2, '0')}';

  void _przesunGodzine(int oMinut) {
    setState(() {
      _minuty = (_minuty + oMinut).clamp(0, 24 * 60 - 1);
    });
  }

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);
    await widget.uslugi.zabiegi.popraw(
      zabiegId: widget.wpis.zabieg.id,
      urzadzenie: widget.uslugi.urzadzenie,
      godzina: _godzina,
      dawka: _dawka,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final oprysk = widget.wpis.oprysk;
    final jednostka = [
      oprysk?.dawkaJednostka,
      oprysk?.dawkaOdniesienie,
    ].whereType<String>().join('/');

    return Scaffold(
      appBar: AppBar(title: const Text('Popraw wpis')),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text(
            oprysk?.srodekNazwa ?? widget.wpis.zabieg.rodzaj.dlaRolnika,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MotywProsty.odstep),
          if (_dawka case final double dawka) ...[
            Text('Dawka', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            WyborLiczby(
              wartosc: dawka,
              jednostka: jednostka.isEmpty ? 'na ha' : jednostka,
              krok: 0.05,
              onZmiana: (nowa) => setState(() => _dawka = nowa),
            ),
            const SizedBox(height: MotywProsty.odstep),
          ] else
            const Ostrzezenie(
              tresc: 'Ten wpis nie ma zapisanej dawki.',
              coZrobic:
                  'Dawkę trzeba dopisać ręcznie na wydruku '
                  'albo wpisać zabieg od nowa.',
            ),
          Text('Godzina', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              _PrzyciskGodziny(
                znak: '−',
                etykieta: 'Wcześniej o kwadrans',
                onTap: () => _przesunGodzine(-krokMinut),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _godzina,
                    style: Theme.of(context).textTheme.displayLarge,
                  ),
                ),
              ),
              _PrzyciskGodziny(
                znak: '+',
                etykieta: 'Później o kwadrans',
                onTap: () => _przesunGodzine(krokMinut),
              ),
            ],
          ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: const Text('Zapisz poprawkę'),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            'Poprzednia wartość zostaje w dzienniku zmian — kontrola widzi '
            'każdą poprawkę.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PrzyciskGodziny extends StatelessWidget {
  const _PrzyciskGodziny({
    required this.znak,
    required this.etykieta,
    required this.onTap,
  });

  final String znak;
  final String etykieta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etykieta,
      child: Material(
        color: MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          child: SizedBox(
            width: MotywProsty.minCelDotyku + 20,
            height: MotywProsty.minCelDotyku + 8,
            child: Center(
              child: Text(
                znak,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
