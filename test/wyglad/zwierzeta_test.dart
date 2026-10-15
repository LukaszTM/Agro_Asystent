import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/zrodlo_pliku.dart';
import 'package:agro_asystent/funkcje/nawozenie/ewidencja_nawozenia.dart';
import 'package:agro_asystent/funkcje/nawozenie/nawoz.dart';
import 'package:agro_asystent/funkcje/nawozenie/plan_nawozenia.dart';
import 'package:agro_asystent/funkcje/odczyt/czytnik_zdjecia.dart';
import 'package:agro_asystent/funkcje/odczyt/odczyt_etykiety.dart';
import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/terminy/przypomnienia.dart';
import 'package:agro_asystent/funkcje/terminy/ustawienia_przypomnien.dart';
import 'package:agro_asystent/funkcje/ustawienia/gospodarstwa.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/funkcje/zwierzeta/stado.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:agro_asystent/wyglad/prosty/zwierzeta/ekran_zwierzeta.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekrany zwierząt (krok 9 etapu 1): stan stada, DJP i lista zgłoszeń
/// do IRZplus. Przeliczniki DJP są danymi ze słownika, nie liczbami w kodzie.

void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      'CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT)',
    );
  });

  tearDown(() async {
    await baza.close();
    await slowniki.close();
  });

  Uslugi zbudujUslugi() => Uslugi(
    gospodarstwoId: 'g1',
    nazwaGospodarstwa: 'Gospodarstwo próbne',
    urzadzenie: 'telefon',
    pola: RepozytoriumPol(baza),
    dzialki: RepozytoriumDzialek(baza),
    zabiegi: RepozytoriumZabiegow(baza),
    rejestr: RejestrZabiegow(baza),
    srodki: SlownikSrodkow(slowniki),
    reguly: reguly,
    importWniosku: ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki)),
    zrodloPliku: const _BrakZrodlaPliku(),
    dokumenty: UslugaDokumentow(
      rejestr: RejestrZabiegow(baza),
      reguly: reguly,
      czcionki: _brakCzcionek,
      wyjscie: const _BrakWyjscia(),
    ),
    czytnikZdjecia: const _BrakZdjec(),
    czytnikEtykiety: CzytnikEtykiety(SlownikSrodkow(slowniki)),
    nawozy: RepozytoriumNawozow(baza),
    nawozenie: EwidencjaNawozenia(
      baza: baza,
      zabiegi: RepozytoriumZabiegow(baza),
      reguly: reguly,
    ),
    planNawozenia: PlanNawozenia(baza: baza, reguly: reguly),
    stado: RepozytoriumStada(baza: baza, reguly: reguly),
    gospodarstwa: RepozytoriumGospodarstw(baza: baza),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
      stado: RepozytoriumStada(baza: baza, reguly: reguly),
    ),
    profil: ProfilZBazy(
      baza,
      stado: RepozytoriumStada(baza: baza, reguly: reguly),
    ),
    przypomnienia: const _BrakPrzypomnien(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );

  Future<void> pokaz(WidgetTester tester, Widget ekran) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: MotywProsty.zbuduj(), home: ekran),
    );
    await tester.pumpAndSettle();
  }

  /// Przewija listę ekranu. Bierzemy pierwszy obszar przewijany, bo pole
  /// tekstowe ma własny, wewnętrzny — przeciąganie go nic nie dałoby.
  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    await tester.scrollUntilVisible(
      czego,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('puste stado mówi, co zrobić', (tester) async {
    await pokaz(tester, EkranZwierzeta(uslugi: zbudujUslugi()));

    expect(find.text('Nie masz jeszcze żadnego zwierzęcia.'), findsOneWidget);
    expect(find.textContaining('0,00 DJP'), findsOneWidget);
  });

  testWidgets('dodane zwierzę wchodzi do DJP i do zgłoszeń', (tester) async {
    await pokaz(tester, EkranZwierzeta(uslugi: zbudujUslugi()));

    await przewinDo(tester, find.text('Dodaj zwierzę'));
    await tester.tap(find.text('Dodaj zwierzę'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'PL005123456789');
    await przewinDo(tester, find.text('Krowy'));
    await tester.tap(find.text('Krowy'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Zapisz zwierzę'));
    await tester.tap(find.text('Zapisz zwierzę'));
    await tester.pumpAndSettle();

    // Przelicznik krowy ze słownika = 1,0.
    expect(find.textContaining('1,00 DJP z 1 sztuk'), findsOneWidget);
    expect(find.text('Do zgłoszenia w IRZplus'), findsOneWidget);
    expect(find.textContaining('PL005123456789'), findsOneWidget);
    expect(find.textContaining('aplikacja ich nie wysyła'), findsOneWidget);
  });

  testWidgets('zwierzę bez grupy nie wchodzi do DJP, ale jest w stadzie', (
    tester,
  ) async {
    await pokaz(tester, EkranZwierzeta(uslugi: zbudujUslugi()));

    await przewinDo(tester, find.text('Dodaj zwierzę'));
    await tester.tap(find.text('Dodaj zwierzę'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.textContaining('nie policzymy go do DJP'));
    expect(
      find.textContaining('nie policzymy go do DJP'),
      findsOneWidget,
      reason: 'Bez grupy nie zgadujemy przelicznika.',
    );
    await przewinDo(tester, find.text('Zapisz zwierzę'));
    await tester.tap(find.text('Zapisz zwierzę'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0,00 DJP z 1 sztuk'), findsOneWidget);
    expect(find.textContaining('1 sztuk bez grupy'), findsOneWidget);
  });

  testWidgets('sprawdzone przeliczniki nie straszą rolnika ostrzeżeniem', (
    tester,
  ) async {
    await pokaz(tester, EkranZwierzeta(uslugi: zbudujUslugi()));

    expect(
      find.textContaining('czekają na sprawdzenie w przepisie'),
      findsNothing,
      reason:
          'Współczynniki są z rozporządzenia (Dz.U. 2020 poz. 243, tab. 3).',
    );
  });

  testWidgets('rzadkie zwierzęta są schowane za „Więcej zwierząt"', (
    tester,
  ) async {
    await pokaz(tester, EkranZwierzeta(uslugi: zbudujUslugi()));
    await przewinDo(tester, find.text('Dodaj zwierzę'));
    await tester.tap(find.text('Dodaj zwierzę'));
    await tester.pumpAndSettle();

    await przewinDo(tester, find.textContaining('Więcej zwierząt'));
    expect(find.text('Szynszyle samce'), findsNothing);

    await tester.tap(find.textContaining('Więcej zwierząt'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Szynszyle samce'));
    expect(find.text('Szynszyle samce'), findsOneWidget);
  });

  testWidgets('zgłoszone zdarzenie znika z listy', (tester) async {
    final stado = RepozytoriumStada(baza: baza, reguly: reguly);
    final stadoId = await stado.dodajStado(
      gospodarstwoId: 'g1',
      nazwa: 'bydło',
      gatunek: 'bydło',
      urzadzenie: 'telefon',
    );
    await stado.dodajZwierze(
      stadoId: stadoId,
      zdarzenie: RodzajZdarzenia.urodzenie,
      urzadzenie: 'telefon',
      numer: 'PL005000000001',
      grupaDjp: 'bydlo_ciele',
      dataUrodzenia: DateTime(2026, 5, 10),
      dataZdarzenia: DateTime(2026, 5, 10),
    );

    await pokaz(tester, EkranZwierzeta(uslugi: zbudujUslugi()));
    expect(find.text('Do zgłoszenia w IRZplus'), findsOneWidget);

    await przewinDo(tester, find.textContaining('PL005000000001'));
    await tester.tap(find.textContaining('PL005000000001'));
    await tester.pumpAndSettle();

    expect(find.text('Do zgłoszenia w IRZplus'), findsNothing);
    expect(find.textContaining('0,15 DJP z 1 sztuk'), findsOneWidget);
  });
}

class _BrakZrodlaPliku implements ZrodloPliku {
  const _BrakZrodlaPliku();

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;
}

Future<CzcionkiWydruku> _brakCzcionek() async =>
    throw UnimplementedError('czcionki wydruku nie są tu potrzebne');

class _BrakWyjscia implements WyjscieDokumentu {
  const _BrakWyjscia();

  @override
  Future<void> drukujPdf({required Uint8List dane, required String nazwa}) =>
      throw UnimplementedError();

  @override
  Future<void> udostepnij({
    required Uint8List dane,
    required String nazwa,
    required String typMime,
  }) => throw UnimplementedError();
}

class _BrakPrzypomnien implements UslugaPrzypomnien {
  const _BrakPrzypomnien();

  @override
  Future<bool> czyWolno() async => false;

  @override
  Future<bool> popros() async => false;

  @override
  Future<void> zaplanuj(List<Przypomnienie> przypomnienia) async {}

  @override
  Future<void> wylacz() async {}
}

class _BrakZdjec implements CzytnikZdjecia {
  const _BrakZdjec();

  @override
  Future<String?> tekst(ZrodloZdjecia zrodlo) async => null;
}
