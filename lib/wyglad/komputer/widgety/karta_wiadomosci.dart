import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../funkcje/wiadomosci/usluga_wiadomosci.dart';
import '../../../funkcje/wiadomosci/wiadomosci.dart';
import '../../../rdzen/wspolne/daty.dart';
import '../motyw.dart';
import 'karta.dart';

/// Wiadomości z branży rolniczej — nagłówki i odnośniki do wydawców.
///
/// Program pokazuje tytuł, krótką zajawkę i nazwę źródła. Cały artykuł
/// czyta się u wydawcy — to jego tekst i jego strona.
class KartaWiadomosci extends StatelessWidget {
  const KartaWiadomosci({
    super.key,
    required this.stan,
    required this.teraz,
    this.onOdswiez,
    this.onOtworz,
  });

  final StanWiadomosci stan;
  final DateTime teraz;
  final VoidCallback? onOdswiez;

  /// Otwarcie artykułu. W programie przeglądarka, w testach zapis wywołania.
  final void Function(String odnosnik)? onOtworz;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return KartaKomputer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wiadomości z branży',
                  style: teksty.headlineMedium,
                ),
              ),
              if (onOdswiez != null)
                TextButton(
                  onPressed: onOdswiez,
                  child: const Text('Pobierz na nowo'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_podpis(), style: teksty.bodyMedium),
          if (stan.brakZrodel) ...[
            const SizedBox(height: MotywKomputer.odstep),
            const OstrzezenieKomputer(
              tresc: 'Nie ustawiono żadnego źródła wiadomości.',
              coZrobic:
                  'Lista kanałów jest plikiem danych programu — dojdzie '
                  'razem z aktualizacją.',
            ),
          ] else if (stan.nicNieOdpowiedzialo && stan.pusty) ...[
            const SizedBox(height: MotywKomputer.odstep),
            const OstrzezenieKomputer(
              tresc: 'Żadne źródło nie odpowiedziało.',
              coZrobic:
                  'Sprawdź internet. Wiadomości to dodatek — reszta '
                  'programu działa bez nich.',
            ),
          ],
          const SizedBox(height: MotywKomputer.odstep),
          for (final wiadomosc in stan.wiadomosci)
            _Wiersz(
              wiadomosc: wiadomosc,
              onOtworz: () => _otworz(wiadomosc.odnosnik),
            ),
        ],
      ),
    );
  }

  String _podpis() {
    if (stan.pobrano case final DateTime kiedy) {
      return 'Pobrano ${Daty.krotko(kiedy)}, '
          '${kiedy.hour.toString().padLeft(2, '0')}:'
          '${kiedy.minute.toString().padLeft(2, '0')}. '
          'Cały artykuł otwiera się u wydawcy.';
    }
    return 'Nagłówki z kanałów branżowych. Cały artykuł otwiera się '
        'u wydawcy.';
  }

  Future<void> _otworz(String odnosnik) async {
    if (onOtworz != null) {
      onOtworz!(odnosnik);
      return;
    }
    final adres = Uri.tryParse(odnosnik);
    if (adres != null) {
      await launchUrl(adres, mode: LaunchMode.externalApplication);
    }
  }
}

class _Wiersz extends StatelessWidget {
  const _Wiersz({required this.wiadomosc, required this.onOtworz});

  final Wiadomosc wiadomosc;
  final VoidCallback onOtworz;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onOtworz,
        borderRadius: BorderRadius.circular(MotywKomputer.zaokraglenieMale),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wiadomosc.tytul,
                style: teksty.bodyLarge?.copyWith(
                  color: MotywKomputer.zielen,
                  decoration: TextDecoration.underline,
                  decorationColor: MotywKomputer.zielen,
                ),
              ),
              if (wiadomosc.zajawka case final String zajawka)
                Text(zajawka, style: teksty.bodyMedium),
              Text(
                [
                  wiadomosc.zrodlo,
                  if (wiadomosc.data case final DateTime kiedy)
                    Daty.krotko(kiedy),
                ].join(' • '),
                style: teksty.bodyMedium?.copyWith(
                  color: MotywKomputer.tekstPomocniczy,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
