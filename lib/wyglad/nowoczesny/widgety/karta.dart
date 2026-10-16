import 'package:flutter/material.dart';

import '../motyw.dart';

/// Biała karta z zaokrągleniem — podstawowy klocek tego wyglądu.
class Karta extends StatelessWidget {
  const Karta({
    super.key,
    required this.child,
    this.onTap,
    this.wyrozniona = false,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Karta akcji — zielone tło, biały tekst.
  final bool wyrozniona;

  @override
  Widget build(BuildContext context) {
    final tlo = wyrozniona ? MotywNowoczesny.zielen : MotywNowoczesny.karta;
    final zaokraglenie = BorderRadius.circular(
      MotywNowoczesny.zaokraglenieKarty,
    );
    return Material(
      color: tlo,
      borderRadius: zaokraglenie,
      child: InkWell(
        borderRadius: zaokraglenie,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(MotywNowoczesny.odstep),
          child: child,
        ),
      ),
    );
  }
}

/// Ostrzeżenie: jedno zdanie i co zrobić (plan, pkt 5 — tak samo w obu
/// wyglądach, bo znaczy to samo).
class OstrzezenieNowoczesne extends StatelessWidget {
  const OstrzezenieNowoczesne({super.key, required this.tresc, this.coZrobic});

  final String tresc;
  final String? coZrobic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MotywNowoczesny.odstep),
      decoration: BoxDecoration(
        color: MotywNowoczesny.ostrzezenieTlo,
        border: Border.all(
          color: MotywNowoczesny.ostrzezenieObramowanie,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(MotywNowoczesny.zaokraglenieMale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tresc,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: MotywNowoczesny.tekst),
          ),
          if (coZrobic != null && coZrobic!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                coZrobic!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

/// Pasek postępu z opisem — dla azotu i innych limitów.
class PasekLimitu extends StatelessWidget {
  const PasekLimitu({
    super.key,
    required this.udzial,
    required this.opis,
    this.przekroczony = false,
  });

  /// Od 0 do 1; powyżej jedynki pasek jest pełny.
  final double udzial;

  final String opis;
  final bool przekroczony;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: udzial.clamp(0, 1),
            minHeight: 10,
            backgroundColor: MotywNowoczesny.tlo,
            color: przekroczony
                ? MotywNowoczesny.ostrzezenieObramowanie
                : MotywNowoczesny.zielen,
          ),
        ),
        const SizedBox(height: 6),
        Text(opis, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
