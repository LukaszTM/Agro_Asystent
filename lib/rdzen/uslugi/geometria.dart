import 'dart:math' as math;

/// Punkt w układzie WGS 84: długość i szerokość geograficzna.
typedef Punkt = ({double dlugosc, double szerokosc});

/// Obrys działki: pierścień zewnętrzny i ewentualne wycięcia.
typedef Pierscien = List<Punkt>;

/// Odczyt geometrii z zapisu WKT i proste rachunki na niej.
///
/// Obsługujemy tylko to, co zwraca ULDK dla działek ewidencyjnych: wielokąt
/// i wielokąt złożony. Nie piszemy własnej biblioteki geometrycznej — wystarczy
/// tyle, żeby narysować działkę i policzyć jej środek oraz zasięg.
abstract final class Geometria {
  /// Usługa zwraca geometrię z przedrostkiem układu: „SRID=4326;POLYGON(...)".
  static (String wkt, int? srid) rozdzielSrid(String zapis) {
    final tekst = zapis.trim();
    if (!tekst.toUpperCase().startsWith('SRID=')) {
      return (tekst, null);
    }
    final srednik = tekst.indexOf(';');
    if (srednik < 0) {
      return (tekst, null);
    }
    final srid = int.tryParse(tekst.substring(5, srednik).trim());
    return (tekst.substring(srednik + 1).trim(), srid);
  }

  /// Zamienia WKT na listę pierścieni. Rzuca [FormatException] przy zapisie,
  /// którego nie rozumiemy — lepiej błąd niż narysowanie czegoś przypadkowego.
  static List<Pierscien> zWkt(String wkt) {
    final (tekst, _) = rozdzielSrid(wkt);
    final rodzaj = tekst.split('(').first.trim().toUpperCase();
    if (rodzaj != 'POLYGON' && rodzaj != 'MULTIPOLYGON') {
      throw FormatException('Nieobsługiwany rodzaj geometrii: $rodzaj');
    }

    final pierscienie = <Pierscien>[];
    for (final dopasowanie in RegExp(r'\(([^()]*)\)').allMatches(tekst)) {
      final tresc = dopasowanie.group(1)!.trim();
      if (tresc.isEmpty) {
        continue;
      }
      final punkty = <Punkt>[];
      for (final para in tresc.split(',')) {
        final liczby = para.trim().split(RegExp(r'\s+'));
        if (liczby.length < 2) {
          continue;
        }
        final dlugosc = double.tryParse(liczby[0]);
        final szerokosc = double.tryParse(liczby[1]);
        if (dlugosc == null || szerokosc == null) {
          throw FormatException('Nieczytelne współrzędne: ${para.trim()}');
        }
        punkty.add((dlugosc: dlugosc, szerokosc: szerokosc));
      }
      if (punkty.length >= 3) {
        pierscienie.add(punkty);
      }
    }
    if (pierscienie.isEmpty) {
      throw const FormatException('Geometria nie zawiera żadnego obrysu');
    }
    return pierscienie;
  }

  /// Najmniejszy prostokąt obejmujący podane obrysy.
  static ({
    double minDlugosc,
    double minSzerokosc,
    double maxDlugosc,
    double maxSzerokosc,
  })
  zasieg(List<Pierscien> pierscienie) {
    final punkty = pierscienie.expand((p) => p).toList(growable: false);
    if (punkty.isEmpty) {
      throw const FormatException('Brak punktów do obliczenia zasięgu');
    }
    var minD = punkty.first.dlugosc;
    var maxD = punkty.first.dlugosc;
    var minS = punkty.first.szerokosc;
    var maxS = punkty.first.szerokosc;
    for (final punkt in punkty) {
      minD = math.min(minD, punkt.dlugosc);
      maxD = math.max(maxD, punkt.dlugosc);
      minS = math.min(minS, punkt.szerokosc);
      maxS = math.max(maxS, punkt.szerokosc);
    }
    return (
      minDlugosc: minD,
      minSzerokosc: minS,
      maxDlugosc: maxD,
      maxSzerokosc: maxS,
    );
  }

  /// Powierzchnia obrysu w hektarach.
  ///
  /// Współrzędne przeliczamy na metry na średniej szerokości geograficznej
  /// działki. Przy wielkości jednego gospodarstwa błąd jest rzędu jednego
  /// procenta — **to za mało na dokument**, a dość na sprawdzenie, czy
  /// pobrano właściwą działkę.
  static double powierzchniaHa(Pierscien obrys) {
    final pierscien = bezPowtorzonegoKonca(obrys);
    if (pierscien.length < 3) {
      return 0;
    }
    final srednia =
        pierscien.map((p) => p.szerokosc).reduce((a, b) => a + b) /
        pierscien.length;
    final metrNaStopienDlugosci = 111320 * math.cos(srednia * math.pi / 180);
    const metrNaStopienSzerokosci = 110540.0;

    var suma = 0.0;
    for (var i = 0; i < pierscien.length; i++) {
      final a = pierscien[i];
      final b = pierscien[(i + 1) % pierscien.length];
      suma +=
          (a.dlugosc * metrNaStopienDlugosci) *
              (b.szerokosc * metrNaStopienSzerokosci) -
          (b.dlugosc * metrNaStopienDlugosci) *
              (a.szerokosc * metrNaStopienSzerokosci);
    }
    return suma.abs() / 2 / 10000;
  }

  /// Środek obrysu — do podpisania działki na mapie.
  ///
  /// Ostatni punkt WKT powtarza pierwszy; gdybyśmy go liczyli, podpis
  /// przesuwałby się w stronę tego narożnika.
  static Punkt srodek(Pierscien pierscien) {
    final punkty = bezPowtorzonegoKonca(pierscien);
    final dlugosc =
        punkty.map((p) => p.dlugosc).reduce((a, b) => a + b) / punkty.length;
    final szerokosc =
        punkty.map((p) => p.szerokosc).reduce((a, b) => a + b) / punkty.length;
    return (dlugosc: dlugosc, szerokosc: szerokosc);
  }

  /// Obrys bez zamykającego powtórzenia pierwszego punktu.
  static Pierscien bezPowtorzonegoKonca(Pierscien pierscien) {
    if (pierscien.length > 1 && pierscien.first == pierscien.last) {
      return pierscien.sublist(0, pierscien.length - 1);
    }
    return pierscien;
  }
}
