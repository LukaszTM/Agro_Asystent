import 'package:flutter/material.dart';

import 'motyw.dart';

/// Ekran zastępczy dla modułów, które powstaną w kolejnych krokach etapu 1.
/// Mówi wprost, czego jeszcze nie ma — bez pustych ekranów i bez udawania.
class EkranWBudowie extends StatelessWidget {
  const EkranWBudowie({super.key, required this.tytul, required this.coBedzie});

  final String tytul;
  final String coBedzie;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tytul)),
      body: Padding(
        padding: const EdgeInsets.all(MotywProsty.odstep),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(MotywProsty.odstep),
              decoration: BoxDecoration(
                color: MotywProsty.ostrzezenieTlo,
                border: Border.all(color: MotywProsty.ostrzezenieObramowanie),
                borderRadius: BorderRadius.circular(
                  MotywProsty.zaokraglenieMale,
                ),
              ),
              child: Text(
                'Ta część jeszcze nie działa.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: MotywProsty.odstep),
            Text(coBedzie, style: Theme.of(context).textTheme.bodyLarge),
            const Spacer(),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Wróć'),
            ),
          ],
        ),
      ),
    );
  }
}
