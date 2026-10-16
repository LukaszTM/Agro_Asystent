import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
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
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/gminy_terminy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';
import 'package:agro_asystent/rdzen/wspolne/mapa_dzialek.dart';
import 'package:agro_asystent/wyglad/nowoczesny/motyw.dart';
import 'package:agro_asystent/wyglad/nowoczesny/nawozenie/ekran_nawozenie.dart';
import 'package:agro_asystent/wyglad/nowoczesny/pola/ekran_dzialki.dart';
import 'package:agro_asystent/wyglad/nowoczesny/pola/ekran_import_wniosku.dart';
import 'package:agro_asystent/wyglad/nowoczesny/ustawienia/ekran_dane_gospodarstwa.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekrany formularzowe wyglądu nowoczesnego, których wcześniej miał tylko
/// wygląd prosty: działki z ULDK, import wniosku, nawożenie z nawozami
/// i dane gospodarstwa (luka 9 z podsumowania etapu 1).
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  const obrys =
      'SRID=4326;POLYGON((19.100 52.100,19.102 52.100,19.102 52.102,'
      '19.100 52.102,19.100 52.100))';
  const odpowiedzUldk =
      '0\n$obrys|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138';

  late Database baza;
  late Database slowniki;
  late ZrodloPliku zrodlo;

  KlientUldk udawanaUsluga(String odpowiedz) => KlientUldk(
    klient: MockClient(
      (_) async => http.Response(
        odpowiedz,
        200,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      ),
    ),
  );

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
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    zrodlo = _ZrodloZDysku(
      nazwa: 'wniosek.pdf',
      bajty: File('test/dane/wzorzec_wniosku.pdf').readAsBytesSync(),
    );
  });

  tearDown(() async {
    await baza.close();
    await slowniki.close();
  });

  Uslugi zbudujUslugi({KlientUldk? uldk}) => Uslugi(
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
    zrodloPliku: zrodlo,
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
    gospodarstwa: RepozytoriumGospodarstw(baza: baza),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: const _BrakPrzypomnien(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
    uldk: uldk ?? udawanaUsluga(odpowiedzUldk),
  );

  Future<void> pokaz(WidgetTester tester, Widget ekran) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: MotywNowoczesny.zbuduj(), home: ekran),
    );
    await tester.pumpAndSettle();
  }

  /// Czeka na pracę poza pętlą testu — odczyt PDF idzie przez `compute`.
  Future<void> poczekajNa(WidgetTester tester, Finder czego) async {
    for (var i = 0; i < 200 && czego.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(czego, findsWidgets);
  }

  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    for (var proba = 0; proba < 40 && czego.evaluate().isEmpty; proba++) {
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -260));
      await tester.pumpAndSettle();
    }
  }

  Future<void> dodajPole({
    String id = 'p1',
    String uprawa = 'kukurydza na ziarno',
    int ar = 1000,
  }) => baza.insert('dzialka_rolna', {
    'id': id,
    'gospodarstwo_id': 'g1',
    'nazwa_wlasna': 'Za stodołą',
    'sezon': DateTime.now().year,
    'uprawa': uprawa,
    'powierzchnia_ar': ar,
    'utworzono': '2026-03-01T08:00:00',
    'zmieniono': '2026-03-01T08:00:00',
    'urzadzenie': 'telefon',
  });

  group('działki i granice z ULDK', () {
    testWidgets('dodanie po numerze kończy się potwierdzeniem na mapie', (
      tester,
    ) async {
      await pokaz(tester, EkranDzialkiNowoczesny(uslugi: zbudujUslugi()));

      expect(find.text('Nie masz jeszcze żadnej działki.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '061506_2.0007.138');
      await tester.tap(find.text('Znajdź działkę'));
      await tester.pumpAndSettle();

      // Potwierdzenie na mapie jest obowiązkowe — nazwy obrębów się
      // powtarzają (plan, pkt 6.1).
      expect(find.text('Czy to ta działka?'), findsOneWidget);
      expect(find.byType(MapaDzialek), findsOneWidget);
      expect(find.text('Brzeziny, Lubartów, lubartowski'), findsOneWidget);

      await tester.tap(find.text('Tak, to moja działka'));
      await tester.pumpAndSettle();

      final zapisane = await RepozytoriumDzialek(baza).wszystkie('g1');
      expect(zapisane.single.maGranice, isTrue);
      expect(find.text('061506_2.0007.138'), findsWidgets);
    });

    testWidgets('brak sieci kończy się jednym zdaniem i radą', (tester) async {
      await pokaz(
        tester,
        EkranDzialkiNowoczesny(
          uslugi: zbudujUslugi(
            uldk: KlientUldk(
              klient: MockClient(
                (_) async => throw http.ClientException('brak sieci'),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '061506_2.0007.138');
      await tester.tap(find.text('Znajdź działkę'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Czy to ta działka?'), findsNothing);
      expect(await RepozytoriumDzialek(baza).wszystkie('g1'), isEmpty);
    });
  });

  group('import wniosku z PDF', () {
    testWidgets('wniosek trafia do gospodarstwa po potwierdzeniu', (
      tester,
    ) async {
      await pokaz(tester, EkranImportWnioskuNowoczesny(uslugi: zbudujUslugi()));

      expect(find.textContaining('Wskaż plik wniosku'), findsOneWidget);
      expect(
        find.textContaining('nic nie jest nigdzie wysyłane'),
        findsOneWidget,
      );

      await tester.tap(find.text('Wybierz plik wniosku'));
      await poczekajNa(tester, find.text('wniosek.pdf'));

      expect(find.text('20'), findsOneWidget);
      expect(find.text('34'), findsOneWidget);
      expect(await RepozytoriumPol(baza).wszystkie('g1'), isEmpty);

      await tester.tap(find.text('Zapisz do gospodarstwa'));
      await poczekajNa(tester, find.text('Zapisane'));

      expect(await RepozytoriumDzialek(baza).wszystkie('g1'), hasLength(20));
      expect(await RepozytoriumPol(baza).wszystkie('g1'), hasLength(34));
      expect(find.textContaining('nie ma w słowniku'), findsOneWidget);
    });

    testWidgets('plik, który nie jest wnioskiem, nie udaje odczytu', (
      tester,
    ) async {
      zrodlo = _ZrodloZDysku(
        nazwa: 'zdjecie.pdf',
        bajty: Uint8List.fromList('to nie jest PDF'.codeUnits),
      );
      await pokaz(tester, EkranImportWnioskuNowoczesny(uslugi: zbudujUslugi()));

      await tester.tap(find.text('Wybierz plik wniosku'));
      await poczekajNa(tester, find.textContaining('Nie udało się odczytać'));

      expect(find.text('Zapisz do gospodarstwa'), findsNothing);
      expect(await RepozytoriumPol(baza).wszystkie('g1'), isEmpty);
    });
  });

  group('nawożenie', () {
    const saletra = Nawoz(
      id: 'n-saletra',
      gospodarstwoId: 'g1',
      nazwa: 'Saletra z worka',
      naturalny: false,
      azotProcent: 34,
      zrodlo: 'worek',
    );

    testWidgets('limit azotu i maksymalna dawka dla uprawy', (tester) async {
      await dodajPole();
      await RepozytoriumNawozow(baza)
          .zapisz(nawoz: saletra, urzadzenie: 'telefon');
      // 800 kg saletry 34% to 272 kg azotu na hektar; kukurydza na ziarno
      // ma w tabeli 14 limit 240 kg.
      await EwidencjaNawozenia(
        baza: baza,
        zabiegi: RepozytoriumZabiegow(baza),
        reguly: reguly,
      ).zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 800,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
      );

      await pokaz(tester, EkranNawozenieNowoczesny(uslugi: zbudujUslugi()));

      expect(find.textContaining('Azot z nawozów naturalnych'), findsWidgets);
      await przewinDo(tester, find.textContaining('wolno dać pod tę uprawę'));
      expect(find.textContaining('wolno dać pod tę uprawę'), findsOneWidget);
      await przewinDo(tester, find.textContaining('272 z 240 kg N/ha'));
      expect(find.textContaining('272 z 240 kg N/ha'), findsOneWidget);
      expect(find.text('ponad limit'), findsOneWidget);
    });

    testWidgets('spis nawozów przyjmuje nowy nawóz z zawartością azotu', (
      tester,
    ) async {
      await pokaz(tester, EkranNawozenieNowoczesny(uslugi: zbudujUslugi()));

      await przewinDo(tester, find.text('Nawozy i zawartość azotu'));
      await tester.tap(find.text('Nawozy i zawartość azotu'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nie masz jeszcze żadnego nawozu'),
        findsOneWidget,
      );
      await tester.tap(find.text('Dodaj nawóz'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Saletra z worka');
      // Zawartość azotu podnosimy przyciskiem „+", bez klawiatury.
      await tester.tap(find.bySemanticsLabel('Zwiększ dawkę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz nawóz'));
      await tester.pumpAndSettle();

      final zapisane = await RepozytoriumNawozow(baza).wszystkie('g1');
      expect(zapisane.single.nazwa, 'Saletra z worka');
      expect(zapisane.single.azotProcent, 1);
      expect(zapisane.single.naturalny, isFalse);
    });

    testWidgets('nawóz bez zawartości azotu mówi o tym wprost', (tester) async {
      await pokaz(tester, EkranNawozenieNowoczesny(uslugi: zbudujUslugi()));
      await przewinDo(tester, find.text('Nawozy i zawartość azotu'));
      await tester.tap(find.text('Nawozy i zawartość azotu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj nawóz'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nie będzie liczony do limitu azotu'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Gnojowica bez analizy');
      await tester.tap(find.text('Naturalny'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz nawóz'));
      await tester.pumpAndSettle();

      final zapisane = await RepozytoriumNawozow(baza).wszystkie('g1');
      expect(zapisane.single.azotProcent, isNull);
      expect(zapisane.single.naturalny, isTrue);
    });
  });

  group('dane gospodarstwa', () {
    testWidgets('nazwa i numer producenta zapisują się', (tester) async {
      final gospodarstwo = await RepozytoriumGospodarstw(baza: baza)
          .jedno('g1');
      await pokaz(
        tester,
        EkranDaneGospodarstwaNowoczesny(
          uslugi: zbudujUslugi(),
          gospodarstwo: gospodarstwo,
        ),
      );

      await tester.enterText(
        find.byType(TextField).first,
        'Gospodarstwo w Dąbrowie',
      );
      await tester.enterText(find.byType(TextField).last, '123456789');
      await tester.tap(find.text('Zapisz dane'));
      await tester.pumpAndSettle();

      final po = await RepozytoriumGospodarstw(baza: baza).jedno('g1');
      expect(po!.nazwa, 'Gospodarstwo w Dąbrowie');
      expect(po.numerProducenta, '123456789');
    });

    testWidgets('gospodarstwo bez nazwy nie zapisuje się po cichu', (
      tester,
    ) async {
      final gospodarstwo = await RepozytoriumGospodarstw(baza: baza)
          .jedno('g1');
      await pokaz(
        tester,
        EkranDaneGospodarstwaNowoczesny(
          uslugi: zbudujUslugi(),
          gospodarstwo: gospodarstwo,
        ),
      );

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.text('Zapisz dane'));
      await tester.pumpAndSettle();

      expect(find.text('Gospodarstwo nie ma nazwy.'), findsOneWidget);
      final po = await RepozytoriumGospodarstw(baza: baza).jedno('g1');
      expect(po!.nazwa, 'Gospodarstwo próbne');
    });

    testWidgets('ostatniego gospodarstwa nie da się usunąć', (tester) async {
      final gospodarstwo = await RepozytoriumGospodarstw(baza: baza)
          .jedno('g1');
      await pokaz(
        tester,
        EkranDaneGospodarstwaNowoczesny(
          uslugi: zbudujUslugi(),
          gospodarstwo: gospodarstwo,
        ),
      );

      await tester.tap(find.text('Usuń gospodarstwo'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Usuń'));
      await tester.pumpAndSettle();

      expect(find.text('To jedyne gospodarstwo w aplikacji.'), findsOneWidget);
      expect(
        await RepozytoriumGospodarstw(baza: baza).wszystkie(),
        hasLength(1),
      );
    });
  });

  group('bez przycięć na telefonie 420 px', () {
    /// Przewija ekran do końca; każde przycięcie układu zgłasza się
    /// w teście jako wyjątek, więc samo dojście do dołu jest sprawdzeniem.
    Future<void> przewinDoKonca(WidgetTester tester) async {
      for (var proba = 0; proba < 20; proba++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('działki, nawożenie i dane gospodarstwa', (tester) async {
      await dodajPole();
      await RepozytoriumDzialek(baza).zapisz(
        gospodarstwoId: 'g1',
        zUldk: KlientUldk.odczytaj(odpowiedzUldk, '061506_2.0007.138', 4326),
        urzadzenie: 'telefon',
      );

      await pokaz(tester, EkranDzialkiNowoczesny(uslugi: zbudujUslugi()));
      await przewinDoKonca(tester);

      await pokaz(tester, EkranNawozenieNowoczesny(uslugi: zbudujUslugi()));
      await przewinDoKonca(tester);

      await pokaz(tester, EkranImportWnioskuNowoczesny(uslugi: zbudujUslugi()));
      await przewinDoKonca(tester);

      final gospodarstwo = await RepozytoriumGospodarstw(baza: baza)
          .jedno('g1');
      await pokaz(
        tester,
        EkranDaneGospodarstwaNowoczesny(
          uslugi: zbudujUslugi(),
          gospodarstwo: gospodarstwo,
        ),
      );
      await przewinDoKonca(tester);

      expect(tester.takeException(), isNull);
    });
  });
}

class _ZrodloZDysku implements ZrodloPliku {
  _ZrodloZDysku({required this.nazwa, required this.bajty});

  final String nazwa;
  final Uint8List? bajty;

  @override
  Future<WybranyPlik?> wybierzPdf() async {
    final dane = bajty;
    return dane == null ? null : WybranyPlik(nazwa: nazwa, bajty: dane);
  }

  @override
  Future<WybranyPlik?> wybierzKopie() async => null;
}

/// Te testy nie dotykają dokumentów.
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
