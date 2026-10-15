import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/zrodlo_pliku.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/wyglad/prosty/dzialki/ekran_import_wniosku.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ścieżka rolnika z kroku 2 etapu 1: wskazanie pliku wniosku, podsumowanie
/// odczytu i zapis do gospodarstwa.
void main() {
  sqfliteFfiInit();
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );
  final fabryka = databaseFactoryFfiNoIsolate;

  late Database baza;
  late Database slowniki;

  /// Źródło pliku bez okna systemowego — w testach podajemy gotowe bajty.
  late _ZrodloZDysku zrodlo;

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-10-15T08:00:00',
      'zmieniono': '2026-10-15T08:00:00',
      'urzadzenie': 'telefon',
    });
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      'CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT)',
    );
    await slowniki.insert('uprawa', {
      'nazwa': 'pszenica zwyczajna ozima',
      'kod_eppo': 'TRZAW',
    });
    zrodlo = _ZrodloZDysku(
      nazwa: 'wniosek.pdf',
      bajty: File('test/dane/wzorzec_wniosku.pdf').readAsBytesSync(),
    );
  });

  tearDown(() async {
    await baza.close();
    await slowniki.close();
  });

  Uslugi zbudujUslugi() => Uslugi(
    gospodarstwoId: 'g1',
    urzadzenie: 'telefon',
    pola: RepozytoriumPol(baza),
    dzialki: RepozytoriumDzialek(baza),
    zabiegi: RepozytoriumZabiegow(baza),
    rejestr: RejestrZabiegow(baza),
    srodki: SlownikSrodkow(slowniki),
    reguly: reguly,
    importWniosku: ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki)),
    zrodloPliku: zrodlo,
  );

  /// Czekanie na odczyt wykonywany w osobnym wątku.
  ///
  /// `pumpAndSettle` tu nie wystarczy z dwóch powodów: kółko postępu kręci
  /// się bez końca i nigdy się nie uspokaja, a osobny wątek potrzebuje
  /// prawdziwego czasu, którego zegar testu sam nie daje.
  Future<void> poczekajNa(WidgetTester tester, Finder czego) async {
    for (var i = 0; i < 200 && czego.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(czego, findsWidgets);
  }

  Future<void> pokaz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranImportWniosku(uslugi: zbudujUslugi()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('wniosek z pliku trafia do gospodarstwa po potwierdzeniu', (
    tester,
  ) async {
    await pokaz(tester);

    expect(find.textContaining('Wskaż plik wniosku'), findsOneWidget);
    expect(
      find.textContaining('nic nie jest nigdzie wysyłane'),
      findsOneWidget,
    );

    await tester.tap(find.text('Wybierz plik wniosku'));
    await poczekajNa(tester, find.text('wniosek.pdf'));

    // Podsumowanie przed zapisem: rolnik widzi, co aplikacja znalazła.
    expect(find.text('20'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
    expect(find.textContaining('28,91 ha'), findsOneWidget);
    expect(find.textContaining('wniosek na 2026'), findsOneWidget);
    expect(await RepozytoriumPol(baza).wszystkie('g1'), isEmpty);

    await tester.tap(find.text('Zapisz do gospodarstwa'));
    await poczekajNa(tester, find.text('Zapisane'));

    expect(find.textContaining('sezon 2026'), findsOneWidget);
    expect(await RepozytoriumDzialek(baza).wszystkie('g1'), hasLength(20));
    expect(await RepozytoriumPol(baza).wszystkie('g1'), hasLength(34));
  });

  testWidgets('uprawy bez kodu w słowniku są wymienione, nie zgadnięte', (
    tester,
  ) async {
    await pokaz(tester);
    await tester.tap(find.text('Wybierz plik wniosku'));
    await poczekajNa(tester, find.text('Zapisz do gospodarstwa'));
    await tester.tap(find.text('Zapisz do gospodarstwa'));
    await poczekajNa(tester, find.text('Zapisane'));

    expect(find.textContaining('nie ma w słowniku'), findsOneWidget);
    expect(
      find.textContaining('nie wpisujemy niczego na domysł'),
      findsOneWidget,
    );
  });

  testWidgets('plik, który nie jest wnioskiem, kończy się jednym zdaniem', (
    tester,
  ) async {
    zrodlo = _ZrodloZDysku(
      nazwa: 'zdjecie.pdf',
      bajty: Uint8List.fromList('to nie jest PDF'.codeUnits),
    );
    await pokaz(tester);

    await tester.tap(find.text('Wybierz plik wniosku'));
    await poczekajNa(tester, find.textContaining('Nie udało się odczytać'));

    expect(find.textContaining('eWniosekPlus'), findsWidgets);
    expect(find.text('Zapisz do gospodarstwa'), findsNothing);
  });

  testWidgets('rezygnacja z wyboru pliku nic nie zmienia', (tester) async {
    zrodlo = _ZrodloZDysku.bezPliku();
    await pokaz(tester);

    await tester.tap(find.text('Wybierz plik wniosku'));
    await tester.pumpAndSettle();

    expect(find.text('Wybierz plik wniosku'), findsOneWidget);
    expect(find.textContaining('Nie udało się'), findsNothing);
    expect(await RepozytoriumPol(baza).wszystkie('g1'), isEmpty);
  });
}

class _ZrodloZDysku implements ZrodloPliku {
  _ZrodloZDysku({required this.nazwa, required this.bajty});

  _ZrodloZDysku.bezPliku() : nazwa = '', bajty = null;

  final String nazwa;
  final Uint8List? bajty;

  @override
  Future<WybranyPlik?> wybierzPdf() async {
    final dane = bajty;
    if (dane == null) {
      return null;
    }
    return WybranyPlik(nazwa: nazwa, bajty: dane);
  }
}
