import 'dart:io';

import 'package:agro_asystent/funkcje/biodynamika/biodynamika.dart';
import 'package:agro_asystent/rdzen/wspolne/kalendarz_biodynamiczny.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wspólny kalendarz — bez wyglądu: kolory podaje test, tak jak podają je
/// motywy telefonu i komputera.
void main() {
  final slownik = SlownikBiodynamiczny.zTekstuJson(
    File('assets/dane/kalendarz_biodynamiczny.json').readAsStringSync(),
  );
  final kalendarz = KalendarzBiodynamiczny(slownik);
  final dzis = DateTime(2026, 12, 7, 9);

  const styl = StylKalendarza(
    tekst: Colors.black,
    tekstPomocniczy: Colors.grey,
    tlo: Colors.white,
    akcent: Colors.green,
    ostrzezenie: Colors.orange,
    barwyPracy: {
      'korzeń': Colors.brown,
      'liść': Colors.lightGreen,
      'kwiat': Colors.purple,
      'owoc': Colors.deepOrange,
    },
    zaokraglenie: 8,
    odstep: 12,
  );

  Future<void> pokaz(WidgetTester tester, {required double szerokosc}) async {
    tester.view.physicalSize = Size(szerokosc, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KalendarzBiodynamicznyWidok(
              tydzien: kalendarz.tydzien(dzis),
              miesiac: kalendarz.miesiac(2026, 12),
              dzis: dzis,
              zastrzezenie: slownik.zastrzezenie,
              styl: styl,
              tytul: 'Kalendarz biodynamiczny',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('na szerokim ekranie każdy dzień to jeden wiersz', (
    tester,
  ) async {
    await pokaz(tester, szerokosc: 900);

    expect(find.text('Kalendarz biodynamiczny'), findsOneWidget);
    expect(find.text('pon 7.12'), findsOneWidget);
    expect(find.text('niedz 13.12'), findsOneWidget);
    // Nów 9 XII: dzień zły do siewu — zdanie główne mówi to wprost.
    expect(find.textContaining('nów o'), findsOneWidget);
    expect(find.byType(IntrinsicHeight), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('na telefonie opis schodzi pod oznaczenia i nic nie wystaje', (
    tester,
  ) async {
    await pokaz(tester, szerokosc: 360);

    expect(find.text('pon 7.12'), findsOneWidget);
    expect(find.byType(IntrinsicHeight), findsNWidgets(7));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Pokaż miesiąc'));
    await tester.pumpAndSettle();
    expect(find.text('grudnia 2026'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^9 grudnia, ')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bez tytułu zostaje sam przełącznik tygodnia i miesiąca', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KalendarzBiodynamicznyWidok(
              tydzien: kalendarz.tydzien(dzis),
              miesiac: kalendarz.miesiac(2026, 12),
              dzis: dzis,
              zastrzezenie: slownik.zastrzezenie,
              styl: styl,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kalendarz biodynamiczny'), findsNothing);
    expect(find.text('Pokaż miesiąc'), findsOneWidget);
  });
}
