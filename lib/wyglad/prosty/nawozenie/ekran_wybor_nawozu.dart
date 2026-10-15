import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/nawozenie/nawoz.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_dawka_nawozu.dart';
import 'ekran_nawozy.dart';

/// Wpis nawożenia, krok 3: czym nawozimy. Lista z własnego spisu — bez
/// pisania na klawiaturze.
class EkranWyborNawozu extends StatefulWidget {
  const EkranWyborNawozu({super.key, required this.uslugi, required this.dane});

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranWyborNawozu> createState() => _EkranWyborNawozuState();
}

class _EkranWyborNawozuState extends State<EkranWyborNawozu> {
  late Future<List<Nawoz>> _nawozy;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _nawozy = widget.uslugi.nawozy.wszystkie(widget.uslugi.gospodarstwoId);
  }

  void _wybierz(Nawoz nawoz) {
    widget.dane
      ..nawoz = nawoz
      ..jednostkaDawki = nawoz.naturalny
          ? JednostkaDawki.tonyNaHektar
          : JednostkaDawki.kilogramyNaHektar
      ..dawka = null;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EkranDawkaNawozu(uslugi: widget.uslugi, dane: widget.dane),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Czym nawozisz?')),
      body: FutureBuilder<List<Nawoz>>(
        future: _nawozy,
        builder: (context, stan) {
          if (!stan.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final nawozy = stan.data!;
          return ListView(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            children: [
              if (nawozy.isEmpty)
                const Ostrzezenie(
                  tresc: 'Nie masz jeszcze żadnego nawozu w spisie.',
                  coZrobic:
                      'Dodaj nawóz — wystarczy nazwa i zawartość azotu '
                      'z worka albo z analizy.',
                ),
              for (final nawoz in nawozy) ...[
                DuzyPrzycisk(
                  etykieta: nawoz.nazwa,
                  opis: [
                    nawoz.naturalny ? 'naturalny' : 'mineralny',
                    nawoz.skladOpis,
                  ].join(' • '),
                  ikona: nawoz.naturalny
                      ? Icons.compost_outlined
                      : Icons.science_outlined,
                  onTap: () => _wybierz(nawoz),
                ),
                const SizedBox(height: MotywProsty.odstep),
              ],
              const SizedBox(height: MotywProsty.odstep),
              FilledButton(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => EkranNowyNawoz(uslugi: widget.uslugi),
                    ),
                  );
                  if (mounted) {
                    setState(_odswiez);
                  }
                },
                child: const Text('Dodaj nawóz'),
              ),
            ],
          );
        },
      ),
    );
  }
}
