import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dokumenty/dokument_ewidencji.dart';
import '../../../funkcje/dokumenty/rodzaj_rejestru.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';

/// Zakładka „Dokumenty" wyglądu nowoczesnego: trzy rejestry, wybór okresu,
/// podgląd i trzy formaty na wyjście.
///
/// Wydruk i eksport są zawsze darmowe — dokumentacji nie zamykamy za opłatą
/// (plan, pkt 11).
class WidokDokumenty extends StatefulWidget {
  const WidokDokumenty({
    super.key,
    required this.uslugi,
    required this.onRejestr,
  });

  final Uslugi uslugi;

  /// Rejestr wpisów — tam rolnik uzupełnia braki przed wydrukiem.
  final VoidCallback onRejestr;

  @override
  State<WidokDokumenty> createState() => _WidokDokumentyState();
}

class _WidokDokumentyState extends State<WidokDokumenty> {
  late RodzajRejestru _rejestr;
  int? _rok;
  Future<DokumentEwidencji?>? _dokument;
  Future<List<int>>? _lata;
  bool _pracuje = false;

  @override
  void initState() {
    super.initState();
    _rejestr =
        widget.uslugi.dokumenty.dostepneRejestry.firstOrNull ??
        RodzajRejestru.ewidencjaSor;
    _lata = widget.uslugi.rejestr.lata(widget.uslugi.gospodarstwoId);
    _dokument = _zbuduj();
  }

  Future<DokumentEwidencji?> _zbuduj() async {
    final gospodarstwo = await widget.uslugi.gospodarstwa.jedno(
      widget.uslugi.gospodarstwoId,
    );
    return widget.uslugi.dokumenty.zbuduj(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      gospodarstwo: widget.uslugi.nazwaGospodarstwa,
      numerProducenta: gospodarstwo?.numerProducenta,
      wlasciciel: gospodarstwo?.wlasciciel,
      rejestrDokumentu: _rejestr,
      rok: _rok,
    );
  }

  void _odswiez() {
    setState(() {
      _dokument = _zbuduj();
    });
  }

  /// Każde wyjście na zewnątrz (wydruk, plik) może się nie udać — rolnik ma
  /// wtedy zobaczyć jedno zdanie, a nie czerwony ekran.
  Future<void> _wykonaj(
    Future<void> Function(DokumentEwidencji) co,
    String nazwaCzynnosci,
  ) async {
    final dokument = await _dokument;
    if (dokument == null || _pracuje) {
      return;
    }
    setState(() => _pracuje = true);
    try {
      await co(dokument);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nie udało się $nazwaCzynnosci. Spróbuj raz jeszcze.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pracuje = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final rejestry = widget.uslugi.dokumenty.dostepneRejestry;

    return FutureBuilder<DokumentEwidencji?>(
      future: _dokument,
      builder: (context, stan) {
        final dokument = stan.data;
        return ListView(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          children: [
            Karta(
              onTap: widget.onRejestr,
              child: Row(
                children: [
                  const Icon(
                    Icons.edit_note_outlined,
                    color: MotywNowoczesny.zielen,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Wpisy w rejestrze — popraw albo cofnij',
                      style: teksty.bodyLarge,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: MotywNowoczesny.tekstPomocniczy,
                  ),
                ],
              ),
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            Text('Rejestr', style: teksty.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rejestr in rejestry)
                  Wybor(
                    etykieta: rejestr.dlaRolnika,
                    wybrany: rejestr == _rejestr,
                    onTap: () {
                      _rejestr = rejestr;
                      _odswiez();
                    },
                  ),
              ],
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            Text('Okres', style: teksty.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<int>>(
              future: _lata,
              builder: (context, stanLat) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Wybor(
                    etykieta: 'Wszystkie lata',
                    wybrany: _rok == null,
                    onTap: () {
                      _rok = null;
                      _odswiez();
                    },
                  ),
                  for (final rok in stanLat.data ?? const <int>[])
                    Wybor(
                      etykieta: '$rok',
                      wybrany: _rok == rok,
                      onTap: () {
                        _rok = rok;
                        _odswiez();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            if (!stan.hasData)
              const Center(child: CircularProgressIndicator())
            else if (dokument == null)
              const OstrzezenieNowoczesne(
                tresc: 'Dla tego rejestru słownik reguł nie podaje dokumentu.',
                coZrobic: 'Zaktualizuj dane aplikacji albo wybierz inny.',
              )
            else ...[
              Karta(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dokument.tytul, style: teksty.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      '${dokument.gospodarstwo} • ${dokument.okres}',
                      style: teksty.bodyLarge,
                    ),
                    Text(
                      'Wpisów: ${dokument.liczbaWpisow} • kolumn wymaganych '
                      'przepisem: ${dokument.kolumny.length}',
                      style: teksty.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dokument.podstawa}\n'
                      'Słownik reguł ${dokument.wersjaRegul}',
                      style: teksty.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (dokument.liczbaWpisow == 0) ...[
                const SizedBox(height: MotywNowoczesny.odstep),
                const OstrzezenieNowoczesne(
                  tresc: 'W tym okresie nie ma żadnego wpisu.',
                  coZrobic: 'Wybierz inny rok albo inny rejestr.',
                ),
              ] else if (dokument.niekompletne.isNotEmpty) ...[
                const SizedBox(height: MotywNowoczesny.odstep),
                OstrzezenieNowoczesne(
                  tresc:
                      '${dokument.niekompletne.length} z '
                      '${dokument.liczbaWpisow} wpisów nie ma kompletu '
                      'danych wymaganych przepisem.',
                  coZrobic:
                      'Brakujące pola wyjdą na wydruku jako „brak" — '
                      'możesz je uzupełnić w rejestrze.',
                ),
              ],
              const SizedBox(height: MotywNowoczesny.odstep),
              if (_pracuje)
                const Center(child: CircularProgressIndicator())
              else ...[
                FilledButton.icon(
                  onPressed: () => _wykonaj(
                    widget.uslugi.dokumenty.wydrukujPdf,
                    'otworzyć wydruku',
                  ),
                  icon: const Icon(Icons.print_outlined, size: 20),
                  label: const Text('Wydrukuj'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _wykonaj(
                          widget.uslugi.dokumenty.zapiszPdf,
                          'przygotować pliku PDF',
                        ),
                        child: const Text('PDF'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _wykonaj(
                          widget.uslugi.dokumenty.zapiszCsv,
                          'przygotować pliku CSV',
                        ),
                        child: const Text('CSV'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _wykonaj(
                          widget.uslugi.dokumenty.zapiszXlsx,
                          'przygotować pliku XLSX',
                        ),
                        child: const Text('XLSX'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: MotywNowoczesny.odstep),
              Text(
                'Wydruk i eksport są zawsze bez opłat.',
                style: teksty.bodyMedium,
              ),
            ],
          ],
        );
      },
    );
  }
}
