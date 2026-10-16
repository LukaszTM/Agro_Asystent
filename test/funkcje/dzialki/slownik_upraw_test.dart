import 'package:agro_asystent/funkcje/dzialki/slownik_upraw.dart';
import 'package:agro_asystent/rdzen/wspolne/tekst.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Słownik upraw do wyboru: co wolno wybrać jako uprawę pola i co się dzieje
/// z nazwą, której rejestr nie rozstrzyga co do gatunku.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database slowniki;

  Future<void> dodaj({
    required String nazwa,
    String? kod,
    String stan = 'kod',
    String? gatunki,
    String? pytanie,
    int zastosowan = 0,
  }) => slowniki.insert('uprawa', {
    'nazwa': nazwa,
    'kod_eppo': kod,
    'stan': stan,
    'gatunki': gatunki,
    'pytanie': pytanie,
    'zastosowan': zastosowan,
    // Tę kolumnę liczy skrypt budujący słownik — tu robimy to samo.
    'szukanie': Tekst.znormalizuj(nazwa),
  });

  setUp(() async {
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute('''
      CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
        stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
        zastosowan INTEGER NOT NULL DEFAULT 0,
        szukanie TEXT NOT NULL DEFAULT '')
    ''');
    await dodaj(nazwa: 'pszenica ozima', kod: 'TRZAW', zastosowan: 1497);
    await dodaj(nazwa: 'kukurydza', kod: 'ZEAMX', zastosowan: 425);
    await dodaj(
      nazwa: 'łubin',
      stan: 'rodzajowa',
      gatunki: 'łubin biały|łubin żółty|łubin wąskolistny',
      pytanie: 'Jaki łubin?',
      zastosowan: 37,
    );
    await dodaj(nazwa: 'łubin żółty', kod: 'LUPLU', zastosowan: 157);
    await dodaj(nazwa: 'łubin biały', kod: 'LUPAL', zastosowan: 158);
    await dodaj(nazwa: 'nieszpułka', stan: 'brak', zastosowan: 92);
    await dodaj(nazwa: 'zboża', stan: 'grupa', zastosowan: 27);
    await dodaj(nazwa: 'róża', stan: 'poza_zakresem', zastosowan: 131);
    await dodaj(
      nazwa: 'uprawa w szklarni',
      stan: 'nie_uprawa',
      zastosowan: 587,
    );
  });

  tearDown(() => slowniki.close());

  SlownikUpraw slownik() => SlownikUpraw(slowniki);

  group('lista do wyboru', () {
    test('najczęstsze uprawy są na górze', () async {
      final wynik = await slownik().doWyboru();
      expect(wynik.uprawy.first.nazwa, 'pszenica ozima');
      expect(wynik.uprawy.map((u) => u.nazwa).take(2), [
        'pszenica ozima',
        'kukurydza',
      ]);
    });

    test(
      'nie proponujemy nazw zbiorczych, miejsc ani roślin spoza zakresu',
      () async {
        final nazwy = (await slownik().doWyboru()).uprawy
            .map((u) => u.nazwa)
            .toSet();
        expect(nazwy, isNot(contains('zboża')));
        expect(nazwy, isNot(contains('uprawa w szklarni')));
        expect(nazwy, isNot(contains('róża')));
      },
    );

    test('uprawa bez rozstrzygnięcia jest do wyboru, ale bez kodu', () async {
      final nieszpulka = (await slownik().doWyboru()).uprawy.firstWhere(
        (u) => u.nazwa == 'nieszpułka',
      );
      expect(nieszpulka.maKod, isFalse);
      expect(nieszpulka.wymagaGatunku, isFalse);
    });

    test('szukanie zawęża listę', () async {
      final wynik = await slownik().doWyboru(szukane: 'łubin');
      expect(wynik.uprawy.map((u) => u.nazwa), contains('łubin'));
      expect(wynik.uprawy.map((u) => u.nazwa), isNot(contains('kukurydza')));
    });

    test('szukanie nie wymaga ogonków ani małych liter', () async {
      // Rolnik pisze „lubin" i „ZYTO" — i ma znaleźć „łubin" oraz „żyto".
      final bezOgonkow = await slownik().doWyboru(szukane: 'lubin');
      expect(bezOgonkow.uprawy.map((u) => u.nazwa), contains('łubin biały'));

      await dodaj(nazwa: 'żyto ozime', kod: 'SECCW', zastosowan: 609);
      final wielkimi = await slownik().doWyboru(szukane: 'ZYTO');
      expect(wielkimi.uprawy.map((u) => u.nazwa), contains('żyto ozime'));
    });

    test('kilka słów szuka niezależnie od kolejności', () async {
      final wynik = await slownik().doWyboru(szukane: 'ozim psz');
      expect(wynik.uprawy.map((u) => u.nazwa), ['pszenica ozima']);
    });

    test('ucięta lista mówi, ile upraw pasuje', () async {
      final wynik = await slownik().doWyboru(limit: 2);
      expect(wynik.uprawy, hasLength(2));
      expect(wynik.jestWiecej, isTrue);
      expect(wynik.razem, greaterThan(2));
    });

    test('krótka lista nie udaje, że jest dłuższa', () async {
      final wynik = await slownik().doWyboru(szukane: 'kukurydza');
      expect(wynik.razem, 1);
      expect(wynik.jestWiecej, isFalse);
    });
  });

  group('nazwa rodzajowa', () {
    test('wymaga gatunku i nosi pytanie do rolnika', () async {
      final lubin = (await slownik().jedna('łubin'))!;
      expect(lubin.wymagaGatunku, isTrue);
      expect(lubin.maKod, isFalse, reason: 'kodu rodzaju nie wpisujemy');
      expect(lubin.pytanie, 'Jaki łubin?');
    });

    test(
      'gatunki wracają w kolejności z danych, a nieznane pomijamy',
      () async {
        final lubin = (await slownik().jedna('łubin'))!;
        final gatunki = await slownik().gatunki(lubin);
        // „łubin wąskolistny" nie ma wiersza w słowniku — nie wymyślamy go.
        expect(gatunki.map((u) => u.nazwa), ['łubin biały', 'łubin żółty']);
        expect(gatunki.every((u) => u.maKod), isTrue);
      },
    );

    test('uprawa bez gatunków w słowniku nie udaje wyboru', () async {
      await dodaj(
        nazwa: 'topola energetyczna',
        stan: 'rodzajowa',
        pytanie: 'Jaka topola?',
      );
      final topola = (await slownik().jedna('topola energetyczna'))!;
      expect(topola.wymagaGatunku, isFalse);
      expect(await slownik().gatunki(topola), isEmpty);
    });
  });

  group('własna nazwa rolnika', () {
    test('nie dostaje kodu EPPO i jest oznaczona jako własna', () {
      final uprawa = UprawaDoWyboru.wlasnaNazwa('  proso na ziarno  ');
      expect(uprawa.nazwa, 'proso na ziarno');
      expect(uprawa.maKod, isFalse);
      expect(uprawa.wlasna, isTrue);
      expect(uprawa.wymagaGatunku, isFalse);
    });
  });

  test('uprawy, której słownik nie zna, nie wymyślamy', () async {
    expect(await slownik().jedna('marsjańska pszenica'), isNull);
  });
}
