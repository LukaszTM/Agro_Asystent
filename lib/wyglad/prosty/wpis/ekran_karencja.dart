import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/wybor_liczby.dart';

/// Karencja przy wpisie: potwierdzenie tej z bazy etykiet albo przepisanie
/// jej z opakowania (krok 8 etapu 1).
///
/// Baza etykiet z zadania P2 podaje karencję dla 84,5% środków. Dla reszty
/// **nie zgadujemy** — rolnik przepisuje liczbę z opakowania i wtedy to on
/// jest źródłem.
class EkranKarencja extends StatefulWidget {
  const EkranKarencja({
    super.key,
    required this.uslugi,
    required this.zabiegId,
    required this.dataZabiegu,
    required this.srodekNazwa,
    this.dniZEtykiety,
    this.dataEtykiety,
  });

  final Uslugi uslugi;
  final String zabiegId;
  final DateTime dataZabiegu;
  final String srodekNazwa;

  /// Karencja znaleziona w bazie etykiet — `null`, gdy jej nie znamy.
  final int? dniZEtykiety;

  final String? dataEtykiety;

  @override
  State<EkranKarencja> createState() => _EkranKarencjaState();
}

class _EkranKarencjaState extends State<EkranKarencja> {
  late double _dni = (widget.dniZEtykiety ?? 0).toDouble();
  bool _zapisuje = false;

  bool get _zEtykiety => widget.dniZEtykiety != null;

  DateTime get _dzienZbioru =>
      widget.dataZabiegu.add(Duration(days: _dni.round()));

  static String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}.${data.year}';

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);
    await widget.uslugi.zabiegi.zapiszKarencje(
      zabiegId: widget.zabiegId,
      dni: _dni.round(),
      // Rolnik potwierdził albo przepisał — w obu razach to jego decyzja.
      zrodlo: _zEtykiety && _dni.round() == widget.dniZEtykiety
          ? 'etykieta MRiRW, potwierdzona przez rolnika'
          : 'opakowanie, wpisane przez rolnika',
      potwierdzona: true,
      dataEtykiety: widget.dataEtykiety,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_zEtykiety ? 'Potwierdź karencję' : 'Wpisz karencję'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text(
            widget.srodekNazwa,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: MotywProsty.odstep),
          if (_zEtykiety)
            Ostrzezenie(
              tresc: 'Baza etykiet podaje ${widget.dniZEtykiety} dni karencji.',
              coZrobic: widget.dataEtykiety == null
                  ? 'Sprawdź opakowanie — jeśli jest inaczej, popraw liczbę.'
                  : 'Z etykiety z ${widget.dataEtykiety}. Sprawdź opakowanie — '
                        'Twoje mogło być wydane wcześniej.',
            )
          else
            const Ostrzezenie(
              tresc: 'Karencji tego środka nie ma w bazie etykiet.',
              coZrobic:
                  'Przepisz ją z opakowania — bez niej nie policzymy '
                  'dnia zbioru.',
            ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Karencja', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          WyborLiczby(
            wartosc: _dni,
            jednostka: 'dni',
            krok: 1,
            minimum: 0,
            maksimum: 365,
            onZmiana: (nowa) => setState(() => _dni = nowa),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text(
            _dni.round() == 0
                ? 'Zero dni znaczy: karencja nie obowiązuje.'
                : 'Zbiór najwcześniej ${_dzien(_dzienZbioru)}.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: Text(_zEtykiety ? 'Potwierdź' : 'Zapisz karencję'),
          ),
        ],
      ),
    );
  }
}
