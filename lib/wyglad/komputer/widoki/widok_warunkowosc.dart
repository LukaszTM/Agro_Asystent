import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dokumenty/dokument_ewidencji.dart';
import '../../../funkcje/warunkowosc/przeglad.dart';
import '../../../funkcje/warunkowosc/wydruk_warunkowosci.dart';
import '../../../funkcje/warunkowosc/zmianowanie.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';

/// Warunkowość: stan każdej normy GAEC i wydruk na kontrolę.
///
/// Stany liczą silniki z `funkcje/warunkowosc/`, a zdania stoją
/// w `przeglad.dart` — telefon, komputer i wydruk mówią to samo.
class WidokWarunkowoscKomputer extends StatefulWidget {
  const WidokWarunkowoscKomputer({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<WidokWarunkowoscKomputer> createState() =>
      _WidokWarunkowoscKomputerState();
}

class _WidokWarunkowoscKomputerState extends State<WidokWarunkowoscKomputer> {
  late Future<List<StanNormy>> _stany;
  bool _pracuje = false;
  String? _komunikat;

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
    String potwierdzenie,
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
    setState(() {
      _pracuje = true;
      _komunikat = null;
    });
    try {
      await co(dokument);
      if (mounted) {
        setState(() => _komunikat = potwierdzenie);
      }
    } finally {
      if (mounted) {
        setState(() => _pracuje = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dokumenty = widget.uslugi.dokumenty;
    return FutureBuilder<List<StanNormy>>(
      future: _stany,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stany = stan.data!;
        return ListView(
          children: [
            NaglowekWidoku(
              tytul: 'Normy GAEC w $_rok r.',
              opis:
                  'Stan policzony z twoich wpisów. Czego aplikacja nie '
                  'policzy, tego nie udaje — pisze „do sprawdzenia".',
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Tabela(
              kolumny: const [
                KolumnaTabeli('Norma'),
                KolumnaTabeli('Co mówi', udzial: 2),
                KolumnaTabeli('Stan'),
                KolumnaTabeli('Co zrobić', udzial: 3),
              ],
              wiersze: [
                for (final stanNormy in stany)
                  WierszTabeli(
                    wartosci: [
                      stanNormy.norma.numer,
                      stanNormy.norma.nazwa,
                      stanNormy.stanDlaRolnika,
                      stanNormy.coZrobic,
                    ],
                    wyrozniony: stanNormy.stan == StanWarunku.niespelniony,
                    podpis: stanNormy.coWiemy.isEmpty
                        ? null
                        : stanNormy.coWiemy.join(' '),
                  ),
              ],
            ),
            const SizedBox(height: MotywKomputer.odstep),
            KartaKomputer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Na kontrolę',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Zestawienie wszystkich norm z tym, co aplikacja '
                    'policzyła. Wydruk i eksport są darmowe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  if (_pracuje)
                    const Center(child: CircularProgressIndicator())
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _zapisz(
                            stany,
                            dokumenty.wydrukujPdf,
                            'Wydruk wysłany do drukarki.',
                          ),
                          icon: const Icon(Icons.print_outlined, size: 20),
                          label: const Text('Wydrukuj'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _zapisz(
                            stany,
                            dokumenty.zapiszPdf,
                            'Zapisano plik PDF.',
                          ),
                          icon: const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 20,
                          ),
                          label: const Text('Zapisz PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _zapisz(
                            stany,
                            dokumenty.zapiszCsv,
                            'Zapisano plik CSV.',
                          ),
                          icon: const Icon(
                            Icons.table_chart_outlined,
                            size: 20,
                          ),
                          label: const Text('Zapisz CSV'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _zapisz(
                            stany,
                            dokumenty.zapiszXlsx,
                            'Zapisano plik XLSX.',
                          ),
                          icon: const Icon(Icons.grid_on_outlined, size: 20),
                          label: const Text('Zapisz XLSX'),
                        ),
                      ],
                    ),
                  if (_komunikat case final String tekst) ...[
                    const SizedBox(height: MotywKomputer.odstep),
                    Text(tekst, style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
