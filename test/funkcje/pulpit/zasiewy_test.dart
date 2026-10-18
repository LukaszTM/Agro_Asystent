import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/pulpit/zasiewy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Struktura zasiewów na pulpicie programu na komputer.
///
/// Rachunek jest prosty, ale łatwo go zrobić źle: zsumować dwa sezony
/// naraz albo wpisać pole bez uprawy do pierwszej lepszej uprawy.
void main() {
  Pole pole({
    required String id,
    required String uprawa,
    required int ar,
    int? sezon = 2026,
  }) => Pole(
    id: id,
    gospodarstwoId: 'g1',
    nazwa: id,
    uprawa: uprawa,
    powierzchniaAr: ar,
    sezon: sezon,
  );

  test('sumuje powierzchnię pól tej samej uprawy', () {
    final zasiewy = Zasiewy.policz([
      pole(id: 'p1', uprawa: 'pszenica ozima', ar: 1200),
      pole(id: 'p2', uprawa: 'pszenica ozima', ar: 800),
      pole(id: 'p3', uprawa: 'kukurydza', ar: 500),
    ]);

    expect(zasiewy.liczbaPol, 3);
    expect(zasiewy.powierzchniaOpis, '25,00 ha');
    expect(zasiewy.uprawy.first.uprawa, 'pszenica ozima');
    expect(zasiewy.uprawy.first.powierzchniaAr, 2000);
    expect(zasiewy.uprawy.first.liczbaPol, 2);
    expect(zasiewy.uprawy.first.udzialOpis(zasiewy.powierzchniaAr), '80 %');
  });

  test('liczy jeden sezon — pola z dwóch lat dałyby za dużo hektarów', () {
    final zasiewy = Zasiewy.policz([
      pole(id: 'stare', uprawa: 'żyto', ar: 1000, sezon: 2025),
      pole(id: 'nowe', uprawa: 'rzepak', ar: 700, sezon: 2026),
    ]);

    expect(zasiewy.sezon, 2026);
    expect(zasiewy.liczbaPol, 1);
    expect(zasiewy.uprawy.single.uprawa, 'rzepak');
  });

  test('sezon można wskazać z ręki', () {
    final zasiewy = Zasiewy.policz([
      pole(id: 'stare', uprawa: 'żyto', ar: 1000, sezon: 2025),
      pole(id: 'nowe', uprawa: 'rzepak', ar: 700, sezon: 2026),
    ], sezon: 2025);

    expect(zasiewy.uprawy.single.uprawa, 'żyto');
  });

  test('pole bez wpisanej uprawy nie udaje uprawy i stoi na końcu', () {
    final zasiewy = Zasiewy.policz([
      pole(id: 'p1', uprawa: '', ar: 5000),
      pole(id: 'p2', uprawa: 'owies', ar: 100),
    ]);

    expect(zasiewy.uprawy.first.uprawa, 'owies');
    expect(zasiewy.uprawy.last.nieznana, isTrue);
    expect(zasiewy.uprawy.last.nazwa, 'Bez wpisanej uprawy');
    expect(zasiewy.polaBezUprawy, 1);
  });

  test('przy wielu uprawach reszta schodzi do jednej pozycji', () {
    final zasiewy = Zasiewy.policz([
      for (var numer = 0; numer < 10; numer++)
        pole(id: 'p$numer', uprawa: 'uprawa $numer', ar: 100 * (10 - numer)),
    ]);

    final widoczne = zasiewy.najwieksze(4);
    expect(widoczne.length, 4);
    expect(widoczne.last.uprawa, 'Pozostałe (7)');
    expect(widoczne.last.liczbaPol, 7);
    expect(
      widoczne.fold<int>(0, (suma, u) => suma + u.powierzchniaAr),
      zasiewy.powierzchniaAr,
    );
  });

  test('bez pól wykres nie ma czego pokazać', () {
    final zasiewy = Zasiewy.policz(const []);

    expect(zasiewy.pusta, isTrue);
    expect(zasiewy.sezon, isNull);
    expect(zasiewy.powierzchniaAr, 0);
    expect(zasiewy.uprawy, isEmpty);
  });

  test('małe udziały pokazujemy z jednym miejscem po przecinku', () {
    final zasiewy = Zasiewy.policz([
      pole(id: 'duze', uprawa: 'pszenica', ar: 9950),
      pole(id: 'male', uprawa: 'gryka', ar: 50),
    ]);

    expect(zasiewy.uprawy.last.udzialOpis(zasiewy.powierzchniaAr), '0,5 %');
  });
}
