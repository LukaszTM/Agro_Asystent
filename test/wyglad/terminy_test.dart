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
import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/terminy/przypomnienia.dart';
import 'package:agro_asystent/funkcje/terminy/ustawienia_przypomnien.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:agro_asystent/wyglad/prosty/terminy/ekran_terminy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Ekran „Terminy": kalendarz obowiązków i włącznik przypomnień.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;
  late _PrzypomnieniaDoPamieci przypomnienia;

  Future<void> dodajPole({required int ar, int sezon = 2026}) async {
    await baza.insert('dzialka_rolna', {
      'id': 'pole-$sezon-$ar',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Za stodołą',
      'sezon': sezon,
      'uprawa': 'pszenica zwyczajna ozima',
      'kod_eppo': 'TRZAW',
      'powierzchnia_ar': ar,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
  }

  Future<void> dodajOpryskZKarencja() async {
    await RepozytoriumZabiegow(baza).zapisz(
      zabieg: Zabieg(
        id: 'z1',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: DateTime.now().subtract(const Duration(days: 2)),
        powierzchniaAr: 2400,
        urzadzenie: 'telefon',
      ),
      pola: const [
        PoleZabiegu(dzialkaRolnaId: 'pole-2026-2400', powierzchniaAr: 2400),
      ],
      oprysk: const SzczegolyOprysku(
        zabiegId: 'z1',
        srodekNazwa: 'Abydos 750 EC',
        nrZezwolenia: 'R-14/2025 h.r.',
        karencjaDni: 10,
        karencjaZrodlo: 'etykieta MRiRW',
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
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    slowniki = await fabryka.openDatabase(inMemoryDatabasePath);
    await slowniki.execute(
      'CREATE TABLE uprawa (nazwa TEXT PRIMARY KEY, kod_eppo TEXT)',
    );
    przypomnienia = _PrzypomnieniaDoPamieci();
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
    reguly: reguly,
    importWniosku: ImportWniosku(baza: baza, srodki: SlownikSrodkow(slowniki)),
    zrodloPliku: const _BrakZrodlaPliku(),
    dokumenty: UslugaDokumentow(
      rejestr: RejestrZabiegow(baza),
      reguly: reguly,
      czcionki: _brakCzcionek,
      wyjscie: const _BrakWyjscia(),
    ),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: przypomnienia,
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );

  Future<void> pokaz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranTerminy(uslugi: zbudujUslugi()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bez pól widać tylko terminy, które dotyczą każdego', (
    tester,
  ) async {
    await pokaz(tester);

    // Ewidencja środków ochrony roślin obowiązuje każdego — ten termin jest
    // zawsze; warunkowość włącza się dopiero powyżej progu powierzchni.
    expect(
      find.textContaining('Ewidencja zabiegów wyłącznie elektronicznie'),
      findsOneWidget,
    );
    expect(find.textContaining('Okrywa na 80%'), findsNothing);
  });

  testWidgets('duże gospodarstwo dostaje terminy warunkowości', (tester) async {
    await dodajPole(ar: 2400);
    await pokaz(tester);

    expect(find.textContaining('Okrywa na 80% gruntów ornych'), findsOneWidget);
    expect(find.textContaining('GAEC 6'), findsWidgets);
  });

  testWidgets('małe gospodarstwo nie dostaje terminów warunkowości', (
    tester,
  ) async {
    await dodajPole(ar: 400);
    await pokaz(tester);

    expect(find.textContaining('Okrywa na 80% gruntów ornych'), findsNothing);
  });

  testWidgets('karencja po oprysku jest na liście z dniem zbioru', (
    tester,
  ) async {
    await dodajPole(ar: 2400);
    await dodajOpryskZKarencja();
    await pokaz(tester);

    expect(find.textContaining('Koniec karencji'), findsOneWidget);
    expect(find.textContaining('Nie zbieraj plonu'), findsOneWidget);
    expect(find.textContaining('Abydos 750 EC'), findsOneWidget);
  });

  testWidgets('włącznik przypomnień planuje je i zapisuje ustawienie', (
    tester,
  ) async {
    await dodajPole(ar: 2400);
    await dodajOpryskZKarencja();
    await pokaz(tester);

    expect(find.text('Telefon nie będzie przypominał.'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(przypomnienia.zaplanowane, isNotEmpty);
    expect(await UstawieniaPrzypomnien(baza).czyWlaczone(), isTrue);
    expect(find.textContaining('Telefon odezwie się rano'), findsOneWidget);
  });

  testWidgets('wyłączenie kasuje przypomnienia', (tester) async {
    await dodajPole(ar: 2400);
    // Karencja kończy się za osiem dni, więc jest co przypominać niezależnie
    // od tego, kiedy test jest uruchamiany.
    await dodajOpryskZKarencja();
    await pokaz(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(przypomnienia.zaplanowane, isNotEmpty);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(przypomnienia.zaplanowane, isEmpty);
    expect(await UstawieniaPrzypomnien(baza).czyWlaczone(), isFalse);
  });

  testWidgets('brak zgody telefonu kończy się zdaniem, co zrobić', (
    tester,
  ) async {
    przypomnienia.zgoda = false;
    await dodajPole(ar: 2400);
    await pokaz(tester);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(przypomnienia.zaplanowane, isEmpty);
    expect(
      find.textContaining('Włącz je w ustawieniach telefonu'),
      findsOneWidget,
    );
    expect(await UstawieniaPrzypomnien(baza).czyWlaczone(), isFalse);
  });
}

class _PrzypomnieniaDoPamieci implements UslugaPrzypomnien {
  bool zgoda = true;
  List<Przypomnienie> zaplanowane = [];

  @override
  Future<bool> czyWolno() async => false;

  @override
  Future<bool> popros() async => zgoda;

  @override
  Future<void> zaplanuj(List<Przypomnienie> przypomnienia) async {
    zaplanowane = przypomnienia;
  }

  @override
  Future<void> wylacz() async {
    zaplanowane = [];
  }
}

class _BrakZrodlaPliku implements ZrodloPliku {
  const _BrakZrodlaPliku();

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;
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
