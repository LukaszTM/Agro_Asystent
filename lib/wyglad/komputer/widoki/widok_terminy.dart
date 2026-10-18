import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/terminy/kalendarz_terminow.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import '../widgety/karta.dart';
import '../widgety/tabela.dart';

/// Kalendarz obowiązków w tabeli: co, do kiedy i co z tym zrobić.
///
/// Te same pozycje co na telefonie — liczy je `funkcje/terminy/`, tu
/// zmienia się tylko układ.
class WidokTerminyKomputer extends StatefulWidget {
  const WidokTerminyKomputer({super.key, required this.uslugi, this.teraz});

  final Uslugi uslugi;
  final DateTime? teraz;

  @override
  State<WidokTerminyKomputer> createState() => _WidokTerminyKomputerState();
}

class _WidokTerminyKomputerState extends State<WidokTerminyKomputer> {
  late Future<List<PozycjaKalendarza>> _pozycje;

  DateTime get _teraz => widget.teraz ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _pozycje = _policz();
  }

  Future<List<PozycjaKalendarza>> _policz() async {
    final profil = await widget.uslugi.profil.policz(
      widget.uslugi.gospodarstwoId,
    );
    return widget.uslugi.kalendarz.najblizsze(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      profil: profil,
      teraz: widget.teraz,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PozycjaKalendarza>>(
      future: _pozycje,
      builder: (context, stan) {
        if (!stan.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pozycje = stan.data!;
        final teraz = _teraz;
        final minelo = pozycje
            .where((p) => p.pilnosc(teraz) == PilnoscTerminu.minelo)
            .length;

        return ListView(
          children: [
            NaglowekWidoku(
              tytul: 'Co trzeba zrobić i do kiedy',
              opis:
                  'Stan na ${Daty.zRokiem(teraz)}. '
                  '${pozycje.length} pozycji'
                  '${minelo == 0 ? '' : ', z tego $minelo po terminie'}.',
            ),
            const SizedBox(height: MotywKomputer.odstep),
            if (pozycje.isEmpty)
              const OstrzezenieKomputer(
                tresc: 'Nie ma teraz żadnego terminu do pilnowania.',
                coZrobic:
                    'Zajrzyj tu po dodaniu pól albo po pierwszym oprysku — '
                    'karencje liczą się same.',
              )
            else
              Tabela(
                kolumny: const [
                  KolumnaTabeli('Termin'),
                  KolumnaTabeli('Obowiązek', udzial: 2),
                  KolumnaTabeli('Co zrobić', udzial: 3),
                ],
                wiersze: [
                  for (final pozycja in pozycje)
                    WierszTabeli(
                      wartosci: [
                        pozycja.okres
                            ? '${Daty.krotko(pozycja.data)} – '
                                  '${Daty.krotko(pozycja.doKiedy!)}'
                            : Daty.krotko(pozycja.data),
                        pozycja.nazwa,
                        pozycja.coZrobic,
                      ],
                      wyrozniony:
                          pozycja.pilnosc(teraz) == PilnoscTerminu.minelo,
                      podpis: _podpis(pozycja),
                    ),
                ],
              ),
            const SizedBox(height: MotywKomputer.odstep),
            Text(
              'Przypomnienia wysyła telefon — komputer pokazuje te same '
              'terminy, ale nie dzwoni.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        );
      },
    );
  }

  static String? _podpis(PozycjaKalendarza pozycja) {
    final czesci = <String>[
      if (pozycja.doWeryfikacji) 'termin do weryfikacji w przepisie',
      if (pozycja.obowiazekNiepewny)
        'nie wiemy, czy ten obowiązek dotyczy gospodarstwa',
      if (pozycja.uwagi.isNotEmpty) pozycja.uwagi,
    ];
    return czesci.isEmpty ? null : czesci.join(' • ');
  }
}
