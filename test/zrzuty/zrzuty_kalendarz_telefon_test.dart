import 'dart:io';

import 'package:agro_asystent/funkcje/biodynamika/biodynamika.dart';
import 'package:agro_asystent/rdzen/wspolne/kalendarz_biodynamiczny.dart';
import 'package:agro_asystent/wyglad/nowoczesny/motyw.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Zrzuty kalendarza biodynamicznego na telefonie — w obu wyglądach,
/// w tygodniu i w miesiącu. Uruchamia się tak jak zrzuty komputera:
///
///   AGRO_ZRZUTY=1 flutter test --update-goldens test/zrzuty
void main() {
  final robZrzuty = Platform.environment['AGRO_ZRZUTY'] == '1';
  final katalog = Directory('dane/wynik/zrzuty').absolute;
  final slownik = SlownikBiodynamiczny.zTekstuJson(
    File('assets/dane/kalendarz_biodynamiczny.json').readAsStringSync(),
  );
  final kalendarz = KalendarzBiodynamiczny(slownik);
  final dzis = DateTime(2026, 10, 1, 9);

  Future<void> wczytajCzcionki() async {
    const inter = '/usr/share/fonts/opentype/inter';
    final kroj = FontLoader('Roboto');
    for (final plik in [
      'Inter-Regular.otf',
      'Inter-Medium.otf',
      'Inter-SemiBold.otf',
      'Inter-Bold.otf',
    ]) {
      final f = File('$inter/$plik');
      if (!f.existsSync()) continue;
      final bajty = f.readAsBytesSync();
      kroj.addFont(Future.value(ByteData.view(bajty.buffer)));
    }
    await kroj.load();
  }

  ThemeData zKrojem(ThemeData motyw) {
    ButtonStyle? popraw(ButtonStyle? styl) {
      final tekst = styl?.textStyle?.resolve(const {});
      if (styl == null || tekst == null) return styl;
      return styl.copyWith(
        textStyle: WidgetStatePropertyAll(tekst.copyWith(fontFamily: 'Roboto')),
      );
    }

    return motyw.copyWith(
      textTheme: motyw.textTheme.apply(fontFamily: 'Roboto'),
      textButtonTheme: TextButtonThemeData(
        style: popraw(motyw.textButtonTheme.style),
      ),
    );
  }

  Future<void> pokaz(
    WidgetTester tester, {
    required ThemeData motyw,
    required StylKalendarza styl,
    required double odstep,
    required Color tlo,
  }) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: motyw,
        home: Scaffold(
          appBar: AppBar(title: const Text('Kalendarz')),
          body: ListView(
            padding: EdgeInsets.all(odstep),
            children: [
              Material(
                color: tlo,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: EdgeInsets.all(odstep),
                  child: KalendarzBiodynamicznyWidok(
                    tydzien: kalendarz.tydzien(dzis),
                    miesiac: kalendarz.miesiac(dzis.year, dzis.month),
                    dzis: dzis,
                    zastrzezenie: slownik.zastrzezenie,
                    styl: styl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> zrzut(WidgetTester tester, String nazwa) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(Uri.file('${katalog.path}/$nazwa.png')),
    );
  }

  group('zrzuty kalendarza na telefonie', () {
    setUp(() async {
      if (!robZrzuty) return;
      katalog.createSync(recursive: true);
      await wczytajCzcionki();
    });

    for (final (nazwa, motyw, styl, odstep, tlo) in [
      (
        'prosty',
        MotywProsty.zbuduj(),
        MotywProsty.stylKalendarza,
        MotywProsty.odstep,
        MotywProsty.powierzchnia,
      ),
      (
        'nowoczesny',
        MotywNowoczesny.zbuduj(),
        MotywNowoczesny.stylKalendarza,
        MotywNowoczesny.odstep,
        MotywNowoczesny.karta,
      ),
    ]) {
      testWidgets('$nazwa: tydzień i miesiąc', (tester) async {
        if (!robZrzuty) return;
        await pokaz(
          tester,
          motyw: zKrojem(motyw),
          styl: styl,
          odstep: odstep,
          tlo: tlo,
        );
        await zrzut(tester, 'tel-$nazwa-kalendarz-tydzien');
        await tester.tap(find.text('Pokaż miesiąc'));
        await zrzut(tester, 'tel-$nazwa-kalendarz-miesiac');
      });
    }
  });
}
