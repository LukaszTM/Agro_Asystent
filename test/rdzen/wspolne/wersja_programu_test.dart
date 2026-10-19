import 'package:agro_asystent/rdzen/wspolne/wersja_programu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Numer wersji na ekranie ustawień.
///
/// W czasie testów z rolnikami to jedyny sposób, żeby wiedzieć, którego
/// pliku dotyczy zgłoszona uwaga.
void main() {
  testWidgets('pokazuje numer wersji z paczki aplikacji', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Mój Łan',
      packageName: 'pl.mojlan.app',
      version: '0.2.0',
      buildNumber: '2',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WierszWersji(przed: 'Mój Łan • ')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mój Łan • Wersja 0.2.0 (budowa 2)'), findsOneWidget);
  });

  test('bez numeru budowy zostaje sama wersja', () {
    const wersja = WersjaProgramu(wersja: '0.2.0', numerBudowy: '');

    expect(wersja.opis, 'Wersja 0.2.0');
  });

  group('wydanie testowe', () {
    test('mówi testerowi, że ogląda wszystko', () {
      final opis = WersjaProgramu.opisWydania(testowe: true);

      expect(opis, contains('wszystkie dodatki odblokowane'));
      // I od razu prostuje, żeby nikt nie uznał, że magazyn będzie
      // darmowy także potem.
      expect(opis, contains('część z nich będzie płatna'));
      expect(opis, contains('dokumentacja'));
    });

    test('w wydaniu dla rolnika nie ma żadnego dopisku', () {
      expect(WersjaProgramu.opisWydania(testowe: false), isEmpty);
    });
  });
}
