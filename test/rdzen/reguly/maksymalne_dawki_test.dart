import 'dart:io';

import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tabela 14 programu azotanowego (Dz.U. 2023 poz. 244, załącznik nr 9):
/// maksymalne ilości azotu działającego dla upraw.
///
/// Liczby sprawdzamy wobec rozporządzenia, nie wobec kodu — gdyby ktoś
/// podmienił słownik, te testy mają zapalić się pierwsze.
void main() {
  late MaksymalneDawkiAzotu tabela;

  setUpAll(() {
    final slownik = SlownikRegul.zTekstuJson(
      File('assets/dane/reguly_prawne.json').readAsStringSync(),
    );
    tabela = slownik.maksymalneDawkiAzotu;
  });

  group('dane tabeli', () {
    test('tabela jest w słowniku i ma podstawę prawną', () {
      expect(tabela.pusta, isFalse);
      expect(tabela.doWeryfikacji, isFalse);
      expect(tabela.zrodlo, contains('tabela 14'));
      expect(tabela.uprawy.length, greaterThan(100));
    });

    test('obniżki dla gleb słabszych są danymi, nie liczbą w kodzie', () {
      final glebowe = {
        for (final o in tabela.obnizki) o.rodzajGleby: o.procent,
      };
      expect(glebowe['bardzo_lekka'], 20);
      expect(glebowe['lekka'], 10);
    });

    test('bobowate mają limit w postaci z tabeli', () {
      expect(tabela.bobowate?.kgNHaMineralne, 30);
      expect(tabela.bobowate?.kgNHaNaturalne, 50);
    });

    test('każdy wiersz ma albo liczbę, albo znacznik bobowatych', () {
      for (final uprawa in tabela.uprawy) {
        expect(uprawa.uprawa, isNotEmpty);
        expect(uprawa.grupa, isNotEmpty);
        expect(
          uprawa.bobowate || uprawa.kgNHa != null,
          isTrue,
          reason: '${uprawa.grupa}/${uprawa.uprawa} bez limitu',
        );
      }
    });
  });

  group('dopasowanie uprawy z pola', () {
    test('nazwa dosłowna, bez ogonków i wielkich liter', () {
      expect(tabela.dlaUprawy('Pszenica ozima').kgNHa, 200);
      expect(tabela.dlaUprawy('pszenica ozima').kgNHa, 200);
      expect(tabela.dlaUprawy('JECZMIEN OZIMY').kgNHa, 140);
    });

    test('dłuższa nazwa z wniosku trafia w nazwę z tabeli', () {
      // Wniosek pisze „kukurydza na ziarno (CCM)", tabela „Kukurydza na
      // ziarno".
      expect(tabela.dlaUprawy('kukurydza na ziarno (CCM)').kgNHa, 240);
      expect(tabela.dlaUprawy('burak cukrowy z plantacji').kgNHa, 180);
    });

    test('dopasowanie bierze najdłuższą nazwę, nie pierwszą', () {
      // „burak pastewny" nie może wygrać z „burak ćwikłowy", a sam „burak"
      // nie może przesłonić żadnego z nich.
      expect(tabela.dlaUprawy('burak ćwikłowy').kgNHa, 150);
      expect(tabela.dlaUprawy('burak pastewny').kgNHa, 200);
      expect(tabela.dlaUprawy('ziemniak wczesny').kgNHa, 90);
      expect(tabela.dlaUprawy('ziemniak późny').kgNHa, 180);
    });

    test('ta sama nazwa w dwóch grupach: nie wybieramy za rolnika', () {
      // Rzepak: 240 kg w oleistych, 200 kg w pastewnych.
      final rzepak = tabela.dlaUprawy('rzepak');
      expect(rzepak.stan, StanMaksymalnejDawki.niejednoznaczny);
      expect(rzepak.kgNHa, isNull);
      expect(rzepak.najnizszyKgNHa, 200);
      expect(rzepak.opisDopasowan, contains('oleiste'));
      expect(rzepak.opisDopasowan, contains('pastewne'));
    });

    test('bobowate mają osobny stan, nie liczbę', () {
      final soja = tabela.dlaUprawy('soja');
      expect(soja.stan, StanMaksymalnejDawki.bobowate);
      expect(soja.kgNHa, isNull);
      expect(soja.bobowate?.kgNHaMineralne, 30);
    });

    test('nieznana uprawa nie dostaje zgadywanego limitu', () {
      final wlasna = tabela.dlaUprawy('mieszanka rolnika z miedzy');
      expect(wlasna.stan, StanMaksymalnejDawki.brak);
      expect(wlasna.kgNHa, isNull);
      expect(wlasna.przekroczony(400), isFalse);
      expect(tabela.dlaUprawy('').stan, StanMaksymalnejDawki.brak);
    });

    test('wiersz zbiorczy wybiera tylko rolnik wprost', () {
      // „Inne oleiste" nie może złapać się na słowo „inne" w nazwie pola.
      expect(
        tabela.dlaUprawy('inne rośliny z pola za domem').stan,
        StanMaksymalnejDawki.brak,
      );
      expect(tabela.dlaUprawy('Inne oleiste').kgNHa, 160);
    });

    test('przekroczenie liczy się od limitu, nie od zaokrąglenia', () {
      final pszenica = tabela.dlaUprawy('pszenica ozima');
      expect(pszenica.przekroczony(199.9), isFalse);
      expect(pszenica.przekroczony(200), isFalse);
      expect(pszenica.przekroczony(200.1), isTrue);
    });
  });
}
