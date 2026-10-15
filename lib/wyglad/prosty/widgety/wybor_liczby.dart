import 'package:flutter/material.dart';

import '../motyw.dart';

/// Wybór liczby przyciskami „+" i „−" — bez klawiatury (plan, pkt 5).
class WyborLiczby extends StatelessWidget {
  const WyborLiczby({
    super.key,
    required this.wartosc,
    required this.onZmiana,
    required this.jednostka,
    this.krok = 0.05,
    this.minimum = 0,
    this.maksimum,
    this.opisMaksimum,
  });

  final double wartosc;
  final double krok;
  final double minimum;
  final double? maksimum;
  final String jednostka;
  final String? opisMaksimum;
  final ValueChanged<double> onZmiana;

  bool get _przekroczonoMaksimum =>
      maksimum != null && wartosc > maksimum! + 1e-9;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Przycisk(
              znak: '−',
              etykieta: 'Mniej',
              onTap: wartosc - krok < minimum
                  ? null
                  : () => onZmiana(
                      double.parse((wartosc - krok).toStringAsFixed(3)),
                    ),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${wartosc.toStringAsFixed(2).replaceAll('.', ',')} $jednostka',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: _przekroczonoMaksimum
                          ? MotywProsty.ostrzezenieObramowanie
                          : MotywProsty.tekst,
                    ),
                  ),
                  if (opisMaksimum != null)
                    Text(
                      opisMaksimum!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
            _Przycisk(
              znak: '+',
              etykieta: 'Więcej',
              onTap: () =>
                  onZmiana(double.parse((wartosc + krok).toStringAsFixed(3))),
            ),
          ],
        ),
      ],
    );
  }
}

class _Przycisk extends StatelessWidget {
  const _Przycisk({required this.znak, required this.etykieta, this.onTap});

  final String znak;
  final String etykieta;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: etykieta,
      child: Material(
        color: onTap == null
            ? MotywProsty.powierzchnia
            : MotywProsty.powierzchniaDruga,
        borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
        child: InkWell(
          borderRadius: BorderRadius.circular(MotywProsty.zaokraglenieMale),
          onTap: onTap,
          child: SizedBox(
            width: 72,
            height: 72,
            child: Center(
              child: Text(
                znak,
                style: const TextStyle(fontSize: 34, color: MotywProsty.tekst),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
