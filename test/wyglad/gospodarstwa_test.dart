import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/slownik_upraw.dart';
import 'package:agro_asystent/funkcje/dzialki/zrodlo_pliku.dart';
import 'package:agro_asystent/funkcje/nawozenie/ewidencja_nawozenia.dart';
import 'package:agro_asystent/funkcje/nawozenie/nawoz.dart';
import 'package:agro_asystent/funkcje/nawozenie/plan_nawozenia.dart';
import 'package:agro_asystent/funkcje/nawozenie/terminy_azotowe.dart';
import 'package:agro_asystent/funkcje/odczyt/czytnik_zdjecia.dart';
import 'package:agro_asystent/funkcje/odczyt/odczyt_etykiety.dart';
import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/terminy/przypomnienia.dart';
import 'package:agro_asystent/funkcje/terminy/ustawienia_przypomnien.dart';
import 'package:agro_asystent/funkcje/ustawienia/gospodarstwa.dart';
import 'package:agro_asystent/funkcje/ustawienia/wybor_wygladu.dart';
import 'package:agro_asystent/funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/funkcje/zwierzeta/stado.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/baza/migracje.dart';
import 'package:agro_asystent/rdzen/reguly/gminy_terminy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:agro_asystent/wyglad/prosty/ustawienia/ekran_gospodarstwa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekran gospodarstwa i konta (krok 10 etapu 1): dane na wydruki,
/// przełączanie między gospodarstwami i nazwa konta.

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
      'numer_producenta': '012345678',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
  });

  tearDown(() async {
    await baza.close();
    await slowniki.close();
  });

  Uslugi zbudujUslugi({bool premium = false}) => Uslugi(
    gospodarstwoId: 'g1',
    nazwaGospodarstwa: 'Gospodarstwo próbne',
    urzadzenie: 'telefon',
    pola: RepozytoriumPol(baza),
    dzialki: RepozytoriumDzialek(baza),
    zabiegi: RepozytoriumZabiegow(baza),
    rejestr: RejestrZabiegow(baza),
    srodki: SlownikSrodkow(slowniki),
    uprawy: SlownikUpraw(slowniki),
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
    terminyAzotowe: TerminyAzotowe(
      baza: baza,
      reguly: reguly,
      gminy: SlownikGminTerminow.pusty,
    ),
    stado: RepozytoriumStada(baza: baza, reguly: reguly),
    zwierzetaWGospodarstwie: ZwierzetaWGospodarstwie(baza),
    wyglad: WyborWygladu(baza),
    kopia: KopiaDanych(baza: baza, wersjaSchematu: najnowszaWersja),
    gospodarstwa: RepozytoriumGospodarstw(
      baza: baza,
      dostep: DostepFunkcji(maPremium: premium),
    ),
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
    dostep: DostepFunkcji(maPremium: premium),
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

  testWidgets('dane gospodarstwa widać i można je poprawić', (tester) async {
    await pokaz(tester, EkranGospodarstwa(uslugi: zbudujUslugi()));

    expect(find.text('Gospodarstwo próbne'), findsOneWidget);
    expect(find.textContaining('012345678'), findsOneWidget);

    await tester.tap(find.text('Gospodarstwo próbne'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Gospodarstwo Kowalskich',
    );
    await przewinDo(tester, find.text('Zapisz dane'));
    await tester.tap(find.text('Zapisz dane'));
    await tester.pumpAndSettle();

    expect(find.text('Gospodarstwo Kowalskich'), findsOneWidget);
    final zBazy = await RepozytoriumGospodarstw(baza: baza).jedno('g1');
    expect(zBazy!.nazwa, 'Gospodarstwo Kowalskich');
  });

  testWidgets('bez premium dodanie kolejnego gospodarstwa jest wyjaśnione', (
    tester,
  ) async {
    await pokaz(tester, EkranGospodarstwa(uslugi: zbudujUslugi()));

    expect(find.text('Dodaj gospodarstwo'), findsNothing);
    await przewinDo(tester, find.textContaining('to dodatek premium'));
    expect(
      find.textContaining('działa w całości bez opłaty'),
      findsOneWidget,
      reason: 'Dokumentacji nie wolno blokować za brak płatności.',
    );
  });

  testWidgets('w premium dodane gospodarstwo staje się bieżącym', (
    tester,
  ) async {
    Uslugi? poZmianie;
    await pokaz(
      tester,
      EkranGospodarstwa(
        uslugi: zbudujUslugi(premium: true),
        onZmiana: (nowe) => poZmianie = nowe,
      ),
    );

    await przewinDo(tester, find.text('Dodaj gospodarstwo'));
    await tester.tap(find.text('Dodaj gospodarstwo'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Gospodarstwo po dziadku',
    );
    await przewinDo(tester, find.text('Dodaj gospodarstwo'));
    await tester.tap(find.text('Dodaj gospodarstwo'));
    await tester.pumpAndSettle();

    expect(poZmianie, isNotNull);
    expect(poZmianie!.nazwaGospodarstwa, 'Gospodarstwo po dziadku');
    expect(find.textContaining('pracujesz tu teraz'), findsOneWidget);

    final zapisane = await RepozytoriumGospodarstw(baza: baza).aktywne();
    expect(zapisane!.nazwa, 'Gospodarstwo po dziadku');
  });

  testWidgets('przełączenie wraca do startu aplikacji i do bazy', (
    tester,
  ) async {
    final repozytorium = RepozytoriumGospodarstw(
      baza: baza,
      dostep: const DostepFunkcji(maPremium: true),
    );
    final drugie = (await repozytorium.dodaj(
      nazwa: 'Gospodarstwo po dziadku',
      urzadzenie: 'telefon',
    )).id!;
    await repozytorium.ustawAktywne('g1');

    Uslugi? poZmianie;
    await pokaz(
      tester,
      EkranGospodarstwa(
        uslugi: zbudujUslugi(premium: true),
        onZmiana: (nowe) => poZmianie = nowe,
      ),
    );

    await przewinDo(tester, find.text('Gospodarstwo po dziadku'));
    await tester.tap(find.text('Gospodarstwo po dziadku'));
    await tester.pumpAndSettle();

    expect(poZmianie!.gospodarstwoId, drugie);
    expect((await repozytorium.aktywne())!.id, drugie);
  });

  testWidgets('nazwa konta zapisuje się i wraca po ponownym wejściu', (
    tester,
  ) async {
    await pokaz(tester, EkranGospodarstwa(uslugi: zbudujUslugi()));

    await przewinDo(tester, find.text('Zapisz konto'));
    await tester.enterText(find.byType(TextField).last, 'Jan Kowalski');
    await tester.tap(find.text('Zapisz konto'));
    await tester.pumpAndSettle();

    final konto = await RepozytoriumGospodarstw(baza: baza).konto();
    expect(konto!.nazwa, 'Jan Kowalski');

    await pokaz(
      tester,
      EkranGospodarstwa(key: UniqueKey(), uslugi: zbudujUslugi()),
    );
    await przewinDo(tester, find.text('Zapisz konto'));
    expect(find.text('Jan Kowalski'), findsOneWidget);
  });

  testWidgets('gospodarstwo bez nazwy nie powstaje i mówi, co zrobić', (
    tester,
  ) async {
    await pokaz(tester, EkranGospodarstwa(uslugi: zbudujUslugi(premium: true)));

    await przewinDo(tester, find.text('Dodaj gospodarstwo'));
    await tester.tap(find.text('Dodaj gospodarstwo'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Dodaj gospodarstwo'));
    await tester.tap(find.text('Dodaj gospodarstwo'));
    await tester.pumpAndSettle();

    expect(find.text('Gospodarstwo nie ma nazwy.'), findsOneWidget);
    expect(find.textContaining('Wpisz nazwę'), findsOneWidget);
  });

  testWidgets('ostatniego gospodarstwa nie można usunąć i ekran wyjaśnia', (
    tester,
  ) async {
    await pokaz(tester, EkranGospodarstwa(uslugi: zbudujUslugi()));

    await tester.tap(find.text('Gospodarstwo próbne'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Usuń gospodarstwo'));
    await tester.tap(find.text('Usuń gospodarstwo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Zrób najpierw kopię danych'), findsOneWidget);
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();

    expect(find.text('To jedyne gospodarstwo w aplikacji.'), findsOneWidget);
    expect(
      (await RepozytoriumGospodarstw(baza: baza).wszystkie()),
      hasLength(1),
    );
  });

  testWidgets('usunięcie przełącza na gospodarstwo, które zostało', (
    tester,
  ) async {
    final repozytorium = RepozytoriumGospodarstw(
      baza: baza,
      dostep: const DostepFunkcji(maPremium: true),
    );
    await repozytorium.dodaj(
      nazwa: 'Gospodarstwo po dziadku',
      urzadzenie: 'telefon',
    );
    await repozytorium.ustawAktywne('g1');

    Uslugi? poZmianie;
    await pokaz(
      tester,
      EkranGospodarstwa(
        uslugi: zbudujUslugi(premium: true),
        onZmiana: (nowe) => poZmianie = nowe,
      ),
    );

    // Nazwa stoi i w karcie danych, i na liście gospodarstw.
    await tester.tap(find.text('Gospodarstwo próbne').first);
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Usuń gospodarstwo'));
    await tester.tap(find.text('Usuń gospodarstwo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń'));
    await tester.pumpAndSettle();

    expect(
      (await repozytorium.wszystkie()).single.nazwa,
      'Gospodarstwo po dziadku',
    );
    expect(poZmianie!.nazwaGospodarstwa, 'Gospodarstwo po dziadku');
    // Wpisy zostają w bazie — wymaga tego kontrola (CLAUDE.md).
    expect(
      (await baza.query(
        'gospodarstwo',
        where: 'id = ?',
        whereArgs: ['g1'],
      )).single['usuniety'],
      1,
    );
  });

  testWidgets('magazyn bez premium mówi o tym wprost i nic nie blokuje', (
    tester,
  ) async {
    await pokaz(tester, EkranGospodarstwa(uslugi: zbudujUslugi()));

    await przewinDo(tester, find.text('Magazyn'));
    await tester.tap(find.text('Magazyn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('należy do wersji płatnej'), findsOneWidget);
    expect(
      find.textContaining('działają bez'),
      findsOneWidget,
      reason: 'dokumentacji nie wolno warunkować płatnością',
    );
    expect(find.text('Dodaj nawóz'), findsNothing);
  });

  testWidgets('w premium magazyn liczy stan z zakupów', (tester) async {
    final uslugi = zbudujUslugi(premium: true);
    await uslugi.nawozy.zapisz(
      nawoz: const Nawoz(
        id: 'n1',
        gospodarstwoId: 'g1',
        nazwa: 'Saletra amonowa',
        azotProcent: 34,
        naturalny: false,
      ),
      urzadzenie: 'telefon',
    );

    await pokaz(tester, EkranGospodarstwa(uslugi: uslugi));
    await przewinDo(tester, find.text('Magazyn'));
    await tester.tap(find.text('Magazyn'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Magazyn jest jeszcze pusty'), findsOneWidget);

    await przewinDo(tester, find.text('Dodaj nawóz'));
    await tester.tap(find.text('Dodaj nawóz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saletra amonowa').last);
    await tester.pumpAndSettle();

    expect(find.text('0,00 kg'), findsOneWidget);

    // Zakup: przyciski „+" i „−", bez klawiatury.
    await przewinDo(tester, find.text('Zakup'));
    await tester.tap(find.text('Zakup'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(find.text('3,00 kg'), findsOneWidget);
    final stan = await uslugi.magazyn.stan(gospodarstwoId: 'g1');
    expect(stan.single.zakupy, 3);
  });

  testWidgets('wygląd przełącza się w ustawieniach i zapisuje w bazie', (
    tester,
  ) async {
    Wyglad? zgloszony;
    final uslugi = zbudujUslugi();
    await pokaz(
      tester,
      EkranGospodarstwa(
        uslugi: uslugi,
        onZmianaWygladu: (wyglad) => zgloszony = wyglad,
      ),
    );

    await przewinDo(tester, find.text('Wygląd aplikacji'));
    expect(find.text('Prosty'), findsOneWidget);
    await tester.tap(find.text('Nowoczesny'));
    await tester.pumpAndSettle();

    expect(await uslugi.wyglad.odczytaj(), Wyglad.nowoczesny);
    // Motyw jest nad ekranami, więc o zmianie musi wiedzieć start aplikacji.
    expect(zgloszony, Wyglad.nowoczesny);
  });
}

class _BrakZrodlaPliku implements ZrodloPliku {
  const _BrakZrodlaPliku();

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;

  @override
  Future<WybranyPlik?> wybierzKopie() async => null;
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
