import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/granica_z_woda.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/dzialki/rodzaj_uzytku.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';

/// Pola gospodarstwa w tabeli: co rośnie, ile ma hektarów i czego jeszcze
/// brakuje do policzenia warunkowości.
///
/// Rodzaj użytku i odpowiedź o wodzie ustawia się tu wprost — na komputerze
/// rolnik zwykle siada do uzupełniania danych całego gospodarstwa naraz.
class WidokPolaKomputer extends StatefulWidget {
  const WidokPolaKomputer({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<WidokPolaKomputer> createState() => _WidokPolaKomputerState();
}

class _WidokPolaKomputerState extends State<WidokPolaKomputer> {
  late Future<List<Pole>> _pola;
  Pole? _wybrane;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _pola = widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId);
  }

  Future<void> _ustawRodzaj(Pole pole, RodzajUzytku rodzaj) async {
    await widget.uslugi.pola.ustawRodzajUzytku(
      poleId: pole.id,
      rodzaj: rodzaj,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _poZmianie(pole.id);
  }

  Future<void> _ustawWode(Pole pole, GranicaZWoda granica) async {
    await widget.uslugi.pola.ustawGranicaZWoda(
      poleId: pole.id,
      granica: granica,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    await _poZmianie(pole.id);
  }

  Future<void> _poZmianie(String poleId) async {
    final swieze = await widget.uslugi.pola.jedno(poleId);
    if (!mounted) {
      return;
    }
    // Pozostałe zakładki czytają dane od nowa przy wejściu, więc tu
    // wystarczy odświeżyć tabelę i panel pola.
    setState(() {
      _wybrane = swieze;
      _odswiez();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pole>>(
      future: _pola,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pola = stan.data!;
        final hektary = pola.fold<double>(
          0,
          (suma, p) => suma + p.powierzchniaHa,
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: ListView(
                children: [
                  NaglowekWidoku(
                    tytul: 'Pola w gospodarstwie',
                    opis:
                        '${pola.length} pól, razem '
                        '${hektary.toStringAsFixed(2).replaceAll('.', ',')} ha. '
                        'Kliknij pole, żeby uzupełnić dane.',
                  ),
                  const SizedBox(height: MotywKomputer.odstep),
                  Tabela(
                    kolumny: const [
                      KolumnaTabeli('Pole', udzial: 2),
                      KolumnaTabeli('Uprawa', udzial: 2),
                      KolumnaTabeli('Powierzchnia', doPrawej: true),
                      KolumnaTabeli('Rodzaj użytku', udzial: 2),
                      KolumnaTabeli('Woda'),
                    ],
                    gdyPusta:
                        'Nie masz jeszcze żadnego pola. Dodaj je w telefonie '
                        'albo wczytaj wniosek z PDF.',
                    wiersze: [
                      for (final pole in pola)
                        WierszTabeli(
                          wartosci: [
                            pole.nazwa,
                            pole.uprawa.isEmpty ? 'brak' : pole.uprawa,
                            pole.powierzchniaOpis,
                            pole.rodzajUzytku.dlaRolnika,
                            pole.granicaZWoda.znana
                                ? (pole.granicaZWoda == GranicaZWoda.tak
                                      ? 'tak'
                                      : 'nie')
                                : 'nie wiadomo',
                          ],
                          wyrozniony:
                              !pole.rodzajUzytku.znany ||
                              !pole.granicaZWoda.znana,
                          onKlik: () => setState(() => _wybrane = pole),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: MotywKomputer.odstep),
            Expanded(
              flex: 2,
              child: _wybrane == null
                  ? const KartaKomputer(
                      child: Text(
                        'Wybierz pole z tabeli, żeby uzupełnić rodzaj użytku '
                        'i odpowiedź o wodzie. Bez nich aplikacja nie '
                        'policzy norm GAEC.',
                      ),
                    )
                  : _SzczegolyPola(
                      pole: _wybrane!,
                      pytanieOWode: widget.uslugi.pasOdWody.pytanie,
                      onRodzaj: (rodzaj) => _ustawRodzaj(_wybrane!, rodzaj),
                      onWoda: (granica) => _ustawWode(_wybrane!, granica),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Dane jednego pola do uzupełnienia. Aplikacja niczego nie zgaduje —
/// zapisuje to, co rolnik kliknie.
class _SzczegolyPola extends StatelessWidget {
  const _SzczegolyPola({
    required this.pole,
    required this.pytanieOWode,
    required this.onRodzaj,
    required this.onWoda,
  });

  final Pole pole;
  final String pytanieOWode;
  final void Function(RodzajUzytku rodzaj) onRodzaj;
  final void Function(GranicaZWoda granica) onWoda;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return ListView(
      children: [
        KartaKomputer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pole.nazwa, style: teksty.titleLarge),
              Text(
                '${pole.uprawa.isEmpty ? 'bez uprawy' : pole.uprawa} • '
                '${pole.powierzchniaOpis}'
                '${pole.sezon == null ? '' : ' • sezon ${pole.sezon}'}',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text('Rodzaj użytku', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Od niego zależą progi normy GAEC 7.',
                style: teksty.bodyMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final rodzaj in RodzajUzytku.doWyboru)
                    rodzaj == pole.rodzajUzytku
                        ? FilledButton(
                            onPressed: () => onRodzaj(rodzaj),
                            child: Text(rodzaj.dlaRolnika),
                          )
                        : OutlinedButton(
                            onPressed: () => onRodzaj(rodzaj),
                            child: Text(rodzaj.dlaRolnika),
                          ),
                ],
              ),
              const SizedBox(height: MotywKomputer.odstep),
              Text('Woda przy polu', style: teksty.titleLarge),
              const SizedBox(height: 4),
              Text(pytanieOWode, style: teksty.bodyMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final granica in GranicaZWoda.doWyboru)
                    granica == pole.granicaZWoda
                        ? FilledButton(
                            onPressed: () => onWoda(granica),
                            child: Text(granica.dlaRolnika),
                          )
                        : OutlinedButton(
                            onPressed: () => onWoda(granica),
                            child: Text(granica.dlaRolnika),
                          ),
                ],
              ),
            ],
          ),
        ),
        if (!pole.rodzajUzytku.znany) ...[
          const SizedBox(height: MotywKomputer.odstep),
          const OstrzezenieKomputer(
            tresc: 'Nie wiemy, czy to grunt orny, łąka czy sad.',
            coZrobic:
                'Wybierz wyżej. Bez tego warunkowość zostaje „do '
                'sprawdzenia", a nie „spełniona".',
          ),
        ],
      ],
    );
  }
}
