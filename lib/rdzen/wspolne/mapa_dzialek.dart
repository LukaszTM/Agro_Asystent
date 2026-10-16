import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../funkcje/dzialki/repozytorium_dzialek.dart';
import '../uslugi/geometria.dart';

/// Barwy mapy. Mapa leży w `rdzen/wspolne/`, bo korzystają z niej oba
/// wyglądy — a `rdzen/` nie może zależeć od warstwy ekranów (CLAUDE.md).
/// Dlatego kolory podaje wygląd, nie mapa.
class BarwyMapy {
  const BarwyMapy({
    required this.tlo,
    required this.obramowanie,
    required this.dzialka,
    required this.wyrozniona,
    required this.kreska,
    required this.tekst,
    required this.zaokraglenie,
  });

  final Color tlo;
  final Color obramowanie;
  final Color dzialka;
  final Color wyrozniona;
  final Color kreska;
  final Color tekst;
  final double zaokraglenie;
}

/// Mapa działek rysowana z granic trzymanych na urządzeniu.
///
/// Bez podkładu zdjęciowego i bez serwera kafelków — działa w polu, gdzie nie
/// ma zasięgu (ADR-0003). Rolnik rozpoznaje pola po kształcie, położeniu
/// względem sąsiednich i po numerze.
class MapaDzialek extends StatelessWidget {
  const MapaDzialek({
    super.key,
    required this.dzialki,
    required this.barwy,
    this.wyrozniona,
    this.wysokosc = 260,
  });

  final BarwyMapy barwy;

  final List<DzialkaEwidencyjna> dzialki;

  /// Identyfikator działki pokazanej mocniejszym obrysem — np. tej właśnie
  /// pobranej, którą rolnik ma potwierdzić.
  final String? wyrozniona;

  final double wysokosc;

  @override
  Widget build(BuildContext context) {
    final zGranicami = dzialki
        .where((d) => d.maGranice)
        .toList(growable: false);
    if (zGranicami.isEmpty) {
      return const SizedBox.shrink();
    }
    return Semantics(
      label: 'Mapa działek',
      image: true,
      child: Container(
        height: wysokosc,
        decoration: BoxDecoration(
          color: barwy.tlo,
          borderRadius: BorderRadius.circular(barwy.zaokraglenie),
          border: Border.all(color: barwy.obramowanie, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: CustomPaint(
          painter: _RysownikDzialek(
            dzialki: zGranicami,
            barwy: barwy,
            wyrozniona: wyrozniona,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _RysownikDzialek extends CustomPainter {
  _RysownikDzialek({
    required this.dzialki,
    required this.barwy,
    this.wyrozniona,
  });

  final List<DzialkaEwidencyjna> dzialki;
  final BarwyMapy barwy;
  final String? wyrozniona;

  @override
  void paint(Canvas plotno, Size rozmiar) {
    final wszystkieObrysy = [for (final dzialka in dzialki) ...dzialka.obrysy];
    if (wszystkieObrysy.isEmpty) {
      return;
    }
    final zasieg = Geometria.zasieg(wszystkieObrysy);

    // Stopień długości geograficznej jest u nas krótszy niż stopień
    // szerokości — bez tej poprawki działki byłyby rozciągnięte.
    final srednia = (zasieg.minSzerokosc + zasieg.maxSzerokosc) / 2;
    final skalaDlugosci = math.cos(srednia * math.pi / 180);
    final szerokoscGeo = math.max(
      (zasieg.maxDlugosc - zasieg.minDlugosc) * skalaDlugosci,
      1e-9,
    );
    final wysokoscGeo = math.max(
      zasieg.maxSzerokosc - zasieg.minSzerokosc,
      1e-9,
    );

    const margines = 12.0;
    final skala = math.min(
      (rozmiar.width - 2 * margines) / szerokoscGeo,
      (rozmiar.height - 2 * margines) / wysokoscGeo,
    );
    final przesuniecieX = (rozmiar.width - szerokoscGeo * skala) / 2;
    final przesuniecieY = (rozmiar.height - wysokoscGeo * skala) / 2;

    Offset naEkran(Punkt punkt) => Offset(
      przesuniecieX +
          (punkt.dlugosc - zasieg.minDlugosc) * skalaDlugosci * skala,
      rozmiar.height -
          przesuniecieY -
          (punkt.szerokosc - zasieg.minSzerokosc) * skala,
    );

    for (final dzialka in dzialki) {
      final czyWyrozniona = dzialka.identyfikator == wyrozniona;
      final wypelnienie = Paint()
        ..style = PaintingStyle.fill
        ..color = czyWyrozniona ? barwy.wyrozniona : barwy.dzialka;
      final obrys = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = czyWyrozniona ? 4 : 2
        ..color = barwy.kreska;

      for (final pierscien in dzialka.obrysy) {
        final sciezka = Path()
          ..addPolygon(pierscien.map(naEkran).toList(), true);
        plotno.drawPath(sciezka, wypelnienie);
        plotno.drawPath(sciezka, obrys);
      }

      final numer = dzialka.nrDzialki ?? dzialka.identyfikator.split('.').last;
      final srodek = naEkran(Geometria.srodek(dzialka.obrysy.first));
      final napis = TextPainter(
        text: TextSpan(
          text: numer,
          style: TextStyle(
            color: barwy.tekst,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      napis.paint(plotno, srodek - Offset(napis.width / 2, napis.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RysownikDzialek poprzedni) =>
      poprzedni.dzialki != dzialki || poprzedni.wyrozniona != wyrozniona;
}
