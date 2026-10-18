import 'package:flutter/material.dart';

import '../../../funkcje/ceny/ceny_skupu.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import 'karta.dart';
import 'tabela.dart';

/// Ceny skupu na pulpicie: notowania urzędowe dla regionu gospodarstwa.
///
/// Program nigdy nie udaje, że to cena dzisiejsza ani że to oferta
/// konkretnego skupu — pokazuje tydzień notowań i źródło.
class KartaCen extends StatelessWidget {
  const KartaCen({super.key, required this.slownik, this.wojewodztwo});

  /// `null`, gdy pliku notowań nie wczytano.
  final SlownikCen? slownik;

  /// Województwo gospodarstwa policzone z działek.
  final String? wojewodztwo;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final dane = slownik;

    if (dane == null || dane.pusty) {
      return KartaKomputer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ceny skupu', style: teksty.headlineMedium),
            const SizedBox(height: MotywKomputer.odstep),
            const OstrzezenieKomputer(
              tresc: 'Nie ma jeszcze wczytanych notowań.',
              coZrobic:
                  'Notowania przygotowuje skrypt na komputerze — program '
                  'nie pobiera stron ministerstwa z urządzenia rolnika. '
                  'Pustego miejsca nie wypełniamy zmyśloną ceną.',
            ),
          ],
        ),
      );
    }

    final ceny = CenySkupu.dlaGospodarstwa(dane, wojewodztwo: wojewodztwo);
    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ceny skupu', style: teksty.headlineMedium),
          const SizedBox(height: 4),
          Text(_podpis(dane), style: teksty.bodyMedium),
          const SizedBox(height: MotywKomputer.odstep),
          Tabela(
            kolumny: const [
              KolumnaTabeli('Produkt', udzial: 3),
              KolumnaTabeli('Cena', doPrawej: true, udzial: 2),
              KolumnaTabeli('Notowanie dla', udzial: 2),
            ],
            gdyPusta: 'W tym tygodniu nie ma notowań dla tego regionu.',
            wiersze: [
              for (final cena in ceny)
                WierszTabeli(
                  wartosci: [cena.produkt, cena.cenaOpis, cena.region],
                  podpis: [
                    if (!cena.zRegionuGospodarstwa)
                      'notowanie krajowe — dla tego województwa go nie ma',
                    if (cena.doWeryfikacji) 'odczyt do weryfikacji',
                  ].join(' • '),
                ),
            ],
          ),
          const SizedBox(height: MotywKomputer.odstep),
          Text(dane.zastrzezenie, style: teksty.bodyMedium),
        ],
      ),
    );
  }

  String _podpis(SlownikCen dane) {
    final tydzien = dane.tydzienOd == null || dane.tydzienDo == null
        ? ''
        : 'Notowania z tygodnia ${Daty.krotko(dane.tydzienOd!)} – '
              '${Daty.krotko(dane.tydzienDo!)}. ';
    final region = wojewodztwo == null
        ? 'Województwa gospodarstwa nie znamy — pokazujemy notowania '
              'krajowe.'
        : 'Województwo gospodarstwa: $wojewodztwo.';
    return '$tydzien$region Źródło: ${dane.zrodlo}.';
  }
}
