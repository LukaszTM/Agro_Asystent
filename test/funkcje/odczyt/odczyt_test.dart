import 'package:agro_asystent/funkcje/odczyt/odczyt_etykiety.dart';
import 'package:agro_asystent/funkcje/odczyt/odczyt_nawozu.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Odczyt zdjęć (krok 7 etapu 1). Teksty w testach wyglądają tak, jak to,
/// co rozpoznawanie pisma zwraca z worka i z etykiety: krzywe wiersze,
/// urwane zdania, czasem przekręcone znaki.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  group('worek nawozu', () {
    test('czyta zapis NPK', () {
      final odczyt = CzytnikNawozu.zTekstu('''
POLIFOSKA 6
NAWÓZ WIELOSKŁADNIKOWY
NPK 6-20-30
Masa netto 500 kg
''');
      expect(odczyt.nazwa, 'POLIFOSKA 6');
      expect(odczyt.azotProcent, 6);
      expect(odczyt.fosforProcent, 20);
      expect(odczyt.potasProcent, 30);
      expect(odczyt.naturalny, isNull, reason: 'ze zdjęcia to nie wynika');
      expect(odczyt.cokolwiekZnaleziono, isTrue);
    });

    test('czyta zapis słowny z przecinkiem', () {
      final odczyt = CzytnikNawozu.zTekstu('''
SALETRA AMONOWA
azot całkowity (N) 34,0 %
w tym azotanowy 17,0 %
''');
      expect(odczyt.nazwa, 'SALETRA AMONOWA');
      expect(odczyt.azotProcent, 34);
    });

    test('czyta skrót „N 46%"', () {
      final odczyt = CzytnikNawozu.zTekstu('MOCZNIK\nN 46%\n');
      expect(odczyt.azotProcent, 46);
    });

    test('rozpoznaje nawóz naturalny po nazwie', () {
      final odczyt = CzytnikNawozu.zTekstu(
        'Obornik bydlęcy\nanaliza: azot całkowity 0,55 %',
      );
      expect(odczyt.naturalny, isTrue);
      expect(odczyt.azotProcent, 0.55);
    });

    test('zdanie z instrukcji nie zostaje wzięte za nazwę', () {
      final odczyt = CzytnikNawozu.zTekstu('''
Stosować zgodnie z zaleceniami
PLONOWIT 12
NPK 12-12-17
''');
      expect(odczyt.nazwa, 'PLONOWIT 12');
    });

    test('gdy nic nie widać, nie zmyślamy', () {
      final odczyt = CzytnikNawozu.zTekstu('|||  ???  ---');
      expect(odczyt.nazwa, isNull);
      expect(odczyt.azotProcent, isNull);
      expect(odczyt.cokolwiekZnaleziono, isFalse);
      expect(odczyt.tekst, isNotEmpty, reason: 'pokazujemy, co odczytaliśmy');
    });
  });

  group('etykieta środka', () {
    late Database slowniki;
    late CzytnikEtykiety czytnik;

    setUp(() async {
      slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
      await slowniki.execute('''
        CREATE TABLE srodek (id INTEGER PRIMARY KEY, nazwa TEXT,
          nr_zezwolenia TEXT, rodzaj TEXT, substancja_czynna TEXT,
          producent TEXT, adres_etykiety TEXT, termin_do_stosowania TEXT)''');
      await slowniki.execute('''
        CREATE TABLE zastosowanie (id INTEGER PRIMARY KEY, srodek_id INTEGER,
          agrofag TEXT, dawka_wartosc REAL, dawka_jednostka TEXT,
          dawka_odniesienie TEXT, dawka_tekst TEXT, dawka_pewnosc TEXT,
          termin_tekst TEXT, bbch_od INTEGER, bbch_do INTEGER,
          maloobszarowe INTEGER)''');
      await slowniki.execute(
        'CREATE TABLE zastosowanie_uprawa (zastosowanie_id INTEGER, uprawa TEXT)',
      );
      await slowniki.execute(
        '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
      );
      await slowniki.execute('''
        CREATE TABLE karencja (srodek_nazwa TEXT, uprawa TEXT, dni INTEGER,
          stan TEXT, data_etykiety TEXT, zrodlo TEXT)''');

      Future<void> dodaj(int id, String nazwa, String zezwolenie) async {
        await slowniki.insert('srodek', {
          'id': id,
          'nazwa': nazwa,
          'nr_zezwolenia': zezwolenie,
          'rodzaj': 'Fungicyd',
        });
        await slowniki.insert('zastosowanie', {
          'id': id * 10,
          'srodek_id': id,
          'agrofag': 'mączniak prawdziwy zbóż i traw',
          'dawka_wartosc': 0.75,
          'dawka_jednostka': 'l',
          'dawka_odniesienie': 'ha',
          'dawka_pewnosc': 'odczytana',
        });
        await slowniki.insert('zastosowanie_uprawa', {
          'zastosowanie_id': id * 10,
          'uprawa': 'pszenica ozima',
        });
      }

      await dodaj(1, 'Abydos 750 EC', 'R-14/2025 h.r.');
      await dodaj(2, 'Abydos 500 SC', 'R-99/2024');

      czytnik = CzytnikEtykiety(SlownikSrodkow(slowniki));
    });

    tearDown(() => slowniki.close());

    test('rozpoznaje nazwę handlową i numer zezwolenia', () async {
      final odczyt = await czytnik.rozpoznaj('''
ABYDOS 750 EC
Środek grzybobójczy
Zezwolenie MRiRW nr R-14/2025 h.r.
''', uprawa: 'pszenica ozima');

      expect(odczyt.nrZezwolenia, 'R-14/2025 h.r.');
      expect(odczyt.cokolwiekZnaleziono, isTrue);
    });

    test('numer zezwolenia rozstrzyga, gdy nazw pasuje kilka', () async {
      final odczyt = await czytnik.rozpoznaj('''
Abydos 500 SC
Zezwolenie nr R-99/2024
''', uprawa: 'pszenica ozima');

      expect(odczyt.dopasowania, hasLength(1));
      expect(odczyt.dopasowania.single.nazwa, 'Abydos 500 SC');
      expect(odczyt.pewne, isTrue);
    });

    test('bez uprawy nie szukamy w słowniku', () async {
      final odczyt = await czytnik.rozpoznaj('Abydos 750 EC\nR-14/2025');
      expect(odczyt.nazwa, 'Abydos 750 EC');
      expect(odczyt.dopasowania, isEmpty);
    });

    test('nieczytelne zdjęcie nie daje fałszywego rozpoznania', () async {
      final odczyt = await czytnik.rozpoznaj(
        'xxxx ?? 12 34\nnic tu nie widać',
        uprawa: 'pszenica ozima',
      );
      expect(odczyt.nazwa, isNull);
      expect(odczyt.nrZezwolenia, isNull);
      expect(odczyt.dopasowania, isEmpty);
      expect(odczyt.cokolwiekZnaleziono, isFalse);
    });

    test('numer zezwolenia czytamy też z rozstrzelonego zapisu', () async {
      final odczyt = await czytnik.rozpoznaj(
        'zezwolenie nr R - 14 / 2025 h. r.',
        uprawa: 'pszenica ozima',
      );
      expect(odczyt.nrZezwolenia, 'R-14/2025 h.r.');
    });
  });
}
