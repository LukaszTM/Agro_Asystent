import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Ikony kalendarza biodynamicznego w stylu drukowanych kalendarzy
/// rolników: rączka siewna, rodzaj pracy (korzeń, liść, kwiat, owoc,
/// gleba) i tarcza Księżyca w dni faz głównych.
///
/// Rysowane, nie z czcionki ikon — w czcionce nie ma rączki siejącej ani
/// marchewki, a rolnik zna te znaki z kalendarza na ścianie. Kolory
/// podaje ekran z motywu; tu nie ma żadnego koloru na stałe.

/// Rączka siewna: jedna (dobry dzień), dwie (bardzo dobry) albo
/// przekreślona (zły dzień do siewu).
class IkonaRaczki extends StatelessWidget {
  const IkonaRaczki({
    super.key,
    required this.ile,
    required this.kolor,
    this.przekreslona = false,
    this.kolorKreski,
    this.rozmiar = 24,
  });

  /// 1 albo 2 rączki.
  final int ile;
  final Color kolor;
  final bool przekreslona;

  /// Kolor kreski przekreślenia — zwykle barwa ostrzeżenia z motywu.
  final Color? kolorKreski;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    final szerokosc = ile > 1 ? rozmiar * 1.7 : rozmiar;
    return Semantics(
      label: przekreslona
          ? 'zły dzień do siewu'
          : (ile > 1 ? 'bardzo dobry dzień do siewu' : 'dobry dzień do siewu'),
      child: CustomPaint(
        size: Size(szerokosc, rozmiar),
        painter: _RaczkaPainter(
          ile: ile,
          kolor: kolor,
          kreska: przekreslona ? (kolorKreski ?? kolor) : null,
        ),
      ),
    );
  }
}

class _RaczkaPainter extends CustomPainter {
  const _RaczkaPainter({required this.ile, required this.kolor, this.kreska});

  final int ile;
  final Color kolor;
  final Color? kreska;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.height;
    for (var numer = 0; numer < ile; numer++) {
      canvas.save();
      canvas.translate(numer * w * 0.7, 0);
      _jednaRaczka(canvas, w);
      canvas.restore();
    }
    if (kreska case final Color kolorKreski) {
      final pedzel = Paint()
        ..color = kolorKreski
        ..strokeWidth = w * 0.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(w * 0.1, w * 0.9),
        Offset(size.width - w * 0.1, w * 0.1),
        pedzel,
      );
    }
  }

  /// Dłoń odwrócona wnętrzem w dół, z której sypią się ziarna.
  void _jednaRaczka(Canvas canvas, double w) {
    final pedzel = Paint()..color = kolor;
    // Dłoń: lekko pochylony owal.
    canvas.save();
    canvas.translate(w * 0.42, w * 0.38);
    canvas.rotate(-0.35);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: w * 0.58, height: w * 0.34),
      pedzel,
    );
    canvas.restore();
    // Palce: trzy krótkie promienie od dłoni w dół-prawo.
    final palec = Paint()
      ..color = kolor
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round;
    for (final (dx, dy) in [(0.62, 0.52), (0.70, 0.42), (0.74, 0.30)]) {
      canvas.drawLine(
        Offset(w * 0.52, w * 0.36),
        Offset(w * dx, w * dy),
        palec,
      );
    }
    // Kciuk.
    canvas.drawLine(
      Offset(w * 0.30, w * 0.28),
      Offset(w * 0.18, w * 0.14),
      palec,
    );
    // Ziarna sypiące się z dłoni.
    final ziarno = Paint()..color = kolor;
    for (final (dx, dy, r) in [
      (0.60, 0.70, 0.055),
      (0.48, 0.80, 0.05),
      (0.70, 0.88, 0.05),
      (0.36, 0.92, 0.045),
    ]) {
      canvas.drawCircle(Offset(w * dx, w * dy), w * r, ziarno);
    }
  }

  @override
  bool shouldRepaint(_RaczkaPainter stary) =>
      stary.ile != ile || stary.kolor != kolor || stary.kreska != kreska;
}

/// Rodzaj pracy: korzeń (marchew), liść, kwiat, owoc (jabłko) albo gleba
/// (szpadel) — gdy tradycja radzi pracę w ziemi zamiast siewu.
class IkonaPracy extends StatelessWidget {
  const IkonaPracy({
    super.key,
    required this.praca,
    required this.kolor,
    this.rozmiar = 24,
  });

  /// „korzeń", „liść", „kwiat", „owoc" albo `null` (gleba).
  final String? praca;
  final Color kolor;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: praca == null ? 'prace w glebie' : 'dzień: $praca',
      child: CustomPaint(
        size: Size(rozmiar, rozmiar),
        painter: _PracaPainter(praca: praca, kolor: kolor),
      ),
    );
  }
}

class _PracaPainter extends CustomPainter {
  const _PracaPainter({required this.praca, required this.kolor});

