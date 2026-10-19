import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/app/aplikacja.dart';
import 'package:agro_asystent/app/uslugi.dart';
import 'package:agro_asystent/funkcje/biodynamika/biodynamika.dart';
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
import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';
import 'package:agro_asystent/rdzen/wspolne/mapa_dzialek.dart';
import 'package:agro_asystent/wyglad/nowoczesny/ekran_glowny.dart';
import 'package:agro_asystent/wyglad/nowoczesny/motyw.dart';
import 'package:agro_asystent/wyglad/nowoczesny/wpis/ekran_wpis.dart';
import 'package:agro_asystent/wyglad/nowoczesny/ustawienia/ekran_ustawienia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Wygląd „Nowoczesny" (plan, pkt 5): podsumowanie sezonu, dolny pasek
/// nawigacji z przyciskiem „+", mapa z filtrami upraw i wpis zabiegu na
/// jednym ekranie.
///
/// Dane, reguły i dokumenty są te same co w wyglądzie prostym — te testy
/// pilnują, żeby drugi wygląd nie zgubił żadnej funkcji ani ostrzeżenia.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  /// Stała data: wynik testów nie może zmieniać się z dnia na dzień.
  final teraz = DateTime(2026, 5, 20, 9, 30);

  late Database gospodarstwo;
  late Database slowniki;
  late Uslugi uslugi;
  late _WyjscieDoPamieci wyjscie;

  Future<Database> zbudujSlowniki() async {
    final baza = await fabryka.openDatabase(inMemoryDatabasePath);
    await baza.execute('''
      CREATE TABLE srodek (id INTEGER PRIMARY KEY, nazwa TEXT, nr_zezwolenia TEXT,
        rodzaj TEXT, substancja_czynna TEXT, producent TEXT, adres_etykiety TEXT,
        termin_do_stosowania TEXT)''');
    await baza.execute(
      '''
      CREATE TABLE zastosowanie (id INTEGER PRIMARY KEY, srodek_id INTEGER,
        agrofag TEXT, dawka_wartosc REAL, dawka_jednostka TEXT,
        dawka_odniesienie TEXT, dawka_tekst TEXT, dawka_pewnosc TEXT,
        termin_tekst TEXT, bbch_od INTEGER, bbch_do INTEGER, maloobszarowe INTEGER)''',
    );
    await baza.execute(
      'CREATE TABLE zastosowanie_uprawa (zastosowanie_id INTEGER, uprawa TEXT)',
    );
    await baza.execute(
      '''CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT,
          stan TEXT NOT NULL DEFAULT 'brak', gatunki TEXT, pytanie TEXT,
          zastosowan INTEGER NOT NULL DEFAULT 0,
          szukanie TEXT NOT NULL DEFAULT '')''',
    );
    await baza.execute('''
      CREATE TABLE karencja (srodek_nazwa TEXT, uprawa TEXT, dni INTEGER,
        stan TEXT, data_etykiety TEXT, zrodlo TEXT)''');

    await baza.insert('srodek', {
      'id': 1,
      'nazwa': 'Abydos 750 EC',
      'nr_zezwolenia': 'R-14/2025 h.r.',
      'rodzaj': 'Fungicyd',
    });
    await baza.insert('zastosowanie', {
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
    await baza.insert('zastosowanie_uprawa', {
      'zastosowanie_id': 10,
      'uprawa': 'pszenica ozima',
    });
    await baza.insert('karencja', {
      'srodek_nazwa': 'Abydos 750 EC',
      'uprawa': 'pszenica ozima',
      'dni': 42,
      'stan': 'dni',
      'data_etykiety': '2025-04-15',
      'zrodlo': 'etykieta MRiRW',
    });
    await baza.insert('uprawa', {
      'nazwa': 'pszenica ozima',
      'kod_eppo': 'TRZAW',
      'stan': 'kod',
      'zastosowan': 100,
      'szukanie': 'pszenica ozima',
    });
    // Nazwa rodzajowa: rejestr nie podaje gatunku, więc ekran musi dopytać.
    await baza.insert('uprawa', {
      'nazwa': 'łubin',
      'stan': 'rodzajowa',
      'gatunki': 'łubin żółty|łubin biały',
      'pytanie': 'Jaki łubin?',
      'zastosowan': 30,
      'szukanie': 'lubin',
    });
    await baza.insert('uprawa', {
      'nazwa': 'łubin żółty',
      'kod_eppo': 'LUPLU',
      'stan': 'kod',
      'zastosowan': 20,
      'szukanie': 'lubin zolty',
    });
    await baza.insert('uprawa', {
      'nazwa': 'łubin biały',
      'kod_eppo': 'LUPAL',
      'stan': 'kod',
      'zastosowan': 10,
      'szukanie': 'lubin bialy',
    });
    return baza;
  }

  setUp(() async {
    gospodarstwo = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    slowniki = await zbudujSlowniki();
    wyjscie = _WyjscieDoPamieci();

    final czas = teraz.toIso8601String();
    await gospodarstwo.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': czas,
      'zmieniono': czas,
      'urzadzenie': 'telefon',
    });

    uslugi = Uslugi(
      gospodarstwoId: 'g1',
      nazwaGospodarstwa: 'Gospodarstwo próbne',
      urzadzenie: 'telefon',
      pola: RepozytoriumPol(gospodarstwo),
      dzialki: RepozytoriumDzialek(gospodarstwo),
      zabiegi: RepozytoriumZabiegow(gospodarstwo),
      rejestr: RejestrZabiegow(gospodarstwo),
      srodki: SlownikSrodkow(slowniki),
      uprawy: SlownikUpraw(slowniki),
      reguly: reguly,
      importWniosku: ImportWniosku(
        baza: gospodarstwo,
        srodki: SlownikSrodkow(slowniki),
      ),
      zrodloPliku: const _BrakZrodlaPliku(),
      dokumenty: UslugaDokumentow(
        rejestr: RejestrZabiegow(gospodarstwo),
        reguly: reguly,
        czcionki: _brakCzcionek,
        wyjscie: wyjscie,
      ),
      czytnikZdjecia: const _BrakZdjec(),
      czytnikEtykiety: CzytnikEtykiety(SlownikSrodkow(slowniki)),
      nawozy: RepozytoriumNawozow(gospodarstwo),
      nawozenie: EwidencjaNawozenia(
        baza: gospodarstwo,
        zabiegi: RepozytoriumZabiegow(gospodarstwo),
        reguly: reguly,
      ),
      planNawozenia: PlanNawozenia(baza: gospodarstwo, reguly: reguly),
      terminyAzotowe: TerminyAzotowe(
        baza: gospodarstwo,
        reguly: reguly,
        gminy: SlownikGminTerminow.pusty,
      ),
      stado: RepozytoriumStada(baza: gospodarstwo, reguly: reguly),
      zwierzetaWGospodarstwie: ZwierzetaWGospodarstwie(gospodarstwo),
      wyglad: WyborWygladu(gospodarstwo),
      kopia: KopiaDanych(baza: gospodarstwo, wersjaSchematu: najnowszaWersja),
      gospodarstwa: RepozytoriumGospodarstw(baza: gospodarstwo),
      kalendarz: KalendarzTerminow(
        reguly: reguly,
        rejestr: RejestrZabiegow(gospodarstwo),
      ),
      profil: ProfilZBazy(gospodarstwo),
      przypomnienia: const _BrakPrzypomnien(),
      ustawieniaPrzypomnien: UstawieniaPrzypomnien(gospodarstwo),
      biodynamika: SlownikBiodynamiczny.zTekstuJson(
        File('assets/dane/kalendarz_biodynamiczny.json').readAsStringSync(),
      ),
    );

    await uslugi.pola.dodaj(
      pole: const Pole(
        id: 'p1',
        gospodarstwoId: 'g1',
        nazwa: 'Za stodołą',
        uprawa: 'pszenica ozima',
        kodEppo: 'TRZAW',
        powierzchniaAr: 320,
        sezon: 2026,
      ),
      urzadzenie: 'telefon',
    );
    await uslugi.pola.dodaj(
      pole: const Pole(
        id: 'p2',
        gospodarstwoId: 'g1',
        nazwa: 'Pod lasem',
        uprawa: 'kukurydza na ziarno',
        powierzchniaAr: 150,
        sezon: 2026,
      ),
      urzadzenie: 'telefon',
    );
  });

  tearDown(() async {
    await gospodarstwo.close();
    await slowniki.close();
  });

  Future<void> otworz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywNowoczesny.zbuduj(),
        home: EkranGlownyNowoczesny(uslugi: uslugi, teraz: teraz),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    await tester.scrollUntilVisible(
      czego,
      200,
      // Pierwszy Scrollable to lista ekranu; dalsze należą np. do pól
      // tekstowych.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> zakladka(WidgetTester tester, String etykieta) async {
    await tester.tap(find.text(etykieta));
    await tester.pumpAndSettle();
  }

  group('dolny pasek nawigacji', () {
    testWidgets('ma pięć zakładek i przycisk „+" w środku', (tester) async {
      await otworz(tester);

      for (final etykieta in [
        'Start',
        'Pola',
        'Terminy',
        'Dokumenty',
        'Kalendarz',
      ]) {
        expect(find.text(etykieta), findsWidgets, reason: etykieta);
      }
      final dodaj = find.bySemanticsLabel('Dodaj zabieg');
      expect(dodaj, findsOneWidget);
      // Bez szuflady i bez menu „trzy kropki" — tak samo jak w prostym.
      expect(find.byType(Drawer), findsNothing);
      expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
    });

    testWidgets('przełącza zakładki, nie zgubiwszy żadnej funkcji', (
      tester,
    ) async {
      await otworz(tester);

      await zakladka(tester, 'Pola');
      expect(find.text('Szukaj pola albo uprawy'), findsOneWidget);

      await zakladka(tester, 'Terminy');
      expect(find.text('Przypominaj o terminach'), findsOneWidget);

      await zakladka(tester, 'Dokumenty');
      expect(find.text('Rejestr'), findsOneWidget);
      // Trzy rejestry z planu (pkt 8) — także w drugim wyglądzie.
      expect(find.text('Opryski'), findsOneWidget);
      expect(find.text('Nawożenie azotem'), findsOneWidget);
      expect(find.text('Ekoschematy'), findsOneWidget);

      await zakladka(tester, 'Kalendarz');
      // Zastrzeżenie stoi na ekranie: to tradycja, nie przepis.
      expect(find.textContaining('tradycja, nie przepis'), findsOneWidget);
      expect(find.text('dobry dzień do siewu'), findsOneWidget);
      await tester.tap(find.text('Pokaż miesiąc'));
      await tester.pumpAndSettle();
      expect(find.text('maja 2026'), findsOneWidget);
    });

    testWidgets('cele dotyku mają co najmniej 44 px', (tester) async {
      await otworz(tester);

      for (final etykieta in [
        'Start',
        'Pola',
        'Terminy',
        'Dokumenty',
        'Kalendarz',
      ]) {
        final zakladka = find.ancestor(
          of: find.text(etykieta),
          matching: find.byType(InkWell),
        );
        expect(
          tester.getSize(zakladka.first).height,
          greaterThanOrEqualTo(MotywNowoczesny.minCelDotyku),
          reason: etykieta,
        );
      }
      expect(
        tester.getSize(find.bySemanticsLabel('Dodaj zabieg')).height,
        greaterThanOrEqualTo(MotywNowoczesny.minCelDotyku),
      );
    });

    testWidgets('żaden napis nie jest mniejszy niż 13 px', (tester) async {
      await otworz(tester);

      final napisy = tester.widgetList<Text>(find.byType(Text));
      expect(napisy, isNotEmpty);
      final domyslny = Theme.of(tester.element(find.byType(Scaffold).first))
          .textTheme
          .bodyMedium!
          .fontSize!;
      for (final napis in napisy) {
        expect(
          napis.style?.fontSize ?? domyslny,
          greaterThanOrEqualTo(MotywNowoczesny.minRozmiarTekstu),
          reason: napis.data ?? '',
        );
      }
    });
  });

  group('start: podsumowanie sezonu', () {
    testWidgets('pokazuje sezon, liczbę pól i powierzchnię', (tester) async {
      await otworz(tester);

      expect(find.text('Sezon 2026'), findsOneWidget);
      expect(find.text('2'), findsOneWidget, reason: 'dwa pola');
      expect(find.text('4,70 ha'), findsOneWidget, reason: '320 ar + 150 ar');
    });

    testWidgets('bez zabiegów mówi, co zrobić, zamiast pustej listy', (
      tester,
    ) async {
      await otworz(tester);

      expect(find.text('Ostatnie zabiegi'), findsOneWidget);
      expect(
        find.textContaining('Nie ma jeszcze żadnego zabiegu'),
        findsOneWidget,
      );
    });

    testWidgets('pasek azotu podaje limit ze słownika reguł', (tester) async {
      await otworz(tester);

      expect(find.text('Azot z nawozów naturalnych'), findsOneWidget);
      // Limit (170 kg/ha) jest danymi — ekran bierze go z reguł, nie z kodu.
      final limit = reguly
          .obowiazek(EwidencjaNawozenia.idObowiazku)!
          .limit(EwidencjaNawozenia.idLimitu)!;
      final razem = limit.wartosc * 4.7;
      expect(
        find.textContaining(razem.toStringAsFixed(1).replaceAll('.', ',')),
        findsOneWidget,
      );
    });
  });

  group('pola: mapa, wyszukiwarka i filtry upraw', () {
    testWidgets('filtr uprawy zawęża listę pól', (tester) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');

      expect(find.text('Za stodołą'), findsOneWidget);
      expect(find.text('Pod lasem'), findsOneWidget);

      await tester.tap(find.text('kukurydza na ziarno'));
      await tester.pumpAndSettle();

      expect(find.text('Pod lasem'), findsOneWidget);
      expect(find.text('Za stodołą'), findsNothing);
    });

    testWidgets('wyszukiwarka szuka po nazwie pola', (tester) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');

      await tester.enterText(find.byType(TextField), 'stodoł');
      await tester.pumpAndSettle();

      expect(find.text('Za stodołą'), findsOneWidget);
      expect(find.text('Pod lasem'), findsNothing);
    });

    testWidgets('bez granic działek nie udajemy mapy', (tester) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');

      expect(find.byType(MapaDzialek), findsNothing);
      expect(
        find.textContaining('Żadna działka nie ma jeszcze granic'),
        findsOneWidget,
      );
    });

    testWidgets('nowe pole dodaje się z listy upraw słownika', (tester) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');

      await przewinDo(tester, find.text('Dodaj pole'));
      await tester.tap(find.text('Dodaj pole'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Przy drodze');
      await tester.tap(find.text('Wybierz uprawę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pszenica ozima'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Zapisz pole'));
      await tester.tap(find.text('Zapisz pole'));
      await tester.pumpAndSettle();

      final pola = await uslugi.pola.wszystkie('g1');
      final dodane = pola.firstWhere((p) => p.nazwa == 'Przy drodze');
      expect(dodane.uprawa, 'pszenica ozima');
      expect(dodane.powierzchniaAr, 100);
      // Kod EPPO bierze się ze słownika upraw, nie z domysłu.
      expect(dodane.kodEppo, 'TRZAW');
    });

    testWidgets('nazwa rodzajowa prowadzi do wyboru gatunku', (tester) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');
      await przewinDo(tester, find.text('Dodaj pole'));
      await tester.tap(find.text('Dodaj pole'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wybierz uprawę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('łubin'));
      await tester.pumpAndSettle();

      // Zamiast kodu rodzaju pytamy o gatunek.
      expect(find.text('Jaki łubin?'), findsOneWidget);
      await tester.tap(find.text('łubin żółty'));
      await tester.pumpAndSettle();

      expect(find.textContaining('LUPLU'), findsOneWidget);
      await przewinDo(tester, find.text('Zapisz pole'));
      await tester.tap(find.text('Zapisz pole'));
      await tester.pumpAndSettle();

      final pola = await uslugi.pola.wszystkie('g1');
      final dodane = pola.firstWhere((p) => p.uprawa == 'łubin żółty');
      expect(dodane.kodEppo, 'LUPLU');
    });

    testWidgets('własna nazwa uprawy zapisuje się bez kodu EPPO', (
      tester,
    ) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');
      await przewinDo(tester, find.text('Dodaj pole'));
      await tester.tap(find.text('Dodaj pole'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Wybierz uprawę'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Nie ma mojej uprawy'));
      await tester.tap(find.text('Nie ma mojej uprawy'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nie podpowiemy środków'),
        findsOneWidget,
        reason: 'rolnik ma wiedzieć, co traci',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'np. gryka na nasiona'),
        'proso na ziarno',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz nazwę'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Zapisz pole'));
      await tester.tap(find.text('Zapisz pole'));
      await tester.pumpAndSettle();

      final pola = await uslugi.pola.wszystkie('g1');
      final dodane = pola.firstWhere((p) => p.uprawa == 'proso na ziarno');
      // Kodu nie wymyślamy — w ewidencji wyjdzie „brak".
      expect(dodane.kodEppo, isNull);
    });

    testWidgets('karta pola pozwala zmienić uprawę na nowy sezon', (
      tester,
    ) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');

      await tester.tap(find.text('Za stodołą'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kod EPPO: TRZAW'), findsOneWidget);

      await przewinDo(tester, find.text('Zmień uprawę'));
      await tester.tap(find.text('Zmień uprawę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('łubin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('łubin żółty'));
      await tester.pumpAndSettle();

      final pola = await uslugi.pola.wszystkie('g1');
      final pole = pola.firstWhere((p) => p.id == 'p1');
      expect(pole.uprawa, 'łubin żółty');
      expect(pole.kodEppo, 'LUPLU');
      // Poprzednia uprawa zostaje w dzienniku zmian.
      final historia = await gospodarstwo.query(
        'historia_zmian',
        where: 'tabela = ? AND wiersz_id = ?',
        whereArgs: ['dzialka_rolna', 'p1'],
      );
      expect(historia, hasLength(1));
      expect(historia.single['dane_json'], contains('pszenica ozima'));
    });

    testWidgets('karta wybranego pola prowadzi do wpisu zabiegu', (
      tester,
    ) async {
      await otworz(tester);
      await zakladka(tester, 'Pola');

      await tester.tap(find.text('Za stodołą'));
      await tester.pumpAndSettle();
      expect(find.text('Zapisz zabieg'), findsOneWidget);

      await tester.tap(find.text('Zapisz zabieg'));
      await tester.pumpAndSettle();
      expect(find.text('Nowy zabieg'), findsOneWidget);
      // Pole przyszło z karty — rolnik nie wybiera go drugi raz.
      expect(find.textContaining('Razem 3,20 ha'), findsOneWidget);
    });
  });

  group('wpis zabiegu na jednym ekranie', () {
    testWidgets('rodzaj, pole, środek i zapis bez zmiany ekranu', (
      tester,
    ) async {
      await otworz(tester);

      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();

      expect(find.text('Co robisz?'), findsOneWidget);
      expect(find.text('Na których polach?'), findsOneWidget);

      await tester.tap(find.text('Oprysk'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Abydos 750 EC'));
      await tester.tap(find.text('Abydos 750 EC'));
      await tester.pumpAndSettle();

      // Dawka i powód są podpowiedziane z rejestru — zostaje „Zapisz".
      expect(find.textContaining('0,75 l/ha'), findsWidgets);
      await przewinDo(tester, find.text('Zapisz'));
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      expect(find.text('Zabieg zapisany'), findsOneWidget);
      expect(find.textContaining('Karencja: 42 dni'), findsOneWidget);

      final zabiegi = await uslugi.zabiegi.wszystkie('g1');
      expect(zabiegi, hasLength(1));
      expect(zabiegi.single.powierzchniaAr, 320);
      final oprysk = await uslugi.zabiegi.szczegolyOprysku(zabiegi.single.id);
      expect(oprysk!.dawka, 0.75);
      expect(oprysk.karencjaDni, 42);
      expect(oprysk.kodEppo, 'TRZAW');
      expect(oprysk.przyczyna, 'mączniak prawdziwy zbóż i traw');
    });

    testWidgets('w wersji darmowej jeden wpis dotyczy jednego pola', (
      tester,
    ) async {
      await otworz(tester);
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oprysk'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pod lasem'));
      await tester.pumpAndSettle();

      // Zabieg na kilku polach naraz to dodatek płatny (plan, pkt 8):
      // wybór drugiego pola zamienia pierwsze, a ewidencja wychodzi ta
      // sama — tylko wpisów jest tyle, ile pól.
      expect(find.text('Jeden wpis dotyczy jednego pola.'), findsOneWidget);
      expect(find.textContaining('Razem 1,50 ha'), findsOneWidget);
      // Podczas wpisu zabiegu nie ma żadnej oferty premium.
      expect(find.textContaining('płatnej'), findsNothing);
    });

    testWidgets('w premium kilka pól naraz liczy powierzchnię samo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: MotywNowoczesny.zbuduj(),
          home: EkranWpisu(
            uslugi: uslugi.zDostepem(const DostepFunkcji(maPremium: true)),
            teraz: teraz,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Oprysk'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Pod lasem'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Razem 4,70 ha'), findsOneWidget);
      // Różne uprawy to osobna sprawa — mówimy o tym, zamiast wybierać
      // środek do złej uprawy.
      expect(
        find.textContaining('Wybrane pola mają różne uprawy'),
        findsOneWidget,
      );
    });

    testWidgets('bez wybranego środka zapis jest zablokowany i wiadomo czemu', (
      tester,
    ) async {
      await otworz(tester);
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Zapisz'));
      final zapisz = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(zapisz.onPressed, isNull);
      expect(find.text('Wybierz rodzaj zabiegu.'), findsOneWidget);
    });

    testWidgets('podczas wpisu nie ma żadnej oferty premium', (tester) async {
      await otworz(tester);
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oprysk'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();

      expect(find.textContaining('premium'), findsNothing);
      expect(find.textContaining('Kup'), findsNothing);
      // „Wersja płatna" to też oferta — podczas wpisu zabiegu jej nie ma.
      expect(find.textContaining('płatn'), findsNothing);
    });

    testWidgets('nawożenie bez znanego azotu nie zgaduje dawki azotu', (
      tester,
    ) async {
      await uslugi.nawozy.zapisz(
        nawoz: const Nawoz(
          id: 'n1',
          gospodarstwoId: 'g1',
          nazwa: 'Obornik bydlęcy',
          naturalny: true,
        ),
        urzadzenie: 'telefon',
      );
      await otworz(tester);
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nawożenie'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Obornik bydlęcy'));
      await tester.tap(find.text('Obornik bydlęcy'));
      await tester.pumpAndSettle();

      await przewinDo(
        tester,
        find.textContaining('Nie znamy zawartości azotu'),
      );
      expect(find.textContaining('Nie znamy zawartości azotu'), findsOneWidget);
    });

    testWidgets('obornik: przyoranie przy wpisie i poprawka z rejestru', (
      tester,
    ) async {
      await uslugi.nawozy.zapisz(
        nawoz: const Nawoz(
          id: 'n1',
          gospodarstwoId: 'g1',
          nazwa: 'Obornik bydlęcy',
          naturalny: true,
          azotProcent: 0.5,
        ),
        urzadzenie: 'telefon',
      );
      await otworz(tester);
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nawożenie'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Obornik bydlęcy'));
      await tester.tap(find.text('Obornik bydlęcy'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Przyoranie'));
      await tester.tap(find.text('Tego samego dnia'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Przyorano 20 maja 2026'), findsOneWidget);
      await przewinDo(tester, find.text('Zapisz'));
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gotowe'));
      await tester.pumpAndSettle();

      final zabiegi = await uslugi.zabiegi.wszystkie('g1');
      var wpis = await uslugi.rejestr.wpis(zabiegi.single.id);
      expect(wpis!.nawozenie?.dataPrzyorania, DateTime(2026, 5, 20));

      // Poprawka z rejestru: „nazajutrz" zamiast „tego samego dnia".
      await przewinDo(tester, find.text('Wszystkie wpisy'));
      await tester.tap(find.text('Wszystkie wpisy'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Obornik bydlęcy'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Popraw wpis'));
      await tester.tap(find.text('Popraw wpis'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Nazajutrz'));
      await tester.tap(find.text('Nazajutrz'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Zapisz poprawkę'));
      await tester.tap(find.text('Zapisz poprawkę'));
      await tester.pumpAndSettle();

      wpis = await uslugi.rejestr.wpis(zabiegi.single.id);
      expect(wpis!.nawozenie?.dataPrzyorania, DateTime(2026, 5, 21));
      final dziennik = await gospodarstwo.query(
        'historia_zmian',
        where: 'tabela = ? AND wiersz_id = ?',
        whereArgs: ['zabieg_nawozenie', zabiegi.single.id],
      );
      expect(dziennik, hasLength(1));
    });

    testWidgets('przy dawce widać maksimum z tabeli dla uprawy', (
      tester,
    ) async {
      await uslugi.nawozy.zapisz(
        nawoz: const Nawoz(
          id: 'n2',
          gospodarstwoId: 'g1',
          nazwa: 'Saletra z worka',
          naturalny: false,
          azotProcent: 34,
          zrodlo: 'worek',
        ),
        urzadzenie: 'telefon',
      );
      await otworz(tester);
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nawożenie'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Saletra z worka'));
      await tester.tap(find.text('Saletra z worka'));
      await tester.pumpAndSettle();

      // Pszenica ozima ma w tabeli 14 limit 200 kg N/ha; domyślne 100 kg
      // saletry 34% to 34 kg azotu.
      await przewinDo(tester, find.textContaining('z 200 kg azotu'));
      expect(
        find.textContaining('Za stodołą: razem 34 z 200 kg azotu na hektar.'),
        findsOneWidget,
      );
    });
  });

  /// Wpis oprysku zrobiony przez ekran — tak jak u rolnika, nie wprost
  /// w bazie.
  Future<void> zapiszOprysk(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oprysk'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Za stodołą'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Abydos 750 EC'));
    await tester.tap(find.text('Abydos 750 EC'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Zapisz'));
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gotowe'));
    await tester.pumpAndSettle();
  }

  group('rejestr wpisów', () {
    testWidgets('wpis widać na liście razem z brakami ewidencji', (
      tester,
    ) async {
      await otworz(tester);
      await zapiszOprysk(tester);

      await przewinDo(tester, find.text('Wszystkie wpisy'));
      await tester.tap(find.text('Wszystkie wpisy'));
      await tester.pumpAndSettle();

      expect(find.text('Rejestr zabiegów'), findsOneWidget);
      expect(find.textContaining('Abydos 750 EC'), findsOneWidget);
      expect(
        find.textContaining('brakuje danych wymaganych przepisem'),
        findsOneWidget,
        reason: 'działki referencyjnej nie znamy — mówimy to wprost',
      );
    });

    testWidgets('poprawka dawki zostaje w bazie i w dzienniku zmian', (
      tester,
    ) async {
      await otworz(tester);
      await zapiszOprysk(tester);

      await przewinDo(tester, find.text('Wszystkie wpisy'));
      await tester.tap(find.text('Wszystkie wpisy'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Abydos 750 EC'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Popraw wpis'));
      await tester.tap(find.text('Popraw wpis'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.bySemanticsLabel('Zmniejsz dawkę'));
      await tester.tap(find.bySemanticsLabel('Zmniejsz dawkę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zapisz poprawkę'));
      await tester.pumpAndSettle();

      final zabiegi = await uslugi.zabiegi.wszystkie('g1');
      final oprysk = await uslugi.zabiegi.szczegolyOprysku(zabiegi.single.id);
      expect(oprysk!.dawka, closeTo(0.70, 1e-9));

      // Wpisy są dopisywane, nie nadpisywane (CLAUDE.md).
      final dziennik = await gospodarstwo.query(
        'historia_zmian',
        where: 'wiersz_id = ?',
        whereArgs: [zabiegi.single.id],
      );
      expect(dziennik.length, greaterThan(1));
    });

    testWidgets('cofnięcie wpisu zostawia ślad, nie usuwa wiersza', (
      tester,
    ) async {
      await otworz(tester);
      await zapiszOprysk(tester);

      await przewinDo(tester, find.text('Wszystkie wpisy'));
      await tester.tap(find.text('Wszystkie wpisy'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Abydos 750 EC'));
      await tester.pumpAndSettle();

      await przewinDo(tester, find.text('Cofnij wpis'));
      await tester.tap(find.text('Cofnij wpis'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cofnij wpis').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('nie ma jeszcze żadnego wpisu'),
        findsOneWidget,
      );
      final wiersze = await gospodarstwo.query('zabieg');
      expect(wiersze.single['usuniety'], 1);
    });
  });

  group('dokumenty', () {
    testWidgets('eksport CSV bierze wpisy z tej samej bazy', (tester) async {
      await otworz(tester);

      // Najpierw wpis, potem eksport — tak jak u rolnika.
      await tester.tap(find.bySemanticsLabel('Dodaj zabieg'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oprysk'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Za stodołą'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Abydos 750 EC'));
      await tester.tap(find.text('Abydos 750 EC'));
      await tester.pumpAndSettle();
      await przewinDo(tester, find.text('Zapisz'));
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gotowe'));
      await tester.pumpAndSettle();

      await zakladka(tester, 'Dokumenty');
      await przewinDo(tester, find.text('CSV'));
      await tester.tap(find.text('CSV'));
      await tester.pumpAndSettle();

      expect(wyjscie.udostepnione, hasLength(1));
      final csv = utf8.decode(wyjscie.udostepnione.single.dane);
      expect(csv, contains('Abydos 750 EC'));
      expect(csv, contains('3,20 ha'), reason: 'powierzchnia z pola');
      expect(csv, contains('opryskiwanie'));
      expect(wyjscie.udostepnione.single.typMime, UslugaDokumentow.mimeCsv);
    });

    testWidgets('bez wpisów nie udajemy dokumentu', (tester) async {
      await otworz(tester);
      await zakladka(tester, 'Dokumenty');

      expect(
        find.textContaining('W tym okresie nie ma żadnego wpisu'),
        findsOneWidget,
      );
    });
  });

  group('wybór wyglądu', () {
    testWidgets('ustawienia zapisują wygląd prosty', (tester) async {
      await otworz(tester);
      await tester.tap(find.byTooltip('Ustawienia'));
      await tester.pumpAndSettle();

      expect(find.text('Wygląd'), findsOneWidget);
      await tester.tap(find.text('Prosty'));
      await tester.pumpAndSettle();

      expect(await uslugi.wyglad.odczytaj(), Wyglad.prosty);
    });

    testWidgets('ustawienia pokazują wygląd zapisany w bazie', (tester) async {
      await uslugi.wyglad.zapisz(Wyglad.nowoczesny);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: MotywNowoczesny.zbuduj(),
          home: EkranUstawienia(uslugi: uslugi),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nowoczesny'), findsOneWidget);
      expect(find.text('podsumowanie sezonu, dolny pasek'), findsOneWidget);
    });

    testWidgets('aplikacja startuje w wyglądzie zapisanym w ustawieniach', (
      tester,
    ) async {
      await uslugi.wyglad.zapisz(Wyglad.nowoczesny);
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(AplikacjaMojLan(uslugi: uslugi));
      await tester.pumpAndSettle();

      expect(find.text('Start'), findsOneWidget, reason: 'dolny pasek');
      expect(find.text('Sezon 2026'), findsOneWidget);
      // Kafelków wyglądu prostego nie ma.
      expect(find.text('Dodaj zabieg'), findsNothing);
    });

    testWidgets('domyślnie startuje wygląd prosty', (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(AplikacjaMojLan(uslugi: uslugi));
      await tester.pumpAndSettle();

      expect(find.text('Dodaj zabieg'), findsOneWidget);
      expect(find.text('Start'), findsNothing);
    });
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

/// Wydruk PDF ma osobny test; tutaj czcionki nie są potrzebne.
Future<CzcionkiWydruku> _brakCzcionek() async =>
    throw UnimplementedError('czcionki wydruku nie są tu potrzebne');

/// Pliki zostają w pamięci — test sprawdza ich treść.
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

/// Te testy nie dotykają powiadomień telefonu.
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
