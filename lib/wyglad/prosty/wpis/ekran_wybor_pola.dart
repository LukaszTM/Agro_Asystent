import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_pol.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_rodzaj_zabiegu.dart';

/// Krok 1: na którym polu. Lista pól z własną nazwą i powierzchnią.
class EkranWyborPola extends StatefulWidget {
  const EkranWyborPola({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranWyborPola> createState() => _EkranWyborPolaState();
}

class _EkranWyborPolaState extends State<EkranWyborPola> {
  late Future<List<Pole>> _pola;

  @override
  void initState() {
    super.initState();
    _pola = widget.uslugi.pola.wszystkie(widget.uslugi.gospodarstwoId);
  }

  void _wybierz(Pole pole) {
    final dane = DaneWpisu(
      gospodarstwoId: widget.uslugi.gospodarstwoId,
      urzadzenie: widget.uslugi.urzadzenie,
    )..pola.add(pole);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EkranRodzajZabiegu(uslugi: widget.uslugi, dane: dane),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Na którym polu?')),
      body: FutureBuilder<List<Pole>>(
        future: _pola,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final pola = stan.data!;
          if (pola.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(MotywProsty.odstep),
              child: Ostrzezenie(
                tresc: 'Nie masz jeszcze żadnego pola.',
                coZrobic:
                    'Dodaj pole w zakładce Pola — wystarczy nazwa, '
                    'uprawa i powierzchnia.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            itemCount: pola.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: MotywProsty.odstep),
            itemBuilder: (context, numer) {
              final pole = pola[numer];
              return DuzyPrzycisk(
                etykieta: pole.nazwa,
                opis: '${pole.uprawa} • ${pole.powierzchniaOpis}',
                ikona: Icons.crop_square,
                onTap: () => _wybierz(pole),
              );
            },
          );
        },
      ),
    );
  }
}
