import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/kompletnosc_ewidencji.dart';
import '../../../funkcje/zabiegi/rejestr_zabiegow.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../../../rdzen/wspolne/opis_karencji.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../wpis/ekran_karencja.dart';
import 'ekran_popraw_wpis.dart';

/// Jeden wpis rejestru w całości — tak, jak ma go zobaczyć kontrola.
///
/// Pola wymagane przez przepis bierzemy ze słownika reguł, więc gdy przepis
/// doda pole, lista rośnie bez zmiany kodu (CLAUDE.md, reguła 1).
class EkranWpisRejestru extends StatefulWidget {
  const EkranWpisRejestru({
    super.key,
    required this.uslugi,
    required this.zabiegId,
  });

  final Uslugi uslugi;
  final String zabiegId;

  @override
  State<EkranWpisRejestru> createState() => _EkranWpisRejestruState();
}

class _EkranWpisRejestruState extends State<EkranWpisRejestru> {
  late Future<WpisRejestru?> _wpis;
  bool _zmienione = false;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _wpis = widget.uslugi.rejestr.wpis(widget.zabiegId);
  }

  Future<void> _popraw(WpisRejestru wpis) async {
    final poprawione = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranPoprawWpis(uslugi: widget.uslugi, wpis: wpis),
      ),
    );
    if (poprawione ?? false) {
      _zmienione = true;
      setState(_odswiez);
    }
  }

  Future<void> _ustawKarencje(WpisRejestru wpis) async {
    final oprysk = wpis.oprysk;
    if (oprysk == null) {
      return;
    }
    final zapisane = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranKarencja(
          uslugi: widget.uslugi,
          zabiegId: wpis.zabieg.id,
          dataZabiegu: wpis.zabieg.data,
          srodekNazwa: oprysk.srodekNazwa,
          dniZEtykiety: oprysk.karencjaDni,
          dataEtykiety: oprysk.karencjaDataEtykiety,
        ),
      ),
    );
    if (zapisane ?? false) {
      _zmienione = true;
      setState(_odswiez);
    }
  }

  Future<void> _cofnij() async {
    final potwierdzone = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Cofnąć ten wpis?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          'Wpis zniknie z ewidencji, ale zostanie w dzienniku zmian — '
          'kontrola zobaczy, że był i że go cofnięto.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Zostaw'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cofnij wpis'),
          ),
        ],
      ),
    );
    if (!(potwierdzone ?? false) || !mounted) {
      return;
    }
    await widget.uslugi.zabiegi.oznaczUsuniety(
      zabiegId: widget.zabiegId,
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Powrót musi powiedzieć rejestrowi, czy wpis się zmienił — inaczej lista
    // pokazywałaby starą dawkę.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (juzZdjety, _) {
        if (!juzZdjety) {
          Navigator.of(context).pop(_zmienione);
        }
      },
      child: _zawartosc(context),
    );
  }

  Widget _zawartosc(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wpis w rejestrze')),
      body: FutureBuilder<WpisRejestru?>(
        future: _wpis,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final wpis = stan.data!;
          final obowiazek = widget.uslugi.reguly.obowiazek(
            KompletnoscEwidencji.idObowiazku(wpis.zabieg.rodzaj),
          );
          final ocena = obowiazek == null
              ? null
              : KompletnoscEwidencji.sprawdz(wpis, obowiazek);

          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              Text(
                '${KompletnoscEwidencji.dzien(wpis.zabieg.data)}'
                '${wpis.zabieg.godzina == null ? '' : ', godz. ${wpis.zabieg.godzina}'}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${wpis.zabieg.rodzaj.dlaRolnika} • ${wpis.opisPol} • '
                '${wpis.powierzchniaOpis}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: MotywProsty.odstep),
              if (wpis.dzienZbioru case final DateTime dzien)
                Ostrzezenie(
                  tresc: wpis.karencjaTrwa(DateTime.now())
                      ? 'Karencja: zbiór najwcześniej '
                            '${KompletnoscEwidencji.dzien(dzien)}.'
                      : 'Karencja minęła '
                            '${KompletnoscEwidencji.dzien(dzien)}.',
                  coZrobic: wpis.oprysk?.karencjaZrodlo == null
                      ? null
                      : 'Źródło: ${wpis.oprysk!.karencjaZrodlo}.',
                ),
              if (wpis.oprysk case final SzczegolyOprysku oprysk) ...[
                if (wpis.dzienZbioru == null)
                  const SizedBox(height: MotywProsty.odstep),
                Text(
                  'Karencja: ${OpisKarencji.dlaWpisu(oprysk)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                DuzyPrzycisk(
                  etykieta: oprysk.karencjaDni == null
                      ? 'Wpisz karencję z opakowania'
                      : 'Potwierdź karencję',
                  opis: oprysk.karencjaPotwierdzona
                      ? 'już potwierdzona — można poprawić'
                      : 'sprawdź liczbę dni na opakowaniu',
                  ikona: Icons.event_available_outlined,
                  onTap: () => _ustawKarencje(wpis),
                ),
                const SizedBox(height: MotywProsty.odstep),
              ] else if (wpis.dzienZbioru != null)
                const SizedBox(height: MotywProsty.odstep),
              if (ocena != null) ..._ewidencja(context, ocena),
              const SizedBox(height: MotywProsty.odstep),
              if (wpis.oprysk != null)
                FilledButton(
                  onPressed: () => _popraw(wpis),
                  child: const Text('Popraw wpis'),
                ),
              const SizedBox(height: MotywProsty.odstep),
              OutlinedButton(
                onPressed: _cofnij,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(
                    MotywProsty.minCelDotyku * 2,
                    MotywProsty.minCelDotyku + 8,
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Cofnij wpis'),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _ewidencja(BuildContext context, OcenaEwidencji ocena) => [
    Text(ocena.obowiazek.nazwa, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 4),
    Text(
      'Podstawa: ${ocena.obowiazek.podstawa}. '
      'Słownik reguł ${widget.uslugi.reguly.wersja}.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: MotywProsty.odstep),
    for (final pole in ocena.pola) _PoleEwidencji(ocena: pole),
    const SizedBox(height: MotywProsty.odstep),
    if (!ocena.kompletna)
      Ostrzezenie(
        tresc: ocena.jednymZdaniem,
        coZrobic:
            'Uzupełnij brakujące dane w aplikacji albo dopisz je '
            'na wydruku przed kontrolą.',
      )
    else
      Text(ocena.jednymZdaniem, style: Theme.of(context).textTheme.bodyLarge),
  ];
}

/// Jedno pole ewidencji: nazwa z przepisu i wartość albo informacja o braku.
class _PoleEwidencji extends StatelessWidget {
  const _PoleEwidencji({required this.ocena});

  final OcenaPola ocena;

  @override
  Widget build(BuildContext context) {
    final (ikona, kolor, tresc) = switch (ocena.stan) {
      StanPola.jest => (
        Icons.check,
        MotywProsty.zielenAkcji,
        ocena.wartosc ?? '',
      ),
      StanPola.brak => (
        Icons.priority_high,
        MotywProsty.ostrzezenieObramowanie,
        'brak — uzupełnij',
      ),
      StanPola.nieWiadomo => (
        Icons.help_outline,
        MotywProsty.ostrzezenieObramowanie,
        'tego pola ta wersja aplikacji nie zna — sprawdź sam',
      ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikona, size: 28, color: kolor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ocena.pole.nazwa,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(tresc, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
