import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/aplikacja.dart';
import 'package:agro_asystent/app/platforma.dart';
import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/biodynamika/biodynamika.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/dzialki/granica_z_woda.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
import 'package:agro_asystent/funkcje/ceny/ceny_skupu.dart';
import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/rodzaj_uzytku.dart';
import 'package:agro_asystent/funkcje/dzialki/slownik_upraw.dart';
import 'package:agro_asystent/funkcje/dzialki/zrodlo_pliku.dart';
import 'package:agro_asystent/funkcje/magazyn/magazyn.dart';
import 'package:agro_asystent/funkcje/nawozenie/ewidencja_nawozenia.dart';
import 'package:agro_asystent/funkcje/nawozenie/nawoz.dart';
import 'package:agro_asystent/funkcje/nawozenie/plan_nawozenia.dart';
import 'package:agro_asystent/funkcje/nawozenie/terminy_azotowe.dart';
import 'package:agro_asystent/funkcje/odczyt/czytnik_zdjecia.dart';
import 'package:agro_asystent/funkcje/pogoda/klient_pogody.dart';
import 'package:agro_asystent/funkcje/wiadomosci/klient_wiadomosci.dart';
import 'package:agro_asystent/funkcje/wiadomosci/wiadomosci.dart';
import 'package:agro_asystent/funkcje/odczyt/odczyt_etykiety.dart';
import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/terminy/przypomnienia.dart';
import 'package:agro_asystent/funkcje/terminy/ustawienia_przypomnien.dart';
import 'package:agro_asystent/funkcje/ustawienia/gospodarstwa.dart';
import 'package:agro_asystent/funkcje/ustawienia/rozmiar_tekstu.dart';
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
import 'package:agro_asystent/wyglad/komputer/ekran_glowny.dart';
import 'package:agro_asystent/wyglad/komputer/motyw.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Program na komputer (plan, pkt 5: „Program na Windows ma jeden wygląd,
/// z ustawieniem wielkości tekstu").
///
/// Te same dane, reguły i dokumenty co na telefonie — inna jest tylko
/// warstwa ekranów: stała nawigacja po lewej i tabele zamiast kafelków.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );
  final biodynamika = SlownikBiodynamiczny.zTekstuJson(
    File('assets/dane/kalendarz_biodynamiczny.json').readAsStringSync(),
  );

  /// Notowania podstawione na sztywno — plik w repozytorium jest pusty,
  /// bo cen nie wolno zmyślić.
  final cenyTestowe = SlownikCen(
    tydzienOd: DateTime(2026, 10, 6),
    tydzienDo: DateTime(2026, 10, 12),
    wersja: '2026.10.12.1',
    zrodlo: 'ZSRIR',
    zastrzezenie: 'To notowanie regionu, nie oferta konkretnego skupu.',
    produkty: const [
      ProduktCenowy(
        nazwa: 'Pszenica konsumpcyjna',
        jednostka: 'zł/t',
        ceny: [
          CenaRegionu(
            region: 'mazowieckie',
            cena: 920.5,
            status: 'potwierdzone',
          ),
        ],
      ),
    ],
  );

  /// Kanał RSS podstawiony na sztywno — test nie chodzi do sieci.
  const kanalyTestowe = SlownikKanalow(
    wersja: 'test',
    kanaly: [
      KanalWiadomosci(
        nazwa: 'Portal rolniczy',
        adres: 'https://przyklad.test/rss',
        strona: 'https://przyklad.test',
        status: 'do_weryfikacji',
      ),
    ],
  );

  const rssTestowy = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0"><channel>
  <item>
    <title>Doplaty: nowy termin</title>
    <link>https://przyklad.test/doplaty</link>
    <description>Agencja wydluzyla termin skladania wnioskow.</description>
    <pubDate>Mon, 28 Sep 2026 07:30:00 +0200</pubDate>
  </item>
