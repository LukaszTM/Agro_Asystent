import 'package:agro_asystent/rdzen/uslugi/geometria.dart';
import 'package:flutter_test/flutter_test.dart';

/// Granice z ULDK przychodzą jako EWKT, a nie jako czyste WKT — to pierwsza
/// rzecz, która zaskoczyła nas w P5 (raport P5). Te testy pilnują, żeby nie
/// wróciło.
void main() {
  group('rozdzielSrid', () {
    test('odczytuje układ z przedrostka EWKT', () {
      final (wkt, srid) = Geometria.rozdzielSrid(
        'SRID=4326;POLYGON((19.1 52.1,19.2 52.1,19.2 52.2,19.1 52.1))',
      );
      expect(srid, 4326);
      expect(wkt, startsWith('POLYGON'));
    });

    test('czyste WKT zostaje bez zmian, układ nieznany', () {
      final (wkt, srid) = Geometria.rozdzielSrid('POLYGON((0 0,1 0,1 1,0 0))');
      expect(srid, isNull);
      expect(wkt, 'POLYGON((0 0,1 0,1 1,0 0))');
    });
  });

  group('zWkt', () {
    test('czyta wielokąt', () {
      final obrysy = Geometria.zWkt(
        'POLYGON((19.1 52.1, 19.2 52.1, 19.2 52.2, 19.1 52.2, 19.1 52.1))',
      );
      expect(obrysy, hasLength(1));
      expect(obrysy.first, hasLength(5));
      expect(obrysy.first.first.dlugosc, closeTo(19.1, 1e-9));
      expect(obrysy.first.first.szerokosc, closeTo(52.1, 1e-9));
    });

    test('czyta wielokąt złożony jako kilka obrysów', () {
      final obrysy = Geometria.zWkt(
        'MULTIPOLYGON(((0 0,1 0,1 1,0 0)),((2 2,3 2,3 3,2 2)))',
      );
      expect(obrysy, hasLength(2));
    });

    test('nieobsługiwany rodzaj geometrii to błąd, nie zgadywanie', () {
      expect(
        () => Geometria.zWkt('POINT(19.1 52.1)'),
        throwsA(isA<FormatException>()),
      );
    });

    test('zapis bez współrzędnych to błąd', () {
      expect(
        () => Geometria.zWkt('POLYGON(())'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  test('zasieg obejmuje wszystkie punkty', () {
    final zasieg = Geometria.zasieg(
      Geometria.zWkt('POLYGON((19.1 52.1,19.3 52.1,19.3 52.4,19.1 52.1))'),
    );
    expect(zasieg.minDlugosc, closeTo(19.1, 1e-9));
    expect(zasieg.maxDlugosc, closeTo(19.3, 1e-9));
    expect(zasieg.minSzerokosc, closeTo(52.1, 1e-9));
    expect(zasieg.maxSzerokosc, closeTo(52.4, 1e-9));
  });

  test('powierzchnia prostokąta 0,01° × 0,01° wychodzi w okolicach 76 ha', () {
    // 0,01° szerokości ≈ 1105 m, 0,01° długości na 52° ≈ 685 m → ≈ 75,7 ha.
    // Sprawdzamy rząd wielkości, bo ten rachunek służy tylko do rozpoznania
    // działki, a nie do dokumentu.
    final obrys = Geometria.zWkt(
      'POLYGON((19.10 52.10,19.11 52.10,19.11 52.11,19.10 52.11,19.10 52.10))',
    ).first;
    expect(Geometria.powierzchniaHa(obrys), closeTo(75.7, 1.0));
  });

  test('srodek obrysu leży w jego wnętrzu', () {
    final obrys = Geometria.zWkt(
      'POLYGON((19.0 52.0,19.2 52.0,19.2 52.2,19.0 52.2,19.0 52.0))',
    ).first;
    final srodek = Geometria.srodek(obrys);
    expect(srodek.dlugosc, closeTo(19.1, 0.02));
    expect(srodek.szerokosc, closeTo(52.1, 0.02));
  });
}
