import 'package:agro_asystent/wyglad/nowoczesny/widgety/wybor.dart'
    as nowoczesny;
import 'package:agro_asystent/wyglad/prosty/widgety/wybor_liczby.dart'
    as prosty;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ekran telefonu — domyślny ekran testowy (800×600) jest za niski na
/// arkusz z klawiaturą.
Future<void> jakTelefon(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  group('odczytajLiczbe', () {
    test('przyjmuje przecinek, kropkę i liczbę bez części ułamkowej', () {
      expect(prosty.odczytajLiczbe('1,5'), 1.5);
      expect(prosty.odczytajLiczbe('2.25'), 2.25);
      expect(prosty.odczytajLiczbe('12'), 12);
      expect(prosty.odczytajLiczbe('3,'), 3);
      expect(nowoczesny.odczytajLiczbe('0,75'), 0.75);
    });

    test('odrzuca pusty tekst i tekst, który nie jest liczbą', () {
      expect(prosty.odczytajLiczbe(''), isNull);
      expect(prosty.odczytajLiczbe(','), isNull);
      expect(prosty.odczytajLiczbe('1,2,3'), isNull);
      expect(nowoczesny.odczytajLiczbe('abc'), isNull);
    });
  });

  group('WyborLiczby (Prosty)', () {
    testWidgets('dotknięcie liczby otwiera klawiaturę i zapisuje dawkę', (
      tester,
    ) async {
      await jakTelefon(tester);
      double? zapisana;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: prosty.WyborLiczby(
              wartosc: 1.5,
              jednostka: 'l/ha',
              onZmiana: (nowa) => zapisana = nowa,
            ),
          ),
        ),
      );

      expect(find.text('dotknij liczby, żeby ją wpisać'), findsOneWidget);
      await tester.tap(find.text('1,50 l/ha'));
      await tester.pumpAndSettle();

      expect(find.text('Wpisz liczbę'), findsOneWidget);
      // Dopóki nic nie wpisano, „Gotowe" jest wyłączone.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Gotowe'))
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('3'));
      await tester.tap(find.text(','));
      await tester.tap(find.text('2'));
      await tester.tap(find.text('5'));
      await tester.pump();
      expect(find.text('3,25 l/ha'), findsOneWidget);

      await tester.tap(find.text('Gotowe'));
      await tester.pumpAndSettle();

      expect(zapisana, 3.25);
      expect(find.text('Wpisz liczbę'), findsNothing);
    });

    testWidgets('„⌫" usuwa znak, „Anuluj" nic nie zmienia', (tester) async {
      await jakTelefon(tester);
      double? zapisana;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: prosty.WyborLiczby(
              wartosc: 2,
              jednostka: 'kg/ha',
              onZmiana: (nowa) => zapisana = nowa,
            ),
          ),
        ),
      );
      await tester.tap(find.text('2,00 kg/ha'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('7'));
      await tester.tap(find.text('8'));
      await tester.tap(find.text('⌫'));
      await tester.pump();
      expect(find.text('7 kg/ha'), findsOneWidget);

      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();
      expect(zapisana, isNull);
    });

    testWidgets('wartość poniżej minimum nie przechodzi', (tester) async {
      await jakTelefon(tester);
      double? zapisana;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: prosty.WyborLiczby(
              wartosc: 1,
              jednostka: 'ha',
              minimum: 0.1,
              onZmiana: (nowa) => zapisana = nowa,
            ),
          ),
        ),
      );
      await tester.tap(find.text('1,00 ha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('0'));
      await tester.pump();

      expect(find.text('Najmniej 0,10 ha.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Gotowe'))
            .onPressed,
        isNull,
      );
      expect(zapisana, isNull);
    });
  });

  group('WyborLiczbyNowoczesny', () {
    testWidgets('dotknięcie liczby otwiera okno z polem do wpisania', (
      tester,
    ) async {
      double? zapisana;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: nowoczesny.WyborLiczbyNowoczesny(
              wartosc: 1.5,
              jednostka: 'l/ha',
              krok: 0.05,
              onZmiana: (nowa) => zapisana = nowa,
            ),
          ),
        ),
      );

      await tester.tap(find.text('1,50 l/ha'));
      await tester.pumpAndSettle();
      expect(find.text('Wpisz liczbę'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '2,8');
      await tester.pump();
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(zapisana, 2.8);
    });

    testWidgets('nieprawidłowy tekst blokuje zapis', (tester) async {
      double? zapisana;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: nowoczesny.WyborLiczbyNowoczesny(
              wartosc: 1,
              jednostka: 'kg/ha',
              krok: 1,
              onZmiana: (nowa) => zapisana = nowa,
            ),
          ),
        ),
      );
      await tester.tap(find.text('1,00 kg/ha'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1,2,3');
      await tester.pump();
      expect(find.text('To nie jest liczba.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Zapisz'))
            .onPressed,
        isNull,
      );
      expect(zapisana, isNull);
    });
  });
}
