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
import 'package:agro_asystent/rdzen/wspolne/tekst.dart';
import 'package:agro_asystent/wyglad/prosty/ekran_pola.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Wybór uprawy pola z listy (wygląd prosty).
///
/// Miara z planu: wpis bez klawiatury. Uprawę rolnik wybiera z listy,
/// a pisze tylko wtedy, gdy jego uprawy w słowniku nie ma — i wtedy nie
/// dostaje wymyślonego kodu EPPO.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;

  Future<void> dodajUprawe({
    required String nazwa,
    String? kod,
    String stan = 'kod',
    String? gatunki,
    String? pytanie,
    int zastosowan = 0,
  }) => slowniki.insert('uprawa', {
    'nazwa': nazwa,
    'kod_eppo': kod,
    'stan': stan,
    'gatunki': gatunki,
    'pytanie': pytanie,
    'zastosowan': zastosowan,
    // Tę kolumnę liczy skrypt budujący słownik — tu robimy to samo.
    'szukanie': Tekst.znormalizuj(nazwa),
  });

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-10-16T08:00:00',
      'zmieniono': '2026-10-16T08:00:00',
      'urzadzenie': 'telefon',
    });
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute('''
      CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
        stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
        zastosowan INTEGER NOT NULL DEFAULT 0,
        szukanie TEXT NOT NULL DEFAULT '')
    ''');
    await dodajUprawe(nazwa: 'pszenica ozima', kod: 'TRZAW', zastosowan: 1497);
    await dodajUprawe(nazwa: 'kukurydza', kod: 'ZEAMX', zastosowan: 425);
    await dodajUprawe(
      nazwa: 'łubin',
      stan: 'rodzajowa',
      gatunki: 'łubin żółty|łubin biały',
      pytanie: 'Jaki łubin?',
      zastosowan: 37,
    );
    await dodajUprawe(nazwa: 'łubin żółty', kod: 'LUPLU', zastosowan: 157);
    await dodajUprawe(nazwa: 'łubin biały', kod: 'LUPAL', zastosowan: 158);
    await dodajUprawe(nazwa: 'nieszpułka', stan: 'brak', zastosowan: 92);
    await dodajUprawe(nazwa: 'zboża', stan: 'grupa', zastosowan: 27);
    await dodajUprawe(nazwa: 'róża', stan: 'poza_zakresem', zastosowan: 131);
    // Uprawa z samego końca listy — przewijaniem nie do znalezienia.
    await dodajUprawe(nazwa: 'salsefia', kod: 'TROPS', zastosowan: 1);
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
    gospodarstwa: RepozytoriumGospodarstw(baza: baza),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: const _BrakPrzypomnien(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );

  Future<void> otworzNowePole(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranPola(uslugi: zbudujUslugi()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dodaj pole'));
    await tester.pumpAndSettle();
  }

  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    // Przewijamy listę ekranu, nie wnętrze pola tekstowego — TextField też
    // ma swój Scrollable i trafienie w niego nic nie przewija.
    await tester.scrollUntilVisible(
      czego,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('uprawę wybiera się z listy, od najczęstszych', (tester) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();

    expect(find.text('Jaka uprawa?'), findsOneWidget);
    expect(find.text('pszenica ozima'), findsOneWidget);
    expect(find.textContaining('kod EPPO: TRZAW'), findsOneWidget);
    // Nazwa zbiorcza i roślina spoza zakresu nie są uprawą pola.
    expect(find.text('zboża'), findsNothing);
    expect(find.text('róża'), findsNothing);
  });

  testWidgets('wybrana uprawa wraca z kodem i zapisuje się z polem', (
    tester,
  ) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('kukurydza'));
    await tester.pumpAndSettle();

    expect(find.textContaining('kod EPPO: ZEAMX'), findsOneWidget);
    await przewinDo(tester, find.text('Zapisz pole'));
    await tester.tap(find.text('Zapisz pole'));
    await tester.pumpAndSettle();

    final pola = await RepozytoriumPol(baza).wszystkie('g1');
    expect(pola.single.uprawa, 'kukurydza');
    expect(pola.single.kodEppo, 'ZEAMX');
  });

  testWidgets('nazwa rodzajowa pyta o gatunek, zamiast dawać kod rodzaju', (
    tester,
  ) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('łubin'));
    await tester.pumpAndSettle();

    expect(find.text('Jaki łubin?'), findsOneWidget);
    expect(find.text('łubin żółty'), findsOneWidget);
    await tester.tap(find.text('łubin żółty'));
    await tester.pumpAndSettle();

    // Jedno dotknięcie zamyka oba ekrany wyboru.
    expect(find.text('Nowe pole'), findsOneWidget);
    expect(find.textContaining('kod EPPO: LUPLU'), findsOneWidget);
  });

  testWidgets('szukanie zawęża listę upraw', (tester) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'kuku');
    await tester.pumpAndSettle();

    expect(find.text('kukurydza'), findsOneWidget);
    expect(find.text('pszenica ozima'), findsNothing);
  });

  testWidgets('własna nazwa uprawy: ostrzeżenie i brak kodu EPPO', (
    tester,
  ) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Nie ma mojej uprawy'));
    await tester.tap(find.text('Nie ma mojej uprawy'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nie podpowiemy środków'), findsOneWidget);
    expect(find.textContaining('zostanie „brak"'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'proso na ziarno');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zapisz nazwę'));
    await tester.pumpAndSettle();

    expect(find.textContaining('bez kodu EPPO'), findsOneWidget);
    await przewinDo(tester, find.text('Zapisz pole'));
    await tester.tap(find.text('Zapisz pole'));
    await tester.pumpAndSettle();

    final pola = await RepozytoriumPol(baza).wszystkie('g1');
    expect(pola.single.uprawa, 'proso na ziarno');
    expect(pola.single.kodEppo, isNull, reason: 'kodu nie wymyślamy');
  });

  testWidgets('klawiatura wychodzi po dotknięciu okienka, nie od razu', (
    tester,
  ) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();

    // Najpierw widać listę upraw — klawiatura nie zasłania ekranu.
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(find.text('pszenica ozima'), findsOneWidget);

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(
      tester.testTextInput.isVisible,
      isTrue,
      reason: 'dotknięcie okienka podnosi klawiaturę',
    );
  });

  testWidgets('wyszukiwarka znajduje uprawę z końca listy', (tester) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'salsef');
    await tester.pumpAndSettle();

    expect(find.text('Znaleziono 1 uprawę.'), findsOneWidget);
    expect(find.text('salsefia'), findsOneWidget);
    expect(find.text('pszenica ozima'), findsNothing);
  });

  testWidgets('szukanie bez ogonków i wielkimi literami też działa', (
    tester,
  ) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();

    // Rolnik nie przełącza klawiatury na polskie znaki.
    await tester.enterText(find.byType(TextField), 'LUBIN');
    await tester.pumpAndSettle();

    expect(find.text('łubin'), findsOneWidget);
  });

  testWidgets('dwa słowa szukają niezależnie od kolejności', (tester) async {
    await otworzNowePole(tester);
    await tester.tap(find.text('Wybierz uprawę'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'ozim psz');
    await tester.pumpAndSettle();

    expect(find.text('pszenica ozima'), findsOneWidget);
  });

  testWidgets('uprawę pola można zmienić na nowy sezon', (tester) async {
    await baza.insert('dzialka_rolna', {
      'id': 'p1',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Za stodołą',
      'sezon': 2026,
      'uprawa': 'pszenica ozima',
      'kod_eppo': 'TRZAW',
      'powierzchnia_ar': 320,
      'utworzono': '2026-10-16T08:00:00',
      'zmieniono': '2026-10-16T08:00:00',
      'urzadzenie': 'telefon',
    });

    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranPola(uslugi: zbudujUslugi()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Za stodołą'));
    await tester.pumpAndSettle();
    expect(find.text('pszenica ozima'), findsOneWidget);
    expect(find.textContaining('Kod EPPO: TRZAW'), findsOneWidget);

    await tester.tap(find.text('Zmień uprawę'));
    await tester.pumpAndSettle();
    // Krótki fragment, żeby wpisany tekst nie mieszał się z nazwą na liście.
    await tester.enterText(find.byType(TextField), 'kuku');
    await tester.pumpAndSettle();
    await tester.tap(find.text('kukurydza'));
    await tester.pumpAndSettle();

    final pole = await RepozytoriumPol(baza).jedno('p1');
    expect(pole!.uprawa, 'kukurydza');
    expect(pole.kodEppo, 'ZEAMX');
    // Poprzednia uprawa zostaje w dzienniku zmian.
    final historia = await baza.query(
      'historia_zmian',
      where: 'tabela = ? AND wiersz_id = ?',
      whereArgs: ['dzialka_rolna', 'p1'],
    );
    expect(historia, hasLength(1));
    expect(historia.single['dane_json'], contains('pszenica ozima'));
  });

  testWidgets('bez wybranej uprawy pola nie da się zapisać', (tester) async {
    await otworzNowePole(tester);
    await przewinDo(tester, find.text('Zapisz pole'));

    final przycisk = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(przycisk.onPressed, isNull);
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
