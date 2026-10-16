import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/dzialki/repozytorium_dzialek.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_dodaj_dzialke.dart';
import '../../../rdzen/wspolne/mapa_dzialek.dart';

/// Działki ewidencyjne gospodarstwa i mapa ich granic.
///
/// Mapa powstaje z granic zapisanych na urządzeniu — po dodaniu działki nie
/// potrzebuje już internetu (plan, pkt 2 i 4 krok 1).
class EkranDzialki extends StatefulWidget {
  const EkranDzialki({super.key, required this.uslugi});

  final Uslugi uslugi;

  @override
  State<EkranDzialki> createState() => _EkranDzialkiState();
}

class _EkranDzialkiState extends State<EkranDzialki> {
  late Future<List<DzialkaEwidencyjna>> _dzialki;
  String? _ostatniaDodana;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _dzialki = widget.uslugi.dzialki.wszystkie(widget.uslugi.gospodarstwoId);
  }

  Future<void> _dodaj() async {
    final dodano = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EkranDodajDzialke(uslugi: widget.uslugi),
      ),
    );
    if (dodano ?? false) {
      setState(_odswiez);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Działki')),
      body: FutureBuilder<List<DzialkaEwidencyjna>>(
        future: _dzialki,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dzialki = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              if (dzialki.isEmpty)
                const Ostrzezenie(
                  tresc: 'Nie masz jeszcze żadnej działki.',
                  coZrobic:
                      'Naciśnij „Dodaj działkę po numerze" i przepisz '
                      'numer z wniosku.',
                )
              else ...[
                MapaDzialek(
                  dzialki: dzialki,
                  barwy: MotywProsty.barwyMapy,
                  wyrozniona: _ostatniaDodana,
                ),
                const SizedBox(height: MotywProsty.odstep),
              ],
              for (final dzialka in dzialki) ...[
                DuzyPrzycisk(
                  etykieta: dzialka.identyfikator,
                  opis: [
                    if (dzialka.polozenie.isNotEmpty) dzialka.polozenie,
                    'około ${dzialka.powierzchniaOpis}',
                  ].join(' • '),
                  ikona: dzialka.maGranice
                      ? Icons.pentagon_outlined
                      : Icons.help_outline,
                  onTap: dzialka.maGranice
                      ? () => setState(
                          () => _ostatniaDodana = dzialka.identyfikator,
                        )
                      : null,
                ),
                const SizedBox(height: MotywProsty.odstep),
              ],
              const SizedBox(height: MotywProsty.odstep),
              FilledButton(
                onPressed: _dodaj,
                child: const Text('Dodaj działkę po numerze'),
              ),
            ],
          );
        },
      ),
    );
  }
}
