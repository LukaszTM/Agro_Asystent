import 'package:agro_asystent/funkcje/slowniczek/slowniczek.dart';
import 'package:agro_asystent/rdzen/wspolne/slowniczek_pojec.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Słowniczek na ekranie — jeden widget dla trzech wyglądów.
///
/// Czego pilnują testy: hasło otwiera się po dotknięciu, szukanie zawęża
/// listę, brak pliku nie wywraca ekranu, a hasło „do weryfikacji" jest
/// oznaczone (plan, pkt 11.5 — nic nie podajemy jako pewne).
void main() {
  const slownik = SlownikPojec(
    wersja: '2026.10.18.1',
    poCo: 'Skróty z wniosku i pism z ARiMR.',
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

  Future<void> pokaz(
    WidgetTester tester, {
    SlownikPojec? dane = slownik,
    int odSzukania = 8,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ListaSlowniczka(slownik: dane, odSzukania: odSzukania),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pokazuje skróty, a wyjaśnienie po dotknięciu', (tester) async {
    await pokaz(tester);

    expect(find.text('TUZ'), findsOneWidget);
    expect(find.text('trwałe użytki zielone'), findsOneWidget);
    // Wyjaśnienie jest zwinięte, żeby lista skrótów mieściła się na raz.
    expect(find.text('Łąki i pastwiska — grunt pod trawą.'), findsNothing);

    await tester.tap(find.text('TUZ'));
    await tester.pumpAndSettle();

    expect(find.text('Łąki i pastwiska — grunt pod trawą.'), findsOneWidget);
    expect(find.textContaining('wniosek o dopłaty'), findsOneWidget);
  });

  testWidgets('hasło do sprawdzenia jest oznaczone', (tester) async {
    await pokaz(tester);

    await tester.tap(find.text('DJP'));
    await tester.pumpAndSettle();

    expect(find.textContaining('do sprawdzenia w przepisie'), findsOneWidget);
  });

  testWidgets('szukanie zawęża listę do jednego hasła', (tester) async {
    await pokaz(tester, odSzukania: 2);

    await tester.enterText(find.byType(TextField), 'laki');
    await tester.pumpAndSettle();

    expect(find.text('TUZ'), findsOneWidget);
    expect(find.text('DJP'), findsNothing);
  });

  testWidgets('nieznane słowo mówi, że hasła nie ma', (tester) async {
    await pokaz(tester, odSzukania: 2);

    await tester.enterText(find.byType(TextField), 'traktor');
    await tester.pumpAndSettle();

    expect(find.textContaining('Nie mamy jeszcze takiego hasła'), findsOne);
  });

  testWidgets('przy kilku hasłach nie ma pola szukania', (tester) async {
    await pokaz(tester);

    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('brak pliku nie wywraca ekranu', (tester) async {
    await pokaz(tester, dane: null);

    expect(find.textContaining('nie udało się wczytać'), findsOneWidget);
  });

  testWidgets('zastrzeżenie i numer wersji stoją pod listą', (tester) async {
    await pokaz(tester);

    expect(find.textContaining('nie zastępuje przepisu'), findsOneWidget);
    expect(find.textContaining('2026.10.18.1'), findsOneWidget);
  });
}
