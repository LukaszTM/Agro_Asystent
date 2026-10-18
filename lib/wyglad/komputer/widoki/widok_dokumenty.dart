import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dokumenty/dokument_ewidencji.dart';
import '../../../funkcje/dokumenty/rodzaj_rejestru.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';

/// Trzy rejestry: podgląd kolumnami z przepisu, wydruk i eksport.
///
/// Kolumny biorą się ze słownika reguł (`wymagane_pola`), nie z kodu — ten
/// sam dokument co na telefonie. Wszystko tu jest darmowe (plan, pkt 8).
class WidokDokumentyKomputer extends StatefulWidget {
  const WidokDokumentyKomputer({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<WidokDokumentyKomputer> createState() => _WidokDokumentyKomputerState();
}

class _WidokDokumentyKomputerState extends State<WidokDokumentyKomputer> {
  late RodzajRejestru _rejestr;
  late Future<DokumentEwidencji?> _dokument;
  late Future<List<int>> _lata;
  int? _rok;
  bool _pracuje = false;
  String? _komunikat;

  @override
  void initState() {
    super.initState();
    _rejestr =
        widget.uslugi.dokumenty.dostepneRejestry.firstOrNull ??
        RodzajRejestru.ewidencjaSor;
    _rok = (widget.teraz ?? DateTime.now()).year;
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
      rejestrDokumentu: _rejestr,
      rok: _rok,
    );
  }

  void _zmien(void Function() zmiana) {
    setState(() {
      zmiana();
      _komunikat = null;
      _dokument = _zbuduj();
    });
  }

  /// Każde wyjście na zewnątrz (drukarka, plik) może się nie udać — rolnik
  /// ma wtedy zobaczyć jedno zdanie, a nie czerwony ekran.
  Future<void> _wykonaj(
    Future<void> Function(DokumentEwidencji) co,
    String potwierdzenie,
  ) async {
    final dokument = await _dokument;
    if (dokument == null || _pracuje) {
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
    } on Object catch (blad) {
      if (mounted) {
        setState(() => _komunikat = 'Nie udało się: $blad');
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
    final dokumenty = widget.uslugi.dokumenty;

    return FutureBuilder<DokumentEwidencji?>(
      future: _dokument,
      builder: (context, stan) {
        if (!stan.hasData && stan.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final dokument = stan.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NaglowekWidoku(
              tytul: 'Rejestry do wydruku i eksportu',
              opis:
                  'Kolumny pochodzą z przepisu, nie z programu. Wydruk '
                  'i eksport są darmowe.',
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final rejestr in dokumenty.dostepneRejestry)
                  rejestr == _rejestr
                      ? FilledButton(
                          onPressed: () => _zmien(() => _rejestr = rejestr),
                          child: Text(rejestr.dlaRolnika),
                        )
                      : OutlinedButton(
                          onPressed: () => _zmien(() => _rejestr = rejestr),
                          child: Text(rejestr.dlaRolnika),
                        ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<List<int>>(
              future: _lata,
              builder: (context, stanLat) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _rok == null
                      ? const FilledButton(
                          onPressed: null,
                          child: Text('Wszystkie lata'),
                        )
                      : OutlinedButton(
                          onPressed: () => _zmien(() => _rok = null),
                          child: const Text('Wszystkie lata'),
                        ),
                  for (final rok in stanLat.data ?? const <int>[])
                    rok == _rok
                        ? FilledButton(
                            onPressed: () => _zmien(() => _rok = rok),
                            child: Text('$rok'),
                          )
                        : OutlinedButton(
                            onPressed: () => _zmien(() => _rok = rok),
                            child: Text('$rok'),
                          ),
                ],
              ),
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Expanded(
              child: dokument == null
                  ? const OstrzezenieKomputer(
                      tresc: 'Nie ma z czego złożyć tego rejestru.',
                      coZrobic:
                          'Zrób pierwszy wpis zabiegu — wtedy rejestr '
                          'powstanie sam.',
                    )
                  : ListView(
                      children: [
                        KartaKomputer(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dokument.tytul, style: teksty.titleLarge),
                              const SizedBox(height: 4),
                              Text(
                                '${dokument.podstawa} • ${dokument.okres} • '
                                '${dokument.liczbaWpisow} wpisów • '
                                'słownik reguł ${dokument.wersjaRegul} • '
                                'sporządzono '
                                '${Daty.krotko(dokument.sporzadzono)}',
                                style: teksty.bodyMedium,
                              ),
                              if (dokument.niekompletne.isNotEmpty) ...[
                                const SizedBox(height: MotywKomputer.odstep),
                                OstrzezenieKomputer(
                                  tresc:
                                      '${dokument.niekompletne.length} wpisów '
                                      'nie ma wszystkich pól wymaganych '
                                      'przepisem.',
                                  coZrobic:
                                      'Na wydruku stoi tam „brak". Uzupełnij '
                                      'wpisy w telefonie, jeśli dane są do '
                                      'odzyskania.',
                                ),
                              ],
                              const SizedBox(height: MotywKomputer.odstep),
                              if (_pracuje)
                                const Center(child: CircularProgressIndicator())
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () => _wykonaj(
                                        dokumenty.wydrukujPdf,
                                        'Wydruk wysłany do drukarki.',
                                      ),
                                      icon: const Icon(
                                        Icons.print_outlined,
                                        size: 20,
                                      ),
                                      label: const Text('Wydrukuj'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => _wykonaj(
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
                                      onPressed: () => _wykonaj(
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
                                      onPressed: () => _wykonaj(
                                        dokumenty.zapiszXlsx,
                                        'Zapisano plik XLSX.',
                                      ),
                                      icon: const Icon(
                                        Icons.grid_on_outlined,
                                        size: 20,
                                      ),
                                      label: const Text('Zapisz XLSX'),
                                    ),
                                  ],
                                ),
                              if (_komunikat case final String tekst) ...[
                                const SizedBox(height: MotywKomputer.odstep),
                                Text(tekst, style: teksty.bodyLarge),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: MotywKomputer.odstep),
                        Tabela(
                          kolumny: [
                            for (final kolumna in dokument.kolumny)
                              KolumnaTabeli(kolumna.nazwa),
                          ],
                          gdyPusta:
                              'W tym rejestrze nie ma jeszcze ani jednego '
                              'wpisu za ${dokument.okres}.',
                          wiersze: [
                            for (final wiersz in dokument.wiersze)
                              WierszTabeli(
                                wartosci: [
                                  for (final wartosc in wiersz.wartosci)
                                    wartosc ?? 'brak',
                                ],
                                wyrozniony: !wiersz.kompletny,
                                podpis: wiersz.kompletny
                                    ? null
                                    : 'brakuje: ${wiersz.braki.join(', ')}',
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}
