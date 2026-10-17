import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/granica_z_woda.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/rodzaj_uzytku.dart';
import 'package:agro_asystent/funkcje/dzialki/uprawy_pola.dart';
import 'package:agro_asystent/funkcje/warunkowosc/okres_legowy.dart';
import 'package:agro_asystent/funkcje/warunkowosc/okrywa.dart';
import 'package:agro_asystent/funkcje/warunkowosc/okrywa_pola.dart';
import 'package:agro_asystent/funkcje/warunkowosc/pas_od_wody.dart';
import 'package:agro_asystent/funkcje/warunkowosc/przeglad.dart';
import 'package:agro_asystent/funkcje/warunkowosc/zmianowanie.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Przegląd warunkowości — etap 2, krok 6.
///
/// Jedno miejsce, w którym rolnik widzi stan każdej normy GAEC. Testy
/// pilnują dwóch rzeczy: że stan bierze się z silników, a nie z osobnego
/// rachunku, i że normy, których aplikacja nie policzy, mówią o tym
/// wprost, zamiast pokazywać „spełniona".
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-przeglad');
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

  PrzegladWarunkowosci przeglad() {
    final pola = RepozytoriumPol(baza);
    final uprawy = RepozytoriumUprawPola(baza);
    return PrzegladWarunkowosci(
      reguly: reguly,
      zmianowanie: Zmianowanie(pola: pola, uprawy: uprawy, reguly: reguly),
      okrywa: Okrywa(
        pola: pola,
        okrywy: RepozytoriumOkrywyPola(baza),
        uprawy: uprawy,
        reguly: reguly,
      ),
      pasOdWody: PasOdWody(pola: pola, reguly: reguly),
      okresLegowy: OkresLegowy(reguly: reguly),
      zabiegi: RepozytoriumZabiegow(baza),
    );
  }

  Future<void> pole({
    required String id,
    double ha = 12,
    String uprawa = 'pszenica ozima',
    RodzajUzytku rodzaj = RodzajUzytku.gruntyOrne,
    GranicaZWoda woda = GranicaZWoda.nie,
    int sezon = 2026,
  }) async {
    await RepozytoriumPol(baza).dodaj(
      pole: Pole(
        id: id,
        gospodarstwoId: 'g1',
        nazwa: 'Pole $id',
        uprawa: uprawa,
        powierzchniaAr: (ha * 100).round(),
        sezon: sezon,
        rodzajUzytku: rodzaj,
      ),
      urzadzenie: 'telefon',
    );
    await RepozytoriumPol(baza)
        .ustawGranicaZWoda(poleId: id, granica: woda, urzadzenie: 'telefon');
  }

  Future<List<StanNormy>> stany({int sezon = 2026}) =>
      przeglad().stany(gospodarstwoId: 'g1', sezon: sezon);

  StanNormy jedna(List<StanNormy> wszystkie, String id) =>
      wszystkie.firstWhere((s) => s.norma.id == id);

  group('wszystkie normy ze słownika', () {
    test('przegląd pokazuje każdą normę, także tę nieliczoną', () async {
      await pole(id: 'p1');
      final wszystkie = await stany();
      expect(wszystkie, hasLength(reguly.warunkowosc.normy.length));
      expect(
        wszystkie.map((s) => s.norma.numer),
        containsAll(['GAEC 1', 'GAEC 4', 'GAEC 6', 'GAEC 7', 'GAEC 8']),
      );
    });

    test('norma, której aplikacja nie policzy, nie udaje spełnionej', () async {
      await pole(id: 'p1');
      final wszystkie = await stany();
      final nieliczone = wszystkie.where((s) => !s.liczona);
      expect(nieliczone, isNotEmpty);
      for (final stanNormy in nieliczone) {
        expect(
          stanNormy.stan,
          StanWarunku.doSprawdzenia,
          reason: stanNormy.norma.numer,
        );
        expect(stanNormy.coZrobic, contains('doradcy'));
      }
    });

    test('każda norma ma stan po polsku i jedno zdanie co zrobić', () async {
      await pole(id: 'p1');
      for (final stanNormy in await stany()) {
        expect(stanNormy.stanDlaRolnika, isNotEmpty);
        expect(stanNormy.coZrobic, isNotEmpty);
      }
    });
  });

  group('stan bierze się z silników', () {
    test('GAEC 7 do 10 ha gruntów ornych nie dotyczy', () async {
      await pole(id: 'p1', ha: 8);
      final gaec7 = jedna(await stany(), 'gaec_7');
      expect(gaec7.stan, StanWarunku.nieDotyczy);
      expect(gaec7.coWiemy.first, contains('Grunty orne: 8,00 ha'));
    });

    test('GAEC 6 bez deklaracji okrywy jest „do sprawdzenia"', () async {
      await pole(id: 'p1');
      final gaec6 = jedna(await stany(), 'gaec_6');
      expect(gaec6.stan, StanWarunku.doSprawdzenia);
      expect(gaec6.coWiemy.first, contains('0 % gruntów ornych'));
      expect(gaec6.coZrobic, contains('co zostaje po zbiorze'));
    });

    test('GAEC 6 z okrywą na wszystkich polach jest spełniona', () async {
      await pole(id: 'p1');
      await RepozytoriumOkrywyPola(baza).zapisz(
        poleId: 'p1',
        sezon: 2026,
        forma: 'uprawa_ozima',
        urzadzenie: 'telefon',
      );
      final gaec6 = jedna(await stany(), 'gaec_6');
      expect(gaec6.stan, StanWarunku.spelniony);
      expect(gaec6.coWiemy.first, contains('100 %'));
      expect(gaec6.coWiemy.any((z) => z.contains('15 października')), isTrue);
    });

    test('GAEC 4 bez odpowiedzi o wodzie prosi o odpowiedź', () async {
      await RepozytoriumPol(baza).dodaj(
        pole: const Pole(
          id: 'p1',
          gospodarstwoId: 'g1',
          nazwa: 'Pole p1',
          uprawa: 'pszenica ozima',
          powierzchniaAr: 400,
          sezon: 2026,
        ),
        urzadzenie: 'telefon',
      );
      final gaec4 = jedna(await stany(), 'gaec_4');
      expect(gaec4.stan, StanWarunku.doSprawdzenia);
      expect(gaec4.coZrobic, contains('graniczą z wodą'));
    });

    test('GAEC 4 z polem przy wodzie przypomina o pasie', () async {
      await pole(id: 'p1', woda: GranicaZWoda.tak);
      final gaec4 = jedna(await stany(), 'gaec_4');
      expect(gaec4.coWiemy.first, contains('Pola graniczące z wodą: 1'));
      expect(gaec4.coZrobic, contains('pas 3 m'));
    });
  });

  group('GAEC 8 liczy się z wpisów', () {
    Future<void> praca({required String podrodzaj, required String data}) =>
        RepozytoriumZabiegow(baza).zapisz(
          zabieg: Zabieg(
            id: 'z-$data-$podrodzaj',
            gospodarstwoId: 'g1',
            rodzaj: RodzajZabiegu.inny,
            data: DateTime.parse(data),
            podrodzaj: podrodzaj,
            urzadzenie: 'telefon',
          ),
          pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 100)],
        );

    test('bez wpisu przycinania norma jest spełniona — i mówimy, skąd to '
        'wiemy', () async {
      await pole(id: 'p1');
      final gaec8 = jedna(await stany(), 'gaec_8');
      expect(gaec8.stan, StanWarunku.spelniony);
      expect(gaec8.coWiemy.first, contains('Według wpisów'));
      expect(gaec8.coWiemy.first, contains('15 kwietnia'));
    });

    test('przycinanie w okresie lęgowym daje „niespełniona"', () async {
      await pole(id: 'p1');
      await praca(podrodzaj: 'przycinanie_drzew', data: '2026-05-10');
      final gaec8 = jedna(await stany(), 'gaec_8');
      expect(gaec8.stan, StanWarunku.niespelniony);
      expect(gaec8.coWiemy.first, contains('1 wpisów przycinania'));
      expect(gaec8.coZrobic, contains('wierzb'));
    });

    test('przycinanie poza okresem nie psuje normy', () async {
      await pole(id: 'p1');
      await praca(podrodzaj: 'przycinanie_drzew', data: '2026-02-10');
      expect(jedna(await stany(), 'gaec_8').stan, StanWarunku.spelniony);
    });

    test('praca wyłączona z zakazu nie psuje normy', () async {
      await pole(id: 'p1');
      await praca(podrodzaj: 'przycinanie_wylaczone', data: '2026-05-10');
      expect(jedna(await stany(), 'gaec_8').stan, StanWarunku.spelniony);
    });

    test('wpis z innego roku nie wchodzi do oceny sezonu', () async {
      await pole(id: 'p1');
      await praca(podrodzaj: 'przycinanie_drzew', data: '2025-05-10');
      expect(jedna(await stany(), 'gaec_8').stan, StanWarunku.spelniony);
      expect(
        jedna(await stany(sezon: 2025), 'gaec_8').stan,
        StanWarunku.niespelniony,
      );
    });
  });

  group('zwolnienia z kontroli', () {
    test(
      'gospodarstwo do 10 ha ma pokazane zwolnienie, ale liczymy dalej',
      () async {
        await pole(id: 'p1', ha: 8);
        final wszystkie = await stany();
        final gaec6 = jedna(wszystkie, 'gaec_6');
        expect(gaec6.zwolnienia, isNotEmpty);
        expect(gaec6.stan, StanWarunku.doSprawdzenia);
      },
    );

    test('powyżej 30 ha zwolnień już nie ma', () async {
      await pole(id: 'p1', ha: 40);
      final gaec7 = jedna(await stany(), 'gaec_7');
      expect(gaec7.zwolnienia, isEmpty);
    });
  });
}
