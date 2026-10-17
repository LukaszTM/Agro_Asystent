import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/granica_z_woda.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/warunkowosc/pas_od_wody.dart';
import 'package:agro_asystent/funkcje/warunkowosc/zmianowanie.dart'
    show StanWarunku;
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Norma GAEC 4: pas bez nawozów i środków ochrony roślin od brzegu wody —
/// etap 2, krok 5.
///
/// Aplikacja nie wie, czy opryskiwacz sięgnął brzegu, i nie udaje, że wie.
/// Jej zadaniem jest przypomnieć o pasie przy polu, o którym **rolnik**
/// powiedział, że graniczy z wodą.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-pas');
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
    GranicaZWoda granica = GranicaZWoda.nieznana,
    double ha = 2,
  }) async {
    await RepozytoriumPol(baza).dodaj(
      pole: Pole(
        id: id,
        gospodarstwoId: 'g1',
        nazwa: 'Pole $id',
        uprawa: 'pszenica ozima',
        powierzchniaAr: (ha * 100).round(),
        sezon: 2026,
      ),
      urzadzenie: 'telefon',
    );
    if (granica.znana) {
      await RepozytoriumPol(
        baza,
      ).ustawGranicaZWoda(poleId: id, granica: granica, urzadzenie: 'telefon');
    }
    return (await RepozytoriumPol(baza).jedno(id))!;
  }

  PasOdWody silnik() => PasOdWody(pola: RepozytoriumPol(baza), reguly: reguly);

  group('liczby z przepisu, nie z kodu', () {
    test('pas 3 m i wyłączenie rowów do 5 m pochodzą ze słownika', () {
      expect(silnik().szerokoscPasaM, 3);
      expect(silnik().rowBezPasaM, 5);
    });

    test('pytanie dla rolnika zawiera obie liczby', () {
      final pytanie = silnik().pytanie;
      expect(pytanie, contains('3 m'));
      expect(pytanie, contains('5 m'));
    });
  });

  group('ostrzeżenie przed zapisem', () {
    test('oprysk na polu przy wodzie ostrzega', () async {
      final przyWodzie = await pole(id: 'p1', granica: GranicaZWoda.tak);

      final ostrzezenie = silnik().ostrzezeniePrzedZapisem(
        pola: [przyWodzie],
        rodzaj: RodzajZabiegu.oprysk,
      );
      expect(ostrzezenie, isNotNull);
      expect(ostrzezenie!.tresc, contains('Pole p1 graniczy z wodą'));
      expect(ostrzezenie.tresc, contains('środków ochrony roślin'));
      expect(ostrzezenie.tresc, contains('3 m'));
      expect(ostrzezenie.coZrobic, contains('Zapisz zabieg tak, jak był'));
    });

    test('nawożenie mówi o nawozach, nie o środkach', () async {
      final przyWodzie = await pole(id: 'p1', granica: GranicaZWoda.tak);

      final ostrzezenie = silnik().ostrzezeniePrzedZapisem(
        pola: [przyWodzie],
        rodzaj: RodzajZabiegu.nawozenie,
      );
      expect(ostrzezenie!.tresc, contains('nawozów'));
      expect(ostrzezenie.tresc, isNot(contains('środków ochrony')));
    });

    test('pole, które nie graniczy z wodą, nie straszy', () async {
      final zwykle = await pole(id: 'p1', granica: GranicaZWoda.nie);

      expect(
        silnik().ostrzezeniePrzedZapisem(
          pola: [zwykle],
          rodzaj: RodzajZabiegu.oprysk,
        ),
        isNull,
      );
    });

    test('bez odpowiedzi rolnika nie ostrzegamy — nie zgadujemy', () async {
      final nieznane = await pole(id: 'p1');

      expect(nieznane.granicaZWoda, GranicaZWoda.nieznana);
      expect(
        silnik().ostrzezeniePrzedZapisem(
          pola: [nieznane],
          rodzaj: RodzajZabiegu.oprysk,
        ),
        isNull,
      );
    });

    test('siew i zbiór nie są objęte tą normą', () async {
      final przyWodzie = await pole(id: 'p1', granica: GranicaZWoda.tak);

      for (final rodzaj in [
        RodzajZabiegu.siew,
        RodzajZabiegu.zbior,
        RodzajZabiegu.uprawaGleby,
        RodzajZabiegu.inny,
        null,
      ]) {
        expect(
          silnik().ostrzezeniePrzedZapisem(pola: [przyWodzie], rodzaj: rodzaj),
          isNull,
          reason: '${rodzaj?.wBazie}',
        );
      }
    });

    test('z kilku pól wymieniamy tylko te przy wodzie', () async {
      final przyWodzie = await pole(id: 'p1', granica: GranicaZWoda.tak);
      final zwykle = await pole(id: 'p2', granica: GranicaZWoda.nie);

      final ostrzezenie = silnik().ostrzezeniePrzedZapisem(
        pola: [przyWodzie, zwykle],
        rodzaj: RodzajZabiegu.oprysk,
      );
      expect(ostrzezenie!.nazwyPol, ['Pole p1']);
      expect(ostrzezenie.tresc, isNot(contains('Pole p2')));
    });

    test('dwa pola przy wodzie w jednym zdaniu', () async {
      final a = await pole(id: 'p1', granica: GranicaZWoda.tak);
      final b = await pole(id: 'p2', granica: GranicaZWoda.tak);

      final ostrzezenie = silnik().ostrzezeniePrzedZapisem(
        pola: [a, b],
        rodzaj: RodzajZabiegu.oprysk,
      );
      expect(ostrzezenie!.tresc, contains('Pola Pole p1, Pole p2 graniczą'));
    });
  });

  group('stan normy w gospodarstwie', () {
    test('bez pól przy wodzie i z odpowiedziami — nie dotyczy', () async {
      await pole(id: 'p1', granica: GranicaZWoda.nie);

      final ocena = await silnik().ocen(gospodarstwoId: 'g1');
      expect(ocena.stan, StanWarunku.nieDotyczy);
      expect(ocena.uwagi, isEmpty);
    });

    test('pole bez odpowiedzi to „do sprawdzenia"', () async {
      await pole(id: 'p1');

      final ocena = await silnik().ocen(gospodarstwoId: 'g1');
      expect(ocena.stan, StanWarunku.doSprawdzenia);
      expect(ocena.polaBezOdpowiedzi.single.id, 'p1');
      expect(ocena.uwagi.first, contains('nie wiemy, czy graniczą'));
    });

    test(
      'pole przy wodzie zostaje „do sprawdzenia" — tego nie policzymy',
      () async {
        await pole(id: 'p1', granica: GranicaZWoda.tak);

        final ocena = await silnik().ocen(gospodarstwoId: 'g1');
        expect(ocena.polaPrzyWodzie.single.id, 'p1');
        expect(ocena.stan, StanWarunku.doSprawdzenia);
        expect(ocena.uwagi.last, contains('wie tylko ten, kto jechał'));
      },
    );

    test('odpowiedź rolnika zostaje w bazie', () async {
      await pole(id: 'p1', granica: GranicaZWoda.tak);
      expect(
        (await RepozytoriumPol(baza).jedno('p1'))!.granicaZWoda,
        GranicaZWoda.tak,
      );

      await RepozytoriumPol(baza).ustawGranicaZWoda(
        poleId: 'p1',
        granica: GranicaZWoda.nie,
        urzadzenie: 'telefon',
      );
      expect(
        (await RepozytoriumPol(baza).jedno('p1'))!.granicaZWoda,
        GranicaZWoda.nie,
      );
    });
  });
}
