import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dokumenty/dokument_ewidencji.dart';
import '../../../funkcje/warunkowosc/przeglad.dart';
import '../../../funkcje/warunkowosc/wydruk_warunkowosci.dart';
import '../../../funkcje/warunkowosc/zmianowanie.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Warunkowość: stan każdej normy GAEC i jedno zdanie, co z tym zrobić.
///
/// Wszystko, co tu stoi, policzyły silniki z `lib/funkcje/warunkowosc/`.
/// Normy, których aplikacja nie policzy, mówią o tym wprost — nigdy nie
/// piszemy „spełniona" z braku danych.
class EkranWarunkowosc extends StatefulWidget {
  const EkranWarunkowosc({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, od którego liczymy sezon. W aplikacji „dzisiaj"; testy podają
  /// stałą datę.
  final DateTime? teraz;

  @override
  State<EkranWarunkowosc> createState() => _EkranWarunkowoscState();
}

class _EkranWarunkowoscState extends State<EkranWarunkowosc> {
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

  DokumentEwidencji? _dokument(List<StanNormy> stany) =>
      WydrukWarunkowosci.zbuduj(
        stany: stany,
        reguly: widget.uslugi.reguly,
        gospodarstwo: widget.uslugi.nazwaGospodarstwa,
        rok: _rok,
      );

  /// Wydruk i eksport są zawsze darmowe (plan, pkt 8) — nie ma tu pytania
  /// o wersję płatną.
  Future<void> _zapisz(
    List<StanNormy> stany,
    Future<void> Function(DokumentEwidencji) co,
  ) async {
    if (_pracuje) {
      return;
    }
    final dokument = _dokument(stany);
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
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              Text('Normy GAEC w $_rok r.', style: teksty.titleLarge),
              const SizedBox(height: 8),
              Text(
                'To, co aplikacja umie policzyć z twoich wpisów. Reszta '
                'zależy od danych, które ma urząd — wtedy piszemy „do '
                'sprawdzenia", a nie „spełniona".',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywProsty.odstep),
              for (final stanNormy in stany) ...[
                _KartaNormy(stanNormy: stanNormy),
                const SizedBox(height: MotywProsty.odstep),
              ],
              const SizedBox(height: MotywProsty.odstep),
              Text('Na kontrolę', style: teksty.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Zestawienie wszystkich norm z tym, co aplikacja policzyła. '
                'Wydruk i eksport są darmowe.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywProsty.odstep),
              if (_pracuje)
                const Center(child: CircularProgressIndicator())
              else ...[
                DuzyPrzycisk(
                  etykieta: 'Wydrukuj PDF',
                  opis: 'cała tabela norm na jednej liście',
                  ikona: Icons.print_outlined,
                  wyrozniony: true,
                  onTap: () => _zapisz(stany, dokumenty.wydrukujPdf),
                ),
                const SizedBox(height: 10),
                DuzyPrzycisk(
                  etykieta: 'Zapisz PDF',
                  opis: 'plik do wysłania albo na pendrive',
                  ikona: Icons.picture_as_pdf_outlined,
                  onTap: () => _zapisz(stany, dokumenty.zapiszPdf),
                ),
                const SizedBox(height: 10),
                DuzyPrzycisk(
                  etykieta: 'Zapisz CSV',
                  opis: 'do arkusza kalkulacyjnego',
                  ikona: Icons.table_chart_outlined,
                  onTap: () => _zapisz(stany, dokumenty.zapiszCsv),
                ),
                const SizedBox(height: 10),
                DuzyPrzycisk(
                  etykieta: 'Zapisz XLSX',
                  opis: 'arkusz Excela',
                  ikona: Icons.grid_on_outlined,
                  onTap: () => _zapisz(stany, dokumenty.zapiszXlsx),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Jedna norma: numer, nazwa, stan i co z tym zrobić.
class _KartaNormy extends StatelessWidget {
  const _KartaNormy({required this.stanNormy});

  final StanNormy stanNormy;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final norma = stanNormy.norma;
    return Container(
      padding: const EdgeInsets.all(MotywProsty.odstep),
      decoration: BoxDecoration(
        color: MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_ikona(stanNormy.stan), size: 32, color: _kolor()),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${norma.numer}: ${norma.nazwa}',
                  style: teksty.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(stanNormy.stanDlaRolnika, style: teksty.headlineMedium),
          const SizedBox(height: 8),
          for (final zdanie in stanNormy.coWiemy) ...[
            Text(zdanie, style: teksty.bodyLarge),
            const SizedBox(height: 6),
          ],
          Text(stanNormy.coZrobic, style: teksty.bodyLarge),
          if (stanNormy.zwolnienia.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final zwolnienie in stanNormy.zwolnienia)
              Text(
                'Zwolnienie: ${zwolnienie.opis}'
                '${zwolnienie.doWeryfikacji ? ' (do potwierdzenia — '
                          '${zwolnienie.zrodlo})' : ''}',
                style: teksty.bodyMedium,
              ),
          ],
          const SizedBox(height: 8),
          Text(norma.opis, style: teksty.bodyMedium),
        ],
      ),
    );
  }

  /// Kolor i ikona mówią to samo co napis — na wydruku i dla osób, które
  /// nie rozróżniają kolorów, zostaje słowo.
  Color _kolor() => switch (stanNormy.stan) {
    StanWarunku.spelniony => MotywProsty.zielenAkcji,
    StanWarunku.niespelniony => MotywProsty.ostrzezenieObramowanie,
    _ => MotywProsty.tekst,
  };

  static IconData _ikona(StanWarunku stan) => switch (stan) {
    StanWarunku.spelniony => Icons.check_circle_outline,
    StanWarunku.niespelniony => Icons.error_outline,
    StanWarunku.nieDotyczy => Icons.remove_circle_outline,
    StanWarunku.doSprawdzenia => Icons.help_outline,
  };
}
