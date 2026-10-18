import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/szukanie_dzialki.dart';
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
import 'package:agro_asystent/wyglad/prosty/dzialki/ekran_dzialki.dart';
import 'package:agro_asystent/rdzen/wspolne/mapa_dzialek.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Krok 1 etapu 1: dodanie działki po numerze ewidencyjnym, granice z ULDK
/// i mapa działająca bez internetu (plan, pkt 4).
void main() {
  sqfliteFfiInit();
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );
  final fabryka = databaseFactoryFfiNoIsolate;

  const obrys =
      'SRID=4326;POLYGON((19.100 52.100,19.102 52.100,19.102 52.102,'
      '19.100 52.102,19.100 52.100))';
  const odpowiedzUldk =
      '0\n$obrys|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138';

  late Database baza;

  /// Klient, który udaje usługę ULDK. `onZapytanie` pozwala sprawdzić,
  /// czy ekran w ogóle sięgnął do sieci.
  KlientUldk udawanaUsluga(
    String odpowiedz, {
    void Function()? onZapytanie,
    int status = 200,
  }) => KlientUldk(
    klient: MockClient((_) async {
      onZapytanie?.call();
      return http.Response(
        odpowiedz,
        status,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }),
  );

  Future<Uslugi> zbudujUslugi({required KlientUldk uldk}) async {
    final slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    return Uslugi(
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
      importWniosku: ImportWniosku(
        baza: baza,
        srodki: SlownikSrodkow(slowniki),
      ),
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
      uldk: uldk,
      wojewodztwa: SlownikWojewodztw.zTekstuJson(
        File('assets/dane/wojewodztwa.json').readAsStringSync(),
      ),
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
      'utworzono': '2026-10-15T08:00:00',
      'zmieniono': '2026-10-15T08:00:00',
      'urzadzenie': 'telefon',
    });
  });

  tearDown(() => baza.close());

  Future<void> pokaz(WidgetTester tester, Uslugi uslugi) async {
    // Ekran telefonu, nie domyślne 800×600 — klawiatura numeru zajmuje dużo
    // miejsca i chcemy sprawdzić, że przycisk mimo to jest pod ręką.
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranDzialki(uslugi: uslugi),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Wpisuje pełny numer dużą klawiaturą — bez klawiatury systemowej.
  ///
  /// Ekran otwiera się na szukaniu po miejscowości (działki spoza
  /// wniosku), więc najpierw przechodzimy na drogę „numer z wniosku".
  Future<void> wpiszNumer(
    WidgetTester tester,
    String numer, {
    bool zWniosku = true,
  }) async {
    final przelacznik = find.text('Mam pełny numer z wniosku');
    if (zWniosku && przelacznik.evaluate().isNotEmpty) {
      await tester.tap(przelacznik);
      await tester.pumpAndSettle();
    }
    // Lista buduje tylko to, co widać, więc najpierw przewijamy do
    // klawiatury — inaczej klawiszy po prostu nie ma w drzewie.
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, numer.split('').first),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    for (final znak in numer.split('')) {
      final klawisz = find.widgetWithText(InkWell, znak).first;
      await tester.ensureVisible(klawisz);
      await tester.pump();
      await tester.tap(klawisz);
      await tester.pump();
    }
  }

  testWidgets('dodanie działki po numerze kończy się potwierdzeniem na mapie', (
    tester,
  ) async {
    final uslugi = await zbudujUslugi(uldk: udawanaUsluga(odpowiedzUldk));
    await pokaz(tester, uslugi);

    expect(find.text('Nie masz jeszcze żadnej działki.'), findsOneWidget);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();

    await wpiszNumer(tester, '061506_2.0007.138');
    expect(find.text('061506_2.0007.138'), findsOneWidget);

    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    // Rolnik musi potwierdzić działkę na mapie, bo nazwy obrębów się
    // powtarzają (plan, pkt 6.1).
    expect(find.text('Czy to ta działka?'), findsOneWidget);
    expect(find.byType(MapaDzialek), findsOneWidget);
    expect(find.text('Brzeziny, Lubartów, lubartowski'), findsOneWidget);
    expect(find.textContaining('około'), findsOneWidget);

    await tester.tap(find.text('Tak, to moja działka'));
    await tester.pumpAndSettle();

    expect(find.text('Działki'), findsOneWidget);
    expect(find.text('061506_2.0007.138'), findsOneWidget);
    expect(find.byType(MapaDzialek), findsOneWidget);

    final zapisane = await RepozytoriumDzialek(baza).wszystkie('g1');
    expect(zapisane.single.maGranice, isTrue);
  });

  testWidgets('mapa rysuje się z bazy, bez ani jednego zapytania do usługi', (
    tester,
  ) async {
    await RepozytoriumDzialek(baza).zapisz(
      gospodarstwoId: 'g1',
      zUldk: KlientUldk.odczytaj(odpowiedzUldk, '061506_2.0007.138', 4326),
      urzadzenie: 'telefon',
    );

    var zapytania = 0;
    final uslugi = await zbudujUslugi(
      uldk: udawanaUsluga(odpowiedzUldk, onZapytanie: () => zapytania++),
    );
    await pokaz(tester, uslugi);

    expect(find.byType(MapaDzialek), findsOneWidget);
    expect(find.text('061506_2.0007.138'), findsOneWidget);
    expect(zapytania, 0);
  });

  testWidgets('nieznany numer daje jedno zdanie i podpowiedź, co zrobić', (
    tester,
  ) async {
    final uslugi = await zbudujUslugi(
      uldk: udawanaUsluga('-1 nie znaleziono dzialki'),
    );
    await pokaz(tester, uslugi);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();
    await wpiszNumer(tester, '061506_2.0007.999');
    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nie znaleziono działki'), findsOneWidget);
    expect(find.textContaining('tak jak we wniosku'), findsOneWidget);
    expect(find.byType(MapaDzialek), findsNothing);
  });

  testWidgets('działka już dodana nie zapisuje się drugi raz', (tester) async {
    await RepozytoriumDzialek(baza).zapisz(
      gospodarstwoId: 'g1',
      zUldk: KlientUldk.odczytaj(odpowiedzUldk, '061506_2.0007.138', 4326),
      urzadzenie: 'telefon',
    );

    final uslugi = await zbudujUslugi(uldk: udawanaUsluga(odpowiedzUldk));
    await pokaz(tester, uslugi);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();
    await wpiszNumer(tester, '061506_2.0007.138');
    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    expect(find.text('Ta działka jest już dodana.'), findsOneWidget);
    expect(find.text('Tak, to moja działka'), findsNothing);

    await tester.tap(find.text('Wróć do listy'));
    await tester.pumpAndSettle();

    expect(await RepozytoriumDzialek(baza).wszystkie('g1'), hasLength(1));
  });

  testWidgets('błąd sieci mówi, że dodane działki działają bez internetu', (
    tester,
  ) async {
    final uslugi = await zbudujUslugi(
      uldk: KlientUldk(
        klient: MockClient(
          (_) async => throw http.ClientException('brak sieci'),
        ),
      ),
    );
    await pokaz(tester, uslugi);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();
    await wpiszNumer(tester, '061506_2.0007.138');
    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nie udało się połączyć'), findsOneWidget);
    expect(find.textContaining('bez internetu'), findsOneWidget);
  });

  /// Usługa na „nazwa numer" oddaje listę (pierwszy wiersz to liczba
  /// wyników); granice daje dopiero zapytanie po identyfikatorze.
  KlientUldk uslugaZNazwa(String lista) => KlientUldk(
    klient: MockClient((zadanie) async {
      final request = zadanie.url.queryParameters['request'];
      final tresc = request == 'GetParcelByIdOrNr' ? lista : odpowiedzUldk;
      return http.Response.bytes(utf8.encode(tresc), 200);
    }),
  );

  Future<void> wpiszMiejscowosc(WidgetTester tester) async {
    await tester.tap(find.text('lubelskie'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Brzeziny');
    await tester.enterText(find.byType(TextField).at(1), '138');
    await tester.pumpAndSettle();
  }

  testWidgets('działkę spoza wniosku znajduje się po województwie, '
      'miejscowości i numerze', (tester) async {
    // Dzierżawy nie ma we wniosku, a pełnego numeru rolnik nie zna.
    final uslugi = await zbudujUslugi(
      uldk: uslugaZNazwa(
        '1\n061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n',
      ),
    );
    await pokaz(tester, uslugi);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();

    expect(find.text('Znajdź działkę po miejscowości'), findsOneWidget);
    // Bez nazwy i numeru przycisk śpi.
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    await wpiszMiejscowosc(tester);
    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    // Jedna taka działka w kraju — od razu mapa do potwierdzenia.
    expect(find.text('Czy to ta działka?'), findsOneWidget);
    expect(find.byType(MapaDzialek), findsOneWidget);
  });

  testWidgets('obręb o tej samej nazwie w kilku gminach daje wybór', (
    tester,
  ) async {
    final uslugi = await zbudujUslugi(
      uldk: uslugaZNazwa(
        '3\n'
        '061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n'
        '061602_2.0004.138|lubelskie|łukowski|Adamów|Brzeziny|138\n'
        '101106_2.0002.138|łódzkie|łowicki|Łowicz|Brzeziny|138\n',
      ),
    );
    await pokaz(tester, uslugi);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();
    await wpiszMiejscowosc(tester);
    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    // Województwo zawęża: z trzech w kraju zostają dwie lubelskie,
    // a program nie wybiera za rolnika.
    expect(find.text('Czy to ta działka?'), findsNothing);
    expect(find.textContaining('Jest 2 takich działek'), findsOneWidget);
    expect(find.textContaining('w kraju 3 razy'), findsOneWidget);
    expect(find.text('gmina Łowicz'), findsNothing);

    // Lista stoi pod polami — na ekranie testowym bywa poza widokiem.
    await tester.ensureVisible(find.text('gmina Lubartów'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('gmina Lubartów'));
    await tester.pumpAndSettle();

    expect(find.text('Czy to ta działka?'), findsOneWidget);
    expect(find.byType(MapaDzialek), findsOneWidget);
  });

  testWidgets('bez internetu szukanie mówi, co zrobić zamiast tego', (
    tester,
  ) async {
    final uslugi = await zbudujUslugi(
      uldk: KlientUldk(
        klient: MockClient(
          (_) async => throw http.ClientException('brak sieci'),
        ),
      ),
    );
    await pokaz(tester, uslugi);

    await tester.tap(find.text('Dodaj działkę'));
    await tester.pumpAndSettle();
    await wpiszMiejscowosc(tester);
    await tester.tap(find.text('Znajdź działkę'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Nie udało się połączyć'), findsOneWidget);
    // Droga awaryjna zostaje: pełny numer z wypisu działa bez szukania.
    expect(find.textContaining('pełny numer'), findsWidgets);
  });
}

/// Te testy nie dotykają wniosku, więc źródło pliku nigdy nie jest pytane.
class _BrakZrodlaPliku implements ZrodloPliku {
  const _BrakZrodlaPliku();

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;

  @override
  Future<WybranyPlik?> wybierzKopie() async => null;
}

/// Te testy nie dotykają dokumentów — wydruk i wyjście nie są pytane.
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
