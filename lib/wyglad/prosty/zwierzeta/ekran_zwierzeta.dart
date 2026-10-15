import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zwierzeta/stado.dart';
import '../../../rdzen/reguly/regula_prawna.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_nowe_zwierze.dart';

/// Zwierzęta: stan stada, DJP i zgłoszenia do IRZplus (krok 9 etapu 1).
class EkranZwierzeta extends StatefulWidget {
  const EkranZwierzeta({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranZwierzeta> createState() => _EkranZwierzetaState();
}

class _EkranZwierzetaState extends State<EkranZwierzeta> {
  late Future<
    ({StanDjp djp, List<Stado> stada, List<ZdarzenieZwierzecia> doZgloszenia})
  >
  _dane;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _dane = _policz();
  }

  Future<
    ({StanDjp djp, List<Stado> stada, List<ZdarzenieZwierzecia> doZgloszenia})
  >
  _policz() async {
    final gospodarstwo = widget.uslugi.gospodarstwoId;
    return (
      djp: await widget.uslugi.stado.djp(gospodarstwo),
      stada: await widget.uslugi.stado.stada(gospodarstwo),
      doZgloszenia: await widget.uslugi.stado.zdarzenia(
        gospodarstwo,
        tylkoNiezgloszone: true,
      ),
    );
  }

  Future<void> _dodajZwierze() async {
    final dodano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranNoweZwierze(uslugi: widget.uslugi),
      ),
    );
    if (dodano ?? false) {
      setState(_odswiez);
    }
  }

  Future<void> _zglos(ZdarzenieZwierzecia zdarzenie) async {
    await widget.uslugi.stado.oznaczZgloszone(
      zdarzenieId: zdarzenie.id,
      kiedy: DateTime.now(),
      urzadzenie: widget.uslugi.urzadzenie,
    );
    if (mounted) {
      setState(_odswiez);
    }
  }

  static String _dzien(DateTime data) =>
      '${data.day.toString().padLeft(2, '0')}.'
      '${data.month.toString().padLeft(2, '0')}.${data.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zwierzęta')),
      body:
          FutureBuilder<
            ({
              StanDjp djp,
              List<Stado> stada,
              List<ZdarzenieZwierzecia> doZgloszenia,
            })
          >(
            future: _dane,
            builder: (context, stan) {
              if (!stan.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final djp = stan.data!.djp;
              final doZgloszenia = stan.data!.doZgloszenia;

              return ListView(
                padding: const EdgeInsets.all(MotywProsty.odstep),
                children: [
                  _Djp(stan: djp),
                  const SizedBox(height: MotywProsty.odstep),
                  if (doZgloszenia.isNotEmpty) ...[
                    Text(
                      'Do zgłoszenia w IRZplus',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    for (final zdarzenie in doZgloszenia) ...[
                      DuzyPrzycisk(
                        etykieta:
                            '${zdarzenie.rodzaj.dlaRolnika}'
                            '${zdarzenie.numerZwierzecia == null ? '' : ': ${zdarzenie.numerZwierzecia}'}',
                        opis:
                            'z dnia ${_dzien(zdarzenie.data)} • '
                            'naciśnij, gdy zgłosisz',
                        ikona: Icons.send_outlined,
                        onTap: () => _zglos(zdarzenie),
                      ),
                      const SizedBox(height: MotywProsty.odstep),
                    ],
                    Text(
                      'Zgłoszenia składasz w IRZplus — aplikacja ich nie wysyła, '
                      'pilnuje tylko terminu.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: MotywProsty.odstep),
                  ],
                  Text('Stado', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  if (djp.sztuk == 0)
                    const Ostrzezenie(
                      tresc: 'Nie masz jeszcze żadnego zwierzęcia.',
                      coZrobic:
                          'Dodaj zwierzę — numer kolczyka i grupa wystarczą.',
                    )
                  else
                    Text(
                      'Sztuk w gospodarstwie: ${djp.sztuk}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  const SizedBox(height: MotywProsty.odstep),
                  FilledButton(
                    onPressed: _dodajZwierze,
                    child: const Text('Dodaj zwierzę'),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _Djp extends StatelessWidget {
  const _Djp({required this.stan});

  final StanDjp stan;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            'Duże jednostki przeliczeniowe',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            '${stan.djp.toStringAsFixed(2).replaceAll('.', ',')} DJP '
            'z ${stan.sztuk} sztuk',
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Od liczby DJP zależy, czy dotyczy Cię ewidencja nawożenia '
            'i plan nawożenia azotem.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (stan.bezWspolczynnika > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${stan.bezWspolczynnika} sztuk bez grupy — te nie są policzone.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: MotywProsty.ostrzezenieObramowanie),
            ),
          ],
          if (stan.doWeryfikacji) ...[
            const SizedBox(height: MotywProsty.odstep),
            Ostrzezenie(
              tresc: 'Przeliczniki na DJP czekają na sprawdzenie w przepisie.',
              coZrobic: stan.zrodlo.isEmpty
                  ? 'Potwierdź wynik u doradcy.'
                  : 'Potwierdź u doradcy: ${stan.zrodlo}.',
            ),
          ],
        ],
      ),
    );
  }
}

/// Wybór grupy zwierząt ze słownika reguł — nazwy i przeliczniki są danymi.
///
/// Rozporządzenie wymienia ponad osiemdziesiąt grup, w tym zwierzęta, których
/// prawie nikt nie trzyma (szynszyle, jenoty, strusie). Pokazujemy od razu
/// pierwsze gatunki z listy — w słowniku stoją w kolejności od
/// najczęstszych — a resztę po naciśnięciu „Więcej zwierząt".
class WyborGrupyDjp extends StatefulWidget {
  const WyborGrupyDjp({
    super.key,
    required this.wspolczynniki,
    required this.wybrana,
    required this.onZmiana,
  });

  /// Ile gatunków widać bez rozwijania.
  static const int gatunkiNaStart = 6;

  final WspolczynnikiDjp wspolczynniki;
  final GrupaDjp? wybrana;
  final void Function(GrupaDjp) onZmiana;

  @override
  State<WyborGrupyDjp> createState() => _WyborGrupyDjpState();
}

class _WyborGrupyDjpState extends State<WyborGrupyDjp> {
  bool _wszystkie = false;

  @override
  Widget build(BuildContext context) {
    final gatunki = widget.wspolczynniki.gatunki;
    final widoczne = _wszystkie
        ? gatunki
        : gatunki.take(WyborGrupyDjp.gatunkiNaStart).toList(growable: false);
    final ukryte = gatunki.length - widoczne.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final gatunek in widoczne) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(gatunek, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final grupa in widget.wspolczynniki.grupyGatunku(gatunek))
                ChoiceChip(
                  label: Text(
                    grupa.nazwa,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  selected: widget.wybrana?.id == grupa.id,
                  onSelected: (_) => widget.onZmiana(grupa),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
            ],
          ),
        ],
        if (ukryte > 0) ...[
          const SizedBox(height: MotywProsty.odstep),
          OutlinedButton(
            onPressed: () => setState(() => _wszystkie = true),
            child: Text('Więcej zwierząt ($ukryte)'),
          ),
        ],
      ],
    );
  }
}
