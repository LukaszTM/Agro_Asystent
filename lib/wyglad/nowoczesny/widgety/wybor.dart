import 'package:flutter/material.dart';

import '../motyw.dart';

/// Wybór jednej możliwości — zamiast listy rozwijanej (CLAUDE.md, reguły
/// interfejsu: wybór z listy zamiast pisania).
class Wybor extends StatelessWidget {
  const Wybor({
    super.key,
    required this.etykieta,
    required this.wybrany,
    required this.onTap,
    this.ikona,
  });

  final String etykieta;
  final bool wybrany;
  final VoidCallback onTap;
  final IconData? ikona;

  @override
  Widget build(BuildContext context) {
    final zaokraglenie = BorderRadius.circular(
      MotywNowoczesny.zaokraglenieMale,
    );
    final kolorTekstu = wybrany ? MotywNowoczesny.karta : MotywNowoczesny.tekst;

    return Semantics(
      button: true,
      selected: wybrany,
      child: Material(
        color: wybrany ? MotywNowoczesny.zielen : MotywNowoczesny.karta,
        borderRadius: zaokraglenie,
        child: InkWell(
          borderRadius: zaokraglenie,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: MotywNowoczesny.minCelDotyku,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ikona != null) ...[
                  Icon(ikona, size: 18, color: kolorTekstu),
                  const SizedBox(width: 6),
                ],
                // Długa etykieta łamie się na dwie linie, zamiast
                // wychodzić za ekran — nazwy ze słownika mogą być dłuższe,
                // niż zmieści się na telefonie.
                Flexible(
                  child: Text(
                    etykieta,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: kolorTekstu),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Liczba z przyciskami „−" i „+" — bez klawiatury (reguły interfejsu).
class WyborLiczbyNowoczesny extends StatelessWidget {
  const WyborLiczbyNowoczesny({
    super.key,
    required this.wartosc,
    required this.jednostka,
    required this.krok,
    required this.onZmiana,
    this.maksimum,
    this.opisMaksimum,
  });

  final double wartosc;
  final String jednostka;
  final double krok;

  /// Największa wartość z rejestru albo z etykiety — przekroczenie
  /// pokazujemy, ale nie blokujemy: decyzja należy do rolnika.
  final double? maksimum;
  final String? opisMaksimum;

  final ValueChanged<double> onZmiana;

  static String _liczba(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _Krok(
              ikona: Icons.remove,
              opis: 'Zmniejsz dawkę',
              onTap: wartosc - krok <= 0
                  ? null
                  : () => onZmiana(
                      double.parse((wartosc - krok).toStringAsFixed(3)),
                    ),
            ),
            Expanded(
              child: Text(
                '${_liczba(wartosc)} $jednostka',
                textAlign: TextAlign.center,
                style: teksty.headlineMedium,
              ),
            ),
            _Krok(
              ikona: Icons.add,
              opis: 'Zwiększ dawkę',
              onTap: () =>
                  onZmiana(double.parse((wartosc + krok).toStringAsFixed(3))),
            ),
          ],
        ),
        if (opisMaksimum != null) ...[
          const SizedBox(height: 4),
          Text(opisMaksimum!, style: teksty.bodyMedium),
        ],
      ],
    );
  }
}

class _Krok extends StatelessWidget {
  const _Krok({required this.ikona, required this.opis, this.onTap});

  final IconData ikona;
  final String opis;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: opis,
      child: Material(
        color: MotywNowoczesny.karta,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: MotywNowoczesny.minCelDotyku,
            height: MotywNowoczesny.minCelDotyku,
            child: Icon(
              ikona,
              color: onTap == null
                  ? MotywNowoczesny.tekstPomocniczy
                  : MotywNowoczesny.zielen,
              semanticLabel: '',
            ),
          ),
        ),
      ),
    );
  }
}
