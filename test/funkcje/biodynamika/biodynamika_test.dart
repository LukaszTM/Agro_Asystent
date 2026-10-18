import 'dart:io';

import 'package:agro_asystent/funkcje/biodynamika/astronomia.dart';
import 'package:agro_asystent/funkcje/biodynamika/biodynamika.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kalendarz biodynamiczny liczony na urządzeniu.
///
/// Rachunek jest astronomiczny i da się go sprawdzić na zdarzeniach,
/// których daty są znane co do minuty: zaćmienia (nów i pełnia),
/// równonoc i przesilenie.
void main() {
  final slownik = SlownikBiodynamiczny.zTekstuJson(
    File('assets/dane/kalendarz_biodynamiczny.json').readAsStringSync(),
  );
  final kalendarz = KalendarzBiodynamiczny(slownik);

  group('astronomia', () {
    test('zaćmienie Słońca wypada w nowiu', () {
      // Całkowite zaćmienie Słońca 8 kwietnia 2024 r., maksimum 18:17 UTC.
      final jd = Astronomia.dzienJulianski(DateTime.utc(2024, 4, 8, 18, 17));

      expect(Astronomia.elongacja(jd), closeTo(360, 0.2));
      expect(Astronomia.oswietlenie(jd), closeTo(0, 0.001));
    });

    test('zaćmienie Księżyca wypada w pełni', () {
      // Całkowite zaćmienie Księżyca 14 marca 2025 r., maksimum 06:58 UTC.
      final jd = Astronomia.dzienJulianski(DateTime.utc(2025, 3, 14, 6, 58));

      expect(Astronomia.elongacja(jd), closeTo(180, 0.2));
      expect(Astronomia.oswietlenie(jd), closeTo(1, 0.001));
    });

    test('Słońce stoi na zerze w równonoc i na 90 stopniach w przesilenie', () {
      final rownonoc = Astronomia.dzienJulianski(
        DateTime.utc(2025, 3, 20, 9, 1),
      );
      final przesilenie = Astronomia.dzienJulianski(
        DateTime.utc(2025, 6, 21, 2, 42),
      );

      expect(Astronomia.dlugoscSlonca(rownonoc), closeTo(0, 0.1));
      expect(Astronomia.dlugoscSlonca(przesilenie), closeTo(90, 0.1));
    });
  });

  group('słownik', () {
    test('dwanaście znaków, żywioły idą po kolei', () {
      expect(slownik.znaki.length, 12);
      expect(
        [for (final znak in slownik.znaki.take(4)) znak.zywiol.id],
        ['ogien', 'ziemia', 'powietrze', 'woda'],
      );
      expect(
        {for (final znak in slownik.znaki) znak.zywiol.praca},
        {'korzeń', 'liść', 'kwiat', 'owoc'},
      );
    });

    test('nów obejmuje koniec i początek obiegu', () {
      expect(slownik.fazaDla(350).nazwa, 'nów');
      expect(slownik.fazaDla(5).nazwa, 'nów');
      expect(slownik.fazaDla(180).nazwa, 'pełnia');
      expect(slownik.fazaDla(90).nazwa, 'pierwsza kwadra');
    });

    test('zodiak gwiazdowy zgadza się z kalendarzem: Słońce wchodzi w Ryby '
        'w połowie marca', () {
      ZnakZodiaku slonceW(DateTime dzien) {
        final jd = Astronomia.dzienJulianski(dzien);
        return slownik.znakDla(
          slownik.gwiazdowa(Astronomia.dlugoscSlonca(jd), dzien),
        );
      }

      expect(slonceW(DateTime.utc(2026, 3, 10, 12)).nazwa, 'Wodnik');
      expect(slonceW(DateTime.utc(2026, 3, 20, 12)).nazwa, 'Ryby');
    });
  });

  group('kalendarz', () {
    test('każdy dzień ma gwiazdozbiór i rodzaj pracy', () {
      for (final dzien in kalendarz.miesiac(2026, 10)) {
        expect(dzien.znak.nazwa, isNotEmpty);
        expect(
          dzien.praca,
          anyOf('korzeń', 'liść', 'kwiat', 'owoc'),
          reason: 'dzień ${dzien.data} bez rodzaju pracy',
        );
        expect(dzien.oswietlenie, inInclusiveRange(0, 1));
      }
    });

    test('w ciągu 28 dni Księżyc obchodzi wszystkie dwanaście znaków', () {
      final znaki = {
        for (var numer = 0; numer < 28; numer++)
          kalendarz
              .dzien(DateTime(2026, 5, 1).add(Duration(days: numer)))
              .znak
              .nazwa,
      };

      expect(znaki.length, 12);
    });

    test('zmiana znaku w ciągu dnia zmienia też rodzaj pracy', () {
      final zeZmiana = kalendarz
          .miesiac(2026, 10)
          .where((dzien) => dzien.zmiana != null)
          .toList();

      // Księżyc zmienia gwiazdozbiór co mniej więcej dwa i pół dnia, więc
      // w miesiącu wypada to kilkanaście razy.
      expect(zeZmiana.length, greaterThan(8));
      for (final dzien in zeZmiana) {
        final zmiana = dzien.zmiana!;
        // Sąsiednie gwiazdozbiory mają różne żywioły, więc po zmianie
        // tradycja radzi co innego.
        expect(zmiana.na.zywiol.praca, isNot(zmiana.z.zywiol.praca));
        expect(zmiana.okolo.day, dzien.data.day);
        // Znak dnia bierzemy z południa — zależnie od godziny zmiany jest
        // to ten sprzed niej albo ten po niej.
        expect(dzien.znak.nazwa, anyOf(zmiana.z.nazwa, zmiana.na.nazwa));
      }
    });

    test('pełnia znaczy pełną tarczę, nów — ciemną', () {
      final pelnia = kalendarz.dzien(DateTime(2025, 3, 14));

      expect(pelnia.faza.nazwa, 'pełnia');
      expect(pelnia.oswietlenie, greaterThan(0.99));
      expect(pelnia.rosnie, isFalse);
    });

    test('tydzień to siedem kolejnych dni od podanego', () {
      final tydzien = kalendarz.tydzien(DateTime(2026, 10, 18, 17, 30));

      expect(tydzien.length, 7);
      expect(tydzien.first.data, DateTime(2026, 10, 18));
      expect(tydzien.last.data, DateTime(2026, 10, 24));
    });

    test(
      'miesiąc ma tyle dni, ile kalendarz — także luty w roku przestępnym',
      () {
        expect(kalendarz.miesiac(2026, 2).length, 28);
        expect(kalendarz.miesiac(2028, 2).length, 29);
        expect(kalendarz.miesiac(2026, 10).length, 31);
      },
    );
  });
}
