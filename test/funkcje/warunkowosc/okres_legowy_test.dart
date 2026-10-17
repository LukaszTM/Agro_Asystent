import 'dart:io';

import 'package:agro_asystent/funkcje/warunkowosc/okres_legowy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';

/// Norma GAEC 8: elementy krajobrazu i okres lęgowy ptaków — etap 2,
/// krok 5.
///
/// Rodzaj pracy wybiera rolnik z listy, więc aplikacja nie odgaduje
/// z tekstu uwag, co robił na polu. Okres zakazu i chronione elementy
/// pochodzą ze słownika reguł.
void main() {
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );
  final silnik = OkresLegowy(reguly: reguly);

  group('prace są danymi, nie listą w kodzie', () {
    test('słownik zna prace i wskazuje normę GAEC 8', () {
      expect(silnik.prace.pusta, isFalse);
      final przycinanie = silnik.praca('przycinanie_drzew')!;
      expect(przycinanie.idNormy, 'gaec_8');
      expect(przycinanie.idTerminuZakazu, 'zakaz_przycinania');
    });

    test('okres zakazu bierze się z terminu normy, nie z pracy', () {
      final termin = silnik.terminZakazu(silnik.praca('przycinanie_drzew')!)!;
      expect(termin.od, '04-15');
      expect(termin.doDnia, '07-31');
    });

    test('praca, której słownik nie zna, nie wywraca wpisu', () {
      expect(silnik.praca('praca_z_przyszlej_wersji'), isNull);
      expect(
        silnik.ostrzezeniePrzedZapisem(
          idPracy: 'praca_z_przyszlej_wersji',
          kiedy: DateTime(2026, 5, 10),
        ),
        isNull,
      );
    });
  });

  group('okres lęgowy ptaków', () {
    test('przycinanie w maju ostrzega i podaje daty z przepisu', () {
      final ostrzezenie = silnik.ostrzezeniePrzedZapisem(
        idPracy: 'przycinanie_drzew',
        kiedy: DateTime(2026, 5, 10),
      );
      expect(ostrzezenie, isNotNull);
      expect(ostrzezenie!.tresc, contains('15 kwietnia'));
      expect(ostrzezenie.tresc, contains('31 lipca'));
      expect(ostrzezenie.tresc, contains('okres lęgowy'));
      expect(ostrzezenie.coZrobic, contains('wierzba'));
    });

    test('ostatni i pierwszy dzień okresu też są objęte', () {
      for (final dzien in [DateTime(2026, 4, 15), DateTime(2026, 7, 31)]) {
        expect(
          silnik.ostrzezeniePrzedZapisem(
            idPracy: 'przycinanie_drzew',
            kiedy: dzien,
          ),
          isNotNull,
          reason: '$dzien',
        );
      }
    });

    test('przycinanie w lutym i w sierpniu nie straszy', () {
      for (final dzien in [DateTime(2026, 2, 20), DateTime(2026, 8, 1)]) {
        expect(
          silnik.ostrzezeniePrzedZapisem(
            idPracy: 'przycinanie_drzew',
            kiedy: dzien,
          ),
          isNull,
          reason: '$dzien',
        );
      }
    });

    test('wierzby i drzewa owocowe przepis wyłącza z zakazu', () {
      expect(
        silnik.ostrzezeniePrzedZapisem(
          idPracy: 'przycinanie_wylaczone',
          kiedy: DateTime(2026, 5, 10),
        ),
        isNull,
      );
    });

    test('inna praca na polu nie dotyczy tej normy', () {
      expect(
        silnik.ostrzezeniePrzedZapisem(
          idPracy: 'inna',
          kiedy: DateTime(2026, 5, 10),
        ),
        isNull,
      );
    });

    test('bez wybranej pracy nie ostrzegamy', () {
      expect(
        silnik.ostrzezeniePrzedZapisem(
          idPracy: null,
          kiedy: DateTime(2026, 5, 10),
        ),
        isNull,
      );
    });
  });

  group('zakaz niszczenia elementów krajobrazu', () {
    test('usunięcie drzewa albo rowu ostrzega w każdym dniu roku', () {
      for (final dzien in [DateTime(2026, 1, 10), DateTime(2026, 9, 30)]) {
        final ostrzezenie = silnik.ostrzezeniePrzedZapisem(
          idPracy: 'usuwanie_elementu',
          kiedy: dzien,
        );
        expect(ostrzezenie, isNotNull, reason: '$dzien');
        expect(ostrzezenie!.tresc, contains('pomnikami przyrody'));
      }
    });

    test('ostrzeżenie podaje progi z przepisu: 2 m rowu i 100 m² oczka', () {
      final ostrzezenie = silnik.ostrzezeniePrzedZapisem(
        idPracy: 'usuwanie_elementu',
        kiedy: DateTime(2026, 1, 10),
      )!;
      expect(ostrzezenie.tresc, contains('2 m'));
      expect(ostrzezenie.tresc, contains('100 m²'));
      expect(ostrzezenie.coZrobic, contains('wpis ma pokazywać prawdę'));
    });
  });
}
