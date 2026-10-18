import 'dart:math' as math;

/// Położenie Słońca i Księżyca liczone na urządzeniu.
///
/// Program ma działać bez internetu, więc efemeryd nie pobieramy — liczymy
/// je skróconymi szeregami z „Astronomical Algorithms" Jeana Meeusa
/// (rozdz. 25 i 47). Dokładność rzędu 0,1 stopnia w zupełności wystarcza
/// do powiedzenia, w którym gwiazdozbiorze stoi Księżyc i jaka jest jego
/// faza; do nawigacji ten rachunek nie służy.
///
/// To czysta matematyka — żadnych progów ani terminów z przepisów.
abstract final class Astronomia {
  static const double _stopienNaRadian = math.pi / 180;

  /// Dzień juliański chwili. Liczymy w czasie uniwersalnym, bo szeregi
  /// Meeusa są w nim wyrażone.
  static double dzienJulianski(DateTime chwila) {
    final utc = chwila.toUtc();
    var rok = utc.year;
    var miesiac = utc.month;
    if (miesiac <= 2) {
      rok -= 1;
      miesiac += 12;
    }
    final a = (rok / 100).floor();
    final b = 2 - a + (a / 4).floor();
    final ulamekDnia = (utc.hour + utc.minute / 60 + utc.second / 3600) / 24;
    return (365.25 * (rok + 4716)).floor() +
        (30.6001 * (miesiac + 1)).floor() +
        utc.day +
        ulamekDnia +
        b -
        1524.5;
  }

  /// Wieki julianskie od epoki J2000.0.
  static double wieki(double dzienJulianski) =>
      (dzienJulianski - 2451545.0) / 36525;

  /// Długość ekliptyczna Słońca w stopniach (zodiak zwrotnikowy).
  static double dlugoscSlonca(double dzienJulianski) {
    final t = wieki(dzienJulianski);
    final sredniaDlugosc = 280.46646 + 36000.76983 * t + 0.0003032 * t * t;
    final anomalia = 357.52911 + 35999.05029 * t - 0.0001537 * t * t;
    final a = anomalia * _stopienNaRadian;
    final rownanieSrodka =
        (1.914602 - 0.004817 * t - 0.000014 * t * t) * math.sin(a) +
        (0.019993 - 0.000101 * t) * math.sin(2 * a) +
        0.000289 * math.sin(3 * a);
    return _doPelnegoKola(sredniaDlugosc + rownanieSrodka);
  }

  /// Długość ekliptyczna Księżyca w stopniach (zodiak zwrotnikowy).
  static double dlugoscKsiezyca(double dzienJulianski) {
    final t = wieki(dzienJulianski);
    final tt = t * t;
    final ttt = tt * t;
    final tttt = ttt * t;

    final srednia =
        218.3164477 +
        481267.88123421 * t -
        0.0015786 * tt +
        ttt / 538841 -
        tttt / 65194000;
    final elongacja =
        297.8501921 +
        445267.1114034 * t -
        0.0018819 * tt +
        ttt / 545868 -
        tttt / 113065000;
    final anomaliaSlonca =
        357.5291092 + 35999.0502909 * t - 0.0001536 * tt + ttt / 24490000;
    final anomaliaKsiezyca =
        134.9633964 +
        477198.8675055 * t +
        0.0087414 * tt +
        ttt / 69699 -
        tttt / 14712000;
    final argumentSzerokosci =
        93.2720950 +
        483202.0175233 * t -
        0.0036539 * tt -
        ttt / 3526000 +
        tttt / 863310000;

    // Poprawka na zmienny mimośród orbity Ziemi — dotyczy wyrazów
    // z anomalią Słońca.
    final e = 1 - 0.002516 * t - 0.0000074 * tt;

    final d = elongacja * _stopienNaRadian;
    final m = anomaliaSlonca * _stopienNaRadian;
    final mp = anomaliaKsiezyca * _stopienNaRadian;
    final f = argumentSzerokosci * _stopienNaRadian;

    // Największe wyrazy tabeli 47.A (w milionowych częściach stopnia).
    final suma =
        6288774 * math.sin(mp) +
        1274027 * math.sin(2 * d - mp) +
        658314 * math.sin(2 * d) +
        213618 * math.sin(2 * mp) +
        -185116 * e * math.sin(m) +
        -114332 * math.sin(2 * f) +
        58793 * math.sin(2 * d - 2 * mp) +
        57066 * e * math.sin(2 * d - m - mp) +
        53322 * math.sin(2 * d + mp) +
        45758 * e * math.sin(2 * d - m) +
        -40923 * e * math.sin(m - mp) +
        -34720 * math.sin(d) +
        -30383 * e * math.sin(m + mp) +
        15327 * math.sin(2 * d - 2 * f) +
        -12528 * math.sin(mp + 2 * f) +
        10980 * math.sin(mp - 2 * f) +
        10675 * math.sin(4 * d - mp) +
        10034 * math.sin(3 * mp) +
        8548 * math.sin(4 * d - 2 * mp) +
        -7888 * e * math.sin(2 * d + m - mp) +
        -6766 * e * math.sin(2 * d + m) +
        -5163 * math.sin(d - mp) +
        4987 * e * math.sin(d + m) +
        4036 * e * math.sin(2 * d - m + mp) +
        3994 * math.sin(2 * d + 2 * mp) +
        3861 * math.sin(4 * d) +
        3665 * math.sin(2 * d - 3 * mp);

    return _doPelnegoKola(srednia + suma / 1000000);
  }

  /// Odległość kątowa Księżyca od Słońca (0–360 stopni).
  ///
  /// 0 to nów, 180 — pełnia; wartości poniżej 180 znaczą, że Księżyc
  /// przybywa.
  static double elongacja(double dzienJulianski) => _doPelnegoKola(
    dlugoscKsiezyca(dzienJulianski) - dlugoscSlonca(dzienJulianski),
  );

  /// Jaka część tarczy jest oświetlona (0–1).
  static double oswietlenie(double dzienJulianski) {
    final kat = elongacja(dzienJulianski) * _stopienNaRadian;
    return (1 - math.cos(kat)) / 2;
  }

  static double _doPelnegoKola(double stopnie) {
    final reszta = stopnie % 360;
    return reszta < 0 ? reszta + 360 : reszta;
  }
}
