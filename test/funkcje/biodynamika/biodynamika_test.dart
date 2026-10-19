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

  group('oznaczenia siewne jak w kalendarzu rolników', () {
    // Daty i godziny faz głównych z drukowanego Kalendarza Rolników na
    // grudzień 2026 (czas środkowoeuropejski). Nasz rachunek ma dokładność
    // około 0,2 stopnia, czyli kilkudziesięciu minut.
    //
    // Druk podaje ostatnią kwadrę 31 XII o 19:59 — to pomyłka wydawnictwa:
    // od ostatniej kwadry 1 XII (7:08) do następnej mija jeden miesiąc
    // synodyczny, 29,53 doby, czyli wypada ona 30 XII wieczorem. Tak też
    // liczy nasz rachunek (i tak podają tablice astronomiczne).
    final kalendarz = KalendarzBiodynamiczny(slownik);

    test('nów, kwadry i pełnia wypadają w dni z kalendarza', () {
      final oczekiwane = {
        DateTime(2026, 12, 1): 'ostatnia kwadra',
        DateTime(2026, 12, 9): 'nów',
        DateTime(2026, 12, 17): 'pierwsza kwadra',
        DateTime(2026, 12, 24): 'pełnia',
        DateTime(2026, 12, 30): 'ostatnia kwadra',
      };
      for (final wpis in oczekiwane.entries) {
        final dzien = kalendarz.dzien(wpis.key);
        expect(dzien.zmianaFazy?.faza.nazwa, wpis.value, reason: '${wpis.key}');
        expect(dzien.ocenaSiewu, OcenaSiewu.zly, reason: '${wpis.key}');
      }
      // Dzień obok fazy jest zwykłym dniem.
      expect(kalendarz.dzien(DateTime(2026, 12, 10)).zmianaFazy, isNull);
    });

    test('godzina nowiu zgadza się z kalendarzem do kilkudziesięciu minut', () {
      // Kalendarz: 9 XII 2026, 1:50 CET = 0:50 UTC. Test liczy w czasie
      // lokalnym maszyny, więc porównujemy w UTC.
      final now = kalendarz.dzien(DateTime(2026, 12, 9)).zmianaFazy!;
      final roznica = now.okolo.toUtc().difference(
        DateTime.utc(2026, 12, 9, 0, 50),
      );
      expect(roznica.inMinutes.abs(), lessThan(90));
    });

    test('kwadry idą po kolei: liść, owoc, korzeń, gleba', () {
      expect(kalendarz.dzien(DateTime(2026, 12, 12)).kwadra.praca, 'liść');
      expect(kalendarz.dzien(DateTime(2026, 12, 20)).kwadra.praca, 'owoc');
      expect(kalendarz.dzien(DateTime(2026, 12, 27)).kwadra.praca, 'korzeń');
      final gleba = kalendarz.dzien(DateTime(2026, 12, 4));
      expect(gleba.kwadra.praca, isNull);
      expect(gleba.ocenaSiewu, OcenaSiewu.bezSiewu);
    });

    test('dwie rączki tylko wtedy, gdy znak mówi to samo, co kwadra', () {
      final dni = kalendarz.miesiac(2026, 12);
      final bardzoDobre = dni.where(
        (d) => d.ocenaSiewu == OcenaSiewu.bardzoDobry,
      );
      expect(bardzoDobre, isNotEmpty);
      for (final dzien in bardzoDobre) {
        expect(dzien.kwadra.praca, dzien.praca, reason: '${dzien.data}');
      }
      final dobre = dni.where((d) => d.ocenaSiewu == OcenaSiewu.dobry);
      for (final dzien in dobre) {
        expect(dzien.kwadra.praca, isNotNull);
        expect(dzien.kwadra.praca, isNot(dzien.praca), reason: '${dzien.data}');
      }
    });

    test('w miesiącu są cztery albo pięć dni faz głównych', () {
      final ile = kalendarz
          .miesiac(2026, 12)
          .where((d) => d.zmianaFazy != null)
          .length;
      expect(ile, inInclusiveRange(4, 5));
    });

    test('plik danych opisuje kwadry i fazy główne', () {
      expect(slownik.siew.kwadry, hasLength(4));
      expect(slownik.siew.fazyGlowne.map((f) => f.stopnie), [0, 90, 180, 270]);
      expect(slownik.siew.opis, contains('rączka'));
    });
  });
}
