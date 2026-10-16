import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/kompletnosc_ewidencji.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/wybor.dart';
import 'ekran_wpis_rejestru.dart';

/// Rejestr zabiegów w wyglądzie nowoczesnym: wszystko, co rolnik wpisał,
/// od najnowszego, z wyszukiwarką i filtrem rodzaju.
///
/// Stąd wchodzi się do poprawki i cofnięcia wpisu — „każdy wpis da się
/// cofnąć i poprawić" obowiązuje w obu wyglądach (plan, pkt 5).
class EkranRejestrNowoczesny extends StatefulWidget {
  const EkranRejestrNowoczesny({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;

  /// Dzień, od którego liczymy karencje; w aplikacji „dzisiaj".
  final DateTime? teraz;

  @override
  State<EkranRejestrNowoczesny> createState() => _EkranRejestrNowoczesnyState();
}

class _EkranRejestrNowoczesnyState extends State<EkranRejestrNowoczesny> {
  late Future<List<WpisRejestru>> _wpisy;
  RodzajZabiegu? _rodzaj;
  String _szukane = '';

  /// Czy cokolwiek się zmieniło — zakładki muszą wtedy przeliczyć dane.
  bool _zmienione = false;

  static const List<(RodzajZabiegu?, String)> _rodzaje = [
    (null, 'Wszystkie'),
    (RodzajZabiegu.oprysk, 'Opryski'),
    (RodzajZabiegu.nawozenie, 'Nawożenie'),
  ];

  @override
  void initState() {
    super.initState();
    _wpisy = _czytaj();
  }

  Future<List<WpisRejestru>> _czytaj() => widget.uslugi.rejestr.wpisy(
    widget.uslugi.gospodarstwoId,
    filtr: FiltrRejestru(rodzaj: _rodzaj, szukane: _szukane),
  );

  void _odswiez() {
    setState(() {
      _wpisy = _czytaj();
    });
  }

  Future<void> _otworz(WpisRejestru wpis) async {
    final zmienione = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranWpisuRejestru(
          uslugi: widget.uslugi,
          zabiegId: wpis.zabieg.id,
          teraz: widget.teraz,
        ),
      ),
    );
    if (zmienione ?? false) {
      _zmienione = true;
      _odswiez();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (juzZdjety, _) {
        if (!juzZdjety) {
          Navigator.of(context).pop(_zmienione);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Rejestr zabiegów')),
        body: ListView(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          children: [
            TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Szukaj: środek, pole, uprawa',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (tekst) {
                _szukane = tekst.trim();
                _odswiez();
              },
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (rodzaj, etykieta) in _rodzaje)
                  Wybor(
                    etykieta: etykieta,
                    wybrany: _rodzaj == rodzaj,
                    onTap: () {
                      _rodzaj = rodzaj;
                      _odswiez();
                    },
                  ),
              ],
            ),
            const SizedBox(height: MotywNowoczesny.odstep),
            FutureBuilder<List<WpisRejestru>>(
              future: _wpisy,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final wpisy = stan.data!;
                if (wpisy.isEmpty) {
                  final pustyRejestr = _szukane.isEmpty && _rodzaj == null;
                  return OstrzezenieNowoczesne(
                    tresc: pustyRejestr
                        ? 'W rejestrze nie ma jeszcze żadnego wpisu.'
                        : 'Nic nie pasuje do tego szukania.',
                    coZrobic: pustyRejestr
                        ? 'Naciśnij „+" na dolnym pasku — wpis zajmuje chwilę.'
                        : 'Pokaż wszystkie wpisy albo wpisz inną nazwę.',
                  );
                }
                return Column(
                  children: [
                    for (final wpis in wpisy) ...[
                      Karta(
                        onTap: () => _otworz(wpis),
                        child: _Wiersz(
                          wpis: wpis,
                          niekompletny: _niekompletny(wpis),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Czy wpis nie ma kompletu danych wymaganych przepisem. Lista pól jest
  /// w słowniku reguł, nie w kodzie ekranu (CLAUDE.md, reguła 1).
  bool _niekompletny(WpisRejestru wpis) {
    final obowiazek = widget.uslugi.reguly.obowiazek(
      KompletnoscEwidencji.idObowiazku(wpis.zabieg.rodzaj),
    );
    if (obowiazek == null) {
      return false;
    }
    return !KompletnoscEwidencji.sprawdz(wpis, obowiazek).kompletna;
  }
}

class _Wiersz extends StatelessWidget {
  const _Wiersz({required this.wpis, required this.niekompletny});

  final WpisRejestru wpis;
  final bool niekompletny;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final co =
        wpis.oprysk?.srodekNazwa ??
        wpis.nawozenie?.nawozNazwa ??
        wpis.zabieg.rodzaj.dlaRolnika;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${KompletnoscEwidencji.dzien(wpis.zabieg.data)} • $co',
                style: teksty.bodyLarge,
              ),
              Text(
                '${wpis.zabieg.rodzaj.dlaRolnika} • ${wpis.opisPol} • '
                '${wpis.powierzchniaOpis}',
                style: teksty.bodyMedium,
              ),
              if (niekompletny)
                Text(
                  'brakuje danych wymaganych przepisem',
                  style: teksty.bodyMedium?.copyWith(
                    color: MotywNowoczesny.ostrzezenieObramowanie,
                  ),
                ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: MotywNowoczesny.tekstPomocniczy),
      ],
    );
  }
}
