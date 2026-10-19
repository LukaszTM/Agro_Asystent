import 'dart:io';

import 'package:agro_asystent/funkcje/nawozenie/ewidencja_nawozenia.dart';
import 'package:agro_asystent/funkcje/nawozenie/nawoz.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/nawozenie/plan_nawozenia.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Nawożenie (krok 6 etapu 1): ewidencja, limit azotu z nawozów naturalnych
/// i zestawienie dla planu nawożenia. Limit pochodzi ze słownika reguł.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late RepozytoriumNawozow nawozy;
  late EwidencjaNawozenia ewidencja;

  const obornik = Nawoz(
    id: 'n-obornik',
    gospodarstwoId: 'g1',
    nazwa: 'Obornik bydlęcy',
    naturalny: true,
    azotProcent: 0.5,
    zrodlo: 'analiza',
  );
  const saletra = Nawoz(
    id: 'n-saletra',
    gospodarstwoId: 'g1',
    nazwa: 'Saletra z worka',
    naturalny: false,
    azotProcent: 34,
    zrodlo: 'worek',
  );
  const gnojowica = Nawoz(
    id: 'n-gnojowica',
    gospodarstwoId: 'g1',
    nazwa: 'Gnojowica bez analizy',
    naturalny: true,
  );

  Future<void> dodajPole(String id, int ar, {int sezon = 2026}) =>
      baza.insert('dzialka_rolna', {
        'id': id,
        'gospodarstwo_id': 'g1',
        'nazwa_wlasna': 'Pole $id',
        'sezon': sezon,
        'uprawa': 'kukurydza na ziarno',
        'powierzchnia_ar': ar,
        'utworzono': '2026-03-01T08:00:00',
        'zmieniono': '2026-03-01T08:00:00',
        'urzadzenie': 'telefon',
      });

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    nawozy = RepozytoriumNawozow(baza);
    ewidencja = EwidencjaNawozenia(
      baza: baza,
      zabiegi: RepozytoriumZabiegow(baza),
      reguly: reguly,
    );
    for (final nawoz in [obornik, saletra, gnojowica]) {
      await nawozy.zapisz(nawoz: nawoz, urzadzenie: 'telefon');
    }
  });

  tearDown(() => baza.close());

  group('spis nawozów', () {
    test('nawozy wracają z zawartością i źródłem', () async {
      final spis = await nawozy.wszystkie('g1');
      expect(spis, hasLength(3));
      final zBazy = spis.firstWhere((n) => n.id == 'n-saletra');
      expect(zBazy.nazwa, 'Saletra z worka');
      expect(zBazy.azotProcent, 34);
      expect(zBazy.naturalny, isFalse);
      expect(zBazy.zrodlo, 'worek');
      expect(zBazy.skladOpis, contains('N 34%'));
    });

    test('nawóz bez zawartości azotu mówi o tym wprost', () {
      expect(gnojowica.azotZnany, isFalse);
      expect(gnojowica.skladOpis, contains('do uzupełnienia'));
      expect(
        gnojowica.azotKgNaHa(25, JednostkaDawki.metrySzescienneNaHektar),
        isNull,
      );
    });

    test('azot liczy się z dawki i jednostki', () {
      // 30 t/ha obornika o zawartości 0,5% N = 150 kg N/ha.
      expect(
        obornik.azotKgNaHa(30, JednostkaDawki.tonyNaHektar),
        closeTo(150, 0.001),
      );
      // 100 kg/ha saletry 34% = 34 kg N/ha.
      expect(
        saletra.azotKgNaHa(100, JednostkaDawki.kilogramyNaHektar),
        closeTo(34, 0.001),
      );
    });

    test('usunięty nawóz znika ze spisu, ale zostaje w bazie', () async {
      await nawozy.usun(id: 'n-saletra', urzadzenie: 'telefon');
      expect(await nawozy.wszystkie('g1'), hasLength(2));
      expect(await baza.query('nawoz'), hasLength(3));
    });
  });

  group('ewidencja nawożenia', () {
    test('wpis zapisuje zabieg, pole i szczegóły nawozu', () async {
      await dodajPole('p1', 1000);
      final id = await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: obornik,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 30,
        jednostka: JednostkaDawki.tonyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 3, 10, 9),
      );

      final wpisy = await ewidencja.wpisy('g1', sezon: 2026);
      expect(wpisy, hasLength(1));
      final wpis = wpisy.single;
      expect(wpis.zabiegId, id);
      expect(wpis.nawozNazwa, 'Obornik bydlęcy');
      expect(wpis.naturalny, isTrue);
      expect(wpis.dawka, 30);
      expect(wpis.dawkaJednostka, 't/ha');
      expect(wpis.azotKgHa, closeTo(150, 0.001));
      expect(wpis.azotKgRazem, closeTo(1500, 0.001));

      // Zabieg trafia też do wspólnego rejestru zabiegów.
      final rejestr = await RejestrZabiegow(baza).wpisy('g1');
      expect(rejestr.single.zabieg.rodzaj, RodzajZabiegu.nawozenie);
      expect(rejestr.single.pola.single.nazwa, 'Pole p1');
    });

    test(
      'data przyorania zapisuje się od razu albo dopisuje później',
      () async {
        await dodajPole('p1', 1000);
        final id = await ewidencja.zapisz(
          gospodarstwoId: 'g1',
          nawoz: obornik,
          pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
          dawka: 30,
          jednostka: JednostkaDawki.tonyNaHektar,
          urzadzenie: 'telefon',
          kiedy: DateTime(2026, 3, 10, 9),
        );
        // Bez daty: jeszcze nie przyorano — nic nie zgadujemy.
        var wpis = (await ewidencja.wpisy('g1')).single;
        expect(wpis.dataPrzyorania, isNull);

        await ewidencja.zapiszPrzyoranie(
          zabiegId: id,
          data: DateTime(2026, 3, 11),
          urzadzenie: 'telefon',
          teraz: DateTime(2026, 3, 11, 18),
        );
        wpis = (await ewidencja.wpisy('g1')).single;
        expect(wpis.dataPrzyorania, DateTime(2026, 3, 11));

        // Rejestr widzi tę samą datę, bo wydruk ewidencji bierze ją stamtąd.
        final zRejestru = await RejestrZabiegow(baza).wpis(id);
        expect(zRejestru!.nawozenie?.dataPrzyorania, DateTime(2026, 3, 11));

        // Poprawka zostawia ślad: wpisy są dopisywane, nie nadpisywane.
        await ewidencja.zapiszPrzyoranie(
          zabiegId: id,
          data: DateTime(2026, 3, 12),
          urzadzenie: 'telefon',
          teraz: DateTime(2026, 3, 12, 18),
        );
        final dziennik = await baza.query(
          'historia_zmian',
          where: 'tabela = ? AND wiersz_id = ?',
          whereArgs: ['zabieg_nawozenie', id],
        );
        expect(dziennik, hasLength(2));
        expect(dziennik.last['dane_json'], contains('2026-03-11'));

        final odRazu = await ewidencja.zapisz(
          gospodarstwoId: 'g1',
          nawoz: obornik,
          pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
          dawka: 20,
          jednostka: JednostkaDawki.tonyNaHektar,
          urzadzenie: 'telefon',
          kiedy: DateTime(2026, 4, 2, 9),
          dataPrzyorania: DateTime(2026, 4, 2, 9),
        );
        final wpisy = await ewidencja.wpisy('g1');
        expect(
          wpisy.firstWhere((w) => w.zabiegId == odRazu).dataPrzyorania,
          DateTime(2026, 4, 2),
        );
      },
    );

    test('wpisy z innego sezonu nie mieszają się', () async {
      await dodajPole('p1', 1000);
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 100,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2025, 4, 1),
      );
      expect(await ewidencja.wpisy('g1', sezon: 2026), isEmpty);
      expect(await ewidencja.wpisy('g1', sezon: 2025), hasLength(1));
    });
  });

  group('limit azotu z nawozów naturalnych', () {
    Future<StanLimituAzotu> policz({double ha = 20}) => ewidencja.limitAzotu(
      gospodarstwoId: 'g1',
      powierzchniaUrHa: ha,
      sezon: 2026,
    );

    test('limit bierze się ze słownika reguł', () async {
      final stan = await policz();
      expect(stan.limitZnany, isTrue);
      expect(stan.limitKgNaHa, 170);
      expect(stan.limitKg, closeTo(3400, 0.001));
      expect(stan.przekroczony, isFalse);
    });

    test('liczy się tylko azot z nawozów naturalnych', () async {
      await dodajPole('p1', 1000);
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: obornik,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 20,
        jednostka: JednostkaDawki.tonyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 3, 10),
      );
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 200,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 4, 10),
      );

      final stan = await policz();
      // 20 t/ha × 0,5% × 10 ha = 1000 kg N; saletra się nie liczy.
      expect(stan.azotNaturalnyKg, closeTo(1000, 0.001));
      expect(stan.azotNaHektar, closeTo(50, 0.001));
      expect(stan.pozostaloKg, closeTo(2400, 0.001));
      expect(stan.pewny, isTrue);
    });

    test('przekroczenie limitu jest widoczne', () async {
      await dodajPole('p1', 2000);
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: obornik,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 2000)],
        dawka: 40,
        jednostka: JednostkaDawki.tonyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 3, 10),
      );

      final stan = await policz();
      // 40 t/ha × 0,5% = 200 kg N/ha na 20 ha = 4000 kg przy limicie 3400 kg.
      expect(stan.azotNaturalnyKg, closeTo(4000, 0.001));
      expect(stan.przekroczony, isTrue);
      expect(stan.wykorzystanie, greaterThan(1));
      expect(stan.pozostaloKg, 0);
    });

    test('nawóz bez zawartości azotu czyni wynik niepewnym', () async {
      await dodajPole('p1', 1000);
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: gnojowica,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 25,
        jednostka: JednostkaDawki.metrySzescienneNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 3, 10),
      );

      final stan = await policz();
      expect(stan.azotNaturalnyKg, 0);
      expect(stan.wpisyBezAzotu, 1);
      expect(stan.pewny, isFalse, reason: 'nie udajemy, że limit jest pewny');
    });
  });

  group('zestawienie dla planu nawożenia', () {
    test('azot rozkłada się na pola, na których był zabieg', () async {
      await dodajPole('p1', 1000);
      await dodajPole('p2', 500);
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 100,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 4, 1),
      );

      final plan = PlanNawozenia(baza: baza, reguly: reguly);
      final zestawienie = await plan.zestawienie(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(powierzchniaUrHa: 15),
        sezon: 2026,
      );

      expect(zestawienie.pola, hasLength(2));
      final pierwsze = zestawienie.pola.firstWhere((p) => p.poleId == 'p1');
      final drugie = zestawienie.pola.firstWhere((p) => p.poleId == 'p2');
      expect(pierwsze.azotKgNaHa, closeTo(34, 0.001));
      expect(pierwsze.azotNaturalnyKgNaHa, 0);
      expect(drugie.azotKg, 0);
      expect(zestawienie.azotRazemKg, closeTo(340, 0.001));
    });

    test('plan wymagany dopiero po przekroczeniu progu ze słownika', () async {
      final plan = PlanNawozenia(baza: baza, reguly: reguly);

      final male = await plan.zestawienie(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(powierzchniaUrHa: 40),
        sezon: 2026,
      );
      expect(male.planWymagany, isFalse);

      final duze = await plan.zestawienie(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(powierzchniaUrHa: 120),
        sezon: 2026,
      );
      expect(duze.planWymagany, isTrue);
      expect(duze.kogoDotyczyPlan, contains('100 ha'));
    });
  });

  group('maksymalna dawka azotu dla uprawy (tabela 14)', () {
    const pole = Pole(
      id: 'p1',
      gospodarstwoId: 'g1',
      nazwa: 'Pole p1',
      uprawa: 'kukurydza na ziarno',
      powierzchniaAr: 1000,
    );

    setUp(() => dodajPole('p1', 1000));

    test('limit bierze się z tabeli, nie z kodu', () async {
      final plan = PlanNawozenia(baza: baza, reguly: reguly);
      final skutki = await plan.skutkiDlaMaksymalnejDawki(
        pola: const [pole],
        azotWpisuKgNaHa: 100,
        kiedy: DateTime(2026, 4, 1),
      );

      expect(skutki, hasLength(1));
      expect(skutki.single.limitKgNaHa, 240);
      expect(skutki.single.azotRazemKgNaHa, 100);
      expect(skutki.single.przekroczony, isFalse);
      expect(skutki.single.ostrzezenie, isNull);
    });

    test('azot zapisany w sezonie wchodzi do rachunku', () async {
      // 600 kg saletry 34% to 204 kg azotu na hektar.
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 600,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 4, 1),
      );

      final plan = PlanNawozenia(baza: baza, reguly: reguly);
      final skutki = await plan.skutkiDlaMaksymalnejDawki(
        pola: const [pole],
        azotWpisuKgNaHa: 50,
        kiedy: DateTime(2026, 5, 1),
      );

      final stan = skutki.single;
      expect(stan.azotWSezonieKgNaHa, closeTo(204, 0.001));
      expect(stan.azotRazemKgNaHa, closeTo(254, 0.001));
      expect(stan.przekroczony, isTrue);
      expect(stan.pozostaloKgNaHa, closeTo(36, 0.001));
      expect(stan.ostrzezenie, contains('Pole p1'));
      expect(stan.ostrzezenie, contains('240'));
      expect(stan.coZrobic, contains('36'));
    });

    test('wpis z innego sezonu nie podbija rachunku', () async {
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 600,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2025, 4, 1),
      );

      final plan = PlanNawozenia(baza: baza, reguly: reguly);
      final skutki = await plan.skutkiDlaMaksymalnejDawki(
        pola: const [pole],
        azotWpisuKgNaHa: 50,
        kiedy: DateTime(2026, 5, 1),
      );

      expect(skutki.single.azotWSezonieKgNaHa, 0);
      expect(skutki.single.przekroczony, isFalse);
    });

    test('uprawa wpisana ręcznie nie dostaje zgadywanego limitu', () async {
      const wlasna = Pole(
        id: 'p1',
        gospodarstwoId: 'g1',
        nazwa: 'Pole p1',
        uprawa: 'mieszanka z miedzy',
        powierzchniaAr: 1000,
      );
      final plan = PlanNawozenia(baza: baza, reguly: reguly);
      final skutki = await plan.skutkiDlaMaksymalnejDawki(
        pola: const [wlasna],
        azotWpisuKgNaHa: 500,
        kiedy: DateTime(2026, 4, 1),
      );

      expect(skutki.single.limitKgNaHa, isNull);
      expect(skutki.single.przekroczony, isFalse);
      expect(skutki.single.ostrzezenie, isNull);
    });

    test('zestawienie pokazuje pola ponad limitem', () async {
      await ewidencja.zapisz(
        gospodarstwoId: 'g1',
        nawoz: saletra,
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 1000)],
        dawka: 800,
        jednostka: JednostkaDawki.kilogramyNaHektar,
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 4, 1),
      );

      final plan = PlanNawozenia(baza: baza, reguly: reguly);
      final zestawienie = await plan.zestawienie(
        gospodarstwoId: 'g1',
        profil: const ProfilGospodarstwa(powierzchniaUrHa: 15),
        sezon: 2026,
      );

      final polePlanu = zestawienie.pola.single;
      expect(polePlanu.limit.kgNHa, 240);
      expect(polePlanu.azotKgNaHa, closeTo(272, 0.001));
      expect(polePlanu.limitPrzekroczony, isTrue);
      expect(zestawienie.polaPonadLimit, hasLength(1));
    });
  });
}
