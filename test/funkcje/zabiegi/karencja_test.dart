import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/wspolne/opis_karencji.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Karencja z bazy etykiet (krok 8 etapu 1): propozycja z bazy, potwierdzenie
/// albo wpis rolnika — i zawsze widoczne źródło.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;
  late RepozytoriumZabiegow zabiegi;

  Future<void> dodajOprysk({int? karencjaDni, String? zrodlo}) async {
    await baza.insert('dzialka_rolna', {
      'id': 'p1',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Za stodołą',
      'sezon': 2026,
      'uprawa': 'pszenica zwyczajna ozima',
      'powierzchnia_ar': 250,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: 'z1',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: DateTime(2026, 5, 10),
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 250)],
      oprysk: SzczegolyOprysku(
        zabiegId: 'z1',
        srodekNazwa: 'Abydos 750 EC',
        nrZezwolenia: 'R-14/2025 h.r.',
        karencjaDni: karencjaDni,
        karencjaZrodlo: zrodlo,
        karencjaDataEtykiety: '2025-03-14',
      ),
      teraz: DateTime(2026, 5, 10),
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
  });

  tearDown(() => baza.close());

  test('karencja z bazy etykiet czeka na potwierdzenie', () async {
    await dodajOprysk(karencjaDni: 42, zrodlo: 'etykieta MRiRW');

    final oprysk = await zabiegi.szczegolyOprysku('z1');
    expect(oprysk!.karencjaDni, 42);
    expect(oprysk.karencjaPotwierdzona, isFalse);
    expect(
      OpisKarencji.dlaWpisu(oprysk),
      '42 dni • etykieta MRiRW • do potwierdzenia',
    );
  });

  test('potwierdzenie zapisuje źródło i zostawia ślad w dzienniku', () async {
    await dodajOprysk(karencjaDni: 42, zrodlo: 'etykieta MRiRW');

    await zabiegi.zapiszKarencje(
      zabiegId: 'z1',
      dni: 42,
      zrodlo: 'etykieta MRiRW, potwierdzona przez rolnika',
      potwierdzona: true,
      teraz: DateTime(2026, 5, 11),
    );

    final oprysk = await zabiegi.szczegolyOprysku('z1');
    expect(oprysk!.karencjaPotwierdzona, isTrue);
    expect(
      OpisKarencji.dlaWpisu(oprysk),
      contains('potwierdzona przez rolnika'),
    );

    final dziennik = await zabiegi.historia('z1');
    expect(
      [for (final wpis in dziennik) wpis['operacja']],
      contains('zmiana'),
      reason: 'poprawka karencji musi zostawić ślad',
    );
  });

  test('brak karencji w bazie: rolnik wpisuje ją z opakowania', () async {
    await dodajOprysk();

    final przed = await zabiegi.szczegolyOprysku('z1');
    expect(przed!.karencjaDni, isNull);
    expect(OpisKarencji.dlaWpisu(przed), 'karencja nieznana');

    await zabiegi.zapiszKarencje(
      zabiegId: 'z1',
      dni: 30,
      zrodlo: 'opakowanie, wpisane przez rolnika',
      potwierdzona: true,
    );

    final po = await zabiegi.szczegolyOprysku('z1');
    expect(po!.karencjaDni, 30);
    expect(po.dzienZbioru(DateTime(2026, 5, 10)), DateTime(2026, 6, 9));
    expect(OpisKarencji.dlaWpisu(po), contains('wpisane przez rolnika'));
  });

  test('zero dni znaczy, że karencja nie obowiązuje', () async {
    await dodajOprysk();
    await zabiegi.zapiszKarencje(
      zabiegId: 'z1',
      dni: 0,
      zrodlo: 'opakowanie, wpisane przez rolnika',
      potwierdzona: true,
    );

    final oprysk = await zabiegi.szczegolyOprysku('z1');
    expect(OpisKarencji.dlaWpisu(oprysk!), 'karencja nie obowiązuje');
  });

  test('poprawiona karencja zmienia dzień zbioru w rejestrze', () async {
    await dodajOprysk(karencjaDni: 42, zrodlo: 'etykieta MRiRW');

    await zabiegi.zapiszKarencje(
      zabiegId: 'z1',
      dni: 21,
      zrodlo: 'opakowanie, wpisane przez rolnika',
      potwierdzona: true,
    );

    final wpis = await RejestrZabiegow(baza).wpis('z1');
    expect(wpis!.dzienZbioru, DateTime(2026, 5, 31));
    expect(wpis.karencjaTrwa(DateTime(2026, 5, 20)), isTrue);
    expect(wpis.karencjaTrwa(DateTime(2026, 6, 1)), isFalse);
  });
}
