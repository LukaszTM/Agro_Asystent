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

    test('daty są sprawdzone w tabeli 2 rozporządzenia', () {
      for (final termin in reguly.terminyNawozenia) {
        expect(termin.doWeryfikacji, isFalse, reason: termin.id);
        expect(termin.zrodlo, contains('Dz.U. 2023 poz. 244'));
        expect(termin.zrodlo, contains('tabela 2'), reason: termin.id);
      }
      expect(reguly.zasadyNawozeniaAzotem.doWeryfikacji, isFalse);
    });

    test('okres stosowania zaczyna się 1 marca', () {
      for (final termin in reguly.terminyNawozenia) {
        expect(termin.okresOd, '03-01', reason: termin.id);
      }
    });

    test('wcześniejsze nawożenie w lutym ma progi z przepisu', () {
      final wiosna = reguly.zasadyNawozeniaAzotem.wczesniejszeWiosna;
      expect(wiosna.jest, isTrue);
      expect(wiosna.okresOd, '02-01');
      expect(wiosna.progi.map((p) => p.stopnieC), containsAll([3.0, 5.0]));
      expect(wiosna.dniPowyzejProgu, 5);
      expect(wiosna.udzialPowiatuProcent, 95);
      expect(wiosna.ktoOglasza, contains('Meteorologii'));
      expect(wiosna.doWeryfikacji, isFalse);
    });

    test('wzór ewidencji nawożenia ma kolumny z tabeli 15', () {
      final obowiazek = reguly.obowiazek('program_azotanowy_ewidencja')!;
      expect(obowiazek.wymaganePola, hasLength(9));
      expect(
        obowiazek.wymaganePola.map((p) => p.id),
        containsAll([
          'data',
          'pole',
          'uprawa',
          'powierzchnia_uprawy',
          'powierzchnia_nawozona',
          'rodzaj_nawozu',
          'dawka_azotu_na_ha',
          'dawka_azotu_razem',
          'data_przyorania',
        ]),
      );
      expect(obowiazek.podstawa, contains('Dz.U. 2023 poz. 244'));
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
      expect(zasady.zakazy, hasLength(5));
      expect(zasady.nieDotyczy.first, contains('pod osłonami'));

      final pogoda = zasady.odstepstwa.firstWhere(
        (o) => o.id == 'niekorzystna_pogoda',
      );
      expect(pogoda.doDnia, '11-30');
      expect(pogoda.wymagaDokumentowania, isFalse);
      expect(pogoda.dotyczyGruntow, 'grunty_orne');
      expect(pogoda.doWeryfikacji, isFalse);

      final poZbiorze = zasady.odstepstwa.firstWhere(
        (o) => o.id == 'uprawa_po_pozno_zbieranych',
      );
      expect(poZbiorze.wymagaDokumentowania, isTrue);
      expect(poZbiorze.limitAzotuKgNaHa, 30);
      expect(poZbiorze.wymaganeZapisy, hasLength(5));
      expect(
        poZbiorze.doDnia,
        isNull,
        reason:
            'Program znosi termin, ale nowej daty nie podaje — '
            'nie wymyślamy jej',
      );
      expect(poZbiorze.uwagi, contains('ministerstwa'));
    });

    test('zakazy mają podstawę: program albo ustawa o nawozach', () {
      final zasady = reguly.zasadyNawozeniaAzotem;
      final odlogi = zasady.zakazy.firstWhere(
        (z) => z.id == 'gleby_odlogowane',
      );
      expect(odlogi.doWeryfikacji, isFalse);
      expect(odlogi.zrodlo, contains('1.3'));

      // Treść zakazu dla gleb niezdatnych jest w ustawie — przeczytana
      // 16.10.2026, razem z ustępem o rozmarzaniu powierzchniowym.
      final niezdatna = zasady.zakazy.firstWhere(
        (z) => z.id == 'gleba_niezdatna',
      );
      expect(niezdatna.doWeryfikacji, isFalse);
      expect(niezdatna.zrodlo, contains('art. 20 ust. 1 pkt 1'));
      expect(niezdatna.opis, contains('rozmarza'));

      expect(zasady.zakazy.where((z) => z.doWeryfikacji), isEmpty);
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
