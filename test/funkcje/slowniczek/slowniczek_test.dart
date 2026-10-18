import 'dart:io';

import 'package:agro_asystent/funkcje/slowniczek/slowniczek.dart';
import 'package:flutter_test/flutter_test.dart';

/// Słowniczek pojęć — skróty z wniosku i pism z ARiMR.
///
/// Czego pilnują testy: hasła są danymi z pliku (nie tekstem w ekranie),
/// szukanie działa bez ogonków i wielkich liter, a brak hasła zwraca
/// `null` zamiast zmyślonego wyjaśnienia.
void main() {
  const slownik = SlownikPojec(
    wersja: '2026.10.18.1',
    poCo: 'Skróty, które rolnik spotyka we wnioskach.',
    zastrzezenie: 'Słowniczek tłumaczy pojęcia, nie zastępuje przepisu.',
    hasla: [
      HasloSlownika(
        skrot: 'TUZ',
        nazwa: 'trwałe użytki zielone',
        wyjasnienie: 'Łąki i pastwiska — grunt pod trawą.',
        gdzie: 'wniosek o dopłaty',
        status: 'potwierdzone',
      ),
      HasloSlownika(
        skrot: 'DJP',
        nazwa: 'duża jednostka przeliczeniowa inwentarza',
        wyjasnienie: 'Miara liczby zwierząt.',
        gdzie: 'program azotanowy',
        status: 'do_weryfikacji',
      ),
    ],
  );

  group('szukanie hasła', () {
    test('znajduje skrót bez względu na wielkość liter', () {
      expect(slownik.szukaj('tuz').single.skrot, 'TUZ');
      expect(slownik.szukaj('TUZ').single.skrot, 'TUZ');
    });

    test('znajduje po nazwie wpisanej bez ogonków', () {
      // Rolnik pisze „laki" tak, jak mu wygodnie — bez polskich znaków.
      expect(slownik.szukaj('uzytki zielone').single.skrot, 'TUZ');
      expect(slownik.szukaj('laki').single.skrot, 'TUZ');
    });

    test('puste szukanie zwraca wszystko', () {
      expect(slownik.szukaj('').length, 2);
      expect(slownik.szukaj('   ').length, 2);
    });

    test('nieznane słowo nie zwraca nic', () {
      expect(slownik.szukaj('traktor'), isEmpty);
    });

    test('hasło po skrócie, a brak hasła to null — nie zgadujemy', () {
      expect(slownik.haslo('tuz')?.nazwa, 'trwałe użytki zielone');
      expect(slownik.haslo('GAEC'), isNull);
    });
  });

  test('hasło bez potwierdzenia w przepisie jest oznaczone', () {
    expect(slownik.haslo('TUZ')!.doWeryfikacji, isFalse);
    expect(slownik.haslo('DJP')!.doWeryfikacji, isTrue);
  });

  group('plik słowniczka w aplikacji', () {
    late SlownikPojec zPliku;

    setUpAll(() {
      zPliku = SlownikPojec.zTekstuJson(
        File('assets/dane/slowniczek.json').readAsStringSync(),
      );
    });

    test('wczytuje się i ma numer wersji', () {
      expect(zPliku.wersja, isNotEmpty);
      expect(zPliku.zastrzezenie, isNotEmpty);
      expect(zPliku.hasla, isNotEmpty);
    });

    test('wyjaśnia TUZ — od tego hasła słowniczek się zaczął', () {
      final tuz = zPliku.haslo('TUZ');

      expect(tuz, isNotNull);
      expect(tuz!.nazwa, contains('trwałe użytki zielone'));
      // Wyjaśnienie musi prowadzić do tego, co rolnik widzi w aplikacji,
      // a nie powtarzać nazwy urzędowej.
      expect(tuz.wyjasnienie, contains('Łąka lub pastwisko'));
    });

    test('każde hasło ma wyjaśnienie, miejsce i stan sprawdzenia', () {
      for (final haslo in zPliku.hasla) {
        expect(haslo.skrot, isNotEmpty, reason: haslo.nazwa);
        expect(haslo.nazwa, isNotEmpty, reason: haslo.skrot);
        expect(haslo.wyjasnienie, isNotEmpty, reason: haslo.skrot);
        expect(haslo.gdzie, isNotEmpty, reason: haslo.skrot);
        expect(
          haslo.status,
          anyOf('potwierdzone', 'do_weryfikacji'),
          reason: haslo.skrot,
        );
      }
    });

    test('skróty się nie powtarzają', () {
      final skroty = zPliku.hasla.map((h) => h.skrot).toList();

      expect(skroty.toSet().length, skroty.length);
    });
  });
}
