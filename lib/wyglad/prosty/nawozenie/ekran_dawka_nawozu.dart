import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../funkcje/nawozenie/plan_nawozenia.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/wybor_liczby.dart';
import 'ekran_zapisano_nawozenie.dart';

/// Wpis nawożenia, krok 4: dawka. Od razu widać, ile to azotu — to liczba,
/// którą rolnik musi pilnować przez cały rok.
class EkranDawkaNawozu extends StatefulWidget {
  const EkranDawkaNawozu({super.key, required this.uslugi, required this.dane});

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranDawkaNawozu> createState() => _EkranDawkaNawozuState();
}

class _EkranDawkaNawozuState extends State<EkranDawkaNawozu> {
  bool _zapisuje = false;

  /// Azot już zapisany na wybranych polach i limity z tabeli 14 —
  /// czytamy raz, bo przy każdym „+" zmienia się tylko dawka.
  late final Future<List<SkutekDlaMaksymalnejDawki>> _stanPol = widget
      .uslugi
      .planNawozenia
      .skutkiDlaMaksymalnejDawki(
        pola: widget.dane.pola,
        azotWpisuKgNaHa: 0,
        kiedy: widget.dane.kiedy,
      );

  double get _dawka => widget.dane.dawka ?? _domyslnaDawka;

  double get _domyslnaDawka =>
      widget.dane.jednostkaDawki == JednostkaDawki.kilogramyNaHektar ? 100 : 20;

  double get _krok =>
      widget.dane.jednostkaDawki == JednostkaDawki.kilogramyNaHektar ? 10 : 1;

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);

    final dane = widget.dane;
    await widget.uslugi.nawozenie.zapisz(
      gospodarstwoId: dane.gospodarstwoId,
      nawoz: dane.nawoz!,
      pola: [
        for (final pole in dane.pola)
          PoleZabiegu(
            dzialkaRolnaId: pole.id,
            powierzchniaAr: pole.powierzchniaAr,
          ),
      ],
      dawka: _dawka,
      jednostka: dane.jednostkaDawki,
      urzadzenie: dane.urzadzenie,
      kiedy: dane.kiedy,
    );

    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            EkranZapisanoNawozenie(uslugi: widget.uslugi, dane: dane),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dane = widget.dane;
    final nawoz = dane.nawoz!;
    dane.dawka ??= _domyslnaDawka;
    final azot = dane.azotKgNaHa;

    return Scaffold(
      appBar: AppBar(title: Text(nawoz.nazwa)),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          Text('Dawka', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MotywProsty.odstep),
          WyborLiczby(
            wartosc: _dawka,
            jednostka: dane.jednostkaDawki.opis,
            krok: _krok,
            minimum: _krok,
            onZmiana: (nowa) => setState(() => dane.dawka = nowa),
          ),
          const SizedBox(height: MotywProsty.odstep),
          Text('Jednostka', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final jednostka in JednostkaDawki.values)
                ChoiceChip(
                  label: Text(
                    jednostka.opis,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  selected: dane.jednostkaDawki == jednostka,
                  onSelected: (_) =>
                      setState(() => dane.jednostkaDawki = jednostka),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MotywProsty.odstep),
          if (azot != null)
            Text(
              'To ${azot.toStringAsFixed(0)} kg azotu na hektar, '
              'czyli ${(azot * dane.powierzchniaAr / 100).toStringAsFixed(0)} kg '
              'na ${dane.powierzchniaOpis}.',
              style: Theme.of(context).textTheme.bodyLarge,
            )
          else
            const Ostrzezenie(
              tresc: 'Ten nawóz nie ma wpisanej zawartości azotu.',
              coZrobic:
                  'Wpis zapiszemy, ale nie policzymy go do limitu '
                  'azotu — uzupełnij zawartość w spisie nawozów.',
            ),
          if (azot != null) ...[
            const SizedBox(height: MotywProsty.odstep),
            _MaksymalnaDawka(stanPol: _stanPol, azotWpisu: azot),
          ],
          const SizedBox(height: MotywProsty.odstep * 2),
          FilledButton(
            onPressed: _zapisuje ? null : _zapisz,
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
  }
}

/// Ostrzeżenie o maksymalnej dawce azotu dla uprawy (tabela 14 programu
/// azotanowego).
///
/// Ekran nie blokuje zapisu — rolnik mógł dać nawóz i musi móc to zapisać.
/// Pokazujemy to, co wie tabela, i co z tym zrobić.
class _MaksymalnaDawka extends StatelessWidget {
  const _MaksymalnaDawka({required this.stanPol, required this.azotWpisu});

  final Future<List<SkutekDlaMaksymalnejDawki>> stanPol;
  final double azotWpisu;

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<SkutekDlaMaksymalnejDawki>>(
        future: stanPol,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const SizedBox.shrink();
          }
          final pola = [for (final pole in stan.data!) pole.zDawka(azotWpisu)];
          final ostrzezenia = pola
              .where((pole) => pole.ostrzezenie != null)
              .toList(growable: false);
          if (ostrzezenia.isNotEmpty) {
            return Column(
              children: [
                for (final pole in ostrzezenia)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Ostrzezenie(
                      tresc: pole.ostrzezenie!,
                      coZrobic: pole.coZrobic ?? '',
                    ),
                  ),
              ],
            );
          }

          // Bez ostrzeżenia mówimy tylko, ile zostało — i tylko wtedy, gdy
          // tabela limit dla tej uprawy podaje.
          final zLimitem = pola
              .where((pole) => pole.limitKgNaHa != null)
              .toList(growable: false);
          if (zLimitem.isEmpty) {
            return const SizedBox.shrink();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final pole in zLimitem)
                Text(
                  '${pole.nazwaPola}: razem '
                  '${pole.azotRazemKgNaHa.toStringAsFixed(0)} '
                  'z ${pole.limitKgNaHa} kg azotu na hektar.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
            ],
          );
        },
      );
}
