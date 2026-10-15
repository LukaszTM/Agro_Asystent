import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../funkcje/zabiegi/slownik_srodkow.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import 'ekran_dawka.dart';

/// Krok 3: czym opryskujemy. Lista zawężona do środków **dopuszczonych
/// w tej uprawie** — rolnik nie przewija całego rejestru.
class EkranWyborSrodka extends StatefulWidget {
  const EkranWyborSrodka({super.key, required this.uslugi, required this.dane});

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranWyborSrodka> createState() => _EkranWyborSrodkaState();
}

class _EkranWyborSrodkaState extends State<EkranWyborSrodka> {
  late Future<List<DopuszczonySrodek>> _srodki;
  String _szukane = '';

  String get _uprawa => widget.dane.pola.first.uprawa;

  @override
  void initState() {
    super.initState();
    _odswiez();
  }

  void _odswiez() {
    _srodki = _szukane.isEmpty
        ? widget.uslugi.srodki.dlaUprawy(_uprawa)
        : widget.uslugi.srodki.szukaj(_uprawa, _szukane);
  }

  void _wybierz(DopuszczonySrodek srodek) {
    widget.dane
      ..srodek = srodek
      ..dawka = srodek.dawka
      ..przyczyna = srodek.agrofag;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EkranDawka(uslugi: widget.uslugi, dane: widget.dane),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Czym opryskujesz?')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(MotywProsty.odstep),
            child: TextField(
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Szukaj po nazwie',
                prefixIcon: Icon(Icons.search, size: 28),
                border: OutlineInputBorder(),
              ),
              onChanged: (tekst) => setState(() {
                _szukane = tekst.trim();
                _odswiez();
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<DopuszczonySrodek>>(
              future: _srodki,
              builder: (context, stan) {
                if (!stan.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final srodki = stan.data!;
                if (srodki.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(MotywProsty.odstep),
                    child: Ostrzezenie(
                      tresc:
                          'Rejestr nie przewiduje tu żadnego środka '
                          'dla uprawy „$_uprawa".',
                      coZrobic: _szukane.isEmpty
                          ? 'Sprawdź, czy uprawa pola jest wpisana poprawnie.'
                          : 'Spróbuj wpisać inną część nazwy.',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(MotywProsty.odstep),
                  itemCount: srodki.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: MotywProsty.odstep),
                  itemBuilder: (context, numer) {
                    final srodek = srodki[numer];
                    return DuzyPrzycisk(
                      etykieta: srodek.nazwa,
                      opis: [
                        if (srodek.agrofag != null) srodek.agrofag!,
                        srodek.dawkaOpis,
                      ].join(' • '),
                      onTap: () => _wybierz(srodek),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