</channel></rss>
''';

  /// Serwis pogodowy podstawiony na sztywno — test nie chodzi do sieci.
  String odpowiedzPogody() {
    final poczatek = DateTime.utc(2026, 10, 1, 6);
    return jsonEncode({
      'properties': {
        'timeseries': [
          for (var numer = 0; numer < 30; numer++)
            {
              'time': poczatek.add(Duration(hours: numer)).toIso8601String(),
              'data': {
                'instant': {
                  'details': {
                    'air_temperature': 9.0 + numer % 4,
                    'wind_speed': 3.0,
                  },
                },
                'next_1_hours': {
                  'details': {'precipitation_amount': 0.0},
                },
              },
            },
        ],
      },
    });
  }

  // Stały dzień: inaczej test pękałby, gdy dzisiejsza data minie termin
  // ze słownika.
  final teraz = DateTime(2026, 10, 1, 9);

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
    await slowniki.execute('''
      CREATE TABLE karencja (srodek_nazwa TEXT, uprawa TEXT, dni INTEGER,
        stan TEXT, data_etykiety TEXT, zrodlo TEXT)''');
    // Jeden środek z rejestru — do wpisu oprysku z komputera.
    await slowniki.insert('srodek', {
      'id': 1,
      'nazwa': 'Abydos 750 EC',
      'nr_zezwolenia': 'R-14/2025 h.r.',
      'rodzaj': 'Fungicyd',
    });
    await slowniki.insert('zastosowanie', {
      'id': 10,
      'srodek_id': 1,
      'agrofag': 'mączniak prawdziwy zbóż i traw',
      'dawka_wartosc': 0.75,
      'dawka_jednostka': 'l',
      'dawka_odniesienie': 'ha',
      'dawka_tekst': 'Maksymalna dawka: 0,75 l/ha',
      'dawka_pewnosc': 'odczytana',
      'bbch_od': 29,
      'bbch_do': 59,
    });
    await slowniki.insert('zastosowanie_uprawa', {
      'zastosowanie_id': 10,
      'uprawa': 'pszenica ozima',
    });
    await slowniki.insert('karencja', {
      'srodek_nazwa': 'Abydos 750 EC',
      'uprawa': 'pszenica ozima',
      'dni': 42,
      'stan': 'dni',
      'data_etykiety': '2025-04-15',
      'zrodlo': 'etykieta MRiRW',
    });
  });

  tearDown(() async {
    await baza.close();
    await slowniki.close();
  });

  Uslugi zbudujUslugi({bool premium = false}) => Uslugi(
    gospodarstwoId: 'g1',
    nazwaGospodarstwa: 'Gospodarstwo próbne',
    // Wpisy z komputera muszą być rozpoznawalne po scaleniu z telefonem.
    urzadzenie: 'komputer',
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
    dostep: DostepFunkcji(maPremium: premium),
    biodynamika: biodynamika,
    klientPogody: KlientPogody(
      klient: MockClient((_) async => http.Response(odpowiedzPogody(), 200)),
    ),
    kanalyWiadomosci: kanalyTestowe,
    cenySkupu: cenyTestowe,
    klientWiadomosci: KlientWiadomosci(
      klient: MockClient(
        (_) async => http.Response.bytes(utf8.encode(rssTestowy), 200),
      ),
    ),
  );

  /// Działka z granicami — z niej program liczy położenie gospodarstwa.
  Future<void> dodajDzialkeZGranicami() => RepozytoriumDzialek(baza).zapisz(
    gospodarstwoId: 'g1',
    zUldk: const DzialkaZUldk(
      identyfikator: '141201_2.0012.123',
      wkt:
          'POLYGON((21.0 52.0, 21.002 52.0, 21.002 52.002, '
          '21.0 52.002, 21.0 52.0))',
      srid: 4326,
      wojewodztwo: 'mazowieckie',
      gmina: 'Przykładowa',
    ),
    urzadzenie: 'komputer',
  );

  Future<void> dodajPole({
    String id = 'p1',
    String nazwa = 'Za stodołą',
    String uprawa = 'pszenica ozima',
    int ar = 1200,
    RodzajUzytku rodzaj = RodzajUzytku.nieznany,
    GranicaZWoda woda = GranicaZWoda.nieznana,
  }) async {
    await RepozytoriumPol(baza).dodaj(
      pole: Pole(
        id: id,
        gospodarstwoId: 'g1',
        nazwa: nazwa,
        uprawa: uprawa,
        powierzchniaAr: ar,
        sezon: 2026,
        rodzajUzytku: rodzaj,
      ),
      urzadzenie: 'komputer',
    );
    if (woda.znana) {
      await RepozytoriumPol(baza)
          .ustawGranicaZWoda(poleId: id, granica: woda, urzadzenie: 'komputer');
    }
  }

  Future<void> dodajZabieg({
    String id = 'z1',
    RodzajZabiegu rodzaj = RodzajZabiegu.zbior,
    String data = '2026-08-02',
    String? uwagi,
  }) => RepozytoriumZabiegow(baza).zapisz(
    zabieg: Zabieg(
      id: id,
      gospodarstwoId: 'g1',
      rodzaj: rodzaj,
      data: DateTime.parse(data),
      uwagi: uwagi,
      powierzchniaAr: 1200,
      urzadzenie: 'komputer',
    ),
    pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1200)],
  );

  /// Okno programu: szeroki monitor, na jakim stoi program na biurku.
  Future<void> pokaz(
    WidgetTester tester, {
    Uslugi? uslugi,
    ZakladkaKomputer zakladka = ZakladkaKomputer.pola,
    Size okno = const Size(1280, 800),
    RozmiarTekstu rozmiar = RozmiarTekstu.normalny,
  }) async {
    tester.view.physicalSize = okno;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywKomputer.zbuduj(rozmiar),
        home: EkranGlownyKomputer(
          uslugi: uslugi ?? zbudujUslugi(),
          teraz: teraz,
          zakladkaNaStart: zakladka,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('nawigacja programu', () {
    testWidgets('wszystkie zakładki widać naraz, bez ukrytego menu', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(tester);

      for (final zakladka in ZakladkaKomputer.values) {
        expect(find.text(zakladka.nazwa), findsWidgets, reason: zakladka.nazwa);
      }
    });

    testWidgets('kliknięcie zakładki przełącza widok', (tester) async {
      await dodajPole();
      await pokaz(tester);

      expect(find.textContaining('Pola w gospodarstwie'), findsOneWidget);

      await tester.tap(find.text('Rejestr zabiegów').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Wszystkie wpisy'), findsOneWidget);

      await tester.tap(find.text('Terminy').first);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Co trzeba zrobić i do kiedy'),
        findsOneWidget,
      );

      await tester.tap(find.text('Warunkowość').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Normy GAEC w 2026 r.'), findsOneWidget);

      await tester.tap(find.text('Ustawienia').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Ustawienia programu'), findsOneWidget);
    });

    testWidgets('na wąskim oknie zostają ikony, a program dalej działa', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(tester, okno: const Size(900, 700));

      // Nazwy zakładek schodzą z paska, ale ikony i widok zostają.
      expect(find.textContaining('Pola w gospodarstwie'), findsOneWidget);
      expect(find.byIcon(ZakladkaKomputer.rejestr.ikona), findsOneWidget);
    });
  });

  group('start programu', () {
    testWidgets('na komputerze startuje wygląd komputerowy, nie telefonowy', (
      tester,
    ) async {
      await dodajPole();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AplikacjaAgroAsystent(
          uslugi: zbudujUslugi(),
          platforma: Platforma.komputer,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rejestr zabiegów'), findsWidgets);
      // Program otwiera się na pulpicie — gospodarstwo na jednym ekranie.
      expect(find.text('Co rośnie'), findsOneWidget);
      // Kafelków wyglądu prostego ani dolnego paska nowoczesnego tu nie ma.
      expect(find.text('Dodaj zabieg'), findsNothing);
      expect(find.text('Start'), findsNothing);
    });

    testWidgets('na telefonie nic się nie zmienia', (tester) async {
      await dodajPole();
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(AplikacjaAgroAsystent(uslugi: zbudujUslugi()));
      await tester.pumpAndSettle();

      expect(find.text('Dodaj zabieg'), findsOneWidget);
      expect(find.textContaining('Pola w gospodarstwie'), findsNothing);
    });
  });

  group('pola w tabeli', () {
    testWidgets('tabela pokazuje pola i wyróżnia braki', (tester) async {
      await dodajPole();
      await dodajPole(
        id: 'p2',
        nazwa: 'Pod lasem',
        uprawa: 'kukurydza',
        ar: 350,
        rodzaj: RodzajUzytku.gruntyOrne,
        woda: GranicaZWoda.nie,
      );
      await pokaz(tester);

      expect(find.text('Za stodołą'), findsOneWidget);
      expect(find.text('Pod lasem'), findsOneWidget);
      expect(find.textContaining('2 pól, razem 15,50 ha'), findsOneWidget);
      // Pole bez rodzaju użytku i bez odpowiedzi o wodzie.
      expect(find.text('Nie wiadomo'), findsOneWidget);
      expect(find.text('nie wiadomo'), findsOneWidget);
    });

    testWidgets('rodzaj użytku i wodę ustawia się na komputerze', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(tester);

      await tester.tap(find.text('Za stodołą'));
      await tester.pumpAndSettle();
      // Ostrzeżenie stoi pod kartą pola — na niskim oknie trzeba przewinąć
      // prawy panel (ostatnia lista na ekranie).
      await tester.drag(find.byType(ListView).last, const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Nie wiemy, czy to grunt orny'),
        findsOneWidget,
      );
      await tester.drag(find.byType(ListView).last, const Offset(0, 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Grunty orne'));
      await tester.pumpAndSettle();
      expect(
        (await RepozytoriumPol(baza).jedno('p1'))!.rodzajUzytku,
        RodzajUzytku.gruntyOrne,
      );

      await tester.tap(find.text('Nie graniczy z wodą'));
      await tester.pumpAndSettle();
      expect(
        (await RepozytoriumPol(baza).jedno('p1'))!.granicaZWoda,
        GranicaZWoda.nie,
      );
      expect(find.textContaining('Nie wiemy, czy to grunt orny'), findsNothing);
    });
  });

  /// Przycisk w oknie zabiegu — pod oknem stoją filtry rejestru o tych
  /// samych napisach („Oprysk", „Nawożenie").
  Finder wOknie(String napis) => find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(OutlinedButton, napis),
  );

  group('rejestr zabiegów', () {
    testWidgets('wpisy widać w tabeli, z filtrem rodzaju', (tester) async {
      await dodajPole();
      await dodajZabieg();
      await dodajZabieg(
        id: 'z2',
        rodzaj: RodzajZabiegu.inny,
        data: '2026-05-10',
        uwagi: 'Przycinanie drzew albo żywopłotu',
      );
      await pokaz(tester, zakladka: ZakladkaKomputer.rejestr);

      expect(find.textContaining('2 wpisów'), findsOneWidget);
      expect(find.text('02.08.2026'), findsOneWidget);
      expect(find.text('Przycinanie drzew albo żywopłotu'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Zbiór'));
      await tester.pumpAndSettle();

      expect(find.text('02.08.2026'), findsOneWidget);
      expect(find.text('10.05.2026'), findsNothing);
    });

    testWidgets('oprysk dopisuje się z komputera w jednym oknie', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(tester, zakladka: ZakladkaKomputer.rejestr);
      expect(find.textContaining('przyciskiem „Dodaj zabieg"'), findsOneWidget);

      await tester.tap(find.text('Dodaj zabieg'));
      await tester.pumpAndSettle();
      expect(find.text('Nowy zabieg'), findsOneWidget);
      // Data i godzina z „teraz" — rolnik zmienia je tylko, gdy trzeba.
      expect(find.text('01.10.2026'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);

      // Zapis bez danych mówi, czego brakuje, zamiast milczeć.
      await tester.tap(find.text('Zapisz zabieg'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Wybierz, co robisz'), findsOneWidget);

      await tester.tap(wOknie('Oprysk'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Za stodołą • pszenica ozima'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Abydos 750 EC'));
      await tester.tap(find.text('Abydos 750 EC'));
      await tester.pumpAndSettle();

      // Dawka z rejestru podpowiedziana w polu tekstowym; można ją zmienić.
      final dawka = find.widgetWithText(TextField, 'Dawka');
      await tester.ensureVisible(dawka);
      expect(find.text('0,75'), findsOneWidget);
      await tester.enterText(dawka, '0,9');
      await tester.pumpAndSettle();
      expect(
        find.textContaining('przekracza dopuszczalną'),
        findsOneWidget,
        reason: 'ostrzeżenie, nie blokada — zabieg mógł się odbyć',
      );
      await tester.enterText(dawka, '0,6');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Zapisz zabieg'));
      await tester.pumpAndSettle();

      expect(find.text('Nowy zabieg'), findsNothing);
      expect(find.textContaining('1 wpisów'), findsOneWidget);
      expect(find.text('Abydos 750 EC'), findsOneWidget);
      expect(
        find.textContaining('zbiór najwcześniej 12.11.2026'),
        findsWidgets,
        reason: 'karencja 42 dni z rejestru liczy się od dnia zabiegu',
      );

      final wpis = (await RejestrZabiegow(baza).wpisy('g1')).single;
      expect(wpis.zabieg.urzadzenie, 'komputer');
      expect(wpis.zabieg.godzina, '09:00');
      expect(wpis.oprysk?.dawka, closeTo(0.6, 1e-9));
      expect(wpis.oprysk?.karencjaDni, 42);
      expect(wpis.oprysk?.rodzajZastosowania, 'opryskiwanie');
    });

    testWidgets('nawożenie obornikiem z dawką z klawiatury i przyoraniem', (
      tester,
    ) async {
      await dodajPole(uprawa: 'kukurydza na ziarno');
      await RepozytoriumNawozow(baza).zapisz(
        nawoz: const Nawoz(
          id: 'n-obornik',
          gospodarstwoId: 'g1',
          nazwa: 'Obornik bydlęcy',
          naturalny: true,
          azotProcent: 0.5,
        ),
        urzadzenie: 'komputer',
      );
      await pokaz(tester, zakladka: ZakladkaKomputer.rejestr);
      await tester.tap(find.text('Dodaj zabieg'));
      await tester.pumpAndSettle();
      await tester.tap(wOknie('Nawożenie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Za stodołą • kukurydza na ziarno'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Obornik bydlęcy'));
      await tester.tap(find.text('Obornik bydlęcy'));
      await tester.pumpAndSettle();

      final dawka = find.widgetWithText(TextField, 'Dawka');
      await tester.ensureVisible(dawka);
      await tester.tap(find.widgetWithText(OutlinedButton, 't/ha'));
      await tester.pumpAndSettle();
      await tester.enterText(dawka, '25');
      await tester.pumpAndSettle();
      // 25 t × 0,5 % = 125 kg N/ha.
      expect(find.textContaining('125,0 kg azotu'), findsOneWidget);

      await tester.ensureVisible(find.text('Nazajutrz'));
      await tester.tap(find.text('Nazajutrz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz zabieg'));
      await tester.pumpAndSettle();

      final wpis = (await RejestrZabiegow(baza).wpisy('g1')).single;
      expect(wpis.zabieg.rodzaj, RodzajZabiegu.nawozenie);
      expect(wpis.nawozenie?.dawka, 25);
      expect(wpis.nawozenie?.azotKgHa, closeTo(125, 1e-6));
      expect(wpis.nawozenie?.dataPrzyorania, DateTime(2026, 10, 2));
    });

    testWidgets('bez premium wpis dotyczy jednego pola, z premium kilku', (
      tester,
    ) async {
      await dodajPole();
      await dodajPole(id: 'p2', nazwa: 'Pod lasem', ar: 300);

      await pokaz(tester, zakladka: ZakladkaKomputer.rejestr);
      await tester.tap(find.text('Dodaj zabieg'));
      await tester.pumpAndSettle();
      expect(find.text('Na którym polu?'), findsOneWidget);
      await tester.tap(find.text('Za stodołą • pszenica ozima'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pod lasem • pszenica ozima'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Powierzchnia zabiegu: 3,00 ha'),
        findsOneWidget,
      );
      await tester.tap(find.text('Anuluj'));
      await tester.pumpAndSettle();

      await pokaz(
        tester,
        uslugi: zbudujUslugi(premium: true),
        zakladka: ZakladkaKomputer.rejestr,
      );
      await tester.tap(find.text('Dodaj zabieg'));
      await tester.pumpAndSettle();
      expect(find.text('Na których polach?'), findsOneWidget);
      await tester.tap(find.text('Za stodołą • pszenica ozima'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pod lasem • pszenica ozima'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Powierzchnia zabiegu: 15,00 ha (2 pola)'),
        findsOneWidget,
      );
    });

    testWidgets('z karty pola zabieg startuje z wybranym polem', (
      tester,
    ) async {
      await dodajPole();
      await pokaz(tester, zakladka: ZakladkaKomputer.pola);
      await tester.tap(find.text('Za stodołą'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj zabieg'));
      await tester.pumpAndSettle();

      expect(find.text('Nowy zabieg'), findsOneWidget);
      expect(
        find.textContaining('Powierzchnia zabiegu: 12,00 ha'),
        findsOneWidget,
      );
      await tester.tap(wOknie('Zbiór'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz zabieg'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Zapisano zabieg na polu'), findsOneWidget);
      final wpis = (await RejestrZabiegow(baza).wpisy('g1')).single;
      expect(wpis.zabieg.rodzaj, RodzajZabiegu.zbior);
      expect(wpis.pola.single.nazwa, 'Za stodołą');
    });

    testWidgets('szukanie zawęża listę wpisów', (tester) async {
      await dodajPole();
      await dodajZabieg(
        id: 'z2',
        rodzaj: RodzajZabiegu.inny,
        data: '2026-05-10',
        uwagi: 'Przycinanie drzew albo żywopłotu',
      );
      await pokaz(tester, zakladka: ZakladkaKomputer.rejestr);

      await tester.enterText(find.byType(TextField), 'Za stodołą');
      await tester.pumpAndSettle();
      expect(find.text('10.05.2026'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'czego tu nie ma');
      await tester.pumpAndSettle();
      expect(find.textContaining('Nic nie pasuje'), findsOneWidget);
    });
  });

  group('wielkość tekstu', () {
    test('motyw skaluje tekst, a ustawienie zapisuje się w bazie', () async {
      final normalny = MotywKomputer.zbuduj();
      final duzy = MotywKomputer.zbuduj(RozmiarTekstu.bardzoDuzy);
      expect(
        duzy.textTheme.bodyLarge!.fontSize,
        greaterThan(normalny.textTheme.bodyLarge!.fontSize!),
      );

      final wybor = WyborRozmiaruTekstu(baza);
      expect(await wybor.odczytaj(), RozmiarTekstu.normalny);
      await wybor.zapisz(RozmiarTekstu.duzy);
      expect(await wybor.odczytaj(), RozmiarTekstu.duzy);
    });

    testWidgets('wybór w ustawieniach zapisuje się i odzywa się do programu', (
      tester,
    ) async {
      RozmiarTekstu? zmieniony;
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: MotywKomputer.zbuduj(),
          home: EkranGlownyKomputer(
            uslugi: zbudujUslugi(),
            teraz: teraz,
            zakladkaNaStart: ZakladkaKomputer.ustawienia,
            onZmianaRozmiaruTekstu: (rozmiar) => zmieniony = rozmiar,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Bardzo duży'));
      await tester.pumpAndSettle();

      expect(zmieniony, RozmiarTekstu.bardzoDuzy);
      expect(
        await WyborRozmiaruTekstu(baza).odczytaj(),
        RozmiarTekstu.bardzoDuzy,
      );
    });
  });

  group('dokumenty i magazyn', () {
    testWidgets('rejestr do wydruku pokazuje kolumny z przepisu', (
      tester,
    ) async {
      await dodajPole();
      await dodajZabieg(rodzaj: RodzajZabiegu.nawozenie, data: '2026-04-02');
      await pokaz(tester, zakladka: ZakladkaKomputer.dokumenty);

      expect(find.textContaining('Rejestry do wydruku'), findsOneWidget);
      expect(find.text('Wydrukuj'), findsOneWidget);
      // Nazwa obowiązku i podstawa prawna pochodzą ze słownika reguł.
      expect(
        find.textContaining('Ewidencja zabiegów środkami ochrony roślin'),
        findsWidgets,
      );
    });

    testWidgets('magazyn bez premium mówi o tym wprost', (tester) async {
      await dodajPole();
      await pokaz(tester, zakladka: ZakladkaKomputer.magazyn);

      expect(find.textContaining('należy do wersji płatnej'), findsOneWidget);
      expect(find.textContaining('Stan na'), findsNothing);
    });

    testWidgets('w premium magazyn liczy stan z zakupów i zużycia', (
      tester,
    ) async {
      final uslugi = zbudujUslugi(premium: true);
      await dodajPole();
      await uslugi.magazyn.zapiszPozycje(
        gospodarstwoId: 'g1',
        rodzaj: RodzajPozycji.nawoz,
        nazwa: 'Saletra amonowa',
        jednostka: 'kg',
        urzadzenie: 'komputer',
        teraz: teraz,
      );
      await uslugi.magazyn.zapiszZakup(
        pozycjaId: PozycjaMagazynu.identyfikator(
          gospodarstwoId: 'g1',
          rodzaj: RodzajPozycji.nawoz,
          nazwa: 'Saletra amonowa',
        ),
        ilosc: 500,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'komputer',
        teraz: teraz,
      );

      await pokaz(tester, uslugi: uslugi, zakladka: ZakladkaKomputer.magazyn);

      expect(find.textContaining('Stan na 01.10.2026'), findsOneWidget);
      expect(find.text('Saletra amonowa'), findsOneWidget);
      expect(find.text('500,00 kg'), findsOneWidget);
    });
  });

  group('bez przycięć na monitorze', () {
    /// Przewija widok do końca; każde przycięcie układu zgłasza się
    /// w teście jako wyjątek, więc samo dojście do dołu jest sprawdzeniem.
    Future<void> przewinDoKonca(WidgetTester tester) async {
      for (var proba = 0; proba < 12; proba++) {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('każda zakładka mieści się na 1280×800 i na 1000×700', (
      tester,
    ) async {
      await dodajPole();
      await dodajZabieg();

      for (final okno in [const Size(1280, 800), const Size(1000, 700)]) {
        for (final zakladka in ZakladkaKomputer.values) {
          await pokaz(tester, zakladka: zakladka, okno: okno);
          await przewinDoKonca(tester);
        }
      }
    });

    testWidgets('bardzo duży tekst też nie rozsypuje układu', (tester) async {
      await dodajPole();
      await pokaz(tester, rozmiar: RozmiarTekstu.bardzoDuzy);
      await przewinDoKonca(tester);
      expect(find.text('Za stodołą'), findsOneWidget);
    });
  });

  group('pola na komputerze', () {
    testWidgets('nowe pole wpisuje się z klawiatury i staje w tabeli', (
      tester,
    ) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pola);

      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj pole'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Za stodołą, Przy drodze…'),
        'Pod lasem',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Zacznij pisać: pszenica, rzepak…'),
        'żyto ozime',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'np. 2,35'),
        '3,40',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Zapisz pole'));
      await tester.pumpAndSettle();

      expect(find.text('Pod lasem'), findsOneWidget);
      expect(find.text('3,40 ha'), findsOneWidget);
      expect(find.text('żyto ozime'), findsOneWidget);
    });

    testWidgets('bez powierzchni pole się nie zapisuje', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pola);

      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj pole'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Za stodołą, Przy drodze…'),
        'Pod lasem',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Zapisz pole'));
      await tester.pumpAndSettle();

      expect(
        find.text('Wpisz powierzchnię w hektarach, na przykład 2,35.'),
        findsOneWidget,
      );
    });

    testWidgets('działkę po numerze dodaje się bez premium', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pola);

      // Dodawanie działek po numerze jest wymagane przepisami, więc nigdy
      // nie chowa się za opłatą (plan, pkt 8).
      expect(
        find.widgetWithText(OutlinedButton, 'Działka po numerze'),
        findsOneWidget,
      );
    });

    testWidgets('działkę spoza wniosku szuka się po miejscowości', (
      tester,
    ) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pola);

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Działka po numerze'),
      );
      await tester.pumpAndSettle();

      // Okno otwiera się na szukaniu po miejscowości — dla dzierżaw,
      // których nie ma we wniosku.
      expect(find.text('Po miejscowości'), findsOneWidget);
      expect(find.text('Miejscowość (obręb)'), findsOneWidget);
      expect(find.text('Numer działki'), findsOneWidget);

      // Druga droga zostaje dla tych, którzy mają pełny numer pod ręką.
      await tester.tap(find.text('Wpisz pełny numer'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, 'np. 141201_2.0012.123/4'),
        findsOneWidget,
      );
    });

    testWidgets('bez premium nie ma przycisku wniosku, ale jest wyjaśnienie', (
      tester,
    ) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pola);

      expect(
        find.widgetWithText(OutlinedButton, 'Wczytaj wniosek z PDF'),
        findsNothing,
      );
      expect(find.textContaining('po numerze ewidencyjnym'), findsOneWidget);
    });

    testWidgets('z premium wniosek wczytuje się na komputerze', (tester) async {
      await pokaz(
        tester,
        uslugi: zbudujUslugi(premium: true),
        zakladka: ZakladkaKomputer.pola,
      );

      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Wczytaj wniosek z PDF'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wniosek z PDF'), findsOneWidget);
      expect(find.textContaining('nic nie wychodzi do sieci'), findsOneWidget);
    });
  });

  group('profil gospodarstwa', () {
    testWidgets('dane gospodarstwa poprawia się na komputerze', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.ustawienia);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Popraw dane gospodarstwa'),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tak, jak ma stać na wydruku'),
        'Gospodarstwo Kowalski',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'imię i nazwisko posiadacza gruntów'),
        'Jan Kowalski',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'np. 18,40'),
        '18,40',
      );
      // Okno urosło o pole właściciela — przycisk bywa pod spodem.
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Nie mam zwierząt'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Nie mam zwierząt'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Zapisz dane'));
      await tester.pumpAndSettle();

      expect(find.text('Gospodarstwo Kowalski'), findsWidgets);
      expect(find.textContaining('18,40 ha'), findsOneWidget);
      expect(find.textContaining('zwierzęta: nie ma'), findsOneWidget);
      expect(find.textContaining('Właściciel: Jan Kowalski'), findsOneWidget);
    });

    testWidgets('bez nazwy gospodarstwo się nie zapisze', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.ustawienia);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Popraw dane gospodarstwa'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tak, jak ma stać na wydruku'),
        '   ',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Zapisz dane'));
      await tester.pumpAndSettle();

      expect(
        find.text('Wpisz nazwę gospodarstwa — stoi na wydrukach.'),
        findsOneWidget,
      );
    });

    testWidgets('bez premium nie ma przycisku drugiego gospodarstwa', (
      tester,
    ) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.ustawienia);

      expect(
        find.widgetWithText(OutlinedButton, 'Dodaj gospodarstwo'),
        findsNothing,
      );
    });
  });

  group('pulpit', () {
    testWidgets('program otwiera się na pulpicie', (tester) async {
      await dodajPole();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: MotywKomputer.zbuduj(),
          home: EkranGlownyKomputer(uslugi: zbudujUslugi(), teraz: teraz),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Co rośnie'), findsOneWidget);
      expect(find.text('Gdzie to leży'), findsOneWidget);
      expect(find.text('Co mnie goni'), findsOneWidget);
    });

    testWidgets('wykres pokazuje uprawy, hektary i udziały', (tester) async {
      await dodajPole(uprawa: 'pszenica ozima', ar: 1200);
      await dodajPole(
        id: 'p2',
        nazwa: 'Przy drodze',
        uprawa: 'kukurydza',
        ar: 800,
      );
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);

      expect(find.text('pszenica ozima'), findsOneWidget);
      expect(find.text('kukurydza'), findsOneWidget);
      expect(find.text('12,00 ha • 60 %'), findsOneWidget);
      expect(find.text('8,00 ha • 40 %'), findsOneWidget);
      // Liczba w środku pierścienia: cała powierzchnia gospodarstwa.
      expect(find.text('20,00 ha'), findsOneWidget);
    });

    testWidgets('pole bez uprawy liczy się osobno, a nie jako uprawa', (
      tester,
    ) async {
      await dodajPole(uprawa: 'owies', ar: 100);
      await dodajPole(id: 'p2', nazwa: 'Nowe', uprawa: '', ar: 400);
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);

      expect(find.text('Bez wpisanej uprawy'), findsOneWidget);
      expect(
        find.textContaining('czeka'),
        findsWidgets,
        reason: 'pulpit ma powiedzieć, że brakuje uprawy',
      );
    });

    testWidgets('bez pól pulpit mówi, od czego zacząć', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);

      expect(
        find.text('Nie wiem jeszcze, co rośnie w gospodarstwie.'),
        findsOneWidget,
      );
      expect(
        find.text('Nie ma jeszcze żadnej działki z granicami.'),
        findsOneWidget,
      );
    });

    testWidgets('kalendarz biodynamiczny stoi z zastrzeżeniem i rozwija się '
        'na miesiąc', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);
      await tester.scrollUntilVisible(
        find.text('Kalendarz biodynamiczny'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Kalendarz biodynamiczny'), findsOneWidget);
      // Zastrzeżenie stoi na ekranie, nie w drobnym druku: to tradycja,
      // a terminy biorą się z przepisów.
      expect(find.textContaining('tradycja, nie przepis'), findsOneWidget);
      expect(find.textContaining('dzień'), findsWidgets);

      await tester.tap(find.text('Pokaż miesiąc'));
      await tester.pumpAndSettle();

      expect(find.text('Pokaż tydzień'), findsOneWidget);
      expect(find.text('października 2026'), findsOneWidget);
    });

    testWidgets('bez działek pogoda mówi, czego jej brakuje', (tester) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);
      await tester.scrollUntilVisible(
        find.text('Pogoda'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Nie wiem, gdzie leży gospodarstwo.'), findsOneWidget);
    });

    testWidgets('z działką pogoda pokazuje godziny, dni i źródło', (
      tester,
    ) async {
      await dodajPole();
      await dodajDzialkeZGranicami();
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);
      await tester.scrollUntilVisible(
        find.text('Pogoda'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Źródło: MET Norway'), findsOneWidget);
      expect(find.textContaining('wiatr do 3 m/s'), findsWidgets);
      // Dopuszczalnej prędkości wiatru przy oprysku program nie wymyśla —
      // odsyła do etykiety.
      expect(find.textContaining('etykiecie środka'), findsOneWidget);
    });

    testWidgets('wiadomości pokazują nagłówek, źródło i odsyłają do wydawcy', (
      tester,
    ) async {
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);
      await tester.scrollUntilVisible(
        find.text('Wiadomości z branży'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Doplaty: nowy termin'), findsOneWidget);
      expect(find.textContaining('Portal rolniczy'), findsWidgets);
      // Program nie pokazuje cudzej treści u siebie.
      expect(find.textContaining('otwiera się u wydawcy'), findsOneWidget);
    });

    testWidgets('ceny skupu pokazują tydzień notowań i region', (tester) async {
      await dodajDzialkeZGranicami();
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);
      await tester.scrollUntilVisible(
        find.text('Ceny skupu'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Pszenica konsumpcyjna'), findsOneWidget);
      expect(find.text('920,50 zł/t'), findsOneWidget);
      expect(find.textContaining('Notowania z tygodnia'), findsOneWidget);
      // Program nie udaje, że to oferta skupu za miedzą.
      expect(find.textContaining('nie oferta'), findsOneWidget);
    });

    testWidgets('z pulpitu przechodzi się do pełnych terminów', (tester) async {
      await dodajPole();
      await pokaz(tester, zakladka: ZakladkaKomputer.pulpit);

      await tester.ensureVisible(find.text('Zobacz wszystkie terminy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zobacz wszystkie terminy'));
      await tester.pumpAndSettle();

      expect(find.text('Co trzeba zrobić i do kiedy'), findsOneWidget);
    });
  });
}

/// Program na komputer nie pyta tu o pliki — kopię sprawdza test kopii.
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
