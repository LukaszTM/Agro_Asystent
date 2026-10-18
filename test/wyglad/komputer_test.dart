import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/aplikacja.dart';
import 'package:agro_asystent/app/platforma.dart';
import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/dzialki/granica_z_woda.dart';
import 'package:agro_asystent/funkcje/dzialki/import_wniosku.dart';
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
      expect(
        find.textContaining('Nie wiemy, czy to grunt orny'),
        findsOneWidget,
      );

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
