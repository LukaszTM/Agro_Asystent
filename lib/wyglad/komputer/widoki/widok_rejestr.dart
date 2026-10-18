import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/kompletnosc_ewidencji.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';

/// Rejestr zabiegów w tabeli — po to jest program na komputer.
///
/// Na telefonie rolnik dopisuje jeden wpis; przy monitorze patrzy na cały
/// sezon naraz, szuka i sprawdza, czy czegoś nie brakuje. Wpisy, które nie
/// mają wszystkich pól wymaganych przepisem, są wyróżnione — ten sam
/// rachunek co w telefonie (`KompletnoscEwidencji`).
class WidokRejestrKomputer extends StatefulWidget {
  const WidokRejestrKomputer({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<WidokRejestrKomputer> createState() => _WidokRejestrKomputerState();
}

class _WidokRejestrKomputerState extends State<WidokRejestrKomputer> {
  late Future<List<WpisRejestru>> _wpisy;
  RodzajZabiegu? _rodzaj;
  int? _rok;
  String _szukane = '';

  int get _biezacyRok => (widget.teraz ?? DateTime.now()).year;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _wpisy = widget.uslugi.rejestr.wpisy(
      widget.uslugi.gospodarstwoId,
      filtr: FiltrRejestru(rodzaj: _rodzaj, rok: _rok, szukane: _szukane),
    );
  }

  void _zmienFiltr(void Function() zmiana) {
    setState(() {
      zmiana();
      _odswiez();
    });
  }

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return FutureBuilder<List<WpisRejestru>>(
      future: _wpisy,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final wpisy = stan.data!;
        final niekompletne = wpisy.where(_niekompletny).length;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NaglowekWidoku(
              tytul: 'Wszystkie wpisy',
              opis:
                  '${wpisy.length} wpisów'
                  '${niekompletne == 0 ? '' : ', z tego $niekompletne '
                            'bez wszystkich pól wymaganych przepisem'}.',
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Szukaj: środek, nawóz albo pole',
                      prefixIcon: Icon(Icons.search, size: 20),
                    ),
                    onChanged: (tekst) => _zmienFiltr(() => _szukane = tekst),
                  ),
                ),
                _Filtr(
                  etykieta: 'Wszystkie rodzaje',
                  wybrany: _rodzaj == null,
                  onKlik: () => _zmienFiltr(() => _rodzaj = null),
                ),
                for (final rodzaj in RodzajZabiegu.values)
                  _Filtr(
                    etykieta: rodzaj.dlaRolnika,
                    wybrany: _rodzaj == rodzaj,
                    onKlik: () => _zmienFiltr(() => _rodzaj = rodzaj),
                  ),
                _Filtr(
                  etykieta: 'Wszystkie lata',
                  wybrany: _rok == null,
                  onKlik: () => _zmienFiltr(() => _rok = null),
                ),
                for (final rok in [_biezacyRok, _biezacyRok - 1])
                  _Filtr(
                    etykieta: '$rok',
                    wybrany: _rok == rok,
                    onKlik: () => _zmienFiltr(() => _rok = rok),
                  ),
              ],
            ),
            const SizedBox(height: MotywKomputer.odstep),
            Expanded(
              child: ListView(
                children: [
                  Tabela(
                    kolumny: const [
                      KolumnaTabeli('Data'),
                      KolumnaTabeli('Rodzaj'),
                      KolumnaTabeli('Środek / nawóz', udzial: 2),
                      KolumnaTabeli('Pola', udzial: 2),
                      KolumnaTabeli('Powierzchnia', doPrawej: true),
                    ],
                    gdyPusta: wpisy.isEmpty && _szukane.isEmpty
                        ? 'Nie ma jeszcze żadnego wpisu. Pierwszy zrobisz '
                              'w telefonie albo tutaj, gdy dojdzie wpis '
                              'zabiegu na komputerze.'
                        : 'Nic nie pasuje do tego, czego szukasz.',
                    wiersze: [
                      for (final wpis in wpisy)
                        WierszTabeli(
                          wartosci: [
                            Daty.krotko(wpis.zabieg.data),
                            wpis.zabieg.rodzaj.dlaRolnika,
                            _co(wpis),
                            wpis.opisPol,
                            wpis.powierzchniaOpis,
                          ],
                          wyrozniony: _niekompletny(wpis),
                          podpis: _podpis(wpis),
                        ),
                    ],
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  Text(
                    'Wpisy poprawia się i cofa w telefonie — tam, gdzie '
                    'powstały. Każda zmiana zostaje w dzienniku zmian.',
                    style: teksty.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _co(WpisRejestru wpis) =>
      wpis.oprysk?.srodekNazwa ??
      wpis.nawozenie?.nawozNazwa ??
      wpis.zabieg.uwagi ??
      'brak';

  String? _podpis(WpisRejestru wpis) {
    final czesci = <String>[
      if (wpis.dzienZbioru case final DateTime dzien)
        'zbiór najwcześniej ${Daty.krotko(dzien)}',
      if (_niekompletny(wpis)) 'brakuje pól wymaganych przepisem',
    ];
    return czesci.isEmpty ? null : czesci.join(' • ');
  }

  bool _niekompletny(WpisRejestru wpis) {
    final id = KompletnoscEwidencji.idObowiazku(wpis.zabieg.rodzaj);
    if (id == null) {
      return false;
    }
    final obowiazek = widget.uslugi.reguly.obowiazek(id);
    return obowiazek != null &&
        !KompletnoscEwidencji.sprawdz(wpis, obowiazek).kompletna;
  }
}

class _Filtr extends StatelessWidget {
  const _Filtr({
    required this.etykieta,
    required this.wybrany,
    required this.onKlik,
  });

  final String etykieta;
  final bool wybrany;
  final VoidCallback onKlik;

  @override
  Widget build(BuildContext context) => wybrany
      ? FilledButton(onPressed: onKlik, child: Text(etykieta))
      : OutlinedButton(onPressed: onKlik, child: Text(etykieta));
}
