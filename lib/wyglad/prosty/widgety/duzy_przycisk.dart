import 'package:flutter/material.dart';

import '../motyw.dart';

/// Duży przycisk-kafelek: jeden wybór, trafiany palcem w rękawicy.
/// Cel dotyku nigdy mniejszy niż wymagany w planie (pkt 5).
class DuzyPrzycisk extends StatelessWidget {
  const DuzyPrzycisk({
    super.key,
    required this.etykieta,
    required this.onTap,
    this.opis,
    this.ikona,
    this.wyrozniony = false,
  });

  final String etykieta;
  final String? opis;
  final IconData? ikona;
  final bool wyrozniony;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final kolorTla = wyrozniony
        ? MotywProsty.zielenAkcji
        : MotywProsty.powierzchniaDruga;
    final kolorTekstu = wyrozniony
        ? MotywProsty.powierzchnia
        : MotywProsty.tekst;

    return Semantics(
      button: true,
      label: etykieta,
      child: Material(
        color: kolorTla,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
        child: InkWell(
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieDuze),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MotywProsty.minCelDotyku + 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(MotywProsty.odstep),
              child: Row(
                children: [
                  if (ikona != null) ...[
                    Icon(ikona, size: 40, color: kolorTekstu),
                    const SizedBox(width: MotywProsty.odstep),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          etykieta,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: kolorTekstu),
                        ),
                        if (opis != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              opis!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: kolorTekstu),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pasek ostrzeżenia: jedno zdanie i co zrobić (plan, pkt 5).
class Ostrzezenie extends StatelessWidget {
  const Ostrzezenie({super.key, required this.tresc, this.coZrobic});

  final String tresc;
  final String? coZrobic;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MotywProsty.odstep),
      decoration: BoxDecoration(
        color: MotywProsty.ostrzezenieTlo,
        border: Border.all(color: MotywProsty.ostrzezenieObramowanie, width: 2),
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tresc, style: Theme.of(context).textTheme.bodyLarge),
          if (coZrobic != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
