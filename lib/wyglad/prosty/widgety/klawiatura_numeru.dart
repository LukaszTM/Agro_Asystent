import 'package:flutter/material.dart';

import '../motyw.dart';

/// Duża klawiatura do wpisania numeru działki — bez klawiatury systemowej
/// (plan, pkt 5: „liczby przyciskami albo dużą klawiaturą numeryczną").
///
/// Numer działki składa się z cyfr i trzech znaków rozdzielających
/// (`_`, `.`, `/`), więc poza cyframi dajemy tylko je.
class KlawiaturaNumeru extends StatelessWidget {
  const KlawiaturaNumeru({
    super.key,
    required this.onZnak,
    required this.onUsun,
    this.dodatkoweZnaki = const ['_', '.', '/'],
  });

  /// Dopisuje znak na końcu numeru.
  final void Function(String znak) onZnak;

  /// Usuwa ostatni znak.
  final VoidCallback onUsun;

  final List<String> dodatkoweZnaki;

  @override
  Widget build(BuildContext context) {
    final klawisze = <Widget>[
      for (var cyfra = 1; cyfra <= 9; cyfra++)
        _Klawisz(napis: '$cyfra', onTap: () => onZnak('$cyfra')),
      for (final znak in dodatkoweZnaki)
        _Klawisz(napis: znak, onTap: () => onZnak(znak)),
      _Klawisz(napis: '0', onTap: () => onZnak('0')),
      _Klawisz(napis: '⌫', etykieta: 'Usuń ostatni znak', onTap: onUsun),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: klawisze,
    );
  }
}

class _Klawisz extends StatelessWidget {
  const _Klawisz({required this.napis, required this.onTap, this.etykieta});

  final String napis;
  final VoidCallback onTap;
  final String? etykieta;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etykieta ?? napis,
      child: Material(
        color: MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: MotywProsty.minCelDotyku,
              minWidth: MotywProsty.minCelDotyku,
            ),
            child: Center(
              child: Text(
                napis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
