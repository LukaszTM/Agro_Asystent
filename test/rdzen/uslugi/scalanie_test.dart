import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/baza/migracje.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/scalanie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Synchronizacja przez dysk użytkownika (plan, pkt 2): dołączenie danych
/// z kopii zrobionej na drugim telefonie.
///
/// Zasada do sprawdzenia jest jedna: **nowszy wpis wygrywa, starszy
/// zostaje w dzienniku zmian.** Scalanie nie ma prawa usunąć ani
/// zdublować dokumentacji — kontrola patrzy na te same wpisy.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database telefon;
  late Database tablet;

  /// Dwie osobne bazy — każda w swoim pliku. Baza pamięciowa
  /// `inMemoryDatabasePath` jest dla sqflite jedną i tą samą bazą, więc
  /// nie da się na niej udawać dwóch urządzeń.
  Future<Database> otworz(String nazwa) async {
    final katalog = Directory.systemTemp.createTempSync('agro-scalanie');
    addTearDown(() => katalog.deleteSync(recursive: true));
    return BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: '${katalog.path}/$nazwa.db',
    );
  }

  Future<void> gospodarstwo(Database gdzie) async {
    await gdzie.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo Łąki Górne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await gdzie.insert('dzialka_rolna', {
      'id': 'pole-1',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Za stodołą',
      'sezon': 2026,
      'uprawa': 'pszenica zwyczajna ozima',
      'powierzchnia_ar': 250,
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
  }

  Future<void> oprysk(
    Database gdzie, {
    required String id,
    required String urzadzenie,
    double dawka = 1.5,
    DateTime? kiedy,
  }) => RepozytoriumZabiegow(gdzie).zapisz(
    zabieg: Zabieg(
      id: id,
      gospodarstwoId: 'g1',
      rodzaj: RodzajZabiegu.oprysk,
      data: DateTime(2026, 5, 10),
      godzina: '08:30',
      powierzchniaAr: 250,
      urzadzenie: urzadzenie,
    ),
    pola: const [PoleZabiegu(dzialkaRolnaId: 'pole-1', powierzchniaAr: 250)],
    oprysk: SzczegolyOprysku(
      zabiegId: id,
      srodekNazwa: 'Abydos 750 EC',
      nrZezwolenia: 'R-14/2025 h.r.',
      dawka: dawka,
      karencjaDni: 42,
    ),
    teraz: kiedy ?? DateTime(2026, 5, 10, 8, 35),
  );

  setUp(() async {
    telefon = await otworz('telefon');
    tablet = await otworz('tablet');
    await gospodarstwo(telefon);
    await gospodarstwo(tablet);
  });

  tearDown(() async {
    await telefon.close();
    await tablet.close();
  });

  Future<Uint8List> kopiaZ(Database gdzie) =>
      KopiaDanych(baza: gdzie, wersjaSchematu: najnowszaWersja).zrob();

  Scalanie scalanieW(Database gdzie, {String urzadzenie = 'telefon'}) =>
      Scalanie(
        baza: gdzie,
        wersjaSchematu: najnowszaWersja,
        urzadzenie: urzadzenie,
      );

  Future<RaportScalenia> scal(
    Database gdzie,
    Uint8List plik, {
    String urzadzenie = 'telefon',
  }) async {
    final wynik = await scalanieW(
      gdzie,
      urzadzenie: urzadzenie,
    ).scal(plik, teraz: DateTime(2026, 10, 16, 20));
    expect(wynik, isA<ScalenieZrobione>());
    return (wynik as ScalenieZrobione).raport;
  }

  Future<List<Map<String, Object?>>> dziennik(Database gdzie) =>
      gdzie.query('historia_zmian', orderBy: 'id');

  group('wpisy z drugiego urządzenia', () {
    test('zabieg z tabletu dochodzi na telefon razem ze szczegółami', () async {
      await oprysk(tablet, id: 'z-tablet', urzadzenie: 'tablet');

      final raport = await scal(telefon, await kopiaZ(tablet));

      expect(raport.zabiegiDodane, 1);
      expect(raport.cokolwiekSieZmienilo, isTrue);
      final zabiegi = await RepozytoriumZabiegow(telefon).wszystkie('g1');
      expect(zabiegi.single.id, 'z-tablet');
      final szczegoly = await RepozytoriumZabiegow(telefon)
          .szczegolyOprysku('z-tablet');
      expect(szczegoly!.srodekNazwa, 'Abydos 750 EC');
      expect(szczegoly.dawka, 1.5);
      // Powiązanie z polem też musi dojść, inaczej zabieg wisiałby w próżni.
      final pola = await telefon.query(
        'zabieg_pole',
        where: 'zabieg_id = ?',
        whereArgs: ['z-tablet'],
      );
      expect(pola, hasLength(1));
    });

    test('scalanie tego samego pliku dwa razy niczego nie dubluje', () async {
      await oprysk(tablet, id: 'z-tablet', urzadzenie: 'tablet');
      final plik = await kopiaZ(tablet);

      await scal(telefon, plik);
      final przedDrugim = (await dziennik(telefon)).length;
      final drugi = await scal(telefon, plik);

      expect(drugi.dodaneRazem, 0);
      expect(drugi.zastapioneRazem, 0);
      expect(drugi.wpisyDziennika, 0);
      expect(drugi.cokolwiekSieZmienilo, isFalse);
      expect(await RepozytoriumZabiegow(telefon).wszystkie('g1'), hasLength(1));
      expect(await dziennik(telefon), hasLength(przedDrugim));
    });

    test('wpisy z obu urządzeń stoją obok siebie, nic nie ginie', () async {
      await oprysk(telefon, id: 'z-telefon', urzadzenie: 'telefon');
      await oprysk(tablet, id: 'z-tablet', urzadzenie: 'tablet');

      await scal(telefon, await kopiaZ(tablet));

      final zabiegi = await RepozytoriumZabiegow(telefon).wszystkie('g1');
      expect(zabiegi.map((z) => z.id), containsAll(['z-telefon', 'z-tablet']));
    });
  });

  group('ten sam wpis poprawiony po obu stronach', () {
    setUp(() async {
      // Ten sam zabieg istnieje w obu bazach — tak jak po pierwszym
      // scaleniu albo po wczytaniu tej samej kopii.
      await oprysk(telefon, id: 'z1', urzadzenie: 'telefon');
      await oprysk(tablet, id: 'z1', urzadzenie: 'tablet');
    });

    test(
      'nowsza poprawka z pliku wygrywa, starsza idzie do dziennika',
      () async {
        await RepozytoriumZabiegow(telefon).popraw(
          zabiegId: 'z1',
          urzadzenie: 'telefon',
          godzina: '09:00',
          teraz: DateTime(2026, 5, 11, 7),
        );
        await RepozytoriumZabiegow(tablet).popraw(
          zabiegId: 'z1',
          urzadzenie: 'tablet',
          godzina: '10:15',
          dawka: 2,
          teraz: DateTime(2026, 5, 12, 7),
        );

        final raport = await scal(telefon, await kopiaZ(tablet));

        expect(raport.zastapione['zabieg'], 1);
        final zabieg = (await RepozytoriumZabiegow(telefon).wszystkie('g1'))
            .single;
        expect(zabieg.godzina, '10:15');
        // Szczegóły idą razem z zabiegiem: dawka z tabletu, nie z telefonu.
        final szczegoly = await RepozytoriumZabiegow(telefon)
            .szczegolyOprysku('z1');
        expect(szczegoly!.dawka, 2);
        // Poprawka z telefonu (godzina 09:00) musi zostać w dzienniku.
        final wpisy = await dziennik(telefon);
        expect(
          wpisy.any((w) => '${w['dane_json']}'.contains('09:00')),
          isTrue,
          reason: 'poprzednia wersja zniknęła z dziennika',
        );
      },
    );

    test('starsza wersja z pliku nie przepada bez śladu', () async {
      await RepozytoriumZabiegow(tablet).popraw(
        zabiegId: 'z1',
        urzadzenie: 'tablet',
        godzina: '07:45',
        teraz: DateTime(2026, 5, 11, 7),
      );
      await RepozytoriumZabiegow(telefon).popraw(
        zabiegId: 'z1',
        urzadzenie: 'telefon',
        godzina: '11:30',
        teraz: DateTime(2026, 5, 12, 7),
      );

      final raport = await scal(telefon, await kopiaZ(tablet));

      expect(raport.pominieteStarsze['zabieg'], 1);
      expect(raport.zastapione['zabieg'], isNull);
      final zabieg = (await RepozytoriumZabiegow(telefon).wszystkie('g1'))
          .single;
      expect(zabieg.godzina, '11:30');

      final pominiete = (await dziennik(telefon))
          .where((w) => '${w['dane_json']}'.contains('pominieto_z_pliku'))
          .toList();
      expect(pominiete, hasLength(1));
      final dane = jsonDecode(
        '${pominiete.single['dane_json']}',
      ) as Map<String, dynamic>;
      expect(
        (dane['pominieto_z_pliku'] as Map<String, dynamic>)['godzina'],
        '07:45',
      );
      expect(pominiete.single['urzadzenie'], 'telefon');
    });

    test('poprawka tylko na jednym urządzeniu wchodzi bez konfliktu', () async {
      await RepozytoriumZabiegow(tablet).popraw(
        zabiegId: 'z1',
        urzadzenie: 'tablet',
        uwagi: 'wiatr 2 m/s',
        teraz: DateTime(2026, 5, 11, 7),
      );

      final raport = await scal(telefon, await kopiaZ(tablet));

      expect(raport.zastapione['zabieg'], 1);
      expect(raport.pominieteRazem, 0);
      final zabieg = (await RepozytoriumZabiegow(telefon).wszystkie('g1'))
          .single;
      expect(zabieg.uwagi, 'wiatr 2 m/s');
    });
  });

  group('czego scalanie nie rusza', () {
    test('ustawienia tego telefonu zostają jego własne', () async {
      await telefon.insert('ustawienia', {
        'klucz': 'wyglad',
        'wartosc': 'prosty',
      });
      await tablet.insert('ustawienia', {
        'klucz': 'wyglad',
        'wartosc': 'nowoczesny',
      });

      await scal(telefon, await kopiaZ(tablet));

      final wiersze = await telefon.query(
        'ustawienia',
        where: 'klucz = ?',
        whereArgs: ['wyglad'],
      );
      expect(wiersze.single['wartosc'], 'prosty');
    });

    test('pole zmienione na tablecie wchodzi z dziennikiem zmiany', () async {
      await tablet.update(
        'dzialka_rolna',
        {
          'uprawa': 'kukurydza na ziarno',
          'zmieniono': '2026-04-01T10:00:00',
          'urzadzenie': 'tablet',
        },
        where: 'id = ?',
        whereArgs: ['pole-1'],
      );

      final raport = await scal(telefon, await kopiaZ(tablet));

      expect(raport.zastapione['dzialka_rolna'], 1);
      final pole = (await telefon.query(
        'dzialka_rolna',
        where: 'id = ?',
        whereArgs: ['pole-1'],
      )).single;
      expect(pole['uprawa'], 'kukurydza na ziarno');
      // Wyzwalacz z migracji 4 zapisał poprzednią uprawę — scalanie nie
      // dopisuje drugiego wpisu o tym samym.
      final oPolu = (await dziennik(telefon))
          .where((w) => w['tabela'] == 'dzialka_rolna')
          .toList();
      expect(oPolu, hasLength(1));
      expect(
        '${oPolu.single['dane_json']}',
        contains('pszenica zwyczajna ozima'),
      );
    });
  });

  group('plik, którego nie rozumiemy', () {
    test('obcy plik jest odrzucony, baza bez zmian', () async {
      await oprysk(telefon, id: 'z1', urzadzenie: 'telefon');

      final wynik = await scalanieW(telefon)
          .scal(Uint8List.fromList('to nie jest kopia'.codeUnits));

      expect(wynik, isA<ScalenieOdrzucone>());
      expect((wynik as ScalenieOdrzucone).blad, BladKopii.nieNaszPlik);
      expect(await RepozytoriumZabiegow(telefon).wszystkie('g1'), hasLength(1));
    });

    test('kopia z nowszego schematu nie jest zgadywana', () async {
      final plik = await KopiaDanych(
        baza: tablet,
        wersjaSchematu: najnowszaWersja + 5,
      ).zrob();

      final wynik = await scalanieW(telefon).scal(plik);

      expect(wynik, isA<ScalenieOdrzucone>());
      expect((wynik as ScalenieOdrzucone).blad, BladKopii.nowszaWersja);
    });
  });
}
