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
import 'package:agro_asystent/wyglad/prosty/ustawienia/ekran_kopia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekran kopii danych (plan, pkt 8): kopia do pliku jest zawsze darmowa,
/// a wczytanie nie może po cichu zdublować dokumentacji.

void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;
  late _ZapisaneWyjscie wyjscie;
  late _ZrodloKopii zrodlo;

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
    wyjscie = _ZapisaneWyjscie();
    zrodlo = _ZrodloKopii();
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      'CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT)',
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
    reguly: reguly,
    importWniosku: ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki)),
    zrodloPliku: zrodlo,
    dokumenty: UslugaDokumentow(
      rejestr: RejestrZabiegow(baza),
      reguly: reguly,
      czcionki: _brakCzcionek,
      wyjscie: wyjscie,
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

  Future<void> dodajPole() => baza.insert('dzialka_rolna', {
    'id': 'pole-1',
    'gospodarstwo_id': 'g1',
    'nazwa_wlasna': 'Za stodołą',
    'sezon': 2026,
    'uprawa': 'pszenica zwyczajna ozima',
    'powierzchnia_ar': 250,
    'utworzono': '2026-03-01T08:00:00',
    'zmieniono': '2026-03-01T08:00:00',
    'urzadzenie': 'telefon',
  });

  testWidgets('kopia zapisuje się do pliku i mówi, co dalej', (tester) async {
    await dodajPole();
    await pokaz(tester, EkranKopia(uslugi: zbudujUslugi()));

    await tester.tap(find.text('Zrób kopię'));
    await tester.pumpAndSettle();

    expect(wyjscie.udostepnione, hasLength(1));
    expect(
      wyjscie.udostepnione.single.nazwa,
      startsWith('agro-asystent-kopia'),
    );
    expect(wyjscie.udostepnione.single.nazwa, endsWith('.zip'));
    expect(wyjscie.udostepnione.single.typMime, 'application/zip');
    expect(find.textContaining('Kopia gotowa'), findsOneWidget);
    expect(find.textContaining('po zgubieniu telefonu'), findsOneWidget);
  });

  testWidgets('kopia jest darmowa i ekran to mówi', (tester) async {
    await pokaz(tester, EkranKopia(uslugi: zbudujUslugi()));
    expect(find.textContaining('darmowa i zawsze będzie'), findsOneWidget);
  });

  testWidgets('wczytania na istniejące dane odmawiamy z wyjaśnieniem', (
    tester,
  ) async {
    await dodajPole();
    final uslugi = zbudujUslugi();
    zrodlo.kopia = await uslugi.kopia.zrob();

    await pokaz(tester, EkranKopia(uslugi: uslugi));
    await tester.tap(find.text('Wczytaj kopię'));
    await tester.pumpAndSettle();

    expect(find.text('W telefonie są już wpisy.'), findsOneWidget);
    expect(find.textContaining('żeby nie zdublować'), findsOneWidget);
    expect(
      (await baza.query('dzialka_rolna')).length,
      1,
      reason: 'odmowa nie może niczego zdublować',
    );
  });

  testWidgets('obcy plik nie jest wczytywany', (tester) async {
    zrodlo.kopia = Uint8List.fromList([9, 9, 9]);
    await pokaz(tester, EkranKopia(uslugi: zbudujUslugi()));

    await tester.tap(find.text('Wczytaj kopię'));
    await tester.pumpAndSettle();

    expect(find.text('To nie jest kopia z tej aplikacji.'), findsOneWidget);
  });
}

/// Zapisuje to, co aplikacja oddaje do świata — bez dotykania systemu.
class _ZapisaneWyjscie implements WyjscieDokumentu {
  final List<({Uint8List dane, String nazwa, String typMime})> udostepnione =
      [];

  @override
  Future<void> drukujPdf({required Uint8List dane, required String nazwa}) =>
      throw UnimplementedError();

  @override
  Future<void> udostepnij({
    required Uint8List dane,
    required String nazwa,
    required String typMime,
  }) async {
    udostepnione.add((dane: dane, nazwa: nazwa, typMime: typMime));
  }
}

/// Podstawia plik kopii zamiast okna systemowego.
class _ZrodloKopii implements ZrodloPliku {
  Uint8List? kopia;

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;

  @override
  Future<WybranyPlik?> wybierzKopie() async {
    final dane = kopia;
    return dane == null
        ? null
        : WybranyPlik(nazwa: 'agro-asystent-kopia.zip', bajty: dane);
  }
}

Future<CzcionkiWydruku> _brakCzcionek() async =>
    throw UnimplementedError('czcionki wydruku nie są tu potrzebne');

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
