import 'dart:convert';

import 'dart:io';

import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zwierzeta/stado.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Zwierzęta (krok 9 etapu 1): rejestr stada, DJP i terminy zgłoszeń.
/// Współczynniki DJP są danymi ze słownika reguł, nie stałymi w kodzie.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late RepozytoriumStada stado;

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-01-01T08:00:00',
      'zmieniono': '2026-01-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    stado = RepozytoriumStada(baza: baza, reguly: reguly);
  });

  tearDown(() => baza.close());

  Future<String> obora() => stado.dodajStado(
    gospodarstwoId: 'g1',
    nazwa: 'Obora',
    gatunek: 'bydło',
    urzadzenie: 'telefon',
    teraz: DateTime(2026, 1, 2),
  );

  Future<String> dodajKrowe(
    String stadoId, {
    required String numer,
    String grupa = 'bydlo_krowa',
    DateTime? kiedy,
  }) => stado.dodajZwierze(
    stadoId: stadoId,
    zdarzenie: RodzajZdarzenia.kupno,
    urzadzenie: 'telefon',
    numer: numer,
    grupaDjp: grupa,
    dataZdarzenia: kiedy ?? DateTime(2026, 2, 1),
    teraz: kiedy ?? DateTime(2026, 2, 1),
  );

  group('słownik współczynników', () {
    test('ma współczynniki z rozporządzenia i podaje źródło', () {
      final wspolczynniki = reguly.wspolczynnikiDjp;
      expect(wspolczynniki.grupy, isNotEmpty);
      expect(wspolczynniki.gatunki, contains('bydło'));
      expect(wspolczynniki.grupa('bydlo_krowa')?.wspolczynnik, 1.0);
      expect(wspolczynniki.grupa('bydlo_ciele')?.wspolczynnik, 0.15);
      expect(
        wspolczynniki.doWeryfikacji,
        isFalse,
        reason: 'tabela 3 z programu azotanowego została sprawdzona',
      );
      expect(wspolczynniki.zrodlo, contains('Dz.U. 2023 poz. 244'));
    });

    test('nazwy grup są przepisane z rozporządzenia', () {
      final wspolczynniki = reguly.wspolczynnikiDjp;
      expect(wspolczynniki.grupa('bydlo_krowa')?.nazwa, 'Krowy');
      expect(
        wspolczynniki.grupa('swinie_tucznik')?.nazwa,
        'Tuczniki, loszki i knurki hodowlane',
      );
      expect(
        wspolczynniki.grupa('swinie_prosie')?.wspolczynnik,
        0.01,
        reason: 'program z 2023 r. zmienił prosięta z 0,02 na 0,01',
      );
      expect(
        wspolczynniki.grupa('swinie_warchlak')?.wspolczynnik,
        0.04,
        reason: 'program z 2023 r. zmienił warchlaki z 0,07 na 0,04',
      );
      expect(
        wspolczynniki.grupa('inne_zwierzeta_500_kg')?.wspolczynnik,
        1.0,
        reason: 'wiersz „inne zwierzęta o łącznej masie 500 kg"',
      );
    });

    test('lamy i alpaki nie są pomylone mimo tych samych nazw grup', () {
      // W rozporządzeniu stoją w dwóch kolumnach obok siebie i mają
      // identyczne nazwy grup — łatwo je pomylić przy przepisywaniu.
      final wspolczynniki = reguly.wspolczynnikiDjp;
      expect(
        wspolczynniki.grupa('lamy_samice_powyzej_1_roku')?.wspolczynnik,
        0.2,
      );
      expect(
        wspolczynniki.grupa('lamy_samce_powyzej_1_roku')?.wspolczynnik,
        0.19,
      );
      expect(
        wspolczynniki.grupa('alpaki_samice_powyzej_1_roku')?.wspolczynnik,
        0.11,
      );
      expect(
        wspolczynniki.grupa('alpaki_samce_powyzej_1_roku')?.wspolczynnik,
        0.12,
      );
      expect(wspolczynniki.gatunki, containsAll(['lamy', 'alpaki']));
    });

    test('niesprawdzony słownik nadal każe potwierdzić wynik u doradcy', () {
      // Gdy kiedyś dojdą nowe grupy, a status wróci do „do_weryfikacji",
      // aplikacja musi znowu oznaczać DJP jako niepewne.
      final niesprawdzony = SlownikRegul.zTekstuJson(
        jsonEncode({
          'wersja': '2026.10.15',
          'obowiazuje_od': '2026-10-15',
          'obowiazki': const [],
          'wspolczynniki_djp': {
            'status_weryfikacji': 'do_weryfikacji',
            'zrodlo': 'projekt zmiany rozporządzenia',
            'grupy': [
              {
                'id': 'bydlo_krowa',
                'gatunek': 'bydło',
                'nazwa': 'Krowy',
                'wspolczynnik': 1.1,
              },
            ],
          },
        }),
      );
      expect(niesprawdzony.wspolczynnikiDjp.doWeryfikacji, isTrue);
    });
  });

  group('rejestr stada', () {
    test('zwierzę wchodzi do stada razem ze zdarzeniem', () async {
      final id = await obora();
      await dodajKrowe(id, numer: 'PL001');

      final zwierzeta = await stado.zwierzeta(id);
      expect(zwierzeta.single.numer, 'PL001');
      expect(zwierzeta.single.grupaDjp, 'bydlo_krowa');
      expect(zwierzeta.single.wspolczynnikDjp, 1.0);

      final zdarzenia = await stado.zdarzenia('g1');
      expect(zdarzenia.single.rodzaj, RodzajZdarzenia.kupno);
      expect(zdarzenia.single.numerZwierzecia, 'PL001');
      expect(zdarzenia.single.zgloszone, isFalse);
    });

    test('sprzedane zwierzę wypada ze stanu stada', () async {
      final id = await obora();
      final krowa = await dodajKrowe(id, numer: 'PL001');
      await dodajKrowe(id, numer: 'PL002', kiedy: DateTime(2026, 2, 2));

      expect(await stado.wStadzie('g1'), hasLength(2));

      await stado.dodajZdarzenie(
        zwierzeId: krowa,
        rodzaj: RodzajZdarzenia.sprzedaz,
        data: DateTime(2026, 6, 1),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 6, 1),
      );

      final wStadzie = await stado.wStadzie('g1');
      expect(wStadzie, hasLength(1));
      expect(wStadzie.single.numer, 'PL002');
    });
  });

  group('DJP', () {
    test('liczy się ze współczynników przypisanych zwierzętom', () async {
      final id = await obora();
      await dodajKrowe(id, numer: 'PL001');
      await dodajKrowe(id, numer: 'PL002', kiedy: DateTime(2026, 2, 2));
      await dodajKrowe(
        id,
        numer: 'PL003',
        grupa: 'bydlo_ciele',
        kiedy: DateTime(2026, 2, 3),
      );

      final stan = await stado.djp('g1');
      expect(stan.sztuk, 3);
      expect(stan.djp, closeTo(2.15, 0.001));
      expect(stan.bezWspolczynnika, 0);
      expect(
        stan.pewny,
        isTrue,
        reason: 'współczynniki są z rozporządzenia, a każde zwierzę ma grupę',
      );
      expect(stan.doWeryfikacji, isFalse);
    });

    test('zwierzę bez grupy nie psuje wyniku po cichu', () async {
      final id = await obora();
      await dodajKrowe(id, numer: 'PL001');
      await stado.dodajZwierze(
        stadoId: id,
        zdarzenie: RodzajZdarzenia.kupno,
        urzadzenie: 'telefon',
        numer: 'PL999',
        teraz: DateTime(2026, 2, 5),
      );

      final stan = await stado.djp('g1');
      expect(stan.djp, closeTo(1.0, 0.001));
      expect(stan.bezWspolczynnika, 1);
      expect(stan.pewny, isFalse);
    });

    test('DJP wchodzi do profilu gospodarstwa i włącza obowiązki', () async {
      final id = await obora();
      for (var i = 0; i < 12; i++) {
        await dodajKrowe(
          id,
          numer: 'PL$i',
          kiedy: DateTime(2026, 2, 1).add(Duration(days: i)),
        );
      }

      final profil = await ProfilZBazy(baza, stado: stado).policz('g1');
      expect(profil.djp, closeTo(12, 0.001));
      expect(profil.posiadaczZwierzat, isTrue);

      // Program azotanowy włącza się od 10 DJP — próg jest w słowniku.
      final obowiazek = reguly.obowiazek('program_azotanowy_ewidencja')!;
      expect(obowiazek.ocena(profil), Ocena.dotyczy);
    });
  });

  group('terminy zgłoszeń', () {
    test('urodzenie daje termin zgłoszenia liczony ze słownika', () async {
      final id = await obora();
      await stado.dodajZwierze(
        stadoId: id,
        zdarzenie: RodzajZdarzenia.urodzenie,
        urzadzenie: 'telefon',
        numer: 'PL100',
        grupaDjp: 'bydlo_ciele',
        dataUrodzenia: DateTime(2026, 5, 10),
        teraz: DateTime(2026, 5, 10),
      );

      final kalendarz = KalendarzTerminow(
        reguly: reguly,
        rejestr: RejestrZabiegow(baza),
        stado: stado,
      );
      final pozycje = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(
          powierzchniaUrHa: 24,
          posiadaczZwierzat: true,
        ),
        teraz: DateTime(2026, 5, 12),
      );

      final zgloszenie = pozycje.firstWhere(
        (p) => p.zrodlo == ZrodloTerminu.zwierzeta,
      );
      expect(zgloszenie.data, DateTime(2026, 5, 17));
      expect(zgloszenie.nazwa, contains('PL100'));
      expect(zgloszenie.coZrobic, contains('IRZplus'));
      expect(zgloszenie.dniDo(DateTime(2026, 5, 12)), 5);
    });

    test('zgłoszone zdarzenie znika z kalendarza', () async {
      final id = await obora();
      await stado.dodajZwierze(
        stadoId: id,
        zdarzenie: RodzajZdarzenia.urodzenie,
        urzadzenie: 'telefon',
        numer: 'PL100',
        dataUrodzenia: DateTime(2026, 5, 10),
        teraz: DateTime(2026, 5, 10),
      );
      final zdarzenie = (await stado.zdarzenia('g1')).single;
      await stado.oznaczZgloszone(
        zdarzenieId: zdarzenie.id,
        kiedy: DateTime(2026, 5, 11),
        urzadzenie: 'telefon',
      );

      final kalendarz = KalendarzTerminow(
        reguly: reguly,
        rejestr: RejestrZabiegow(baza),
        stado: stado,
      );
      final pozycje = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(
          powierzchniaUrHa: 24,
          posiadaczZwierzat: true,
        ),
        teraz: DateTime(2026, 5, 12),
      );
      expect(
        pozycje.where((p) => p.zrodlo == ZrodloTerminu.zwierzeta),
        isEmpty,
      );
    });

    test('bez zwierząt termin zgłoszenia się nie pojawia', () async {
      final kalendarz = KalendarzTerminow(
        reguly: reguly,
        rejestr: RejestrZabiegow(baza),
        stado: stado,
      );
      final pozycje = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(powierzchniaUrHa: 24),
        teraz: DateTime(2026, 5, 12),
      );
      expect(
        pozycje.where((p) => p.zrodlo == ZrodloTerminu.zwierzeta),
        isEmpty,
      );
    });
  });
}
