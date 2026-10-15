import 'package:flutter/material.dart';

import '../../../app/uslugi.dart';
import '../../../funkcje/zabiegi/dane_wpisu.dart';
import '../../../rdzen/modele/zabieg.dart';
import '../motyw.dart';
import '../widgety/duzy_przycisk.dart';
import '../widgety/wybor_liczby.dart';
import 'ekran_zapisano.dart';

/// Krok 4: dawka i powód. Dawka jest już podpowiedziana z rejestru, więc
/// zwykle wystarczy nacisnąć „Zapisz".
class EkranDawka extends StatefulWidget {
  const EkranDawka({super.key, required this.uslugi, required this.dane});

  final Uslugi uslugi;
  final DaneWpisu dane;

  @override
  State<EkranDawka> createState() => _EkranDawkaState();
}

class _EkranDawkaState extends State<EkranDawka> {
  bool _zapisuje = false;

  Future<void> _zapisz() async {
    if (_zapisuje) {
      return;
    }
    setState(() => _zapisuje = true);

    final dane = widget.dane;
    final srodek = dane.srodek!;
    final identyfikator =
        'z-${DateTime.now().microsecondsSinceEpoch}-${dane.pola.first.id}';

    final zabieg = Zabieg(
      id: identyfikator,
      gospodarstwoId: dane.gospodarstwoId,
      rodzaj: dane.rodzaj ?? RodzajZabiegu.oprysk,
      data: dane.kiedy,
      godzina:
          '${dane.kiedy.hour.toString().padLeft(2, '0')}:${dane.kiedy.minute.toString().padLeft(2, '0')}',
      powierzchniaAr: dane.powierzchniaAr,
      urzadzenie: dane.urzadzenie,
    );

    await widget.uslugi.zabiegi.zapisz(
      zabieg: zabieg,
      pola: [
        for (final pole in dane.pola)
          PoleZabiegu(
            dzialkaRolnaId: pole.id,
            powierzchniaAr: pole.powierzchniaAr,
          ),
      ],
      oprysk: SzczegolyOprysku(
        zabiegId: identyfikator,
        srodekNazwa: srodek.nazwa,
        nrZezwolenia: srodek.nrZezwolenia,
        dawka: dane.dawka,
        dawkaJednostka: srodek.dawkaJednostka,
        dawkaOdniesienie: srodek.dawkaOdniesienie,
        przyczyna: dane.przyczyna,
        agrofag: srodek.agrofag,
        bbchOd: srodek.bbchOd,
        bbchDo: srodek.bbchDo,
        kodEppo: dane.pola.first.kodEppo,
        // Rolnik wybrał „Oprysk", więc rodzaj zastosowania jest znany
        // z jego wyboru — nie z domysłu (ewidencja wymaga tego pola).
        rodzajZastosowania: 'opryskiwanie',
        karencjaDni: srodek.karencjaZnana ? srodek.karencjaDni : null,
        karencjaZrodlo: srodek.karencjaZnana ? 'etykieta MRiRW' : null,
        karencjaDataEtykiety: srodek.karencjaDataEtykiety,
      ),
    );

    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => EkranZapisano(dane: dane, zabieg: zabieg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dane = widget.dane;
    final srodek = dane.srodek!;
    final maksymalna = srodek.dawka;
    final dawka = dane.dawka ?? maksymalna ?? 0;
    final razem = dane.iloscSrodkaRazem;

    return Scaffold(
      appBar: AppBar(title: Text(srodek.nazwa)),
      body: ListView(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        children: [
          if (!srodek.dawkaZnana)
            Ostrzezenie(
              tresc: 'Rejestr nie podaje tu dawki w jednoznacznej postaci.',
              coZrobic:
                  srodek.dawkaTekst ?? 'Sprawdź dawkę na etykiecie środka.',
            )
          else ...[
            Text('Dawka', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: MotywProsty.odstep),
            WyborLiczby(
              wartosc: dawka,
              jednostka: '${srodek.dawkaJednostka}/${srodek.dawkaOdniesienie}',
              krok: 0.05,
              maksimum: maksymalna,
              opisMaksimum: 'największa dopuszczalna: ${srodek.dawkaOpis}',
              onZmiana: (nowa) => setState(() => dane.dawka = nowa),
            ),
            if (maksymalna != null && dawka > maksymalna + 1e-9) ...[
              const SizedBox(height: MotywProsty.odstep),
              const Ostrzezenie(
                tresc: 'Ta dawka przekracza dopuszczalną z rejestru.',
                coZrobic:
                    'Zmniejsz dawkę przyciskiem „−" albo sprawdź etykietę.',
              ),
            ],
            if (razem != null) ...[
              const SizedBox(height: MotywProsty.odstep),
              Text(
                'Na ${dane.powierzchniaOpis} potrzeba '
                '${razem.toStringAsFixed(2).replaceAll('.', ',')} '
                '${srodek.dawkaJednostka}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ],
          const SizedBox(height: MotywProsty.odstep),
          Text('Powód zabiegu', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            dane.przyczyna ?? 'nie podano',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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
