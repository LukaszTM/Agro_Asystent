import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/baza/migracje.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Testy bazy gospodarstwa na SQLite uruchomionym na komputerze — ta sama
/// baza i te same migracje, które pojadą na telefon.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  Future<void> dodajGospodarstwo(String id) => baza.insert('gospodarstwo', {
    'id': id,
    'nazwa': 'Gospodarstwo próbne',
    'utworzono': '2026-10-15T08:00:00',
    'zmieniono': '2026-10-15T08:00:00',
    'urzadzenie': 'telefon',
  });

  Future<void> dodajPole(String id, String gospodarstwoId) =>
      baza.insert('dzialka_rolna', {
        'id': id,
        'gospodarstwo_id': gospodarstwoId,
        'nazwa_wlasna': 'Za stodołą',
        'sezon': 2026,
        'uprawa': 'pszenica ozima',
        'kod_eppo': 'TRZAW',
        'powierzchnia_ar': 320,
        'utworzono': '2026-10-15T08:00:00',
        'zmieniono': '2026-10-15T08:00:00',
        'urzadzenie': 'telefon',
      });

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
  });

  tearDown(() => baza.close());

  group('migracje', () {
    test('zakładają komplet tabel z punktu 7 planu', () async {
      final tabele = (await baza.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      )).map((w) => w['name'] as String).toSet();

      for (final oczekiwana in [
        'gospodarstwo',
        'dzialka_ewidencyjna',
        'dzialka_rolna',
        'dzialka_rolna_czesc',
        'zabieg',
        'zabieg_pole',
        'zabieg_oprysk',
        'zabieg_nawozenie',
        'nawoz',
        'stado',
        'zwierze',
        'zdarzenie_zwierzecia',
        'historia_zmian',
        'ustawienia',
      ]) {
        expect(tabele, contains(oczekiwana));
      }
    });

    test('baza jest w najnowszej wersji', () async {
      expect(await baza.getVersion(), najnowszaWersja);
    });

    test('ponowne otwarcie nie psuje istniejącej bazy', () async {
      await dodajGospodarstwo('g1');
      await baza.close();
      baza = await BazaGospodarstwa.otworz(
        fabryka: fabryka,
        sciezka: inMemoryDatabasePath,
      );
      expect(await baza.getVersion(), najnowszaWersja);
    });

    test('klucze obce są pilnowane', () async {
      // Zabieg bez istniejącego gospodarstwa nie może trafić do ewidencji.
      expect(
        () => baza.insert('zabieg', {
          'id': 'z1',
          'gospodarstwo_id': 'nie-ma-takiego',
          'typ': 'oprysk',
          'data': '2026-05-10',
          'utworzono': '2026-05-10T10:00:00',
          'zmieniono': '2026-05-10T10:00:00',
          'urzadzenie': 'telefon',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('nieznany rodzaj zabiegu jest odrzucany', () async {
      await dodajGospodarstwo('g1');
      expect(
        () => baza.insert('zabieg', {
          'id': 'z1',
          'gospodarstwo_id': 'g1',
          'typ': 'wymyslony',
          'data': '2026-05-10',
          'utworzono': '2026-05-10T10:00:00',
          'zmieniono': '2026-05-10T10:00:00',
          'urzadzenie': 'telefon',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });

  group('zapis zabiegu', () {
    late RepozytoriumZabiegow repozytorium;

    setUp(() async {
      repozytorium = RepozytoriumZabiegow(baza);
      await dodajGospodarstwo('g1');
      await dodajPole('p1', 'g1');
    });

    Zabieg przykladowyZabieg() => Zabieg(
      id: 'z1',
      gospodarstwoId: 'g1',
      rodzaj: RodzajZabiegu.oprysk,
      data: DateTime(2026, 5, 10),
      godzina: '08:30',
      powierzchniaAr: 320,
      urzadzenie: 'telefon',
    );

    test('zapisuje zabieg, pole i szczegóły oprysku', () async {
      await repozytorium.zapisz(
        zabieg: przykladowyZabieg(),
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 320)],
        oprysk: const SzczegolyOprysku(
          zabiegId: 'z1',
          srodekNazwa: 'Abydos 750 EC',
          nrZezwolenia: 'R-14/2025 h.r.',
          dawka: 0.75,
          dawkaJednostka: 'l',
          dawkaOdniesienie: 'ha',
          przyczyna: 'mączniak prawdziwy zbóż i traw',
          bbchOd: 29,
          bbchDo: 59,
          kodEppo: 'TRZAW',
          karencjaDni: 42,
          karencjaZrodlo: 'etykieta MRiRW',
          karencjaDataEtykiety: '2025-04-15',
          karencjaPotwierdzona: true,
        ),
      );

      final zabiegi = await repozytorium.wszystkie('g1');
      expect(zabiegi, hasLength(1));
      expect(zabiegi.single.rodzaj, RodzajZabiegu.oprysk);

      final oprysk = await repozytorium.szczegolyOprysku('z1');
      expect(oprysk!.srodekNazwa, 'Abydos 750 EC');
      expect(oprysk.dawka, 0.75);
      expect(oprysk.karencjaDni, 42);
    });

    test('dzień zbioru liczy się z karencji', () {
      const oprysk = SzczegolyOprysku(
        zabiegId: 'z1',
        srodekNazwa: 'Abydos 750 EC',
        nrZezwolenia: 'R-14/2025 h.r.',
        karencjaDni: 42,
      );
      expect(oprysk.dzienZbioru(DateTime(2026, 5, 10)), DateTime(2026, 6, 21));
    });

    test('nieznana karencja nie daje daty zbioru', () {
      const oprysk = SzczegolyOprysku(
        zabiegId: 'z1',
        srodekNazwa: 'Środek bez etykiety',
        nrZezwolenia: 'R-1/2020',
      );
      expect(oprysk.dzienZbioru(DateTime(2026, 5, 10)), isNull);
    });

    test(
      'zapis jest w jednej transakcji — błąd nie zostawia połowy wpisu',
      () async {
        await expectLater(
          repozytorium.zapisz(
            zabieg: przykladowyZabieg(),
            pola: const [
              PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 320),
              PoleZabiegu(
                dzialkaRolnaId: 'nie-ma-takiego-pola',
                powierzchniaAr: 10,
              ),
            ],
          ),
          throwsA(isA<DatabaseException>()),
        );
        expect(await repozytorium.wszystkie('g1'), isEmpty);
      },
    );
  });

  group('wpisy są dopisywane, nie nadpisywane', () {
    late RepozytoriumZabiegow repozytorium;

    setUp(() async {
      repozytorium = RepozytoriumZabiegow(baza);
      await dodajGospodarstwo('g1');
      await dodajPole('p1', 'g1');
      await repozytorium.zapisz(
        zabieg: Zabieg(
          id: 'z1',
          gospodarstwoId: 'g1',
          rodzaj: RodzajZabiegu.oprysk,
          data: DateTime(2026, 5, 10),
          powierzchniaAr: 320,
          urzadzenie: 'telefon',
        ),
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 320)],
      );
    });

    test('dodanie zabiegu trafia do dziennika zmian', () async {
      final historia = await repozytorium.historia('z1');
      expect(historia, hasLength(1));
      expect(historia.single['operacja'], 'dodanie');
    });

    test('poprawka zapisuje poprzednią treść', () async {
      await baza.update(
        'zabieg',
        {
          'powierzchnia_ar': 280,
          'zmieniono': '2026-05-11T09:00:00',
          'urzadzenie': 'telefon',
        },
        where: 'id = ?',
        whereArgs: ['z1'],
      );

      final historia = await repozytorium.historia('z1');
      expect(historia, hasLength(2));
      expect(historia.last['operacja'], 'zmiana');
      // W dzienniku zostaje to, co było przed poprawką.
      expect(historia.last['dane_json'], contains('320'));
    });

    test('cofnięcie wpisu zostawia wiersz i ślad w dzienniku', () async {
      await repozytorium.oznaczUsuniety(zabiegId: 'z1', urzadzenie: 'telefon');

      expect(await repozytorium.wszystkie('g1'), isEmpty);
      final wiersze = await baza.query(
        'zabieg',
        where: 'id = ?',
        whereArgs: ['z1'],
      );
      expect(wiersze, hasLength(1), reason: 'wiersz zostaje w bazie');
      expect(wiersze.single['usuniety'], 1);

      final historia = await repozytorium.historia('z1');
      expect(historia.last['operacja'], 'usuniecie');
    });
  });
}
