import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/czytnik_wniosku.dart';
import 'package:agro_asystent/rdzen/uslugi/pdf/tekst_pdf.dart';
import 'package:flutter_test/flutter_test.dart';

/// Czytnik wniosku w aplikacji musi dawać te same liczby co sprawdzony
/// czytnik w Pythonie z zadania P4. Wzorzec `test/dane/wzorzec_wniosku.pdf`
/// jest zanonimizowany — prawdziwego wniosku nie ma w repozytorium
/// (CLAUDE.md, reguła 2).
void main() {
  group('wzorzec wniosku', () {
    late WniosekZPdf wniosek;

    setUpAll(() {
      wniosek = CzytnikWniosku.zBajtow(
        File('test/dane/wzorzec_wniosku.pdf').readAsBytesSync(),
      );
    });

    test('odczytuje tabelę X w całości', () {
      expect(wniosek.dzialki, hasLength(20));
      expect(wniosek.powierzchniaDzialekHa, closeTo(34.79, 0.01));
      expect(wniosek.dzialki.first.gmina, isNotEmpty);
      expect(wniosek.dzialki.first.nrDzialki, isNotEmpty);
      expect(wniosek.dzialki.first.powierzchniaHa, isNotNull);
    });

    test('odczytuje tabelę XI w całości', () {
      expect(wniosek.pola, hasLength(34));
      expect(wniosek.powierzchniaPolAr, 2891);
      expect(wniosek.pola.first.oznaczenie, 'A');
      expect(wniosek.pola.first.uprawa, isNotEmpty);
    });

    test('rok bierze z nagłówka wniosku, nie z zegara', () {
      expect(wniosek.rok, 2026);
    });

    test('nazwy upraw są pełne, bez wsiąkniętej stopki strony', () {
      expect(wniosek.uprawy, contains('pszenica zwyczajna ozima'));
      expect(wniosek.uprawy, contains('trawy wieloletnie na gruntach ornych'));
      for (final uprawa in wniosek.uprawy) {
        expect(uprawa, isNot(contains('Status')));
        expect(uprawa, isNot(contains('Strona')));
      }
    });

    test('identyfikatory działek są pełne — takie, jakich chce ULDK', () {
      expect(wniosek.identyfikatoryDzialek, isNotEmpty);
      for (final identyfikator in wniosek.identyfikatoryDzialek) {
        expect(
          RegExp(r'^\d{6}_\d\.\d{4}(\.AR_\d+)?\.\d+(/\d+)?$')
              .hasMatch(identyfikator),
          isTrue,
          reason: identyfikator,
        );
      }
    });

    test('kontrola wypada zgodnie i nic nie zostaje pominięte', () {
      expect(wniosek.kontrola.ostrzezenia, isEmpty);
      expect(wniosek.kontrola.wierszePominiete, 0);
      expect(wniosek.kontrola.wynikPewny, isTrue);
    });

    test('części pól sumują się do ich powierzchni', () {
      for (final pole in wniosek.pola) {
        final sumaCzesci = pole.czesci.fold(
          0,
          (suma, czesc) => suma + czesc.powierzchniaAr,
        );
        expect(sumaCzesci, pole.powierzchniaAr, reason: pole.oznaczenie);
      }
    });
  });

  group('pułapki układu wniosku', () {
    /// Buduje wiersz z podanych słów, nadając im położenie na stronie.
    List<SlowoPdf> wiersz(List<(String, double)> slowa, double gora) => [
      for (final (tekst, x) in slowa)
        SlowoPdf(tekst: tekst, x0: x, x1: x + 20, gora: gora),
    ];

    /// Nagłówek tabeli XI i wiersz numeracji kolumn — bez nich czytnik
    /// słusznie nie bierze niczego za dane.
    List<List<SlowoPdf>> tabelaXi(List<List<SlowoPdf>> wiersze) => [
      wiersz([
        ('OŚWIADCZENIE', 10),
        ('O', 60),
        ('ZADEKLAROWANYCH', 80),
        ('POWIERZCHNIACH', 160),
      ], 20),
      wiersz([
        ('1', 10),
        ('2', 40),
        ('3', 70),
        ('4', 100),
        ('5', 130),
        ('6', 160),
        ('7', 190),
        ('8', 220),
      ], 30),
      ...wiersze,
    ];

    test('numer działki rozbity na dwa wiersze składa się w jeden', () {
      // Tak wygląda każdy wiersz prawdziwego wniosku: w wierszu stoi numer
      // obrębu, a numer działki spada do następnego wiersza (lekcja z P4).
      final wniosek = CzytnikWniosku.zWierszy(
        tabelaXi([
          wiersz([
            ('A', 10),
            ('pszenica', 40),
            ('2', 100),
            ('50', 115),
            ('061506_2.0007', 160),
            ('2', 230),
            ('50', 245),
            ('PWD', 280),
          ], 40),
          wiersz([('.138', 160)], 50),
        ]),
      );
      expect(wniosek.pola, hasLength(1));
      expect(wniosek.pola.single.identyfikatory, ['061506_2.0007.138']);
      expect(wniosek.pola.single.powierzchniaAr, 250);
      expect(wniosek.kontrola.ostrzezenia, isEmpty);
    });

    test('jedno pole na kilku działkach: wiersze bez oznaczenia', () {
      final wniosek = CzytnikWniosku.zWierszy(
        tabelaXi([
          wiersz([
            ('A', 10),
            ('pszenica', 40),
            ('2', 100),
            ('50', 115),
            ('061506_2.0007', 160),
            ('1', 230),
            ('20', 245),
            ('PWD', 280),
          ], 40),
          wiersz([('.138', 160)], 50),
          wiersz([
            ('061506_2.0007', 160),
            ('1', 230),
            ('30', 245),
            ('PWD', 280),
          ], 60),
          wiersz([('.139', 160)], 70),
        ]),
      );
      expect(wniosek.pola, hasLength(1));
      expect(wniosek.pola.single.powierzchniaAr, 250);
      expect(wniosek.pola.single.czesci, hasLength(2));
      expect(wniosek.pola.single.identyfikatory, [
        '061506_2.0007.138',
        '061506_2.0007.139',
      ]);
      expect(wniosek.kontrola.ostrzezenia, isEmpty);
    });

    test('nazwa uprawy złamana na dwa wiersze wraca w całości', () {
      final wniosek = CzytnikWniosku.zWierszy(
        tabelaXi([
          wiersz([
            ('B', 10),
            ('trawy', 40),
            ('0', 100),
            ('81', 115),
            ('061506_2.0007', 160),
            ('0', 230),
            ('81', 245),
            ('ONW', 280),
          ], 40),
          wiersz([
            ('wieloletnie', 40),
            ('na', 75),
            ('gruntach', 90),
            ('ornych', 120),
            ('.140', 160),
          ], 50),
        ]),
      );
      expect(
        wniosek.pola.single.uprawa,
        'trawy wieloletnie na gruntach ornych',
      );
      expect(wniosek.pola.single.identyfikatory, ['061506_2.0007.140']);
    });

    test('kody płatności z prawej strony nie wchodzą do nazwy uprawy', () {
      final wniosek = CzytnikWniosku.zWierszy(
        tabelaXi([
          wiersz([
            ('C', 10),
            ('ziemniak', 40),
            ('0', 100),
            ('78', 115),
            ('061506_2.0007', 160),
            ('0', 230),
            ('78', 245),
            ('ONW', 280),
          ], 40),
          // „UPP" stoi po prawej stronie identyfikatora — to płatność.
          wiersz([('.141', 160), ('UPP', 300)], 50),
        ]),
      );
      expect(wniosek.pola.single.uprawa, 'ziemniak');
      expect(wniosek.pola.single.identyfikatory, ['061506_2.0007.141']);
    });

    test('niezgodna suma części daje ostrzeżenie, a nie cichą poprawkę', () {
      final wniosek = CzytnikWniosku.zWierszy(
        tabelaXi([
          wiersz([
            ('E', 10),
            ('żyto', 40),
            ('2', 100),
            ('0', 115),
            ('061506_2.0007', 160),
            ('1', 230),
            ('0', 245),
          ], 40),
          wiersz([('.143', 160)], 50),
        ]),
      );
      expect(wniosek.kontrola.wynikPewny, isFalse);
      expect(wniosek.kontrola.ostrzezenia.single, contains('pole E'));
    });

    test('wiersz przed numeracją kolumn nie jest danymi', () {
      final wniosek = CzytnikWniosku.zWierszy([
        wiersz([
          ('OŚWIADCZENIE', 10),
          ('O', 60),
          ('ZADEKLAROWANYCH', 80),
          ('POWIERZCHNIACH', 160),
        ], 20),
        wiersz([
          ('Oznaczenie', 10),
          ('Uprawa', 40),
          ('Powierzchnia', 100),
          ('061506_2.0007', 160),
          ('1', 230),
          ('0', 245),
        ], 30),
      ]);
      expect(wniosek.pola, isEmpty);
    });

    test('odsyłacz przy nazwie uprawy jest usuwany z nazwy', () {
      expect(
        CzytnikWniosku.oczyscUprawe('Uprawa mieszana_'),
        'Uprawa mieszana',
      );
      expect(CzytnikWniosku.oczyscUprawe(' TUZ '), 'TUZ');
    });
  });
}
