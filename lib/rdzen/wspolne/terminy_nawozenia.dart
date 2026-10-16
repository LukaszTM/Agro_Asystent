import 'package:flutter/material.dart';

import '../../funkcje/nawozenie/terminy_azotowe.dart';
import '../reguly/regula_prawna.dart';

/// Kolory i odstępy karty — każdy wygląd podaje swoje, żeby ten widget
/// nie musiał nic wiedzieć o `lib/wyglad/` (CLAUDE.md, reguły architektury).
class StylKarty {
  const StylKarty({
    required this.tlo,
    required this.obramowanie,
    required this.zaokraglenie,
    required this.odstep,
    this.grubosc = 2,
  });

  final Color tlo;
  final Color obramowanie;
  final double zaokraglenie;
  final double odstep;
  final double grubosc;
}

/// Do kiedy wolno stosować nawozy azotowe — z rozbiciem na rodzaj nawozu
/// i rodzaj gruntu, bo przepis daje inną datę dla obornika i dla gnojowicy.
///
/// Dla gruntów ornych termin zależy od gminy: wykazy z załączników do
/// programu azotanowego są danymi, a kod tylko dopasowuje gminę działki.
class KartaTerminowNawozenia extends StatelessWidget {
  const KartaTerminowNawozenia({
    super.key,
    required this.terminy,
    required this.zasady,
    required this.wGminach,
    required this.styl,
    required this.ostrzezenie,
  });

  final List<Termin> terminy;
  final ZasadyNawozeniaAzotem zasady;
  final TerminyGospodarstwa wGminach;

  /// Kolory i odstępy wyglądu, w którym karta stoi.
  final StylKarty styl;

  /// Ostrzeżenie w wyglądzie wywołującego — treść jest wspólna, bo znaczy
  /// to samo w obu wyglądach, a wygląd ramki należy do ekranu.
  final Widget Function(String tresc, String? coZrobic) ostrzezenie;

  static String _dzien(String dataRoczna) {
    final czesci = dataRoczna.split('-');
    if (czesci.length != 2) {
      return dataRoczna;
    }
    const miesiace = [
      'stycznia',
      'lutego',
      'marca',
      'kwietnia',
      'maja',
      'czerwca',
      'lipca',
      'sierpnia',
      'września',
      'października',
      'listopada',
      'grudnia',
    ];
    final miesiac = int.tryParse(czesci.first);
    final dzien = int.tryParse(czesci.last);
    if (miesiac == null || dzien == null || miesiac < 1 || miesiac > 12) {
      return dataRoczna;
    }
    return '$dzien ${miesiace[miesiac - 1]}';
  }

  /// Data dla tego terminu: z wykazu gmin, gdy przepis go przewiduje
  /// i gminy działek są znane; inaczej domyślna ze słownika.
  String? _data(Termin termin) {
    if (termin.wariantyGmin != null && !wGminach.pusty) {
      return wGminach.najwczesniejszy;
    }
    return termin.dataRoczna;
  }

  @override
  Widget build(BuildContext context) {
    if (terminy.isEmpty) {
      return const SizedBox.shrink();
    }
    // Daty są potwierdzone w rozporządzeniu; ostrzegamy tylko wtedy, gdy
    // któryś zapis naprawdę czeka na sprawdzenie.
    final niepewne =
        terminy.any((t) => t.doWeryfikacji) ||
        zasady.odstepstwa.any((o) => o.doWeryfikacji) ||
        zasady.zakazy.any((z) => z.doWeryfikacji);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(styl.odstep),
      decoration: BoxDecoration(
        color: styl.tlo,
        borderRadius: BorderRadius.circular(styl.zaokraglenie),
        border: Border.all(color: styl.obramowanie, width: styl.grubosc),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Do kiedy wolno nawozić',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (final termin in terminy) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${termin.coToZaNawoz ?? termin.nazwa}: '
                    'do ${_dzien(_data(termin) ?? '')}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (termin.okresOd != null)
                    Text(
                      'wolno od ${_dzien(termin.okresOd!)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  Text(
                    termin.rodzajGruntu == 'grunty_orne'
                        ? 'grunty orne'
                        : 'łąki, pastwiska, uprawy wieloletnie i trwałe',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
          if (wGminach.rozneTerminy) ...[
            const SizedBox(height: 4),
            Text(
              'Twoje działki leżą w gminach o różnych terminach. '
              'Powyżej stoi najwcześniejszy — pilnuj go, albo sprawdź '
              'termin osobno dla każdego pola.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (wGminach.dzialkiBezKoduGminy > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Przy ${wGminach.dzialkiBezKoduGminy} działkach nie rozpoznaliśmy '
              'gminy — dla nich termin może być inny.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          for (final zakaz in zasady.zakazy) ...[
            SizedBox(height: styl.odstep),
            ostrzezenie(
              zakaz.doWeryfikacji
                  ? '${zakaz.nazwa} — do sprawdzenia'
                  : zakaz.nazwa,
              zakaz.opis,
            ),
          ],
          for (final odstepstwo in zasady.odstepstwa) ...[
            SizedBox(height: styl.odstep),
            Text(
              odstepstwo.doDnia == null
                  ? '${odstepstwo.nazwa} — termin z tabeli nie obowiązuje'
                  : '${odstepstwo.nazwa} — wolno do '
                        '${_dzien(odstepstwo.doDnia!)}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              odstepstwo.kiedy,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (odstepstwo.limitAzotuKgNaHa != null)
              Text(
                'Najwyżej ${odstepstwo.limitAzotuKgNaHa!.toStringAsFixed(0)} '
                'kg N/ha — ${odstepstwo.limitDotyczy ?? ''}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (odstepstwo.wymagaDokumentowania)
              Text(
                'Trzeba zapisać: ${odstepstwo.wymaganeZapisy.join(', ')}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            if (odstepstwo.doDnia == null && odstepstwo.uwagi.isNotEmpty)
              Text(
                odstepstwo.uwagi,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
          if (zasady.odleglosciOdWod.odleglosci.isNotEmpty) ...[
            SizedBox(height: styl.odstep),
            Text(
              'Jak blisko wody',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            for (final odleglosc in zasady.odleglosciOdWod.odleglosci)
              Text(
                '${odleglosc.metry.toStringAsFixed(0)} m — '
                '${odleglosc.nazwa.toLowerCase()}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            Text(
              'Przy uprawie wolno o połowę mniej, ale nie bliżej niż '
              '${zasady.odleglosciOdWod.zmniejszenieNieMniejNizM.toStringAsFixed(0)} m: '
              '${zasady.odleglosciOdWod.warunkiZmniejszenia.join(' albo ')}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (zasady.wczesniejszeWiosna.jest) ...[
            SizedBox(height: styl.odstep),
            Text(
              'Wiosną wolno wcześniej',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              zasady.wczesniejszeWiosna.opis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            for (final prog in zasady.wczesniejszeWiosna.progi)
              Text(
                '${prog.stopnieC.toStringAsFixed(0)}°C — ${prog.dotyczy}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            Text(
              'Próg uznaje się za przejście po '
              '${zasady.wczesniejszeWiosna.dniPowyzejProgu} dniach z rzędu. '
              'Daty ogłasza ${zasady.wczesniejszeWiosna.ktoOglasza}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (niepewne) ...[
            SizedBox(height: styl.odstep),
            ostrzezenie(
              'Część zasad czeka na sprawdzenie w przepisie.',
              'Potwierdź u doradcy, zanim wyjedziesz w pole.',
            ),
          ],
        ],
      ),
    );
  }
}
