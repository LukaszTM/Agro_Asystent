import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dokumenty/dokument_ewidencji.dart';
import '../../../funkcje/warunkowosc/przeglad.dart';
import '../../../funkcje/warunkowosc/wydruk_warunkowosci.dart';
import '../../../funkcje/warunkowosc/zmianowanie.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

/// Warunkowość w wyglądzie nowoczesnym — te same zdania co w prostym,
/// bo liczą je silniki z `lib/funkcje/warunkowosc/`.
class EkranWarunkowoscNowoczesny extends StatefulWidget {
  const EkranWarunkowoscNowoczesny({
    super.key,
    required this.uslugi,
    this.teraz,
  });

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<EkranWarunkowoscNowoczesny> createState() =>
      _EkranWarunkowoscNowoczesnyState();
}

class _EkranWarunkowoscNowoczesnyState
    extends State<EkranWarunkowoscNowoczesny> {
  late Future<List<StanNormy>> _stany;
  bool _pracuje = false;

  int get _rok => (widget.teraz ?? DateTime.now()).year;

  @override
  void initState() {
    super.initState();
    _stany = widget.uslugi.przegladWarunkowosci.stany(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      sezon: _rok,
    );
  }

  /// Wydruk i eksport są zawsze darmowe (plan, pkt 8).
  Future<void> _zapisz(
    List<StanNormy> stany,
    Future<void> Function(DokumentEwidencji) co,
  ) async {
    if (_pracuje) {
      return;
    }
    final dokument = WydrukWarunkowosci.zbuduj(
      stany: stany,
      reguly: widget.uslugi.reguly,
      gospodarstwo: widget.uslugi.nazwaGospodarstwa,
      rok: _rok,
    );
    if (dokument == null) {
      return;
    }
    setState(() => _pracuje = true);
    try {
      await co(dokument);
    } finally {
      if (mounted) {
        setState(() => _pracuje = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final dokumenty = widget.uslugi.dokumenty;

    return Scaffold(
      appBar: AppBar(title: const Text('Warunkowość')),
      body: FutureBuilder<List<StanNormy>>(
        future: _stany,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stany = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywNowoczesny.odstep),
            children: [
              Text('Normy GAEC w $_rok r.', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Stan policzony z twoich wpisów. Czego aplikacja nie '
                'policzy, tego nie udaje — pisze „do sprawdzenia".',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywNowoczesny.odstep),
              for (final stanNormy in stany) ...[
                _KartaNormy(stanNormy: stanNormy),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: MotywNowoczesny.odstep),
              Text('Na kontrolę', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Zestawienie wszystkich norm — wydruk i eksport darmowe.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (_pracuje)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Wybor(
                      etykieta: 'Wydrukuj PDF',
                      ikona: Icons.print_outlined,
                      wybrany: false,
                      onTap: () => _zapisz(stany, dokumenty.wydrukujPdf),
                    ),
                    Wybor(
                      etykieta: 'Zapisz PDF',
                      ikona: Icons.picture_as_pdf_outlined,
                      wybrany: false,
                      onTap: () => _zapisz(stany, dokumenty.zapiszPdf),
                    ),
                    Wybor(
                      etykieta: 'CSV',
                      ikona: Icons.table_chart_outlined,
                      wybrany: false,
                      onTap: () => _zapisz(stany, dokumenty.zapiszCsv),
                    ),
                    Wybor(
                      etykieta: 'XLSX',
                      ikona: Icons.grid_on_outlined,
                      wybrany: false,
                      onTap: () => _zapisz(stany, dokumenty.zapiszXlsx),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _KartaNormy extends StatelessWidget {
  const _KartaNormy({required this.stanNormy});

  final StanNormy stanNormy;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final norma = stanNormy.norma;
    return Karta(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_ikona(stanNormy.stan), size: 20, color: _kolor()),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${norma.numer}: ${norma.nazwa}',
                  style: teksty.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(stanNormy.stanDlaRolnika, style: teksty.bodyLarge),
          const SizedBox(height: 4),
          for (final zdanie in stanNormy.coWiemy)
            Text(zdanie, style: teksty.bodyMedium),
          const SizedBox(height: 4),
          Text(stanNormy.coZrobic, style: teksty.bodyMedium),
        ],
      ),
    );
  }

  Color _kolor() => switch (stanNormy.stan) {
    StanWarunku.spelniony => MotywNowoczesny.zielen,
    StanWarunku.niespelniony => MotywNowoczesny.ostrzezenieObramowanie,
    _ => MotywNowoczesny.tekstPomocniczy,
  };

  static IconData _ikona(StanWarunku stan) => switch (stan) {
    StanWarunku.spelniony => Icons.check_circle_outline,
    StanWarunku.niespelniony => Icons.error_outline,
    StanWarunku.nieDotyczy => Icons.remove_circle_outline,
    StanWarunku.doSprawdzenia => Icons.help_outline,
  };
}
