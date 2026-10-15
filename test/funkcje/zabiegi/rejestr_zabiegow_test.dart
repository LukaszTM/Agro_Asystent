import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Rejestr zabiegów to rdzeń aplikacji (plan, pkt 1): z niego powstają
/// ewidencja, wydruk i eksport. Te testy pilnują, że wpis wraca z pola,
/// uprawą, kodem EPPO i działkami referencyjnymi z wniosku.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;
  late RepozytoriumZabiegow zabiegi;
  late RejestrZabiegow rejestr;

  Future<void> dodajPole({
    required String id,
    required String nazwa,
    String uprawa = 'pszenica zwyczajna ozima',
    String? kodEppo = 'TRZAW',
    int powierzchniaAr = 250,
    List<String> dzialki = const [],
  }) async {
    await baza.insert('dzialka_rolna', {
      'id': id,
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': nazwa,
      'sezon': 2026,
      'uprawa': uprawa,
      'kod_eppo': kodEppo,
      'powierzchnia_ar': powierzchniaAr,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    for (final identyfikator in dzialki) {
      await baza.insert('dzialka_ewidencyjna', {
        'id': 'dz-$identyfikator',
        'gospodarstwo_id': 'g1',
        'identyfikator': identyfikator,
        'utworzono': '2026-05-01T08:00:00',
        'zmieniono': '2026-05-01T08:00:00',
        'urzadzenie': 'telefon',
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await baza.insert('dzialka_rolna_czesc', {
        'dzialka_rolna_id': id,
        'dzialka_ewidencyjna_id': 'dz-$identyfikator',
        'powierzchnia_ar': powierzchniaAr,
      });
    }
  }

  Future<void> dodajOprysk({
    required String id,
    required String poleId,
    required DateTime kiedy,
    String srodek = 'Abydos 750 EC',
    double? dawka = 0.75,
    int powierzchniaAr = 250,
  }) async {
    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: id,
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: kiedy,
        godzina: '08:30',
        powierzchniaAr: powierzchniaAr,
        urzadzenie: 'telefon',
      ),
      pola: [
        PoleZabiegu(dzialkaRolnaId: poleId, powierzchniaAr: powierzchniaAr),
      ],
      oprysk: SzczegolyOprysku(
        zabiegId: id,
        srodekNazwa: srodek,
        nrZezwolenia: 'R-14/2025 h.r.',
        dawka: dawka,
        dawkaJednostka: 'l',
        dawkaOdniesienie: 'ha',
        przyczyna: 'mączniak prawdziwy zbóż i traw',
        bbchOd: 29,
        bbchDo: 59,
        kodEppo: 'TRZAW',
        rodzajZastosowania: 'opryskiwanie',
        karencjaDni: 42,
        karencjaZrodlo: 'etykieta MRiRW',
      ),
      teraz: kiedy,
    );
  }

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    zabiegi = RepozytoriumZabiegow(baza);
    rejestr = RejestrZabiegow(baza);
  });

  tearDown(() => baza.close());

  test('wpis wraca z polem, uprawą i działkami z wniosku', () async {
    await dodajPole(
      id: 'p1',
      nazwa: 'Za stodołą',
      dzialki: ['061506_2.0007.138', '061506_2.0007.139'],
    );
    await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

    final wpisy = await rejestr.wpisy('g1');
    expect(wpisy, hasLength(1));
    final wpis = wpisy.single;
    expect(wpis.opisPol, 'Za stodołą');
    expect(wpis.uprawy, 'pszenica zwyczajna ozima');
    expect(wpis.powierzchniaOpis, '2,50 ha');
    expect(wpis.oprysk?.srodekNazwa, 'Abydos 750 EC');
    expect(wpis.dzialkiReferencyjne, [
      '061506_2.0007.138',
      '061506_2.0007.139',
    ]);
    expect(wpis.pola.single.kodEppo, 'TRZAW');
  });

  test('wpisy idą od najnowszego', () async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));
    await dodajOprysk(id: 'z2', poleId: 'p1', kiedy: DateTime(2026, 6, 1));

    final wpisy = await rejestr.wpisy('g1');
    expect([for (final w in wpisy) w.zabieg.id], ['z2', 'z1']);
  });

  test('szukanie znajduje po nazwie środka, pola i uprawy', () async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajPole(
      id: 'p2',
      nazwa: 'Przy drodze',
      uprawa: 'ziemniak',
      kodEppo: 'SOLTU',
    );
    await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));
    await dodajOprysk(
      id: 'z2',
      poleId: 'p2',
      kiedy: DateTime(2026, 5, 11),
      srodek: 'Dithane NeoTec 75 WG',
    );

    Future<List<String>> szukaj(String czego) async => [
      for (final wpis in await rejestr.wpisy(
        'g1',
        filtr: FiltrRejestru(szukane: czego),
      ))
        wpis.zabieg.id,
    ];

    expect(await szukaj('Abydos'), ['z1']);
    expect(await szukaj('drodze'), ['z2']);
    expect(await szukaj('ziemniak'), ['z2']);
    expect(await szukaj('nie ma takiego'), isEmpty);
  });

  test('filtr rodzaju i roku zawęża rejestr', () async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2025, 5, 10));
    await dodajOprysk(id: 'z2', poleId: 'p1', kiedy: DateTime(2026, 5, 10));
    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: 'z3',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.nawozenie,
        data: DateTime(2026, 4, 1),
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 250)],
    );

    final opryski = await rejestr.wpisy(
      'g1',
      filtr: const FiltrRejestru(rodzaj: RodzajZabiegu.oprysk),
    );
    expect([for (final w in opryski) w.zabieg.id], ['z2', 'z1']);

    final rok2026 = await rejestr.wpisy(
      'g1',
      filtr: const FiltrRejestru(rok: 2026),
    );
    expect([for (final w in rok2026) w.zabieg.id], ['z2', 'z3']);
    expect(await rejestr.lata('g1'), [2026, 2025]);
  });

  test(
    'cofnięty wpis nie wraca w rejestrze, ale zostaje w dzienniku',
    () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      await zabiegi.oznaczUsuniety(zabiegId: 'z1', urzadzenie: 'telefon');

      expect(await rejestr.wpisy('g1'), isEmpty);
      final historia = await zabiegi.historia('z1');
      expect([
        for (final wpis in historia) wpis['operacja'],
      ], containsAll(['dodanie', 'usuniecie']));
    },
  );

  test('karencja liczy dzień zbioru od daty zabiegu', () async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

    final wpis = (await rejestr.wpisy('g1')).single;
    expect(wpis.dzienZbioru, DateTime(2026, 6, 21));
    expect(wpis.karencjaTrwa(DateTime(2026, 6, 1)), isTrue);
    expect(wpis.karencjaTrwa(DateTime(2026, 7, 1)), isFalse);
  });

  test('poprawka dawki zostawia poprzednią wartość w dzienniku', () async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

    await zabiegi.popraw(
      zabiegId: 'z1',
      urzadzenie: 'telefon',
      dawka: 0.5,
      godzina: '10:15',
      teraz: DateTime(2026, 5, 11, 9),
    );

    final wpis = await rejestr.wpis('z1');
    expect(wpis!.oprysk?.dawka, 0.5);
    expect(wpis.zabieg.godzina, '10:15');

    final dziennikOprysku = await baza.query(
      'historia_zmian',
      where: 'tabela = ? AND wiersz_id = ?',
      whereArgs: ['zabieg_oprysk', 'z1'],
    );
    expect(dziennikOprysku, hasLength(1));
    expect(dziennikOprysku.single['dane_json'], contains('0.75'));
  });

  test('brak wpisu to null, a nie wyjątek', () async {
    expect(await rejestr.wpis('nie-ma'), isNull);
  });
}
