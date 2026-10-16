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
import 'package:agro_asystent/funkcje/zabiegi/dane_wpisu.dart';
import 'package:agro_asystent/wyglad/prosty/nawozenie/ekran_nawozy.dart';
import 'package:agro_asystent/wyglad/prosty/wpis/ekran_wybor_srodka.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Odczyt zdjęć w ekranach (krok 7 etapu 1): worek nawozu i etykieta środka.
/// Zdjęcia nie robimy — czytnik podstawiamy, bo sprawdzamy, co aplikacja
/// robi z odczytanym tekstem.

void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;
  late _CzytnikZPamieci czytnik;

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
    await slowniki.execute('''
      CREATE TABLE srodek (id INTEGER PRIMARY KEY, nazwa TEXT,
        nr_zezwolenia TEXT, rodzaj TEXT, substancja_czynna TEXT,
        producent TEXT, adres_etykiety TEXT, termin_do_stosowania TEXT)''');
    await slowniki.execute('''
      CREATE TABLE zastosowanie (id INTEGER PRIMARY KEY, srodek_id INTEGER,
        agrofag TEXT, dawka_wartosc REAL, dawka_jednostka TEXT,
        dawka_odniesienie TEXT, dawka_tekst TEXT, dawka_pewnosc TEXT,
        termin_tekst TEXT, bbch_od INTEGER, bbch_do INTEGER,
        maloobszarowe INTEGER)''');
    await slowniki.execute(
      'CREATE TABLE zastosowanie_uprawa (zastosowanie_id INTEGER, uprawa TEXT)',
    );
    await slowniki.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    await slowniki.execute('''
      CREATE TABLE karencja (srodek_nazwa TEXT, uprawa TEXT, dni INTEGER,
        stan TEXT, data_etykiety TEXT, zrodlo TEXT)''');

    Future<void> dodajSrodek(int id, String nazwa, String zezwolenie) async {
      await slowniki.insert('srodek', {
        'id': id,
        'nazwa': nazwa,
        'nr_zezwolenia': zezwolenie,
        'rodzaj': 'Fungicyd',
      });
      await slowniki.insert('zastosowanie', {
        'id': id * 10,
        'srodek_id': id,
        'agrofag': 'mączniak prawdziwy zbóż i traw',
        'dawka_wartosc': 0.75,
        'dawka_jednostka': 'l',
        'dawka_odniesienie': 'ha',
        'dawka_pewnosc': 'odczytana',
      });
      await slowniki.insert('zastosowanie_uprawa', {
        'zastosowanie_id': id * 10,
        'uprawa': 'pszenica ozima',
      });
    }

    await dodajSrodek(1, 'Abydos 750 EC', 'R-14/2025 h.r.');
    await dodajSrodek(2, 'Dithane NeoTec 75 WG', 'R-55/2023');

    czytnik = _CzytnikZPamieci();
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
    czytnikZdjecia: czytnik,
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

  Future<void> pokaz(WidgetTester tester, Widget ekran) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(theme: MotywProsty.zbuduj(), home: ekran),
    );
    await tester.pumpAndSettle();
  }

  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    await tester.scrollUntilVisible(
      czego,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  group('worek nawozu', () {
    testWidgets('odczyt wypełnia nazwę i zawartość azotu do potwierdzenia', (
      tester,
    ) async {
      czytnik.tekstZeZdjecia = 'SALETRA AMONOWA\nazot całkowity (N) 34,0 %\n';
      await pokaz(tester, EkranNowyNawoz(uslugi: zbudujUslugi()));

      await tester.tap(find.text('Odczytaj z worka'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sprawdź i popraw'), findsOneWidget);
      expect(find.text('SALETRA AMONOWA'), findsOneWidget);
      expect(find.textContaining('34'), findsWidgets);

      await przewinDo(tester, find.text('Zapisz nawóz'));
      await tester.tap(find.text('Zapisz nawóz'));
      await tester.pumpAndSettle();

      final nawozy = await RepozytoriumNawozow(baza).wszystkie('g1');
      expect(nawozy.single.nazwa, 'SALETRA AMONOWA');
      expect(nawozy.single.azotProcent, 34);
      expect(nawozy.single.zrodlo, 'zdjęcie worka');
    });

    testWidgets('nieczytelne zdjęcie mówi, co zrobić', (tester) async {
      czytnik.tekstZeZdjecia = '||| ??? ---';
      await pokaz(tester, EkranNowyNawoz(uslugi: zbudujUslugi()));

      await tester.tap(find.text('Odczytaj z worka'));
      await tester.pumpAndSettle();

      expect(find.textContaining('nic nie dało się odczytać'), findsOneWidget);
      expect(
        find.textContaining('Wpisz nazwę i zawartość azotu ręcznie'),
        findsOneWidget,
      );
    });

    testWidgets('błąd aparatu kończy się jednym zdaniem', (tester) async {
      czytnik.blad = const BladOdczytuZdjecia(
        'Nie udało się otworzyć aparatu.',
        coZrobic: 'Sprawdź zgodę na aparat.',
      );
      await pokaz(tester, EkranNowyNawoz(uslugi: zbudujUslugi()));

      await tester.tap(find.text('Odczytaj z worka'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Nie udało się otworzyć aparatu'),
        findsOneWidget,
      );
    });
  });

  group('etykieta środka', () {
    DaneWpisu daneZPolem() =>
        DaneWpisu(gospodarstwoId: 'g1', urzadzenie: 'telefon')
          ..pola.add(
            const Pole(
              id: 'p1',
              gospodarstwoId: 'g1',
              nazwa: 'Za stodołą',
              uprawa: 'pszenica ozima',
              kodEppo: 'TRZAW',
              powierzchniaAr: 250,
            ),
          );

    testWidgets('rozpoznana etykieta zawęża listę do jednego środka', (
      tester,
    ) async {
      czytnik.tekstZeZdjecia =
          'ABYDOS 750 EC\nZezwolenie MRiRW nr R-14/2025 h.r.';
      await pokaz(
        tester,
        EkranWyborSrodka(uslugi: zbudujUslugi(), dane: daneZPolem()),
      );

      expect(find.text('Dithane NeoTec 75 WG'), findsOneWidget);

      await tester.tap(find.text('Rozpoznaj etykietę'));
      await tester.pumpAndSettle();

      expect(find.text('Abydos 750 EC'), findsOneWidget);
      expect(find.text('Dithane NeoTec 75 WG'), findsNothing);
    });

    testWidgets('środka spoza rejestru nie dopisujemy', (tester) async {
      czytnik.tekstZeZdjecia = 'NIEZNANY 100 EC\nR-77/2020';
      await pokaz(
        tester,
        EkranWyborSrodka(uslugi: zbudujUslugi(), dane: daneZPolem()),
      );

      await tester.tap(find.text('Rozpoznaj etykietę'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('rejestr nie ma takiego środka'),
        findsOneWidget,
      );
      expect(find.text('Abydos 750 EC'), findsOneWidget);
    });
  });
}

/// Czytnik, który zamiast aparatu oddaje przygotowany tekst.
class _CzytnikZPamieci implements CzytnikZdjecia {
  String? tekstZeZdjecia;
  BladOdczytuZdjecia? blad;

  @override
  Future<String?> tekst(ZrodloZdjecia zrodlo) async {
    final doRzucenia = blad;
    if (doRzucenia != null) {
      throw doRzucenia;
    }
    return tekstZeZdjecia;
  }
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
