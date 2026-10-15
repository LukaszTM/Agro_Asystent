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
import 'package:agro_asystent/funkcje/odczyt/czytnik_zdjecia.dart';
import 'package:agro_asystent/funkcje/odczyt/odczyt_etykiety.dart';
import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/terminy/przypomnienia.dart';
import 'package:agro_asystent/funkcje/terminy/ustawienia_przypomnien.dart';
import 'package:agro_asystent/funkcje/ustawienia/gospodarstwa.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/funkcje/zwierzeta/stado.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/wyglad/prosty/motyw.dart';
import 'package:agro_asystent/wyglad/prosty/rejestr/ekran_rejestr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Rejestr zabiegów oczami rolnika: lista wpisów, podgląd całej ewidencji,
/// poprawka i cofnięcie wpisu (krok 3 etapu 1).
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfiNoIsolate;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late Database slowniki;
  late RepozytoriumZabiegow zabiegi;

  Future<void> dodajPole({
    required String id,
    required String nazwa,
    String? kodEppo = 'TRZAW',
    String identyfikatorDzialki = '061506_2.0007.138',
  }) async {
    await baza.insert('dzialka_rolna', {
      'id': id,
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': nazwa,
      'sezon': 2026,
      'uprawa': 'pszenica zwyczajna ozima',
      'kod_eppo': kodEppo,
      'powierzchnia_ar': 250,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await baza.insert('dzialka_ewidencyjna', {
      'id': 'dz-$identyfikatorDzialki',
      'gospodarstwo_id': 'g1',
      'identyfikator': identyfikatorDzialki,
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    await baza.insert('dzialka_rolna_czesc', {
      'dzialka_rolna_id': id,
      'dzialka_ewidencyjna_id': 'dz-$identyfikatorDzialki',
      'powierzchnia_ar': 250,
    });
  }

  Future<void> dodajOprysk({
    required String id,
    required String poleId,
    String? godzina = '08:30',
    String? rodzajZastosowania = 'opryskiwanie',
  }) async {
    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: id,
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: DateTime(2026, 5, 10),
        godzina: godzina,
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: [PoleZabiegu(dzialkaRolnaId: poleId, powierzchniaAr: 250)],
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
        kodEppo: 'TRZAW',
        rodzajZastosowania: rodzajZastosowania,
        karencjaDni: 42,
        karencjaZrodlo: 'etykieta MRiRW',
      ),
      teraz: DateTime(2026, 5, 10, 8, 30),
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
    zabiegi = RepozytoriumZabiegow(baza);
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
    stado: RepozytoriumStada(baza: baza, reguly: reguly),
    gospodarstwa: RepozytoriumGospodarstw(baza: baza),
    kalendarz: KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    ),
    profil: ProfilZBazy(baza),
    przypomnienia: const _BrakPrzypomnien(),
    ustawieniaPrzypomnien: UstawieniaPrzypomnien(baza),
  );

  /// Przewija ekran do podanego miejsca — ewidencja ma dwanaście pól, więc
  /// na telefonie nie mieści się cała naraz.
  Future<void> przewinDo(WidgetTester tester, Finder czego) async {
    await tester.scrollUntilVisible(
      czego,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
  }

  Future<void> pokaz(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: MotywProsty.zbuduj(),
        home: EkranRejestr(uslugi: zbudujUslugi()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('pusty rejestr mówi, co zrobić', (tester) async {
    await pokaz(tester);
    expect(
      find.text('W rejestrze nie ma jeszcze żadnego wpisu.'),
      findsOneWidget,
    );
    expect(find.textContaining('pięć dotknięć'), findsOneWidget);
  });

  testWidgets('wpis widać na liście i w podglądzie z całą ewidencją', (
    tester,
  ) async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1');
    await pokaz(tester);

    expect(find.textContaining('10.05.2026'), findsOneWidget);
    expect(find.textContaining('Abydos 750 EC'), findsOneWidget);
    expect(find.textContaining('Każdy ma komplet danych'), findsOneWidget);

    await tester.tap(find.textContaining('10.05.2026'));
    await tester.pumpAndSettle();

    // Karencja z etykiety, policzona od daty zabiegu.
    expect(find.textContaining('21.06.2026'), findsOneWidget);

    // Pola wymagane przepisem, każde z wartością.
    expect(
      find.text('Ewidencja zabiegów środkami ochrony roślin'),
      findsOneWidget,
    );
    // Nad ewidencją stoi teraz karencja ze źródłem, więc pola przepisu
    // trzeba przewinąć.
    expect(find.textContaining('Karencja: 42 dni'), findsOneWidget);
    await przewinDo(tester, find.text('numer zezwolenia środka'));
    expect(find.text('R-14/2025 h.r.'), findsOneWidget);
    await przewinDo(tester, find.text('BBCH 29–59'));
    await przewinDo(tester, find.text('opryskiwanie'));
    await przewinDo(tester, find.text('061506_2.0007.138'));
    await przewinDo(
      tester,
      find.textContaining('Ewidencja tego wpisu jest kompletna'),
    );
  });

  testWidgets('braki w ewidencji są wymienione, a nie przemilczane', (
    tester,
  ) async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą', kodEppo: null);
    await dodajOprysk(
      id: 'z1',
      poleId: 'p1',
      godzina: null,
      rodzajZastosowania: null,
    );
    await pokaz(tester);

    expect(find.textContaining('bez pełnych danych'), findsOneWidget);

    await tester.tap(find.textContaining('10.05.2026'));
    await tester.pumpAndSettle();

    await przewinDo(tester, find.text('godzina zabiegu'));
    expect(find.text('brak — uzupełnij'), findsWidgets);
    await przewinDo(tester, find.textContaining('brakuje 3 rzeczy'));
    expect(
      find.textContaining('godzina zabiegu, kod EPPO uprawy'),
      findsOneWidget,
    );
  });

  testWidgets('szukanie po nazwie środka zawęża rejestr', (tester) async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1');
    await pokaz(tester);

    await tester.enterText(find.byType(TextField), 'Dithane');
    await tester.pumpAndSettle();
    expect(find.text('Nic nie pasuje do tego szukania.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Abydos');
    await tester.pumpAndSettle();
    expect(find.textContaining('Abydos 750 EC'), findsOneWidget);
  });

  testWidgets('poprawka dawki zmienia wpis i wraca do rejestru', (
    tester,
  ) async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1');
    await pokaz(tester);

    await tester.tap(find.textContaining('10.05.2026'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Popraw wpis'));
    await tester.tap(find.text('Popraw wpis'));
    await tester.pumpAndSettle();

    expect(find.text('08:30'), findsOneWidget);
    // Na ekranie są dwa przyciski „−": dawka i godzina. Godzina jest druga.
    expect(find.text('−'), findsNWidgets(2));
    await tester.tap(find.text('−').last);
    await tester.pumpAndSettle();
    expect(find.text('08:15'), findsOneWidget);

    await tester.tap(find.text('Zapisz poprawkę'));
    await tester.pumpAndSettle();

    final wpis = await RejestrZabiegow(baza).wpis('z1');
    expect(wpis!.zabieg.godzina, '08:15');

    // Po poprawce wracamy do podglądu wpisu — w ewidencji stoi nowa godzina.
    await tester.drag(find.byType(ListView).last, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(find.text('godzina zabiegu'), findsOneWidget);
    expect(find.text('08:15'), findsOneWidget);
  });

  testWidgets('cofnięcie wpisu pyta i usuwa go z rejestru', (tester) async {
    await dodajPole(id: 'p1', nazwa: 'Za stodołą');
    await dodajOprysk(id: 'z1', poleId: 'p1');
    await pokaz(tester);

    await tester.tap(find.textContaining('10.05.2026'));
    await tester.pumpAndSettle();
    await przewinDo(tester, find.text('Cofnij wpis'));
    await tester.tap(find.text('Cofnij wpis'));
    await tester.pumpAndSettle();

    expect(find.text('Cofnąć ten wpis?'), findsOneWidget);
    expect(find.textContaining('zostanie w dzienniku zmian'), findsOneWidget);

    await tester.tap(find.text('Cofnij wpis').last);
    await tester.pumpAndSettle();

    expect(
      find.text('W rejestrze nie ma jeszcze żadnego wpisu.'),
      findsOneWidget,
    );
    expect(await zabiegi.historia('z1'), isNotEmpty);
  });
}

class _BrakZrodlaPliku implements ZrodloPliku {
  const _BrakZrodlaPliku();

  @override
  Future<WybranyPlik?> wybierzPdf() async => null;
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
