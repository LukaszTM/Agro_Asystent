import 'package:flutter/material.dart';

import '../../../funkcje/pogoda/pogoda.dart';
import '../../../funkcje/pogoda/usluga_pogody.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import 'karta.dart';

/// Pogoda na pulpicie: najbliższe godziny i kilka dób naprzód.
///
/// Pogoda jest dodatkiem — bez internetu karta pokazuje **ostatni zapisany
/// odczyt razem z datą**, zamiast pustki albo wymyślonych liczb.
class KartaPogody extends StatelessWidget {
  const KartaPogody({
    super.key,
    required this.stan,
    required this.teraz,
    this.onOdswiez,
  });

  final StanPogody stan;
  final DateTime teraz;
  final VoidCallback? onOdswiez;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final prognoza = stan.prognoza;

    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Pogoda', style: teksty.headlineMedium)),
              if (onOdswiez != null)
                TextButton(
                  onPressed: onOdswiez,
                  child: const Text('Pobierz na nowo'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_podpis(prognoza), style: teksty.bodyMedium),
          if (stan.brakPolozenia) ...[
            const SizedBox(height: MotywKomputer.odstep),
            const OstrzezenieKomputer(
              tresc: 'Nie wiem, gdzie leży gospodarstwo.',
              coZrobic:
                  'Dodaj działkę po numerze — położenie policzę z jej '
                  'granic, bez pytania o adres.',
            ),
          ],
          if (stan.blad case final String wiadomosc) ...[
            const SizedBox(height: MotywKomputer.odstep),
            OstrzezenieKomputer(tresc: wiadomosc, coZrobic: stan.coZrobic),
          ],
          if (prognoza != null) ...[
            const SizedBox(height: MotywKomputer.odstep),
            _Godziny(godziny: prognoza.najblizszeGodziny(teraz, ile: 8)),
            const SizedBox(height: MotywKomputer.odstep),
            _Dni(dni: prognoza.dni.take(4).toList(), dzis: teraz),
            const SizedBox(height: MotywKomputer.odstep),
            Text(
              'Źródło: ${prognoza.zrodlo}. Wiatr podajemy w metrach na '
              'sekundę — dopuszczalną prędkość przy oprysku sprawdź na '
              'etykiecie środka.',
              style: teksty.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  String _podpis(Prognoza? prognoza) {
    if (prognoza == null) {
      return 'Prognozy jeszcze nie pobrano.';
    }
    final kiedy =
        '${Daty.krotko(prognoza.pobrano)}, '
        '${prognoza.pobrano.hour.toString().padLeft(2, '0')}:'
        '${prognoza.pobrano.minute.toString().padLeft(2, '0')}';
    return prognoza.starsza(teraz)
        ? 'Ostatni odczyt: $kiedy — starszy niż trzy godziny.'
        : 'Odczyt z $kiedy.';
  }
}

class _Godziny extends StatelessWidget {
  const _Godziny({required this.godziny});

  final List<GodzinaPogody> godziny;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final godzina in godziny)
            Container(
              width: 92,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: MotywKomputer.powierzchniaDruga,
                borderRadius: BorderRadius.circular(
                  MotywKomputer.zaokraglenieMale,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '${godzina.czas.hour.toString().padLeft(2, '0')}:00',
                    style: teksty.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(godzina.temperaturaOpis, style: teksty.bodyLarge),
                  Text(godzina.opadOpis, style: teksty.bodyMedium),
                  Text('${godzina.wiatrOpis} wiatr', style: teksty.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Dni extends StatelessWidget {
  const _Dni({required this.dni, required this.dzis});

  final List<DzienPogody> dni;
  final DateTime dzis;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      children: [
        for (final dzien in dni)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(
                    Daty.tenSamDzien(dzien.data, dzis)
                        ? 'dziś'
                        : '${Daty.dzienTygodnia(dzien.data)} '
                              '${dzien.data.day}.${dzien.data.month}',
                    style: teksty.bodyLarge,
                  ),
                ),
                Expanded(
                  child: Text(dzien.temperaturaOpis, style: teksty.bodyLarge),
                ),
                Expanded(
                  child: Text(
                    'opad ${dzien.opadOpis}',
                    style: teksty.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Text(
                    'wiatr do ${dzien.wiatrMax.round()} m/s',
                    style: teksty.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
