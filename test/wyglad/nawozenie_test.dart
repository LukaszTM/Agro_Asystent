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
import 'package:agro_asystent/funkcje/nawozenie/terminy_azotowe.dart';
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
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/gminy_terminy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:agro_asystent/wyglad/prosty/nawozenie/ekran_nawozenie.dart';
import 'package:agro_asystent/wyglad/prosty/nawozenie/ekran_nawozy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekrany nawożenia (krok 6 etapu 1): spis nawozów, limit azotu
/// i zestawienie dla planu nawożenia.

void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;

  Future<void> dodajDzialke(String identyfikator) =>
      baza.insert('dzialka_ewidencyjna', {
        'id': 'dz-$identyfikator',
        'gospodarstwo_id': 'g1',
        'identyfikator': identyfikator,
        'utworzono': '2026-03-01T08:00:00',
        'zmieniono': '2026-03-01T08:00:00',
        'urzadzenie': 'telefon',
      });

  Future<void> dodajPole({required int ar}) => baza.insert('dzialka_rolna', {
    'id': 'pole-$ar',
    'gospodarstwo_id': 'g1',
    'nazwa_wlasna': 'Za stodołą',
    'sezon': DateTime.now().year,
    'uprawa': 'kukurydza na ziarno',
    'powierzchnia_ar': ar,
    'utworzono': '2026-03-01T08:00:00',
    'zmieniono': '2026-03-01T08:00:00',
    'urzadzenie': 'telefon',
  });

  Future<void> dodajNawozenie({
    required double azotProcent,
    required double dawkaTonNaHa,
    required int ar,
  }) async {
    final nawoz = Nawoz(
      id: 'n-obornik',
      gospodarstwoId: 'g1',
      nazwa: 'Obornik bydlęcy',
      naturalny: true,
      azotProcent: azotProcent,
    );
    await RepozytoriumNawozow(baza).zapisz(nawoz: nawoz, urzadzenie: 'telefon');
    await EwidencjaNawozenia(
      baza: baza,
      zabiegi: RepozytoriumZabiegow(baza),
      reguly: reguly,
    ).zapisz(
      gospodarstwoId: 'g1',
      nawoz: nawoz,
      pola: [PoleZabiegu(dzialkaRolnaId: 'pole-$ar', powierzchniaAr: ar)],
      dawka: dawkaTonNaHa,
      jednostka: JednostkaDawki.tonyNaHektar,
      urzadzenie: 'telefon',
    );
  }

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

  Uslugi zbudujUslugi({SlownikGminTerminow? gminy}) => Uslugi(
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
    terminyAzotowe: TerminyAzotowe(
      baza: baza,
      reguly: reguly,
      gminy: gminy ?? SlownikGminTerminow.pusty,
    ),
    stado: RepozytoriumStada(baza: baza, reguly: reguly),
    gospodarstwa: RepozytoriumGospodarstw(baza: baza),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: const _BrakPrzypomnien(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );

  Future<void> pokaz(WidgetTester tester, Widget ekran) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: MotywProsty.zbuduj(), home: ekran),
    );
    await tester.pumpAndSettle();
  }

  /// Przewija listę aż szukany tekst się zbuduje. `scrollUntilVisible`
  /// tu nie wystarcza, bo tekst występuje w kilku miejscach naraz.
  Future<void> przewijajDo(WidgetTester tester, Finder czego) async {
    for (var proba = 0; proba < 12 && czego.evaluate().isEmpty; proba++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
  }

  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    await tester.scrollUntilVisible(
      czego,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pusty spis nawozów mówi, co zrobić', (tester) async {
    await pokaz(tester, EkranNawozy(uslugi: zbudujUslugi()));

    expect(
      find.text('Nie masz jeszcze żadnego nawozu w spisie.'),
      findsOneWidget,
    );
    expect(find.textContaining('niczego nie zgadujemy'), findsOneWidget);
  });

  testWidgets('dodany nawóz wraca na liście ze składem', (tester) async {
    await pokaz(tester, EkranNawozy(uslugi: zbudujUslugi()));

    await tester.tap(find.text('Dodaj nawóz'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Saletra z worka');
    await tester.tap(find.text('+').first);
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Zapisz nawóz'));
    await tester.tap(find.text('Zapisz nawóz'));
    await tester.pumpAndSettle();

    expect(find.text('Saletra z worka'), findsOneWidget);
    expect(find.textContaining('mineralny'), findsOneWidget);
    expect(find.textContaining('N 1%'), findsOneWidget);
  });

  testWidgets('nawóz bez azotu nie udaje, że zna skład', (tester) async {
    await pokaz(tester, EkranNawozy(uslugi: zbudujUslugi()));

    await tester.tap(find.text('Dodaj nawóz'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Gnojowica bez analizy');
    await przewinDo(tester, find.text('Zapisz nawóz'));
    await tester.tap(find.text('Zapisz nawóz'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('zawartość azotu do uzupełnienia'),
      findsOneWidget,
    );
  });

  testWidgets('limit azotu liczy się z wpisów i ze słownika reguł', (
    tester,
  ) async {
    await dodajPole(ar: 1000);
    await dodajNawozenie(azotProcent: 0.5, dawkaTonNaHa: 20, ar: 1000);
    await pokaz(tester, EkranNawozenie(uslugi: zbudujUslugi()));

    // 20 t/ha × 0,5% = 100 kg N/ha na 10 ha; limit 170 kg N/ha.
    expect(find.textContaining('100 z 170 kg N/ha'), findsOneWidget);
    expect(find.textContaining('Zostało 700 kg azotu'), findsOneWidget);
    // Karta terminów zepchnęła listę wpisów poniżej ekranu.
    await przewijajDo(tester, find.textContaining('Obornik bydlęcy'));
    expect(find.textContaining('Obornik bydlęcy'), findsWidgets);
  });

  testWidgets('przekroczony limit mówi wprost, czego nie robić', (
    tester,
  ) async {
    await dodajPole(ar: 1000);
    await dodajNawozenie(azotProcent: 0.5, dawkaTonNaHa: 40, ar: 1000);
    await pokaz(tester, EkranNawozenie(uslugi: zbudujUslugi()));

    expect(find.textContaining('Limit przekroczony'), findsOneWidget);
    expect(
      find.textContaining('Nie stosuj więcej nawozów naturalnych'),
      findsOneWidget,
    );
  });

  testWidgets('nawóz bez zawartości azotu czyni limit niepewnym', (
    tester,
  ) async {
    await dodajPole(ar: 1000);
    await dodajNawozenie(azotProcent: 0.5, dawkaTonNaHa: 10, ar: 1000);
    // Drugi wpis: nawóz naturalny bez analizy.
    const bezAnalizy = Nawoz(
      id: 'n-gnojowica',
      gospodarstwoId: 'g1',
      nazwa: 'Gnojowica bez analizy',
      naturalny: true,
    );
    await RepozytoriumNawozow(baza)
        .zapisz(nawoz: bezAnalizy, urzadzenie: 'telefon');
    await EwidencjaNawozenia(
      baza: baza,
      zabiegi: RepozytoriumZabiegow(baza),
      reguly: reguly,
    ).zapisz(
      gospodarstwoId: 'g1',
      nawoz: bezAnalizy,
      pola: const [
        PoleZabiegu(dzialkaRolnaId: 'pole-1000', powierzchniaAr: 1000),
      ],
      dawka: 25,
      jednostka: JednostkaDawki.metrySzescienneNaHektar,
      urzadzenie: 'telefon',
    );

    await pokaz(tester, EkranNawozenie(uslugi: zbudujUslugi()));
    expect(find.textContaining('nawóz bez znanej zawartości'), findsOneWidget);
  });

  testWidgets('plan nawożenia wymagany dopiero powyżej progu', (tester) async {
    await dodajPole(ar: 1000);
    await pokaz(tester, EkranNawozenie(uslugi: zbudujUslugi()));
    expect(
      find.textContaining('musi mieć plan nawożenia azotem'),
      findsNothing,
    );

    await dodajPole(ar: 12000);
    // Nowy klucz, żeby ekran policzył wszystko od nowa, a nie pokazał
    // poprzedniego wyniku.
    await pokaz(
      tester,
      EkranNawozenie(key: UniqueKey(), uslugi: zbudujUslugi()),
    );
    expect(
      find.textContaining('musi mieć plan nawożenia azotem'),
      findsOneWidget,
    );
    expect(find.textContaining('Plan sporządza doradca'), findsOneWidget);
  });

  testWidgets('karta terminów mówi, do kiedy wolno nawozić i czym', (
    tester,
  ) async {
    await dodajPole(ar: 1000);
    await pokaz(tester, EkranNawozenie(uslugi: zbudujUslugi()));

    expect(find.textContaining('Do kiedy wolno nawozić'), findsOneWidget);
    // Obornik na gruntach ornych do 31 października, na łąkach do 30 listopada.
    expect(find.textContaining('do 31 października'), findsWidgets);
    expect(find.textContaining('do 30 listopada'), findsWidgets);
    // Gnojowica i saletra na gruntach ornych — termin domyślny 20 października.
    expect(find.textContaining('do 20 października'), findsOneWidget);
    expect(find.textContaining('gnojowica'), findsWidgets);

    await przewinDo(tester, find.textContaining('zamarznięta'));
    expect(find.textContaining('zamarznięta'), findsOneWidget);
    expect(
      find.textContaining('Niekorzystne warunki pogodowe'),
      findsOneWidget,
    );
    expect(find.textContaining('30 kg N/ha'), findsOneWidget);
    expect(
      find.textContaining('ze streszczenia ministerstwa'),
      findsOneWidget,
      reason: 'daty nie są potwierdzone w tabeli 2 rozporządzenia',
    );
  });

  testWidgets('gmina z wykazu zmienia termin na gruntach ornych', (
    tester,
  ) async {
    final gminy = SlownikGminTerminow.zTekstuJson(
      File('assets/dane/gminy_terminy_azotowe.json').readAsStringSync(),
    );
    final doPietnastego = gminy.warianty
        .firstWhere((w) => w.dataRoczna == '10-15')
        .gminy
        .first;
    await dodajPole(ar: 1000);
    await dodajDzialke(
      '${doPietnastego.substring(0, 6)}_${doPietnastego.substring(6)}.0001.1',
    );

    await pokaz(tester, EkranNawozenie(uslugi: zbudujUslugi(gminy: gminy)));

    expect(find.textContaining('do 15 października'), findsOneWidget);
    expect(
      find.textContaining('do 20 października'),
      findsNothing,
      reason: 'w tej gminie termin domyślny nie obowiązuje',
    );
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

/// Testy, które nie dotykają zdjęć, dostają czytnik odmawiający pracy.
class _BrakZdjec implements CzytnikZdjecia {
  const _BrakZdjec();

  @override
  Future<String?> tekst(ZrodloZdjecia zrodlo) async => null;
}
