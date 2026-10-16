import 'dart:io';

import 'package:agro_asystent/funkcje/nawozenie/terminy_azotowe.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/reguly/gminy_terminy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Graniczne terminy stosowania nawozów azotowych jesienią.
///
/// Daty i wykazy gmin są danymi (`reguly_prawne.json`,
/// `gminy_terminy_azotowe.json`) — w kodzie Dart nie ma ani jednej daty
/// z przepisu.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );
  final gminy = SlownikGminTerminow.zTekstuJson(
    File('assets/dane/gminy_terminy_azotowe.json').readAsStringSync(),
  );

  late Database baza;

  Future<void> dodajDzialke(String identyfikator) =>
      baza.insert('dzialka_ewidencyjna', {
        'id': 'dz-$identyfikator',
        'gospodarstwo_id': 'g1',
        'identyfikator': identyfikator,
        'utworzono': '2026-03-01T08:00:00',
        'zmieniono': '2026-03-01T08:00:00',
        'urzadzenie': 'telefon',
      });

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
  });

  tearDown(() => baza.close());

  TerminyAzotowe usluga() =>
      TerminyAzotowe(baza: baza, reguly: reguly, gminy: gminy);

  group('słownik terminów', () {
    test('ma cztery terminy graniczne: dwa nawozy × dwa rodzaje gruntu', () {
      final terminy = reguly.terminyNawozenia;
      expect(terminy, hasLength(4));

      final stale = terminy
          .where((t) => t.rodzajNawozu == 'naturalne_stale')
          .toList();
      expect(
        stale.firstWhere((t) => t.rodzajGruntu == 'grunty_orne').dataRoczna,
        '10-31',
      );
      expect(
        stale
            .firstWhere(
              (t) => t.rodzajGruntu == 'tuz_uprawy_wieloletnie_trwale',
            )
            .dataRoczna,
        '11-30',
      );

      final plynne = terminy
          .where(
            (t) => t.rodzajNawozu == 'mineralne_azotowe_i_naturalne_plynne',
          )
          .toList();
      expect(
        plynne.firstWhere((t) => t.rodzajGruntu == 'grunty_orne').dataRoczna,
        '10-20',
      );
      expect(
        plynne
            .firstWhere(
              (t) => t.rodzajGruntu == 'tuz_uprawy_wieloletnie_trwale',
            )
            .dataRoczna,
        '10-31',
      );
    });

    test('daty czekają na sprawdzenie w rozporządzeniu', () {
      // Daty wzięliśmy z komunikatu ministerstwa, a nie z tabeli 2
      // programu — aplikacja musi o tym mówić (CLAUDE.md, reguła 5).
      for (final termin in reguly.terminyNawozenia) {
        expect(termin.doWeryfikacji, isTrue, reason: termin.id);
        expect(termin.zrodlo.isNotEmpty, isTrue, reason: termin.id);
      }
      expect(reguly.zasadyNawozeniaAzotem.doWeryfikacji, isTrue);
    });

    test('wykazy gmin są z rozporządzenia, więc potwierdzone', () {
      expect(gminy.doWeryfikacji, isFalse);
      expect(gminy.zrodlo, contains('Dz.U. 2023 poz. 244'));
      expect(gminy.warianty, hasLength(2));
      final daty = gminy.warianty.map((w) => w.dataRoczna).toList();
      expect(daty, containsAll(['10-15', '10-25']));
      // Żadna gmina nie może być w dwóch wykazach naraz — termin byłby
      // niejednoznaczny.
      expect(
        gminy.warianty.first.gminy.intersection(gminy.warianty.last.gminy),
        isEmpty,
      );
    });

    test('odstępstwa i zakazy są danymi, nie warunkami w kodzie', () {
      final zasady = reguly.zasadyNawozeniaAzotem;
      expect(zasady.zakazy, isNotEmpty);
      expect(zasady.nieDotyczy, contains('uprawy pod osłonami'));

      final pogoda = zasady.odstepstwa.firstWhere(
        (o) => o.id == 'niekorzystna_pogoda',
      );
      expect(pogoda.doDnia, '11-30');
      expect(pogoda.wymagaDokumentowania, isFalse);

      final poZbiorze = zasady.odstepstwa.firstWhere(
        (o) => o.id == 'uprawa_po_pozno_zbieranych',
      );
      expect(poZbiorze.wymagaDokumentowania, isTrue);
      expect(poZbiorze.limitAzotuKgNaHa, 30);
      expect(poZbiorze.wymaganeZapisy, hasLength(5));
    });
  });

  group('kod gminy z identyfikatora działki', () {
    test('bierze sześć cyfr gminy i cyfrę rodzaju', () {
      expect(SlownikGminTerminow.kodGminy('061506_2.0007.138'), '0615062');
      expect(SlownikGminTerminow.kodGminy('  022101_1.0001.5  '), '0221011');
    });

    test('dziwnego identyfikatora nie zgadujemy', () {
      expect(SlownikGminTerminow.kodGminy('bez numeru'), isNull);
      expect(SlownikGminTerminow.kodGminy('12345.0001.1'), isNull);
    });
  });

  group('termin dla gospodarstwa', () {
    test('gmina z wykazu do 25 X dostaje swoją datę, nie domyślną', () async {
      // 0615062 jest w załączniku nr 3.
      await dodajDzialke('061506_2.0007.138');

      final wynik = await usluga().dlaGospodarstwa('g1');
      expect(wynik.terminy, hasLength(1));
      expect(wynik.terminy.single.kodGminy, '0615062');
      expect(wynik.terminy.single.dataRoczna, '10-25');
      expect(wynik.terminy.single.zrodlo, contains('załącznik nr 3'));
      expect(wynik.rozneTerminy, isFalse);
    });

    test('gmina z wykazu do 15 X ma termin wcześniejszy niż domyślny', () async {
      final doPietnastego = gminy.warianty
          .firstWhere((w) => w.dataRoczna == '10-15')
          .gminy
          .first;
      await dodajDzialke(
        '${doPietnastego.substring(0, 6)}_${doPietnastego.substring(6)}.0001.1',
      );

      final wynik = await usluga().dlaGospodarstwa('g1');
      expect(wynik.terminy.single.dataRoczna, '10-15');
      expect(wynik.najwczesniejszy, '10-15');
    });

    test('gmina poza wykazami dostaje termin domyślny ze słownika', () async {
      final wWykazach = {
        for (final wariant in gminy.warianty) ...wariant.gminy,
      };
      // Dowolna gmina, której nie ma w żadnym wykazie.
      final poza = [
        for (var i = 1; i <= 99; i++) '02${i.toString().padLeft(2, '0')}011',
      ].firstWhere((kod) => !wWykazach.contains(kod));
      await dodajDzialke('${poza.substring(0, 6)}_${poza.substring(6)}.0001.1');

      final wynik = await usluga().dlaGospodarstwa('g1');
      expect(wynik.terminy.single.dataRoczna, '10-20');
      expect(wynik.terminy.single.zrodlo, contains('domyślny'));
    });

    test('działki w różnych gminach dają najwcześniejszy termin', () async {
      final doPietnastego = gminy.warianty
          .firstWhere((w) => w.dataRoczna == '10-15')
          .gminy
          .first;
      await dodajDzialke('061506_2.0007.138');
      await dodajDzialke(
        '${doPietnastego.substring(0, 6)}_${doPietnastego.substring(6)}.0002.7',
      );

      final wynik = await usluga().dlaGospodarstwa('g1');
      expect(wynik.terminy, hasLength(2));
      expect(wynik.rozneTerminy, isTrue);
      expect(
        wynik.najwczesniejszy,
        '10-15',
        reason: 'wiąże ten wcześniejszy, inaczej rolnik przekroczy termin',
      );
    });

    test(
      'nierozpoznana gmina jest policzona osobno, nie przemilczana',
      () async {
        await dodajDzialke('działka bez numeru');

        final wynik = await usluga().dlaGospodarstwa('g1');
        expect(wynik.dzialkiBezKoduGminy, 1);
        expect(wynik.terminy, isEmpty);
      },
    );

    test('bez działek nie wymyślamy terminu gminnego', () async {
      final wynik = await usluga().dlaGospodarstwa('g1');
      expect(wynik.pusty, isTrue);
      expect(wynik.najwczesniejszy, isNull);
    });
  });
}
