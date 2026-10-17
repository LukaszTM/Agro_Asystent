import 'dart:io';

import 'package:agro_asystent/funkcje/magazyn/magazyn.dart';
import 'package:agro_asystent/funkcje/magazyn/zuzycie_z_zabiegu.dart';
import 'package:agro_asystent/funkcje/nawozenie/nawoz.dart';
import 'package:agro_asystent/funkcje/zabiegi/dane_wpisu.dart';
import 'package:agro_asystent/funkcje/zabiegi/slownik_srodkow.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Magazyn środków i nawozów — etap 2, krok 7.
///
/// Zasady, których pilnują testy: stan liczy się z ruchów (nie jest
/// osobną liczbą), zużycie przy zabiegu nie odpisuje towaru dwa razy,
/// aplikacja nie zakłada pozycji sama i nie zgaduje ilości, a magazyn
/// nigdy nie wpływa na ewidencję zabiegu.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-magazyn');
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

  Magazyn magazyn() => Magazyn(baza);

  Future<String> pozycja({
    String nazwa = 'Abydos 750 EC',
    RodzajPozycji rodzaj = RodzajPozycji.srodek,
    String jednostka = 'l',
    DateTime? terminDoStosowania,
  }) => magazyn().zapiszPozycje(
    gospodarstwoId: 'g1',
    rodzaj: rodzaj,
    nazwa: nazwa,
    jednostka: jednostka,
    terminDoStosowania: terminDoStosowania,
    urzadzenie: 'telefon',
    teraz: DateTime(2026, 4, 1),
  );

  group('stan liczy się z ruchów', () {
    test('zakup dodaje, zużycie odejmuje', () async {
      final id = await pozycja();
      await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 20,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        cenaZaJednostke: 120,
        teraz: DateTime(2026, 4, 2),
      );
      await magazyn().odpiszPoZabiegu(
        zabiegId: 'z1',
        pozycjaId: id,
        ilosc: 2.4,
        kiedy: DateTime(2026, 4, 10),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 10),
      );

      final stan = (await magazyn().stan(
        gospodarstwoId: 'g1',
        naDzien: DateTime(2026, 5, 1),
      )).single;
      expect(stan.ilosc, closeTo(17.6, 0.001));
      expect(stan.zakupy, 20);
      expect(stan.zuzycie, closeTo(2.4, 0.001));
      expect(stan.iloscOpis, '17,60 l');
      expect(stan.ostatniZakup, DateTime(2026, 4, 2));
      expect(stan.wartoscZakupow, closeTo(2400, 0.001));
    });

    test('stan na wcześniejszy dzień nie widzi późniejszych ruchów', () async {
      final id = await pozycja();
      await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 10,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );

      final przed = (await magazyn().stan(
        gospodarstwoId: 'g1',
        naDzien: DateTime(2026, 4, 1),
      )).single;
      expect(przed.ilosc, 0);
    });

    test('bez ceny nie zgadujemy wartości zakupów', () async {
      final id = await pozycja();
      await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 5,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );
      final stan = (await magazyn().stanPozycji(pozycjaId: id))!;
      expect(stan.wartoscZakupow, isNull);
    });

    test('poprawka stanu dopisuje różnicę, nie nadpisuje liczby', () async {
      final id = await pozycja();
      await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 10,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );
      // W magazynie stoi 8 l, nie 10 — rolnik poprawia stan.
      await magazyn().zapiszPoprawke(
        pozycjaId: id,
        roznica: -2,
        kiedy: DateTime(2026, 4, 20),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 20),
      );

      final stan = (await magazyn().stanPozycji(pozycjaId: id))!;
      expect(stan.ilosc, closeTo(8, 0.001));
      expect(stan.ruchy, hasLength(2), reason: 'zakup zostaje widoczny');
    });

    test('cofnięty ruch nie liczy się do stanu, ale zostaje w bazie', () async {
      final id = await pozycja();
      final ruch = await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 10,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );
      await magazyn().usunRuch(ruchId: ruch, urzadzenie: 'telefon');

      expect((await magazyn().stanPozycji(pozycjaId: id))!.ilosc, 0);
      expect(await baza.query('magazyn_ruch'), hasLength(1));
      final historia = await baza.query(
        'historia_zmian',
        where: 'tabela = ?',
        whereArgs: ['magazyn_ruch'],
      );
      expect(historia.single['operacja'], 'usuniecie');
    });
  });

  group('zużycie przy zabiegu', () {
    test('ten sam zabieg nie odpisuje towaru dwa razy', () async {
      final id = await pozycja();
      for (final ilosc in [2.4, 3.0]) {
        await magazyn().odpiszPoZabiegu(
          zabiegId: 'z1',
          pozycjaId: id,
          ilosc: ilosc,
          kiedy: DateTime(2026, 4, 10),
          urzadzenie: 'telefon',
          teraz: DateTime(2026, 4, 10),
        );
      }

      final stan = (await magazyn().stanPozycji(pozycjaId: id))!;
      expect(stan.ruchy, hasLength(1), reason: 'poprawka wpisu, nie nowy ruch');
      expect(stan.ilosc, closeTo(-3, 0.001), reason: 'liczy się poprawiona');
    });

    test('nieznanej ilości nie zgadujemy', () async {
      final id = await pozycja();
      expect(
        await magazyn().odpiszPoZabiegu(
          zabiegId: 'z1',
          pozycjaId: id,
          ilosc: null,
          kiedy: DateTime(2026, 4, 10),
          urzadzenie: 'telefon',
        ),
        isNull,
      );
      expect((await magazyn().stanPozycji(pozycjaId: id))!.ruchy, isEmpty);
    });

    test('bez pozycji w magazynie zabieg nic nie zakłada', () async {
      expect(
        await magazyn().odpiszZabieg(
          gospodarstwoId: 'g1',
          zabiegId: 'z1',
          rodzaj: RodzajPozycji.srodek,
          nazwa: 'Środek, którego nie mam',
          ilosc: 2,
          kiedy: DateTime(2026, 4, 10),
          urzadzenie: 'telefon',
        ),
        isNull,
      );
      expect(await baza.query('magazyn_pozycja'), isEmpty);
      expect(await baza.query('magazyn_ruch'), isEmpty);
    });

    test('nazwa z innym zapisem trafia w tę samą pozycję', () async {
      await pozycja(nazwa: 'Abydos 750 EC');
      final znaleziona = await magazyn().pozycjaONazwie(
        gospodarstwoId: 'g1',
        rodzaj: RodzajPozycji.srodek,
        nazwa: 'ABYDOS 750 EC',
      );
      expect(znaleziona, isNotNull);
    });
  });

  group('premium i ewidencja', () {
    DaneWpisu wpisOprysku() {
      final dane = DaneWpisu(
        gospodarstwoId: 'g1',
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 4, 10),
      );
      dane.pola.add(
        const Pole(
          id: 'p1',
          gospodarstwoId: 'g1',
          nazwa: 'Za stodołą',
          uprawa: 'pszenica ozima',
          powierzchniaAr: 320,
        ),
      );
      dane
        ..srodek = const DopuszczonySrodek(
          srodekId: 1,
          nazwa: 'Abydos 750 EC',
          nrZezwolenia: 'R-14/2025 h.r.',
          zastosowanieId: 1,
          dawka: 0.75,
          dawkaJednostka: 'l',
          dawkaOdniesienie: 'ha',
          dawkaPewnosc: 'z_rejestru',
        )
        ..dawka = 0.75;
      return dane;
    }

    test('bez premium magazyn nie rusza, a wpis i tak jest zapisany', () async {
      final id = await pozycja();
      final ruch = await ZuzycieZZabiegu.odpisz(
        magazyn: magazyn(),
        dostep: const DostepFunkcji.darmowa(),
        dane: wpisOprysku(),
        zabiegId: 'z1',
        urzadzenie: 'telefon',
      );

      expect(ruch, isNull);
      expect((await magazyn().stanPozycji(pozycjaId: id))!.ruchy, isEmpty);
    });

    test('z premium zużycie liczy się z dawki i powierzchni', () async {
      final id = await pozycja();
      await ZuzycieZZabiegu.odpisz(
        magazyn: magazyn(),
        dostep: const DostepFunkcji(maPremium: true),
        dane: wpisOprysku(),
        zabiegId: 'z1',
        urzadzenie: 'telefon',
      );

      // 0,75 l/ha na 3,20 ha to 2,40 l.
      final stan = (await magazyn().stanPozycji(pozycjaId: id))!;
      expect(stan.zuzycie, closeTo(2.4, 0.001));
      expect(stan.ruchy.single.zabiegId, 'z1');
    });

    test('nawóz odpisuje się z dawki w jednostce rolnika', () async {
      final id = await pozycja(
        nazwa: 'Saletra amonowa',
        rodzaj: RodzajPozycji.nawoz,
        jednostka: 'kg',
      );
      final dane = DaneWpisu(
        gospodarstwoId: 'g1',
        urzadzenie: 'telefon',
        kiedy: DateTime(2026, 4, 10),
      );
      dane.pola.add(
        const Pole(
          id: 'p1',
          gospodarstwoId: 'g1',
          nazwa: 'Za stodołą',
          uprawa: 'pszenica ozima',
          powierzchniaAr: 200,
        ),
      );
      dane
        ..nawoz = const Nawoz(
          id: 'n1',
          gospodarstwoId: 'g1',
          nazwa: 'Saletra amonowa',
          azotProcent: 34,
          naturalny: false,
        )
        ..jednostkaDawki = JednostkaDawki.kilogramyNaHektar
        ..dawka = 150;

      await ZuzycieZZabiegu.odpisz(
        magazyn: magazyn(),
        dostep: const DostepFunkcji(maPremium: true),
        dane: dane,
        zabiegId: 'z2',
        urzadzenie: 'telefon',
      );

      // 150 kg/ha na 2 ha to 300 kg.
      expect(
        (await magazyn().stanPozycji(pozycjaId: id))!.zuzycie,
        closeTo(300, 0.001),
      );
      expect(
        ZuzycieZZabiegu.jednostkaNawozu(JednostkaDawki.kilogramyNaHektar),
        'kg',
      );
    });
  });

  group('ostrzeżenia', () {
    test('wycofany środek z zapasem w magazynie ostrzega', () async {
      final id = await pozycja(terminDoStosowania: DateTime(2026, 6, 30));
      await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 5,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );

      final stan = (await magazyn().stanPozycji(
        pozycjaId: id,
        naDzien: DateTime(2026, 8, 1),
      ))!;
      expect(stan.terminMinal, isTrue);
      final ostrzezenia = magazyn().ostrzezenia(stan);
      expect(ostrzezenia, hasLength(1));
      expect(ostrzezenia.single.tresc, contains('30.06.2026'));
      expect(ostrzezenia.single.coZrobic, contains('Nie stosuj'));
    });

    test('przed terminem i bez zapasu nie ostrzegamy', () async {
      final id = await pozycja(terminDoStosowania: DateTime(2026, 12, 31));
      await magazyn().zapiszZakup(
        pozycjaId: id,
        ilosc: 5,
        kiedy: DateTime(2026, 4, 2),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 2),
      );
      final stan = (await magazyn().stanPozycji(
        pozycjaId: id,
        naDzien: DateTime(2026, 8, 1),
      ))!;
      expect(magazyn().ostrzezenia(stan), isEmpty);
    });

    test('zużycie większe niż zakupy mówi o tym wprost', () async {
      final id = await pozycja();
      await magazyn().odpiszPoZabiegu(
        zabiegId: 'z1',
        pozycjaId: id,
        ilosc: 3,
        kiedy: DateTime(2026, 4, 10),
        urzadzenie: 'telefon',
        teraz: DateTime(2026, 4, 10),
      );
      final stan = (await magazyn().stanPozycji(pozycjaId: id))!;
      expect(stan.stanUjemny, isTrue);
      final ostrzezenie = magazyn().ostrzezenia(stan).single;
      expect(ostrzezenie.tresc, contains('przewyższa zakupy'));
      expect(
        ostrzezenie.coZrobic,
        contains('ewidencja zabiegów zostaje bez zmian'),
      );
    });
  });
}
