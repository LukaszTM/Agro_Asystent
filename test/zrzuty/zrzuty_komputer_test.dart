import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
import 'package:agro_asystent/funkcje/dzialki/szukanie_dzialki.dart';
import 'package:agro_asystent/funkcje/dzialki/zrodlo_pliku.dart';
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
import 'package:flutter/services.dart' show FontLoader;
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
        stan TEXT, data_etykiety TEXT)''');
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
    wojewodztwa: SlownikWojewodztw.zTekstuJson(
      File('assets/dane/wojewodztwa.json').readAsStringSync(),
    ),
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

  /// Style przycisków w motywie nie podają nazwy kroju (na Windows bierze
  /// się czcionka systemowa). Silnik testowy wstawia wtedy font-zaślepkę
  /// z kwadratami, więc do zrzutów dopisujemy im tę samą rodzinę, co
  /// reszcie tekstu.
  ThemeData zKrojemDoZrzutow(ThemeData motyw) {
    ButtonStyle? zKrojem(ButtonStyle? styl) {
      final tekst = styl?.textStyle?.resolve(const {});
      if (styl == null || tekst == null) {
        return styl;
      }
      return styl.copyWith(
        textStyle: WidgetStatePropertyAll(tekst.copyWith(fontFamily: 'Roboto')),
      );
    }

    return motyw.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: zKrojem(motyw.filledButtonTheme.style),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: zKrojem(motyw.outlinedButtonTheme.style),
      ),
      textButtonTheme: TextButtonThemeData(
        style: zKrojem(motyw.textButtonTheme.style),
      ),
      appBarTheme: motyw.appBarTheme.copyWith(
        titleTextStyle: motyw.appBarTheme.titleTextStyle?.copyWith(
          fontFamily: 'Roboto',
        ),
      ),
    );
  }

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
        // Pasek „DEBUG" w rogu to tylko ozdoba testów — na zrzutach go nie ma.
        debugShowCheckedModeBanner: false,
        theme: zKrojemDoZrzutow(MotywKomputer.zbuduj(rozmiar)),
        home: EkranGlownyKomputer(
          uslugi: uslugi ?? zbudujUslugi(),
          teraz: teraz,
          zakladkaNaStart: zakladka,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // ---------------------------------------------------------------------
  // Zrzuty ekranu programu na komputer.
  //
  // W tym kontenerze nie ma Windowsa ani GTK, więc program nie uruchomi się
  // „naprawdę". Ten sam kod ekranów rysuje jednak silnik Fluttera w teście —
  // z prawdziwymi krojami (Roboto z SDK) i prawdziwymi ikonami — i zapisuje
  // obraz do pliku. Uruchamia się tylko na żądanie:
  //   AGRO_ZRZUTY=1 flutter test --update-goldens test/zrzuty
  // Wynik: dane/wynik/zrzuty/*.png (katalog poza repozytorium).
  // ---------------------------------------------------------------------
  final robZrzuty = Platform.environment['AGRO_ZRZUTY'] == '1';
  final katalogZrzutow = Directory('dane/wynik/zrzuty').absolute;

  /// Kroje do zrzutów: Inter z systemu (ma wagę 600, której używają
  /// przyciski; Roboto z SDK jej nie ma i przyciski wychodziłyby
  /// kwadratami) pod nazwą rodziny, której program używa domyślnie,
  /// oraz ikony Material z SDK.
  Future<void> wczytajCzcionki() async {
    const inter = '/usr/share/fonts/opentype/inter';
    final kroj = FontLoader('Roboto');
    for (final plik in [
      'Inter-Regular.otf',
      'Inter-Medium.otf',
      'Inter-SemiBold.otf',
      'Inter-Bold.otf',
      'Inter-Italic.otf',
    ]) {
      final f = File('$inter/$plik');
      if (!f.existsSync()) {
        continue;
      }
      final bajty = f.readAsBytesSync();
      kroj.addFont(Future.value(ByteData.view(bajty.buffer)));
    }
    await kroj.load();
    const sdk = '/opt/sdk/flutter/bin/cache/artifacts/material_fonts';
    final ikony = FontLoader('MaterialIcons');
    final otf = File('$sdk/MaterialIcons-Regular.otf').readAsBytesSync();
    ikony.addFont(Future.value(ByteData.view(otf.buffer)));
    await ikony.load();
  }

  /// Gospodarstwo na próbę — dane zmyślone, takie jak w instrukcji
  /// dla testerów.
  Future<void> daneNaProbe() async {
    await baza.update(
      'gospodarstwo',
      {'wlasciciel': 'Jan Przykładowy', 'powierzchnia_ur_ha': 28.5},
      where: 'id = ?',
      whereArgs: ['g1'],
    );
    for (final (nazwa, kod, ile) in [
      ('pszenica ozima', 'TRZAW', 120),
      ('kukurydza', 'ZEAMX', 90),
      ('rzepak ozimy', 'BRSNW', 80),
      ('żyto ozime', 'SECCW', 40),
    ]) {
      await slowniki.insert('uprawa', {
        'nazwa': nazwa,
        'kod_eppo': kod,
        'stan': 'kod',
        'zastosowan': ile,
        'szukanie': nazwa.replaceAll('ż', 'z'),
      });
    }
    await slowniki.insert('srodek', {
      'id': 1,
      'nazwa': 'Abydos 750 EC',
      'nr_zezwolenia': 'R-14/2025 h.r.',
      'rodzaj': 'Fungicyd',
    });
    await dodajPole(
      id: 'p1',
      nazwa: 'Za stodołą',
      uprawa: 'pszenica ozima',
      ar: 1200,
      rodzaj: RodzajUzytku.gruntyOrne,
      woda: GranicaZWoda.nie,
    );
    await dodajPole(
      id: 'p2',
      nazwa: 'Przy drodze',
      uprawa: 'kukurydza',
      ar: 850,
      rodzaj: RodzajUzytku.gruntyOrne,
    );
    await dodajPole(
      id: 'p3',
      nazwa: 'Pod lasem',
      uprawa: 'rzepak ozimy',
      ar: 560,
      rodzaj: RodzajUzytku.gruntyOrne,
      woda: GranicaZWoda.tak,
    );
    await dodajPole(
      id: 'p4',
      nazwa: 'Łąka nad rzeką',
      uprawa: 'Trawy',
      ar: 300,
      rodzaj: RodzajUzytku.tuz,
    );
    await dodajDzialkeZGranicami();
    await RepozytoriumZabiegow(baza).zapisz(
      zabieg: Zabieg(
        id: 'z1',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: DateTime(2026, 9, 20),
        godzina: '07:30',
        powierzchniaAr: 1200,
        urzadzenie: 'telefon',
      ),
      pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1200)],
      oprysk: const SzczegolyOprysku(
        zabiegId: 'z1',
        srodekNazwa: 'Abydos 750 EC',
        nrZezwolenia: 'R-14/2025 h.r.',
        dawka: 0.75,
        dawkaJednostka: 'l',
        dawkaOdniesienie: 'ha',
        przyczyna: 'mączniak prawdziwy zbóż i traw',
        agrofag: 'mączniak prawdziwy zbóż i traw',
        kodEppo: 'TRZAW',
        rodzajZastosowania: 'opryskiwanie',
        karencjaDni: 42,
        karencjaZrodlo: 'etykieta MRiRW',
      ),
    );
    await dodajZabieg(id: 'z2', rodzaj: RodzajZabiegu.siew, data: '2026-09-28');
    await dodajZabieg(
      id: 'z3',
      rodzaj: RodzajZabiegu.zbior,
      data: '2026-08-02',
    );
  }

  Future<void> zrzut(WidgetTester tester, String nazwa) async {
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(Uri.file('${katalogZrzutow.path}/$nazwa.png')),
    );
  }

  group('zrzuty ekranu programu na komputer', () {
    setUp(() async {
      if (!robZrzuty) {
        return;
      }
      katalogZrzutow.createSync(recursive: true);
      await wczytajCzcionki();
      await daneNaProbe();
    });

    for (final (zakladka, nazwa) in [
      (ZakladkaKomputer.pulpit, '01-pulpit'),
      (ZakladkaKomputer.rejestr, '03-rejestr-zabiegow'),
      (ZakladkaKomputer.terminy, '04-terminy'),
      (ZakladkaKomputer.warunkowosc, '05-warunkowosc'),
      (ZakladkaKomputer.dokumenty, '06-dokumenty'),
      (ZakladkaKomputer.magazyn, '07-magazyn'),
      (ZakladkaKomputer.ustawienia, '08-ustawienia'),
    ]) {
      testWidgets(nazwa, (tester) async {
        await pokaz(
          tester,
          uslugi: zbudujUslugi(premium: true),
          zakladka: zakladka,
        );
        await zrzut(tester, nazwa);
      }, skip: !robZrzuty);
    }

    testWidgets('02-pola z wybranym polem', (tester) async {
      await pokaz(
        tester,
        uslugi: zbudujUslugi(premium: true),
        zakladka: ZakladkaKomputer.pola,
      );
      await tester.tap(find.text('Pod lasem').first);
      await zrzut(tester, '02-pola');
    }, skip: !robZrzuty);

    testWidgets('09-dzialka po miejscowosci', (tester) async {
      await pokaz(
        tester,
        uslugi: zbudujUslugi(premium: true),
        zakladka: ZakladkaKomputer.pola,
      );
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Działka po numerze'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('lubelskie'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'Brzeziny');
      await tester.enterText(find.byType(TextField).at(1), '138');
      await zrzut(tester, '09-dzialka-po-miejscowosci');
    }, skip: !robZrzuty);

    testWidgets('10-nowe pole', (tester) async {
      await pokaz(
        tester,
        uslugi: zbudujUslugi(premium: true),
        zakladka: ZakladkaKomputer.pola,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj pole'));
      await tester.pumpAndSettle();
      await zrzut(tester, '10-nowe-pole');
    }, skip: !robZrzuty);

    testWidgets('11-pulpit duzy tekst', (tester) async {
      await pokaz(
        tester,
        uslugi: zbudujUslugi(premium: true),
        zakladka: ZakladkaKomputer.pulpit,
        rozmiar: RozmiarTekstu.bardzoDuzy,
      );
      await zrzut(tester, '11-pulpit-bardzo-duzy-tekst');
    }, skip: !robZrzuty);
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
