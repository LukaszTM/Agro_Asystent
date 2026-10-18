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
      appName: 'Agro Asystent',
      packageName: 'pl.agroasystent.agro_asystent',
      version: '0.2.0',
      buildNumber: '2',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: WierszWersji(przed: 'Agro Asystent • ')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Agro Asystent • Wersja 0.2.0 (budowa 2)'),
      findsOneWidget,
    );
  });

  test('bez numeru budowy zostaje sama wersja', () {
    const wersja = WersjaProgramu(wersja: '0.2.0', numerBudowy: '');

    expect(wersja.opis, 'Wersja 0.2.0');
  });
}
