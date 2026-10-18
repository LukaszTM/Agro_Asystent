import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motyw.dart';

/// Jeden kawałek wykresu kołowego.
class CzescWykresu {
  const CzescWykresu({
    required this.nazwa,
    required this.wartosc,
    required this.kolor,
    this.opis,
  });

  final String nazwa;

  /// Wielkość kawałka w dowolnej jednostce — wykres liczy udziały sam.
  final double wartosc;

  final Color kolor;

  /// Drugi wiersz w legendzie: powierzchnia, udział, liczba pól.
  final String? opis;
}

/// Wykres kołowy z legendą — struktura zasiewów na pulpicie.
///
/// Pierścień, nie pełne koło: w środku zostaje miejsce na liczbę, która
/// i tak jest najważniejsza (ile hektarów razem). Legenda stoi obok, bo
/// podpisy na kawałkach robią się nieczytelne przy wąskich udziałach.
class WykresKolowy extends StatelessWidget {
  const WykresKolowy({
    super.key,
    required this.czesci,
    this.srednica = 200,
    this.wSrodku,
    this.podSrodkiem,
  });

  final List<CzescWykresu> czesci;
  final double srednica;

  /// Duża liczba w środku pierścienia.
  final String? wSrodku;

  /// Podpis pod nią, drobnym tekstem.
  final String? podSrodkiem;

  @override
  Widget build(BuildContext context) {
    final teksty = Theme.of(context).textTheme;
    final suma = czesci.fold<double>(0, (s, c) => s + math.max(c.wartosc, 0));

    final kolo = SizedBox(
      width: srednica,
      height: srednica,
      child: CustomPaint(
        painter: _RysownikKola(czesci: czesci, suma: suma),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (wSrodku case final String liczba)
                Text(
                  liczba,
                  textAlign: TextAlign.center,
                  style: teksty.headlineMedium,
                ),
              if (podSrodkiem case final String podpis)
                Text(
                  podpis,
                  textAlign: TextAlign.center,
                  style: teksty.bodyMedium,
                ),
            ],
          ),
        ),
      ),
    );

    final legenda = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final czesc in czesci)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3, right: 10),
                  decoration: BoxDecoration(
                    color: czesc.kolor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(czesc.nazwa, style: teksty.bodyLarge),
                      if (czesc.opis case final String opis)
                        Text(opis, style: teksty.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    // Wykres bez podpisów nic nie mówi czytnikowi ekranu — dlatego ta sama
    // treść idzie słowami.
    return Semantics(
      label: [
        'Struktura zasiewów',
        for (final czesc in czesci)
          '${czesc.nazwa}${czesc.opis == null ? '' : ': ${czesc.opis}'}',
      ].join('. '),
      excludeSemantics: true,
      child: Wrap(
        spacing: MotywKomputer.odstep * 1.5,
        runSpacing: MotywKomputer.odstep,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          kolo,
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: legenda,
          ),
        ],
      ),
    );
  }
}

class _RysownikKola extends CustomPainter {
  _RysownikKola({required this.czesci, required this.suma});

  final List<CzescWykresu> czesci;
  final double suma;

  @override
  void paint(Canvas plotno, Size rozmiar) {
    final srodek = Offset(rozmiar.width / 2, rozmiar.height / 2);
    final promien = math.min(rozmiar.width, rozmiar.height) / 2;
    final grubosc = promien * 0.42;
    final sciezka = Rect.fromCircle(
      center: srodek,
      radius: promien - grubosc / 2,
    );

    if (suma <= 0) {
      plotno.drawArc(
        sciezka,
        0,
        math.pi * 2,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grubosc
          ..color = MotywKomputer.powierzchniaDruga,
      );
      return;
    }

    // Start u góry, zgodnie z ruchem wskazówek zegara — tak czyta się
    // każdy wykres na papierze.
    var kat = -math.pi / 2;
    for (final czesc in czesci) {
      final udzial = math.max(czesc.wartosc, 0) / suma;
      if (udzial <= 0) {
        continue;
      }
      final rozpietosc = udzial * math.pi * 2;
      plotno.drawArc(
        sciezka,
        kat,
        // Szpara między kawałkami, ale nigdy szersza niż sam kawałek.
        math.max(rozpietosc - 0.015, rozpietosc * 0.6),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grubosc
          ..color = czesc.kolor,
      );
      kat += rozpietosc;
    }
  }

  @override
  bool shouldRepaint(_RysownikKola stary) =>
      stary.suma != suma || stary.czesci.length != czesci.length;
}
