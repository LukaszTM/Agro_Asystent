import 'package:agro_asystent/app/aplikacja.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ekran główny (wygląd prosty)', () {
    testWidgets('pokazuje cztery duże przyciski bez ukrytego menu', (
      tester,
    ) async {
      await tester.pumpWidget(const AplikacjaAgroAsystent());

      expect(find.text('Pola'), findsOneWidget);
      expect(find.text('Dodaj zabieg'), findsOneWidget);
      expect(find.text('Terminy'), findsOneWidget);
      expect(find.text('Dokumenty'), findsOneWidget);
      // Bez szuflady nawigacji i bez menu „trzy kropki".
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
    });

    testWidgets('każdy przycisk ma co najmniej 48 px wysokości', (
      tester,
    ) async {
      await tester.pumpWidget(const AplikacjaAgroAsystent());

      for (final etykieta in ['Pola', 'Dodaj zabieg', 'Terminy', 'Dokumenty']) {
        final przycisk = find.ancestor(
          of: find.text(etykieta),
          matching: find.byType(InkWell),
        );
        expect(przycisk, findsOneWidget, reason: etykieta);
        expect(
          tester.getSize(przycisk).height,
          greaterThanOrEqualTo(48),
          reason: etykieta,
        );
      }
    });

    testWidgets('żaden widoczny napis nie jest mniejszy niż 18 px', (
      tester,
    ) async {
      await tester.pumpWidget(const AplikacjaAgroAsystent());

      final napisy = tester.widgetList<Text>(find.byType(Text));
      expect(napisy, isNotEmpty);
      for (final napis in napisy) {
        final rozmiar =
            napis.style?.fontSize ??
            Theme.of(tester.element(find.byType(Scaffold)))
                .textTheme
                .bodyMedium!
                .fontSize!;
        expect(rozmiar, greaterThanOrEqualTo(18), reason: napis.data ?? '');
      }
    });

    testWidgets('dotknięcie kafelka otwiera ekran z informacją, co będzie', (
      tester,
    ) async {
      await tester.pumpWidget(const AplikacjaAgroAsystent());

      await tester.tap(find.text('Dodaj zabieg'));
      await tester.pumpAndSettle();

      expect(find.text('Ta część jeszcze nie działa.'), findsOneWidget);
      expect(find.text('Wróć'), findsOneWidget);

      await tester.tap(find.text('Wróć'));
      await tester.pumpAndSettle();
      expect(find.text('Pola'), findsOneWidget);
    });
  });
}