  final String? praca;
  final Color kolor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final wypelnienie = Paint()..color = kolor;
    final kreska = Paint()
      ..color = kolor
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.1
      ..strokeCap = StrokeCap.round;
    switch (praca) {
      case 'korzeń':
        // Marchew: trójkąt w dół i nać.
        final marchew = Path()
          ..moveTo(w * 0.32, w * 0.32)
          ..lineTo(w * 0.68, w * 0.32)
          ..lineTo(w * 0.50, w * 0.96)
          ..close();
        canvas.drawPath(marchew, wypelnienie);
        for (final dx in [0.38, 0.50, 0.62]) {
          canvas.drawLine(
            Offset(w * 0.5, w * 0.30),
            Offset(w * dx, w * 0.06),
            kreska,
          );
        }
      case 'liść':
        final lisc = Path()
          ..moveTo(w * 0.12, w * 0.88)
          ..quadraticBezierTo(w * 0.10, w * 0.25, w * 0.88, w * 0.12)
          ..quadraticBezierTo(w * 0.80, w * 0.85, w * 0.12, w * 0.88)
          ..close();
        canvas.drawPath(lisc, wypelnienie);
        canvas.drawLine(
          Offset(w * 0.20, w * 0.80),
          Offset(w * 0.72, w * 0.28),
          kreska..color = Colors.white.withValues(alpha: 0.7),
        );
      case 'kwiat':
        for (var i = 0; i < 5; i++) {
          final kat = i * 2 * math.pi / 5 - math.pi / 2;
          canvas.drawCircle(
            Offset(
              w * 0.5 + math.cos(kat) * w * 0.28,
              w * 0.5 + math.sin(kat) * w * 0.28,
            ),
            w * 0.17,
            wypelnienie,
          );
        }
        canvas.drawCircle(
          Offset(w * 0.5, w * 0.5),
          w * 0.14,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
      case 'owoc':
        // Jabłko: koło z wcięciem u góry, ogonek i listek.
        canvas.drawCircle(Offset(w * 0.5, w * 0.58), w * 0.36, wypelnienie);
        canvas.drawLine(
          Offset(w * 0.5, w * 0.26),
          Offset(w * 0.56, w * 0.06),
          kreska,
        );
        final listek = Path()
          ..moveTo(w * 0.56, w * 0.18)
          ..quadraticBezierTo(w * 0.70, w * 0.02, w * 0.84, w * 0.12)
          ..quadraticBezierTo(w * 0.72, w * 0.26, w * 0.56, w * 0.18)
          ..close();
        canvas.drawPath(listek, wypelnienie);
      default:
        // Szpadel: trzonek z uchwytem i ostrze.
        canvas.drawLine(
          Offset(w * 0.5, w * 0.10),
          Offset(w * 0.5, w * 0.52),
          kreska,
        );
        canvas.drawLine(
          Offset(w * 0.36, w * 0.10),
          Offset(w * 0.64, w * 0.10),
          kreska,
        );
        final ostrze = Path()
          ..moveTo(w * 0.28, w * 0.50)
          ..lineTo(w * 0.72, w * 0.50)
          ..lineTo(w * 0.68, w * 0.82)
          ..quadraticBezierTo(w * 0.5, w * 0.98, w * 0.32, w * 0.82)
          ..close();
        canvas.drawPath(ostrze, wypelnienie);
    }
  }

  @override
  bool shouldRepaint(_PracaPainter stary) =>
      stary.praca != praca || stary.kolor != kolor;
}

/// Tarcza Księżyca w dniu fazy głównej: nów (ciemna), pełnia (jasna),
/// kwadry (pół na pół).
class IkonaFazy extends StatelessWidget {
  const IkonaFazy({
    super.key,
    required this.stopnie,
    required this.kolorCiemny,
    required this.kolorJasny,
    this.rozmiar = 22,
  });

  /// Elongacja fazy: 0 nów, 90 pierwsza kwadra, 180 pełnia, 270 ostatnia.
  final double stopnie;
  final Color kolorCiemny;
  final Color kolorJasny;
  final double rozmiar;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(rozmiar, rozmiar),
      painter: _FazaPainter(
        stopnie: stopnie,
        ciemny: kolorCiemny,
        jasny: kolorJasny,
      ),
    );
  }
}

class _FazaPainter extends CustomPainter {
  const _FazaPainter({
    required this.stopnie,
    required this.ciemny,
    required this.jasny,
  });

  final double stopnie;
  final Color ciemny;
  final Color jasny;

  @override
  void paint(Canvas canvas, Size size) {
    final srodek = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1;
    final obrys = Paint()
      ..color = ciemny
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final faza = stopnie % 360;
    if (faza < 45 || faza >= 315) {
      canvas.drawCircle(srodek, r, Paint()..color = ciemny);
    } else if (faza >= 135 && faza < 225) {
      canvas.drawCircle(srodek, r, Paint()..color = jasny);
      canvas.drawCircle(srodek, r, obrys);
    } else {
      // Kwadra: prawa połowa jasna, gdy przybywa; lewa, gdy ubywa.
      canvas.drawCircle(srodek, r, Paint()..color = ciemny);
      final prostokat = Rect.fromCircle(center: srodek, radius: r);
      final przybywa = faza < 180;
      canvas.drawArc(
        prostokat,
        przybywa ? -math.pi / 2 : math.pi / 2,
        math.pi,
        true,
        Paint()..color = jasny,
      );
      canvas.drawCircle(srodek, r, obrys);
    }
  }

  @override
  bool shouldRepaint(_FazaPainter stary) =>
      stary.stopnie != stopnie ||
      stary.ciemny != ciemny ||
      stary.jasny != jasny;
}
