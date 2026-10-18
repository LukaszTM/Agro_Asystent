import 'package:flutter/material.dart';

import '../motyw.dart';

/// Karta programu na komputer: biała płaszczyzna z obramowaniem.
class KartaKomputer extends StatelessWidget {
  const KartaKomputer({super.key, required this.child, this.onKlik});

  final Widget child;
  final VoidCallback? onKlik;

  @override
  Widget build(BuildContext context) {
    final tresc = Padding(
      padding: const EdgeInsets.all(MotywKomputer.odstep),
      child: child,
    );
    final ksztalt = BorderRadius.circular(MotywKomputer.zaokraglenieKarty);
    return Container(
      decoration: BoxDecoration(
        color: MotywKomputer.karta,
        border: Border.all(color: MotywKomputer.obramowanie),
        borderRadius: ksztalt,
      ),
      child: onKlik == null
          ? tresc
          : InkWell(borderRadius: ksztalt, onTap: onKlik, child: tresc),
    );
  }
}

/// Ostrzeżenie: jedno zdanie, co się stało, i jedno, co zrobić.
///
/// Te same barwy co na telefonie — ostrzeżenie ma znaczyć to samo
/// niezależnie od urządzenia (plan, pkt 5).
class OstrzezenieKomputer extends StatelessWidget {
  const OstrzezenieKomputer({super.key, required this.tresc, this.coZrobic});

  final String tresc;
  final String? coZrobic;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MotywKomputer.odstep),
      decoration: BoxDecoration(
        color: MotywKomputer.ostrzezenieTlo,
        border: Border.all(
          color: MotywKomputer.ostrzezenieObramowanie,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(MotywKomputer.zaokraglenieMale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tresc, style: teksty.bodyLarge),
          if (coZrobic case final String rada) ...[
            const SizedBox(height: 6),
            Text(rada, style: teksty.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Nagłówek widoku: tytuł i jedno zdanie, co tu widać.
class NaglowekWidoku extends StatelessWidget {
  const NaglowekWidoku({super.key, required this.tytul, this.opis});

  final String tytul;
  final String? opis;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tytul, style: teksty.headlineMedium),
        if (opis case final String zdanie) ...[
          const SizedBox(height: 4),
          Text(zdanie, style: teksty.bodyMedium),
        ],
      ],
    );
  }
}
