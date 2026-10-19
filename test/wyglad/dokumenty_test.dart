import 'dart:convert';
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
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/gminy_terminy.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';
import 'package:agro_asystent/wyglad/prosty/dokumenty/ekran_dokumenty.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekran „Wydruk i eksport": podgląd dokumentu, wybór okresu i trzy formaty.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;
  late RepozytoriumZabiegow zabiegi;
  late _WyjscieDoPamieci wyjscie;

  Future<CzcionkiWydruku> czcionki() async => CzcionkiWydruku(
    zwykla: File('assets/czcionki/dejavu_sans_pl.ttf').readAsBytesSync(),
    pogrubiona: File('assets/czcionki/dejavu_sans_pl_bold.ttf')
        .readAsBytesSync(),
  );

  Future<void> dodajWpis({
    required String id,
    required DateTime kiedy,
    String? kodEppo = 'TRZAW',
  }) async {
    await baza.insert('dzialka_rolna', {
      'id': 'pole-$id',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Za stodołą',
      'sezon': kiedy.year,
      'uprawa': 'pszenica zwyczajna ozima',
      'kod_eppo': kodEppo,
      'powierzchnia_ar': 250,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: id,
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: kiedy,
        godzina: '08:30',
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: [PoleZabiegu(dzialkaRolnaId: 'pole-$id', powierzchniaAr: 250)],
      oprysk: SzczegolyOprysku(
        zabiegId: id,
        srodekNazwa: 'Abydos 750 EC',
        nrZezwolenia: 'R-14/2025 h.r.',
        dawka: 0.75,
        dawkaJednostka: 'l',
        dawkaOdniesienie: 'ha',
        przyczyna: 'mączniak prawdziwy zbóż i traw',
        bbchOd: 29,
        bbchDo: 59,
        kodEppo: kodEppo,
        rodzajZastosowania: 'opryskiwanie',
      ),
      teraz: kiedy,
    );
  }

  Future<void> dodajNawozenie({required DateTime kiedy}) async {
    await baza.insert('dzialka_rolna', {
      'id': 'pole-n',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Pod lasem',
      'sezon': kiedy.year,
      'uprawa': 'kukurydza na ziarno',
      'powierzchnia_ar': 400,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    const nawoz = Nawoz(
      id: 'n-saletra',
      gospodarstwoId: 'g1',
      nazwa: 'Saletra amonowa',
      naturalny: false,
      azotProcent: 34,
    );
    await RepozytoriumNawozow(baza).zapisz(nawoz: nawoz, urzadzenie: 'telefon');
    await EwidencjaNawozenia(
      baza: baza,
      zabiegi: RepozytoriumZabiegow(baza),
      reguly: reguly,
    ).zapisz(
      gospodarstwoId: 'g1',
      nawoz: nawoz,
      pola: const [PoleZabiegu(dzialkaRolnaId: 'pole-n', powierzchniaAr: 400)],
      dawka: 200,
      jednostka: JednostkaDawki.kilogramyNaHektar,
      urzadzenie: 'telefon',
      kiedy: kiedy,
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
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    zabiegi = RepozytoriumZabiegow(baza);
    wyjscie = _WyjscieDoPamieci();
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
    zabiegi: zabiegi,
    rejestr: RejestrZabiegow(baza),
    srodki: SlownikSrodkow(slowniki),
    uprawy: SlownikUpraw(slowniki),
    reguly: reguly,
    importWniosku: ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki)),
    zrodloPliku: const _BrakZrodlaPliku(),
    dokumenty: UslugaDokumentow(
      rejestr: RejestrZabiegow(baza),
      reguly: reguly,
      czcionki: czcionki,
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
    gospodarstwa: RepozytoriumGospodarstw(baza: baza),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: const _BrakPrzypomnien(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );

  Future<void> pokaz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranDokumenty(uslugi: zbudujUslugi()),
      ),
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

  testWidgets('podgląd pokazuje, co wyjdzie na papier', (tester) async {
    await dodajWpis(id: 'z1', kiedy: DateTime(2026, 5, 10));
    await pokaz(tester);

    expect(
      find.text('Ewidencja zabiegów środkami ochrony roślin'),
      findsWidgets,
    );
    expect(find.textContaining('Gospodarstwo próbne'), findsOneWidget);
    expect(find.textContaining('Wpisów: 1'), findsOneWidget);
    expect(
      find.textContaining('kolumn wymaganych przepisem: 12'),
      findsOneWidget,
    );
    expect(find.textContaining(reguly.wersja), findsOneWidget);

    // Zdanie o braku opłat stoi pod przyciskami — plan, pkt 11: dokumentacji
    // nigdy nie zamykamy za opłatą.
    await przewinDo(tester, find.textContaining('zawsze bez opłat'));
  });

  testWidgets('trzy formaty dają trzy pliki o właściwych nazwach', (
    tester,
  ) async {
    await dodajWpis(id: 'z1', kiedy: DateTime(2026, 5, 10));
    await pokaz(tester);

    await przewinDo(tester, find.text('Plik CSV'));
    await tester.tap(find.text('Plik CSV'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Plik XLSX'));
    await tester.tap(find.text('Plik XLSX'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Plik PDF'));
    await tester.tap(find.text('Plik PDF'));
    await tester.pumpAndSettle();

    expect(wyjscie.udostepnione, hasLength(3));
    expect(wyjscie.udostepnione[0].nazwa, endsWith('.csv'));
    expect(wyjscie.udostepnione[1].nazwa, endsWith('.xlsx'));
    expect(wyjscie.udostepnione[2].nazwa, endsWith('.pdf'));
    expect(wyjscie.wydrukowane, isEmpty);
  });

  testWidgets('„Wydrukuj" otwiera wydruk, a nie zapis pliku', (tester) async {
    await dodajWpis(id: 'z1', kiedy: DateTime(2026, 5, 10));
    await pokaz(tester);

    await przewinDo(tester, find.text('Wydrukuj'));
    await tester.tap(find.text('Wydrukuj'));
    await tester.pumpAndSettle();

    expect(wyjscie.wydrukowane, hasLength(1));
    expect(wyjscie.wydrukowane.single.dane, isNotEmpty);
    expect(wyjscie.udostepnione, isEmpty);
  });

  testWidgets('wybór roku zawęża dokument', (tester) async {
    await dodajWpis(id: 'z1', kiedy: DateTime(2025, 5, 10));
    await dodajWpis(id: 'z2', kiedy: DateTime(2026, 5, 10));
    await pokaz(tester);

    expect(find.textContaining('Wpisów: 2'), findsOneWidget);

    await tester.tap(find.text('2026'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Wpisów: 1'), findsOneWidget);
    expect(find.textContaining('rok 2026'), findsOneWidget);
  });

  testWidgets('braki w ewidencji widać przed wydrukiem', (tester) async {
    await dodajWpis(id: 'z1', kiedy: DateTime(2026, 5, 10), kodEppo: null);
    await pokaz(tester);

    expect(
      find.textContaining('nie ma kompletu danych wymaganych przepisem'),
      findsOneWidget,
    );
    expect(find.textContaining('wyjdą na wydruku jako „brak"'), findsOneWidget);
  });

  testWidgets('pusty okres mówi wprost, że nie ma wpisów', (tester) async {
    await pokaz(tester);
    expect(find.text('W tym okresie nie ma żadnego wpisu.'), findsOneWidget);
  });

  testWidgets('do wyboru są trzy rejestry z planu', (tester) async {
    await dodajWpis(id: 'z1', kiedy: DateTime(2026, 5, 10));
    await pokaz(tester);

    expect(
      find.text('Ewidencja zabiegów środkami ochrony roślin'),
      findsWidgets,
    );
    expect(
      find.text('Program azotanowy: ewidencja nawożenia azotem'),
      findsOneWidget,
    );
    expect(
      find.text('Ekoschematy: rejestr zabiegów agrotechnicznych'),
      findsOneWidget,
    );
  });

  testWidgets('ewidencja nawożenia drukuje nawóz i azot', (tester) async {
    await dodajNawozenie(kiedy: DateTime(2026, 4, 1));
    await pokaz(tester);

    await tester.tap(
      find.text('Program azotanowy: ewidencja nawożenia azotem'),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Wpisów: 1'), findsOneWidget);
    // Wzór z tabeli 15: dziewięć kolumn.
    expect(
      find.textContaining('kolumn wymaganych przepisem: 9'),
      findsOneWidget,
    );

    // Podgląd pokazuje samo zestawienie, więc treść sprawdzamy w eksporcie.
    await przewinDo(tester, find.text('Plik CSV'));
    await tester.tap(find.text('Plik CSV'));
    await tester.pumpAndSettle();

    final csv = utf8.decode(wyjscie.udostepnione.single.dane);
    expect(csv, contains('Program azotanowy'));
    expect(csv, contains('Saletra amonowa'));
    // 200 kg/ha × 34% = 68 kg N/ha, na 4 ha razem 272 kg N.
    expect(csv, contains('68 kg N/ha'));
    expect(csv, contains('272 kg N'));
    expect(csv, contains('Pod lasem'));
    expect(
      csv,
      contains('nie dotyczy'),
      reason: 'saletra to nawóz mineralny — daty przyorania nie wymaga',
    );
  });
}

class _BrakZrodlaPliku implements ZrodloPliku {
  const _BrakZrodlaPliku();

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;

  @override
  Future<WybranyPlik?> wybierzKopie() async => null;
}

class _WyjscieDoPamieci implements WyjscieDokumentu {
  final List<({Uint8List dane, String nazwa, String typMime})> udostepnione =
      [];
  final List<({Uint8List dane, String nazwa})> wydrukowane = [];

  @override
  Future<void> drukujPdf({
    required Uint8List dane,
    required String nazwa,
  }) async {
    wydrukowane.add((dane: dane, nazwa: nazwa));
  }

  @override
  Future<void> udostepnij({
    required Uint8List dane,
    required String nazwa,
    required String typMime,
  }) async {
    udostepnione.add((dane: dane, nazwa: nazwa, typMime: typMime));
  }
}

/// Te testy nie dotykają terminów — przypomnienia nie są planowane.
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
