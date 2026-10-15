import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dokumenty/dokument_ewidencji.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';

/// Dokumenty: podgląd, wydruk PDF i eksport CSV/XLSX (krok 4 etapu 1).
///
/// Wszystko tutaj jest darmowe — dokumentacji rolnika nigdy nie zamykamy za
/// opłatą (plan, pkt 11).
class EkranDokumenty extends StatefulWidget {
  const EkranDokumenty({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranDokumenty> createState() => _EkranDokumentyState();
}

class _EkranDokumentyState extends State<EkranDokumenty> {
  late RodzajZabiegu _rodzaj;
  int? _rok;
  Future<DokumentEwidencji?>? _dokument;
  Future<List<int>>? _lata;
  bool _pracuje = false;

  @override
  void initState() {
    super.initState();
    _rodzaj =
        widget.uslugi.dokumenty.dostepneRodzaje.firstOrNull ??
        RodzajZabiegu.oprysk;
    _lata = widget.uslugi.rejestr.lata(widget.uslugi.gospodarstwoId);
    _odswiez();
  }

  void _odswiez() {
    _dokument = _zbuduj();
  }

  /// Numer producenta bierzemy z danych gospodarstwa — stoi w nagłówku
  /// wydruku i eksportu, a gdy rolnik go nie podał, piszemy „brak".
  Future<DokumentEwidencji?> _zbuduj() async {
    final gospodarstwo = await widget.uslugi.gospodarstwa.jedno(
      widget.uslugi.gospodarstwoId,
    );
    return widget.uslugi.dokumenty.zbuduj(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      gospodarstwo: widget.uslugi.nazwaGospodarstwa,
      numerProducenta: gospodarstwo?.numerProducenta,
      rodzaj: _rodzaj,
      rok: _rok,
    );
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
              'Nie udało się $nazwaCzynnosci. Spróbuj jeszcze raz.',
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: MotywProsty.powierzchnia),
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
    final rodzaje = widget.uslugi.dokumenty.dostepneRodzaje;

    return Scaffold(
      appBar: AppBar(title: const Text('Wydruk i eksport')),
      body: FutureBuilder<DokumentEwidencji?>(
        future: _dokument,
        builder: (context, stan) {
          final dokument = stan.data;
          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              Text('Dokument', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              for (final rodzaj in rodzaje)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _Wybor(
                    etykieta:
                        widget.uslugi.dokumenty.obowiazek(rodzaj)?.nazwa ??
                        rodzaj.dlaRolnika,
                    wybrany: rodzaj == _rodzaj,
                    onTap: () => setState(() {
                      _rodzaj = rodzaj;
                      _odswiez();
                    }),
                  ),
                ),
              const SizedBox(height: MotywProsty.odstep),
              Text('Okres', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              FutureBuilder<List<int>>(
                future: _lata,
                builder: (context, stanLat) => Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _Wybor(
                      etykieta: 'Wszystkie lata',
                      wybrany: _rok == null,
                      waski: true,
                      onTap: () => setState(() {
                        _rok = null;
                        _odswiez();
                      }),
                    ),
                    for (final rok in stanLat.data ?? const <int>[])
                      _Wybor(
                        etykieta: '$rok',
                        wybrany: _rok == rok,
                        waski: true,
                        onTap: () => setState(() {
                          _rok = rok;
                          _odswiez();
                        }),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: MotywProsty.odstep),
              if (!stan.hasData)
                const Center(child: CircularProgressIndicator())
              else if (dokument == null)
                const Ostrzezenie(
                  tresc:
                      'Dla tego rodzaju zabiegu słownik reguł nie podaje '
                      'dokumentu.',
                  coZrobic:
                      'Zaktualizuj dane aplikacji albo wybierz inny '
                      'dokument.',
                )
              else ...[
                _Podglad(dokument: dokument),
                const SizedBox(height: MotywProsty.odstep),
                if (_pracuje)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  FilledButton(
                    onPressed: () => _wykonaj(
                      widget.uslugi.dokumenty.wydrukujPdf,
                      'otworzyć wydruku',
                    ),
                    child: const Text('Wydrukuj'),
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                  DuzyPrzycisk(
                    etykieta: 'Plik PDF',
                    opis: 'do wysłania albo zapisania na dysku',
                    ikona: Icons.picture_as_pdf_outlined,
                    onTap: () => _wykonaj(
                      widget.uslugi.dokumenty.zapiszPdf,
                      'przygotować pliku PDF',
                    ),
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                  DuzyPrzycisk(
                    etykieta: 'Plik CSV',
                    opis: 'otwiera się w Excelu i w Arkuszach Google',
                    ikona: Icons.table_rows_outlined,
                    onTap: () => _wykonaj(
                      widget.uslugi.dokumenty.zapiszCsv,
                      'przygotować pliku CSV',
                    ),
                  ),
                  const SizedBox(height: MotywProsty.odstep),
                  DuzyPrzycisk(
                    etykieta: 'Plik XLSX',
                    opis: 'arkusz kalkulacyjny',
                    ikona: Icons.grid_on_outlined,
                    onTap: () => _wykonaj(
                      widget.uslugi.dokumenty.zapiszXlsx,
                      'przygotować pliku XLSX',
                    ),
                  ),
                ],
                const SizedBox(height: MotywProsty.odstep),
                Text(
                  'Wydruk i eksport są zawsze bez opłat.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Podgląd dokumentu przed wydrukiem: co dokładnie wyjdzie na papier.
class _Podglad extends StatelessWidget {
  const _Podglad({required this.dokument});

  final DokumentEwidencji dokument;

  @override
  Widget build(BuildContext context) {
    final niekompletne = dokument.niekompletne.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MotywProsty.odstep),
          decoration: BoxDecoration(
            color: MotywProsty.powierzchnia,
            borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
            border: Border.all(color: MotywProsty.powierzchniaDruga, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dokument.tytul,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${dokument.gospodarstwo} • ${dokument.okres}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 6),
              Text(
                'Wpisów: ${dokument.liczbaWpisow} • '
                'kolumn wymaganych przepisem: ${dokument.kolumny.length}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${dokument.podstawa}\nSłownik reguł ${dokument.wersjaRegul}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (dokument.liczbaWpisow == 0) ...[
          const SizedBox(height: MotywProsty.odstep),
          const Ostrzezenie(
            tresc: 'W tym okresie nie ma żadnego wpisu.',
            coZrobic: 'Wybierz inny rok albo inny dokument.',
          ),
        ] else if (niekompletne > 0) ...[
          const SizedBox(height: MotywProsty.odstep),
          Ostrzezenie(
            tresc:
                '$niekompletne z ${dokument.liczbaWpisow} wpisów nie ma '
                'kompletu danych wymaganych przepisem.',
            coZrobic:
                'Brakujące pola wyjdą na wydruku jako „brak" — '
                'możesz je uzupełnić w rejestrze.',
          ),
        ],
      ],
    );
  }
}

/// Wybór jednej z kilku możliwości — duży cel dotyku, bez listy rozwijanej.
class _Wybor extends StatelessWidget {
  const _Wybor({
    required this.etykieta,
    required this.wybrany,
    required this.onTap,
    this.waski = false,
  });

  final String etykieta;
  final bool wybrany;
  final VoidCallback onTap;
  final bool waski;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: wybrany,
      child: Material(
        color: wybrany
            ? MotywProsty.zielenAkcji
            : MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          child: Container(
            width: waski ? null : double.infinity,
            constraints: const BoxConstraints(
              minHeight: MotywProsty.minCelDotyku,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            alignment: Alignment.centerLeft,
            child: Text(
              etykieta,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: wybrany ? MotywProsty.powierzchnia : MotywProsty.tekst,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
