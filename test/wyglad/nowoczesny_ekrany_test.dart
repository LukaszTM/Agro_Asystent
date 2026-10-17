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
import 'package:agro_asystent/funkcje/dzialki/rodzaj_uzytku.dart';
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
import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/gminy_terminy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';
import 'package:agro_asystent/rdzen/wspolne/mapa_dzialek.dart';
import 'package:agro_asystent/funkcje/magazyn/magazyn.dart';
import 'package:agro_asystent/wyglad/nowoczesny/magazyn/ekran_magazyn.dart';
import 'package:agro_asystent/wyglad/nowoczesny/motyw.dart';
import 'package:agro_asystent/wyglad/nowoczesny/nawozenie/ekran_nawozenie.dart';
import 'package:agro_asystent/wyglad/nowoczesny/pola/ekran_dzialki.dart';
import 'package:agro_asystent/wyglad/nowoczesny/pola/ekran_import_wniosku.dart';
import 'package:agro_asystent/funkcje/warunkowosc/okrywa_pola.dart';
import 'package:agro_asystent/wyglad/nowoczesny/pola/ekran_pole.dart';
import 'package:agro_asystent/wyglad/nowoczesny/ustawienia/ekran_dane_gospodarstwa.dart';
import 'package:agro_asystent/wyglad/nowoczesny/warunkowosc/ekran_warunkowosc.dart';
import 'package:agro_asystent/wyglad/nowoczesny/wpis/ekran_wpis.dart';
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

  Uslugi zbudujUslugi({KlientUldk? uldk, bool premium = false}) => Uslugi(
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
    dostep: DostepFunkcji(maPremium: premium),
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

  group('rodzaj użytku i uprawy w latach', () {
    testWidgets('rodzaj użytku zapisuje wybór rolnika, nie podpowiedź', (
      tester,
    ) async {
      await dodajPole();
      final pole = (await RepozytoriumPol(baza).jedno('p1'))!;
      await pokaz(
        tester,
        EkranPoleNowoczesny(uslugi: zbudujUslugi(), pole: pole),
      );

      expect(find.textContaining('Nie wiemy, czy to grunt'), findsOneWidget);
      expect(
        find.textContaining('Z nazwy uprawy wychodzi: Grunty orne'),
        findsOneWidget,
      );
      expect(pole.rodzajUzytku, RodzajUzytku.nieznany);

      await tester.tap(find.text('Łąka lub pastwisko'));
      await tester.pumpAndSettle();

      expect(
        (await RepozytoriumPol(baza).jedno('p1'))!.rodzajUzytku,
        RodzajUzytku.tuz,
      );
      expect(find.textContaining('Nie wiemy, czy to grunt'), findsNothing);
    });

    testWidgets('brakujące lata idą od roku z przepisu', (tester) async {
      await dodajPole();
      final pole = (await RepozytoriumPol(baza).jedno('p1'))!;
      await pokaz(
        tester,
        EkranPoleNowoczesny(uslugi: zbudujUslugi(), pole: pole),
      );

      await przewinDo(tester, find.textContaining('od 2023 r.'));
      expect(find.textContaining('od 2023 r.'), findsWidgets);
      expect(find.text('Dopisz rok 2025'), findsOneWidget);
      expect(find.text('Dopisz rok 2023'), findsOneWidget);
      // Rok bieżący wziął się z pola, więc nie ma go wśród brakujących.
      expect(find.text('Dopisz rok ${DateTime.now().year}'), findsNothing);
    });

    testWidgets('okrywa po zbiorze: podpowiedź, a zapis po dotknięciu', (
      tester,
    ) async {
      await dodajPole(uprawa: 'pszenica ozima');
      final pole = (await RepozytoriumPol(baza).jedno('p1'))!;
      await pokaz(
        tester,
        EkranPoleNowoczesny(uslugi: zbudujUslugi(), pole: pole),
      );

      await przewinDo(tester, find.textContaining('Nie wiemy, co zostaje'));
      expect(find.textContaining('Nie wiemy, co zostaje'), findsOneWidget);
      // Ozimina w uprawie to podpowiedź, nie zapis.
      expect(find.textContaining('Podpowiedź: Uprawa ozima'), findsOneWidget);
      expect(
        await RepozytoriumOkrywyPola(baza)
            .dlaPola(poleId: 'p1', sezon: DateTime.now().year),
        isNull,
      );

      await przewinDo(tester, find.text('Uprawa ozima'));
      await tester.ensureVisible(find.text('Uprawa ozima'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uprawa ozima'));
      await tester.pumpAndSettle();

      final deklaracja = await RepozytoriumOkrywyPola(baza)
          .dlaPola(poleId: 'p1', sezon: DateTime.now().year);
      expect(deklaracja?.forma, 'uprawa_ozima');
      expect(deklaracja?.zrodlo, 'podpowiedz potwierdzona');
    });
  });

  group('siew, zbiór i prace przy drzewach', () {
    testWidgets('zbiór zapisuje się bez środka i bez dawki', (tester) async {
      await dodajPole();
      await pokaz(
        tester,
        EkranWpisu(uslugi: zbudujUslugi(), teraz: DateTime(2026, 8, 2, 10)),
      );

      await tester.tap(find.text('Zbiór'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Zapisz'));
      await tester.ensureVisible(find.text('Zapisz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      final zabiegi = await RepozytoriumZabiegow(baza).wszystkie('g1');
      expect(zabiegi.single.rodzaj, RodzajZabiegu.zbior);
      // Baza trzyma dzień i godzinę w osobnych kolumnach.
      expect(zabiegi.single.data, DateTime(2026, 8, 2));
      expect(zabiegi.single.godzina, '10:00');
      // Dzień zbioru jest potrzebny normie GAEC 6 — teraz ma skąd się wziąć.
      expect(
        await RepozytoriumOkrywyPola(baza)
            .dzienZbioruZWpisow(poleId: 'p1', sezon: 2026),
        DateTime(2026, 8, 2),
      );
    });

    testWidgets('przycinanie w okresie lęgowym ostrzega, ale nie blokuje', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(
        tester,
        EkranWpisu(uslugi: zbudujUslugi(), teraz: DateTime(2026, 5, 10, 9)),
      );

      await tester.tap(find.text('Inny'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Przycinanie drzew albo żywopłotu'));
      await tester.ensureVisible(find.text('Przycinanie drzew albo żywopłotu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Przycinanie drzew albo żywopłotu'));
      await tester.pumpAndSettle();

      expect(find.textContaining('okres lęgowy'), findsOneWidget);
      expect(find.textContaining('15 kwietnia'), findsOneWidget);

      await przewinDo(tester, find.text('Zapisz'));
      await tester.ensureVisible(find.text('Zapisz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      final zabiegi = await RepozytoriumZabiegow(baza).wszystkie('g1');
      expect(zabiegi.single.rodzaj, RodzajZabiegu.inny);
      expect(zabiegi.single.podrodzaj, 'przycinanie_drzew');
      expect(zabiegi.single.uwagi, 'Przycinanie drzew albo żywopłotu');
    });

    testWidgets('przy pracy „inny" bez wyboru zapis jest zablokowany', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(
        tester,
        EkranWpisu(uslugi: zbudujUslugi(), teraz: DateTime(2026, 5, 10, 9)),
      );

      await tester.tap(find.text('Inny'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Wybierz z listy, co robisz.'));
      expect(find.text('Wybierz z listy, co robisz.'), findsOneWidget);
    });
  });

  group('warunkowość', () {
    testWidgets('każda norma ma stan, a nieliczona mówi o tym wprost', (
      tester,
    ) async {
      await dodajPole(ar: 2400);
      await baza.update(
        'dzialka_rolna',
        {'rodzaj_uzytku': 'grunty_orne', 'granica_z_woda': 'nie'},
        where: 'gospodarstwo_id = ?',
        whereArgs: ['g1'],
      );
      await pokaz(
        tester,
        EkranWarunkowoscNowoczesny(
          uslugi: zbudujUslugi(),
          teraz: DateTime(2026, 10, 1),
        ),
      );

      expect(find.textContaining('Normy GAEC w 2026 r.'), findsOneWidget);
      await przewinDo(tester, find.textContaining('IUNG-PIB'));
      expect(find.textContaining('IUNG-PIB'), findsOneWidget);

      await przewinDo(tester, find.textContaining('GAEC 7:'));
      expect(find.textContaining('GAEC 7:'), findsOneWidget);
      expect(find.textContaining('Grunty orne: 24,00 ha'), findsOneWidget);

      // Wydruk na kontrolę jest darmowy — żadnej oferty premium.
      await przewinDo(tester, find.text('Wydrukuj PDF'));
      expect(find.text('Wydrukuj PDF'), findsOneWidget);
      expect(find.textContaining('premium'), findsNothing);
    });
  });

  group('magazyn', () {
    testWidgets('bez premium ekran mówi o tym wprost', (tester) async {
      await pokaz(tester, EkranMagazynNowoczesny(uslugi: zbudujUslugi()));

      expect(find.textContaining('należy do wersji płatnej'), findsOneWidget);
      expect(find.text('Dodaj nawozy ze spisu'), findsNothing);
    });

    testWidgets('w premium zużycie z zabiegu zdejmuje towar ze stanu', (
      tester,
    ) async {
      final uslugi = zbudujUslugi(premium: true);
      await uslugi.magazyn.zapiszPozycje(
        gospodarstwoId: 'g1',
        rodzaj: RodzajPozycji.srodek,
        nazwa: 'Abydos 750 EC',
        jednostka: 'l',
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 1),
      );
      await uslugi.magazyn.zapiszZakup(
        pozycjaId: PozycjaMagazynu.identyfikator(
          gospodarstwoId: 'g1',
          rodzaj: RodzajPozycji.srodek,
          nazwa: 'Abydos 750 EC',
        ),
        ilosc: 10,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );

      // Wpis oprysku na 3,20 ha dawką 0,75 l/ha zdejmuje 2,40 l.
      await uslugi.magazyn.odpiszZabieg(
        gospodarstwoId: 'g1',
        zabiegId: 'z1',
        rodzaj: RodzajPozycji.srodek,
        nazwa: 'Abydos 750 EC',
        ilosc: 2.4,
        kiedy: DateTime(2026, 4, 10),
        urzadzenie: 'telefon',
      );

      await pokaz(
        tester,
        EkranMagazynNowoczesny(uslugi: uslugi, teraz: DateTime(2026, 4, 20)),
      );
      expect(find.textContaining('7,60 l'), findsOneWidget);
      expect(find.textContaining('kupione 10,00'), findsOneWidget);
      expect(find.textContaining('zużyte 2,40'), findsOneWidget);
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
