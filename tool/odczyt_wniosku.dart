// Narzędzie wiersza poleceń dla dewelopera — wynik wypisujemy na ekran.
// ignore_for_file: avoid_print

import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/czytnik_wniosku.dart';

/// Odczyt wniosku z pliku na dysku dewelopera — służy do porównania wyniku
/// z czytnikiem w Pythonie (`tools/p4_wniosek/czytnik.py`) na prawdziwym
/// wniosku, którego nie wolno trzymać w repozytorium (CLAUDE.md, reguła 2).
///
/// Użycie: `dart run tool/odczyt_wniosku.dart <plik.pdf>`
void main(List<String> argv) {
  final plik = File(argv[0]).readAsBytesSync();
  final wniosek = CzytnikWniosku.zBajtow(plik);
  print(
    'Działki referencyjne: ${wniosek.dzialki.length} '
    '(${wniosek.powierzchniaDzialekHa.toStringAsFixed(2)} ha)',
  );
  print('Pola (działki rolne):  ${wniosek.pola.length}');
  print(
    'Powierzchnia pól:      '
    '${(wniosek.powierzchniaPolAr / 100).toStringAsFixed(2)} ha',
  );
  print('Różnych upraw:         ${wniosek.uprawy.length}');
  print('Identyfikatorów:       ${wniosek.identyfikatoryDzialek.length}');
  print('Pominięte wiersze:     ${wniosek.kontrola.wierszePominiete}');
  for (final przyklad in wniosek.kontrola.przykladyPominietych) {
    print('    $przyklad');
  }
  print('Kontrola: ${wniosek.kontrola.wynikPewny ? "zgodna" : "NIEZGODNA"}');
  for (final ostrzezenie in wniosek.kontrola.ostrzezenia.take(10)) {
    print('  ! $ostrzezenie');
  }
  print('Uprawy: ${wniosek.uprawy.join("; ")}');
}
