import 'package:agro_asystent/app/aplikacja.dart';
import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ścieżka wpisu oprysku z planu (pkt 5): pole → rodzaj zabiegu → środek →
/// dawka i przyczyna → zapis. Miara powodzenia: najwyżej pięć dotknięć
/// i żadnego pisania na klawiaturze.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;

  late Database gospodarstwo;
  late Database slowniki;
  late Uslugi uslugi;

  /// Mały słownik o budowie takiej samej jak plik dołączany do aplikacji.
  Future<Database> zbudujSlowniki() async {
    final baza = await fabryka.openDatabase(inMemoryDatabasePath);
    await baza.execute('''
      CREATE TABLE srodek (id INTEGER PRIMARY KEY, nazwa TEXT, nr_zezwolenia TEXT,
        rodzaj TEXT, substancja_czynna TEXT, producent TEXT, adres_etykiety TEXT,
        termin_do_stosowania TEXT)''');
    await baza.execute(
      '''
      CREATE TABLE zastosowanie (id INTEGER PRIMARY KEY, srodek_id INTEGER,
        agrofag TEXT, dawka_wartosc REAL, dawka_jednostka TEXT,
        dawka_odniesienie TEXT, dawka_tekst TEXT, dawka_pewnosc TEXT,
        termin_tekst TEXT, bbch_od INTEGER, bbch_do INTEGER, maloobszarowe INTEGER)''',
    );
    await baza.execute(
      'CREATE TABLE zastosowanie_uprawa (zastosowanie_id INTEGER, uprawa TEXT)',
    );
    await baza.execute(
      'CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT)',
    );
    await baza.execute('''
      CREATE TABLE karencja (srodek_nazwa TEXT, uprawa TEXT, dni INTEGER,
        stan TEXT, data_etykiety TEXT, zrodlo TEXT)''');

    await baza.insert('srodek', {
      'id': 1,
      'nazwa': 'Abydos 750 EC',
      'nr_zezwolenia': 'R-14/2025 h.r.',
      'rodzaj': 'Fungicyd',
    });
    await baza.insert('zastosowanie', {
      'id': 10,
      'srodek_id': 1,
      'agrofag': 'mączniak prawdziwy zbóż i traw',
      'dawka_wartosc': 0.75,
      'dawka_jednostka': 'l',
      'dawka_odniesienie': 'ha',
      'dawka_tekst': 'Maksymalna dawka: 0,75 l/ha',
      'dawka_pewnosc': 'odczytana',
      'bbch_od': 29,
      'bbch_do': 59,
    });
    await baza.insert('zastosowanie_uprawa', {
      'zastosowanie_id': 10,
      'uprawa': 'pszenica ozima',
    });
    await baza.insert('karencja', {
      'srodek_nazwa': 'Abydos 750 EC',
      'uprawa': 'pszenica ozima',
      'dni': 42,
      'stan': 'dni',
      'data_etykiety': '2025-04-15',
      'zrodlo': 'etykieta MRiRW',
    });

    // Drugi środek: bez karencji w bazie — rolnik musi ją sprawdzić sam.
    await baza.insert('srodek', {
      'id': 2,
      'nazwa': 'Bez Etykiety 100 SC',
      'nr_zezwolenia': 'R-99/2024',
    });
    await baza.insert('zastosowanie', {
      'id': 11,
      'srodek_id': 2,
      'agrofag': 'rdza brunatna',
      'dawka_wartosc': 1.2,
      'dawka_jednostka': 'l',
      'dawka_odniesienie': 'ha',
      'dawka_pewnosc': 'odczytana',
    });
    await baza.insert('zastosowanie_uprawa', {
      'zastosowanie_id': 11,
      'uprawa': 'pszenica ozima',
    });

    await baza.insert('uprawa', {
      'nazwa': 'pszenica ozima',
      'kod_eppo': 'TRZAW',
    });
    return baza;
  }

  setUp(() async {
    gospodarstwo = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    slowniki = await zbudujSlowniki();

    final czas = DateTime(2026, 5, 10).toIso8601String();
    await gospodarstwo.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Moje gospodarstwo',
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': 'telefon',
    });

    uslugi = Uslugi(
      gospodarstwoId: 'g1',
      urzadzenie: 'telefon',
      pola: RepozytoriumPol(gospodarstwo),
      zabiegi: RepozytoriumZabiegow(gospodarstwo),
      srodki: SlownikSrodkow(slowniki),
    );

    await uslugi.pola.dodaj(
      pole: const Pole(
        id: 'p1',
        gospodarstwoId: 'g1',
        nazwa: 'Za stodołą',
        uprawa: 'pszenica ozima',
        kodEppo: 'TRZAW',
        powierzchniaAr: 320,
      ),
      urzadzenie: 'telefon',
    );
  });

  tearDown(() async {
    await gospodarstwo.close();
    await slowniki.close();
  });

  Future<void> otworz(WidgetTester tester) async {
    await tester.pumpWidget(AplikacjaAgroAsystent(uslugi: uslugi));
    await tester.pumpAndSettle();
  }

  testWidgets('wpis oprysku w pięciu dotknięciach, bez klawiatury', (
    tester,
  ) async {
    await otworz(tester);

    var dotkniecia = 0;
    Future<void> dotknij(Finder cel) async {
      dotkniecia++;
      await tester.tap(cel);
      await tester.pumpAndSettle();
    }

    await dotknij(find.text('Dodaj zabieg'));
    await dotknij(find.text('Za stodołą'));
    await dotknij(find.text('Oprysk'));
    await dotknij(find.text('Abydos 750 EC'));
    await dotknij(find.text('Zapisz'));

    expect(dotkniecia, lessThanOrEqualTo(5));
    expect(find.text('Zabieg zapisany'), findsOneWidget);
  });

  testWidgets('po zapisie widać karencję i dzień zbioru', (tester) async {
    await otworz(tester);
    for (final cel in [
      'Dodaj zabieg',
      'Za stodołą',
      'Oprysk',
      'Abydos 750 EC',
      'Zapisz',
    ]) {
      await tester.tap(find.text(cel));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Karencja: 42 dni'), findsOneWidget);
    expect(find.textContaining('Zbiór najwcześniej'), findsOneWidget);
    // Rolnik ma wiedzieć, z jakiej etykiety pochodzi karencja.
    expect(find.textContaining('2025-04-15'), findsOneWidget);
  });

  testWidgets('nieznana karencja jest powiedziana wprost', (tester) async {
    await otworz(tester);
    for (final cel in [
      'Dodaj zabieg',
      'Za stodołą',
      'Oprysk',
      'Bez Etykiety 100 SC',
      'Zapisz',
    ]) {
      await tester.tap(find.text(cel));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Karencji nie znamy'), findsOneWidget);
    expect(find.textContaining('Sprawdź ją na etykiecie'), findsOneWidget);
  });

  testWidgets('zabieg trafia do bazy z dawką, karencją i kodem EPPO', (
    tester,
  ) async {
    await otworz(tester);
    for (final cel in [
      'Dodaj zabieg',
      'Za stodołą',
      'Oprysk',
      'Abydos 750 EC',
      'Zapisz',
    ]) {
      await tester.tap(find.text(cel));
      await tester.pumpAndSettle();
    }

    final zabiegi = await uslugi.zabiegi.wszystkie('g1');
    expect(zabiegi, hasLength(1));
    expect(zabiegi.single.powierzchniaAr, 320, reason: 'powierzchnia z pola');

    final oprysk = await uslugi.zabiegi.szczegolyOprysku(zabiegi.single.id);
    expect(oprysk!.srodekNazwa, 'Abydos 750 EC');
    expect(oprysk.nrZezwolenia, 'R-14/2025 h.r.');
    expect(oprysk.dawka, 0.75, reason: 'dawka podpowiedziana z rejestru');
    expect(oprysk.karencjaDni, 42);
    expect(oprysk.kodEppo, 'TRZAW');
    expect(oprysk.przyczyna, 'mączniak prawdziwy zbóż i traw');
  });

  testWidgets('dawka ponad dopuszczalną daje ostrzeżenie', (tester) async {
    await otworz(tester);
    for (final cel in [
      'Dodaj zabieg',
      'Za stodołą',
      'Oprysk',
      'Abydos 750 EC',
    ]) {
      await tester.tap(find.text(cel));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('0,75 l/ha'), findsWidgets);
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();

    expect(find.textContaining('przekracza dopuszczalną'), findsOneWidget);
  });

  testWidgets('lista środków pokazuje tylko dopuszczone w tej uprawie', (
    tester,
  ) async {
    await otworz(tester);
    for (final cel in ['Dodaj zabieg', 'Za stodołą', 'Oprysk']) {
      await tester.tap(find.text(cel));
      await tester.pumpAndSettle();
    }

    expect(find.text('Abydos 750 EC'), findsOneWidget);
    expect(find.text('Bez Etykiety 100 SC'), findsOneWidget);
    expect(find.textContaining('mączniak'), findsOneWidget);
  });

  testWidgets('podczas wpisu nie ma zachęty do premium', (tester) async {
    await otworz(tester);
    for (final cel in [
      'Dodaj zabieg',
      'Za stodołą',
      'Oprysk',
      'Abydos 750 EC',
    ]) {
      await tester.tap(find.text(cel));
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('premium', findRichText: true), findsNothing);
    expect(find.textContaining('Kup'), findsNothing);
  });
}
