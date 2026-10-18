import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Testy pilnujące zasad z CLAUDE.md, których analizator nie sprawdza sam.
void main() {
  group('logika nie zależy od wyglądu', () {
    test('rdzen i funkcje nie importują niczego z wyglad', () {
      final winowajcy = <String>[];
      for (final katalog in ['lib/rdzen', 'lib/funkcje']) {
        for (final plik in _plikiDart(katalog)) {
          final tresc = plik.readAsStringSync();
          final importyWygladu = RegExp(
            r'''^\s*import\s+['"][^'"]*wyglad/''',
            multiLine: true,
          );
          if (importyWygladu.hasMatch(tresc)) {
            winowajcy.add(plik.path);
          }
        }
      }
      expect(
        winowajcy,
        isEmpty,
        reason:
            'Baza, reguły i dokumenty są wspólne dla obu wyglądów. '
            'Przenieś kod ekranu do lib/wyglad/.',
      );
    });

    test('żaden wygląd nie importuje innego wyglądu', () {
      // Trzy warstwy ekranów: dwa wyglądy telefonu i program na komputer.
      // Każda z nich ma własne ekrany; wspólny kod idzie do rdzenia,
      // inaczej zmiana w jednym wyglądzie psułaby drugi.
      final winowajcy = <String>[];
      const wyglady = ['prosty', 'nowoczesny', 'komputer'];
      for (final swoj in wyglady) {
        for (final obcy in wyglady.where((w) => w != swoj)) {
          for (final plik in _plikiDart('lib/wyglad/$swoj')) {
            final wzor = RegExp(
              '''^\\s*import\\s+['"][^'"]*wyglad/$obcy/''',
              multiLine: true,
            );
            if (wzor.hasMatch(plik.readAsStringSync())) {
              winowajcy.add('${plik.path} → $obcy');
            }
          }
        }
      }
      expect(
        winowajcy,
        isEmpty,
        reason: 'Wspólny kod ekranów trafia do lib/rdzen/wspolne/.',
      );
    });
  });

  group('jedno miejsce decydujące o premium', () {
    test('tylko lib/rdzen/dostep wymienia funkcje premium', () {
      final winowajcy = <String>[];
      for (final plik in _plikiDart('lib')) {
        if (plik.path.contains('lib/rdzen/dostep/')) {
          continue;
        }
        final tresc = plik.readAsStringSync();
        if (RegExp(r'\b(maPremium|_tylkoPremium)\b').hasMatch(tresc)) {
          winowajcy.add(plik.path);
        }
      }
      expect(
        winowajcy,
        isEmpty,
        reason:
            'Pytaj przez DostepFunkcji.czyDostepna(Funkcja...), '
            'nie o samo posiadanie premium.',
      );
    });
  });

  group('progi i terminy jako dane', () {
    test('kod nie wpisuje na stałe limitu azotu ani progów powierzchni', () {
      final winowajcy = <String>[];
      // Liczby z przepisów, które najłatwiej wpisać omyłkowo w kodzie.
      final podejrzane = RegExp(r'(?<![\w.])(170|100\.0|60\.0|10\.0)(?![\w.])');
      for (final plik in _plikiDart('lib')) {
        for (final wiersz in plik.readAsLinesSync()) {
          final bezKomentarza = wiersz.split('//').first;
          if (podejrzane.hasMatch(bezKomentarza)) {
            winowajcy.add('${plik.path}: ${wiersz.trim()}');
          }
        }
      }
      expect(
        winowajcy,
        isEmpty,
        reason:
            'Progi, limity i terminy należą do '
            'assets/dane/reguly_prawne.json, nie do kodu Dart.',
      );
    });
  });
}

Iterable<File> _plikiDart(String katalog) {
  final katalogDart = Directory(katalog);
  if (!katalogDart.existsSync()) {
    return const [];
  }
  return katalogDart
      .listSync(recursive: true)
      .whereType<File>()
      .where((p) => p.path.endsWith('.dart'));
}
