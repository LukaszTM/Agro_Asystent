import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/rodzaj_uzytku.dart';
import 'package:agro_asystent/funkcje/dzialki/uprawy_pola.dart';
import 'package:agro_asystent/funkcje/warunkowosc/okrywa.dart';
import 'package:agro_asystent/funkcje/warunkowosc/okrywa_pola.dart';
import 'package:agro_asystent/funkcje/warunkowosc/zmianowanie.dart'
    show StanWarunku;
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Norma GAEC 6: okrywa ochronna gleby — etap 2, krok 4.
///
/// Progi pochodzą ze słownika reguł (Dz.U. z 2025 r. poz. 1674): okrywa na
/// co najmniej 80 % gruntów ornych od zbioru do 15 października, przerwa do
/// 4 tygodni na siew ozimin. Testy pilnują też tego, czego aplikacja robić
/// nie może: zgadywać formy okrywy i uznawać normę za spełnioną, gdy
/// rolnik jeszcze nic nie powiedział.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-okrywa');
    addTearDown(() => katalog.deleteSync(recursive: true));
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: '${katalog.path}/gospodarstwo.db',
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
  });

  tearDown(() => baza.close());

  Future<Pole> pole({
    required String id,
    required double ha,
    String uprawa = 'pszenica ozima',
    RodzajUzytku rodzaj = RodzajUzytku.gruntyOrne,
    int sezon = 2026,
  }) async {
    final nowe = Pole(
      id: id,
      gospodarstwoId: 'g1',
      nazwa: 'Pole $id',
      uprawa: uprawa,
      powierzchniaAr: (ha * 100).round(),
      sezon: sezon,
      rodzajUzytku: rodzaj,
    );
    await RepozytoriumPol(baza).dodaj(pole: nowe, urzadzenie: 'telefon');
    return nowe;
  }

  Future<void> zadeklaruj({
    required String poleId,
    required String forma,
    int sezon = 2026,
    int? przerwaDni,
  }) => RepozytoriumOkrywyPola(baza).zapisz(
    poleId: poleId,
    sezon: sezon,
    forma: forma,
    przerwaDni: przerwaDni,
    urzadzenie: 'telefon',
  );

  Future<void> zabieg({
    required String poleId,
    required RodzajZabiegu rodzaj,
    required String data,
    String? uwagi,
  }) => RepozytoriumZabiegow(baza).zapisz(
    zabieg: Zabieg(
      id: 'z-$poleId-$data-${rodzaj.wBazie}',
      gospodarstwoId: 'g1',
      rodzaj: rodzaj,
      data: DateTime.parse(data),
      uwagi: uwagi,
      urzadzenie: 'telefon',
    ),
    pola: [PoleZabiegu(dzialkaRolnaId: poleId, powierzchniaAr: 1000)],
  );

  Okrywa silnik() => Okrywa(
    pola: RepozytoriumPol(baza),
    okrywy: RepozytoriumOkrywyPola(baza),
    uprawy: RepozytoriumUprawPola(baza),
    reguly: reguly,
  );

  Future<OcenaOkrywy> ocen({int sezon = 2026}) =>
      silnik().ocen(gospodarstwoId: 'g1', sezon: sezon);

  group('próg i termin pochodzą ze słownika', () {
    test('wymagany udział to 80 % z przepisu, nie liczba z kodu', () async {
      await pole(id: 'p1', ha: 10);
      final ocena = await ocen();
      expect(ocena.wymaganyUdzial, 80);
      expect(ocena.limitPrzerwyDni, 28);
    });

    test('termin to 15 października ocenianego sezonu', () async {
      await pole(id: 'p1', ha: 10);
      final ocena = await ocen(sezon: 2027);
      expect(ocena.terminDo, DateTime(2027, 10, 15));
    });

    test('bez gruntów ornych norma nie dotyczy', () async {
      await pole(id: 'laka', ha: 12, rodzaj: RodzajUzytku.tuz);
      final ocena = await ocen();
      expect(ocena.powierzchniaGruntowOrnychHa, 0);
      expect(ocena.stan, StanWarunku.nieDotyczy);
    });
  });

  group('udział okrywy', () {
    test('wszystkie pola z okrywą — norma spełniona', () async {
      await pole(id: 'p1', ha: 6);
      await pole(id: 'p2', ha: 4);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');
      await zadeklaruj(poleId: 'p2', forma: 'miedzyplon');

      final ocena = await ocen();
      expect(ocena.udzialOkrywy, closeTo(100, 0.001));
      expect(ocena.stan, StanWarunku.spelniony);
      expect(ocena.brakujeHa, 0);
    });

    test('gleba odkryta na 30 % — norma niespełniona', () async {
      await pole(id: 'p1', ha: 7);
      await pole(id: 'p2', ha: 3);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');
      await zadeklaruj(poleId: 'p2', forma: 'brak');

      final ocena = await ocen();
      expect(ocena.udzialOkrywy, closeTo(70, 0.001));
      expect(ocena.stan, StanWarunku.niespelniony);
      expect(ocena.polaBezOkrywy.single.pole.id, 'p2');
      expect(ocena.brakujeHa, closeTo(1, 0.001));
    });

    test('dokładnie 80 % wystarczy', () async {
      await pole(id: 'p1', ha: 8);
      await pole(id: 'p2', ha: 2);
      await zadeklaruj(poleId: 'p1', forma: 'sciernisko');
      await zadeklaruj(poleId: 'p2', forma: 'brak');

      final ocena = await ocen();
      expect(ocena.udzialOkrywy, closeTo(80, 0.001));
      expect(ocena.stan, StanWarunku.spelniony);
    });

    test('łąki i sady nie wchodzą do rachunku', () async {
      await pole(id: 'orne', ha: 5);
      await pole(id: 'laka', ha: 20, rodzaj: RodzajUzytku.tuz);
      await zadeklaruj(poleId: 'orne', forma: 'uprawa_ozima');

      final ocena = await ocen();
      expect(ocena.powierzchniaGruntowOrnychHa, closeTo(5, 0.001));
      expect(ocena.powierzchniaUrHa, closeTo(25, 0.001));
      expect(ocena.stan, StanWarunku.spelniony);
    });
  });

  group('brak deklaracji to „do sprawdzenia", nie „spełniona"', () {
    test('pole bez deklaracji wstrzymuje wynik', () async {
      await pole(id: 'p1', ha: 5);
      await pole(id: 'p2', ha: 5);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');

      final ocena = await ocen();
      expect(ocena.udzialOkrywy, closeTo(50, 0.001));
      expect(ocena.udzialMozliwy, closeTo(100, 0.001));
      expect(ocena.stan, StanWarunku.doSprawdzenia);
      expect(ocena.polaBezDeklaracji.single.pole.id, 'p2');
      expect(ocena.uwagi.first, contains('nie wiadomo, co zostaje'));
    });

    test(
      'gdy potwierdzone pola same dają 80 %, reszta nie wstrzymuje',
      () async {
        await pole(id: 'p1', ha: 9);
        await pole(id: 'p2', ha: 1);
        await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');

        final ocena = await ocen();
        expect(ocena.stan, StanWarunku.spelniony);
        expect(ocena.polaBezDeklaracji, hasLength(1));
      },
    );

    test('gdy nawet z polami bez deklaracji nie wyjdzie 80 % — '
        'norma niespełniona', () async {
      await pole(id: 'p1', ha: 5);
      await pole(id: 'p2', ha: 3);
      await pole(id: 'p3', ha: 2);
      await zadeklaruj(poleId: 'p1', forma: 'brak');
      await zadeklaruj(poleId: 'p2', forma: 'brak');

      final ocena = await ocen();
      expect(ocena.udzialMozliwy, closeTo(20, 0.001));
      expect(ocena.stan, StanWarunku.niespelniony);
    });

    test('nieznana forma z przyszłej wersji słownika nie liczy się', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'forma_ktorej_nie_znamy');

      final ocena = await ocen();
      expect(ocena.pola.single.forma, isNull);
      expect(ocena.pola.single.liczySie, isFalse);
      expect(ocena.stan, StanWarunku.niespelniony);
    });
  });

  group('przerwa na siew ozimin', () {
    test('przerwa w granicach przepisu nie psuje okrywy', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima', przerwaDni: 28);

      final ocena = await ocen();
      expect(ocena.polaZaDlugaPrzerwa, isEmpty);
      expect(ocena.stan, StanWarunku.spelniony);
    });

    test('przerwa dłuższa niż 4 tygodnie wyłącza pole z rachunku', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima', przerwaDni: 35);

      final ocena = await ocen();
      expect(ocena.polaZaDlugaPrzerwa.single.pole.id, 'p1');
      expect(ocena.udzialOkrywy, 0);
      expect(ocena.stan, StanWarunku.niespelniony);
    });
  });

  group('podpowiedzi z wpisów — nigdy z domysłu', () {
    test('siew międzyplonu po zbiorze podpowiada międzyplon', () async {
      final p = await pole(id: 'p1', ha: 10);
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.zbior,
        data: '2026-07-20',
      );
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.siew,
        data: '2026-08-05',
        uwagi: 'międzyplon ścierniskowy — gorczyca',
      );

      final podpowiedz = await silnik().podpowiedz(pole: p, sezon: 2026);
      expect(podpowiedz?.forma.id, 'miedzyplon');
      expect(podpowiedz?.skad, contains('z twojego wpisu'));
    });

    test('siew sprzed zbioru nie jest podpowiedzią okrywy', () async {
      final p = await pole(id: 'p1', ha: 10, uprawa: 'kukurydza');
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.siew,
        data: '2026-04-10',
        uwagi: 'wsiewka w kukurydzę',
      );
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.zbior,
        data: '2026-09-25',
      );

      expect(await silnik().podpowiedz(pole: p, sezon: 2026), isNull);
    });

    test('ozimina zapisana na następny rok podpowiada uprawę ozimą', () async {
      final p = await pole(id: 'p1', ha: 10, uprawa: 'kukurydza');
      await RepozytoriumUprawPola(baza).zapisz(
        poleId: 'p1',
        sezon: 2027,
        uprawa: 'pszenica ozima',
        urzadzenie: 'telefon',
      );

      final podpowiedz = await silnik().podpowiedz(pole: p, sezon: 2026);
      expect(podpowiedz?.forma.id, 'uprawa_ozima');
      expect(podpowiedz?.skad, contains('2027'));
    });

    test('trawy na gruncie ornym podpowiadają się z samej uprawy', () async {
      final p = await pole(id: 'p1', ha: 10, uprawa: 'trawy w uprawie polowej');
      final podpowiedz = await silnik().podpowiedz(pole: p, sezon: 2026);
      expect(podpowiedz?.forma.id, 'trawy');
    });

    test('bez wpisów nie podpowiadamy niczego', () async {
      final p = await pole(id: 'p1', ha: 10, uprawa: 'kukurydza');
      expect(await silnik().podpowiedz(pole: p, sezon: 2026), isNull);
    });

    test('gleby odkrytej aplikacja nigdy nie podpowiada', () async {
      final p = await pole(id: 'p1', ha: 10, uprawa: 'grunt zaorany');
      final podpowiedz = await silnik().podpowiedz(pole: p, sezon: 2026);
      expect(podpowiedz?.forma.id, isNot('brak'));
    });

    test('pole z deklaracją nie dostaje podpowiedzi', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');
      final ocena = await ocen();
      expect(ocena.pola.single.podpowiedz, isNull);
    });
  });

  group('dzień zbioru i ślad zmian', () {
    test('dzień zbioru bierze się z wpisu, gdy rolnik go nie podał', () async {
      await pole(id: 'p1', ha: 10);
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.zbior,
        data: '2026-07-20',
      );
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.zbior,
        data: '2026-08-02',
      );

      final ocena = await ocen();
      expect(ocena.pola.single.dataZbioru, DateTime(2026, 8, 2));
    });

    test('zbiór z innego sezonu nie wchodzi do oceny', () async {
      await pole(id: 'p1', ha: 10);
      await zabieg(
        poleId: 'p1',
        rodzaj: RodzajZabiegu.zbior,
        data: '2025-07-20',
      );

      final ocena = await ocen();
      expect(ocena.pola.single.dataZbioru, isNull);
    });

    test('poprawiona deklaracja zostawia ślad w dzienniku zmian', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');
      await zadeklaruj(poleId: 'p1', forma: 'brak');

      final historia = await baza.query(
        'historia_zmian',
        where: 'tabela = ? AND wiersz_id = ?',
        whereArgs: ['okrywa_pola', 'ok-p1-2026'],
      );
      expect(historia, hasLength(1));
      expect(historia.single['dane_json'], contains('uprawa_ozima'));
    });

    test('ta sama deklaracja z dwóch urządzeń to jeden wiersz', () async {
      await pole(id: 'p1', ha: 10);
      await RepozytoriumOkrywyPola(baza).zapisz(
        poleId: 'p1',
        sezon: 2026,
        forma: 'uprawa_ozima',
        urzadzenie: 'telefon',
      );
      await RepozytoriumOkrywyPola(baza).zapisz(
        poleId: 'p1',
        sezon: 2026,
        forma: 'uprawa_ozima',
        urzadzenie: 'komputer',
      );

      final wiersze = await baza.query('okrywa_pola');
      expect(wiersze, hasLength(1));
    });

    test('cofnięta deklaracja wraca do „do sprawdzenia"', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima');
      await RepozytoriumOkrywyPola(baza)
          .usun(poleId: 'p1', sezon: 2026, urzadzenie: 'telefon');

      final ocena = await ocen();
      expect(ocena.pola.single.zadeklarowana, isFalse);
      expect(ocena.stan, StanWarunku.doSprawdzenia);
    });

    test('deklaracja dotyczy jednego sezonu', () async {
      await pole(id: 'p1', ha: 10);
      await zadeklaruj(poleId: 'p1', forma: 'uprawa_ozima', sezon: 2025);

      expect((await ocen(sezon: 2025)).stan, StanWarunku.spelniony);
      expect((await ocen(sezon: 2026)).stan, StanWarunku.doSprawdzenia);
    });
  });

  group('czego aplikacja nie policzy', () {
    test('pola bez rodzaju użytku są wymienione osobno', () async {
      await pole(id: 'p1', ha: 10);
      await pole(id: 'p2', ha: 4, rodzaj: RodzajUzytku.nieznany);

      final ocena = await ocen();
      expect(ocena.polaBezRodzajuUzytku.single.id, 'p2');
    });

    test('sad dostaje uwagę o międzyrzędziach, a nie wynik', () async {
      await pole(id: 'orne', ha: 10);
      await zadeklaruj(poleId: 'orne', forma: 'uprawa_ozima');
      await pole(id: 'sad', ha: 2, rodzaj: RodzajUzytku.uprawyTrwale);

      final ocena = await ocen();
      expect(ocena.polaUprawTrwalych.single.id, 'sad');
      expect(ocena.uwagi.any((u) => u.contains('międzyrzędziach')), isTrue);
    });

    test('lista form jest oznaczona jako do weryfikacji', () async {
      await pole(id: 'p1', ha: 10);
      final ocena = await ocen();
      expect(reguly.warunkowosc.formyOkrywy.doWeryfikacji, isTrue);
      expect(ocena.uwagi.any((u) => u.contains('ARiMR')), isTrue);
    });

    test(
      'zwolnienie do 10 ha jest pokazane, ale nie zdejmuje rachunku',
      () async {
        await pole(id: 'p1', ha: 8);
        await zadeklaruj(poleId: 'p1', forma: 'brak');

        final ocena = await ocen();
        expect(ocena.zwolnioneZKontroli, isTrue);
        expect(ocena.stan, StanWarunku.niespelniony);
      },
    );
  });
}
