import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/historia_upraw.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/rodzaj_uzytku.dart';
import 'package:agro_asystent/funkcje/dzialki/uprawy_pola.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/baza/migracje.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Uprawy pola po sezonach i rodzaj użytku — etap 2, krok 2.
///
/// Bez tych dwóch rzeczy norma GAEC 7 nie da się policzyć: próg 10 ha
/// dotyczy **gruntów ornych**, a zmianowanie porównuje uprawę w plonie
/// głównym rok po roku, licząc od 2023 r.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  String plikBazy(String nazwa) {
    final katalog = Directory.systemTemp.createTempSync('agro-uprawy');
    addTearDown(() => katalog.deleteSync(recursive: true));
    return '${katalog.path}/$nazwa.db';
  }

  /// Baza w starszej wersji schematu — do sprawdzenia przejścia.
  Future<Database> wWersji(int wersja, String sciezka) => fabryka.openDatabase(
    sciezka,
    options: OpenDatabaseOptions(
      version: wersja,
      onConfigure: (baza) => baza.execute('PRAGMA foreign_keys = ON'),
      onCreate: (baza, docelowa) async {
        for (final migracja in migracje) {
          if (migracja.wersja > docelowa) {
            continue;
          }
          for (final polecenie in migracja.polecenia) {
            await baza.execute(polecenie);
          }
        }
      },
    ),
  );

  Future<void> gospodarstwo(DatabaseExecutor baza) =>
      baza.insert('gospodarstwo', {
        'id': 'g1',
        'nazwa': 'Gospodarstwo próbne',
        'utworzono': '2026-03-01T08:00:00',
        'zmieniono': '2026-03-01T08:00:00',
        'urzadzenie': 'telefon',
      });

  Future<void> pole(
    DatabaseExecutor baza, {
    String id = 'p1',
    String uprawa = 'pszenica zwyczajna ozima',
    String? kodEppo = 'TRZAW',
    int sezon = 2026,
    String? oznaczenie,
    int ar = 1200,
  }) => baza.insert('dzialka_rolna', {
    'id': id,
    'gospodarstwo_id': 'g1',
    'nazwa_wlasna': 'Pole $id',
    'oznaczenie_z_wniosku': oznaczenie,
    'sezon': sezon,
    'uprawa': uprawa,
    'kod_eppo': kodEppo,
    'powierzchnia_ar': ar,
    'utworzono': '2026-03-01T08:00:00',
    'zmieniono': '2026-03-01T08:00:00',
    'urzadzenie': 'telefon',
  });

  group('przejście na nowy schemat', () {
    test('uprawa z pola trafia do historii, bez pytania rolnika', () async {
      final sciezka = plikBazy('stara');
      final stara = await wWersji(4, sciezka);
      await gospodarstwo(stara);
      await pole(stara);
      await stara.close();

      final baza = await BazaGospodarstwa.otworz(
        fabryka: fabryka,
        sciezka: sciezka,
      );
      addTearDown(baza.close);

      final historia = await RepozytoriumUprawPola(baza).historia('p1');
      expect(historia, hasLength(1));
      expect(historia.single.sezon, 2026);
      expect(historia.single.uprawa, 'pszenica zwyczajna ozima');
      expect(historia.single.kodEppo, 'TRZAW');
      expect(historia.single.zrodlo, 'pole');
      // Identyfikator wyliczany — dwa urządzenia dadzą ten sam wiersz.
      expect(historia.single.id, 'up-p1-2026-g');
    });

    test(
      'poprzednia uprawa z dziennika zmian wraca jako rok wcześniej',
      () async {
        final sciezka = plikBazy('zdziennikiem');
        final stara = await wWersji(4, sciezka);
        await gospodarstwo(stara);
        await pole(stara);
        await stara.insert('historia_zmian', {
          'tabela': 'dzialka_rolna',
          'wiersz_id': 'p1',
          'operacja': 'zmiana',
          'dane_json':
              '{"poprzednio":{"nazwa_wlasna":"Pole p1","uprawa":"rzepak ozimy",'
              '"kod_eppo":"BRSNN","sezon":2025,"powierzchnia_ar":1200}}',
          'czas': '2026-03-01T09:00:00',
          'urzadzenie': 'telefon',
        });
        await stara.close();

        final baza = await BazaGospodarstwa.otworz(
          fabryka: fabryka,
          sciezka: sciezka,
        );
        addTearDown(baza.close);

        final historia = await RepozytoriumUprawPola(baza).historia('p1');
        expect(historia.map((h) => h.sezon), [2026, 2025]);
        final poprzedni = historia.last;
        expect(poprzedni.uprawa, 'rzepak ozimy');
        expect(poprzedni.kodEppo, 'BRSNN');
        expect(poprzedni.zrodlo, 'dziennik zmian');
      },
    );

    test('poprawka uprawy w tym samym sezonie nie udaje historii', () async {
      // Rolnik poprawił literówkę w tym samym roku — to nie jest uprawa
      // z poprzedniego sezonu i nie może przesłonić obecnej.
      final sciezka = plikBazy('poprawka');
      final stara = await wWersji(4, sciezka);
      await gospodarstwo(stara);
      await pole(stara);
      await stara.insert('historia_zmian', {
        'tabela': 'dzialka_rolna',
        'wiersz_id': 'p1',
        'operacja': 'zmiana',
        'dane_json':
            '{"poprzednio":{"uprawa":"pszenca ozima","kod_eppo":null,'
            '"sezon":2026}}',
        'czas': '2026-03-01T09:00:00',
        'urzadzenie': 'telefon',
      });
      await stara.close();

      final baza = await BazaGospodarstwa.otworz(
        fabryka: fabryka,
        sciezka: sciezka,
      );
      addTearDown(baza.close);

      final historia = await RepozytoriumUprawPola(baza).historia('p1');
      expect(historia, hasLength(1));
      expect(historia.single.uprawa, 'pszenica zwyczajna ozima');
    });
  });

  group('zapis i poprawianie', () {
    late Database baza;

    setUp(() async {
      baza = await BazaGospodarstwa.otworz(
        fabryka: fabryka,
        sciezka: plikBazy('zapis'),
      );
      await gospodarstwo(baza);
      await pole(baza, uprawa: '', kodEppo: null);
    });

    tearDown(() => baza.close());

    test('dopisanie roku wcześniejszego i odczyt po sezonach', () async {
      final uprawy = RepozytoriumUprawPola(baza);
      await uprawy.zapisz(
        poleId: 'p1',
        sezon: 2024,
        uprawa: 'kukurydza na ziarno',
        urzadzenie: 'telefon',
      );
      await uprawy.zapisz(
        poleId: 'p1',
        sezon: 2025,
        uprawa: 'rzepak ozimy',
        kodEppo: 'BRSNN',
        urzadzenie: 'telefon',
      );

      final historia = await uprawy.historia('p1');
      expect(historia.map((h) => h.sezon), [2025, 2024]);
      expect(historia.first.uprawa, 'rzepak ozimy');
      expect(historia.first.zrodlo, 'rolnik');
    });

    test('poprawka roku zostaje w dzienniku zmian', () async {
      final uprawy = RepozytoriumUprawPola(baza);
      await uprawy.zapisz(
        poleId: 'p1',
        sezon: 2024,
        uprawa: 'kukurydza na ziarno',
        urzadzenie: 'telefon',
      );
      await uprawy.zapisz(
        poleId: 'p1',
        sezon: 2024,
        uprawa: 'burak cukrowy',
        urzadzenie: 'telefon',
      );

      final historia = await uprawy.historia('p1');
      expect(historia, hasLength(1), reason: 'jeden rok, jeden wpis');
      expect(historia.single.uprawa, 'burak cukrowy');

      final dziennik = await baza.query(
        'historia_zmian',
        where: 'tabela = ?',
        whereArgs: ['uprawa_pola'],
      );
      expect(dziennik, hasLength(1));
      expect('${dziennik.single['dane_json']}', contains('kukurydza'));
    });

    test('cofnięcie wpisu zostawia wiersz i ślad', () async {
      final uprawy = RepozytoriumUprawPola(baza);
      await uprawy.zapisz(
        poleId: 'p1',
        sezon: 2024,
        uprawa: 'kukurydza na ziarno',
        urzadzenie: 'telefon',
      );
      await uprawy.usun(poleId: 'p1', sezon: 2024, urzadzenie: 'telefon');

      expect(await uprawy.historia('p1'), isEmpty);
      expect(await baza.query('uprawa_pola'), hasLength(1));
      final dziennik = await baza.query(
        'historia_zmian',
        where: 'tabela = ? AND operacja = ?',
        whereArgs: ['uprawa_pola', 'usuniecie'],
      );
      expect(dziennik, hasLength(1));
    });

    test('zmiana uprawy pola zapisuje się też w historii', () async {
      await RepozytoriumPol(baza).zmienUprawe(
        poleId: 'p1',
        uprawa: 'jęczmień ozimy',
        kodEppo: 'HORVW',
        urzadzenie: 'telefon',
      );

      final historia = await RepozytoriumUprawPola(baza).historia('p1');
      expect(historia.single.sezon, 2026);
      expect(historia.single.uprawa, 'jęczmień ozimy');
    });

    test(
      'plon główny i międzyplon to osobne wiersze tego samego roku',
      () async {
        final uprawy = RepozytoriumUprawPola(baza);
        await uprawy.zapisz(
          poleId: 'p1',
          sezon: 2026,
          uprawa: 'pszenica zwyczajna ozima',
          urzadzenie: 'telefon',
        );
        await uprawy.zapisz(
          poleId: 'p1',
          sezon: 2026,
          uprawa: 'facelia błękitna',
          plonGlowny: false,
          urzadzenie: 'telefon',
        );

        final wszystkie = await uprawy.historia('p1');
        expect(wszystkie, hasLength(2));
        expect(wszystkie.where((u) => u.plonGlowny), hasLength(1));
        // Do GAEC 7 liczy się tylko plon główny.
        final plonGlowny = await uprawy.plonGlownyWSezonie(
          gospodarstwoId: 'g1',
          sezon: 2026,
        );
        expect(plonGlowny.single.uprawa, 'pszenica zwyczajna ozima');
      },
    );
  });

  group('propozycje z wniosków z wcześniejszych lat', () {
    late Database baza;

    setUp(() async {
      baza = await BazaGospodarstwa.otworz(
        fabryka: fabryka,
        sciezka: plikBazy('wnioski'),
      );
      await gospodarstwo(baza);
      // Import wniosku zakłada osobny wiersz pola na każdy sezon.
      await pole(
        baza,
        id: 'pole-2025-A',
        sezon: 2025,
        oznaczenie: 'A',
        uprawa: 'rzepak ozimy',
        kodEppo: 'BRSNN',
      );
      await pole(
        baza,
        id: 'pole-2026-A',
        sezon: 2026,
        oznaczenie: 'A',
        uprawa: 'pszenica zwyczajna ozima',
      );
    });

    tearDown(() => baza.close());

    test('uprawa z poprzedniego wniosku jest propozycją, nie faktem', () async {
      final uprawy = RepozytoriumUprawPola(baza);
      final propozycje = await uprawy.propozycjeZWnioskow('pole-2026-A');

      expect(propozycje, hasLength(1));
      expect(propozycje.single.sezon, 2025);
      expect(propozycje.single.uprawa, 'rzepak ozimy');
      // Dopóki rolnik nie potwierdzi, historia pola 2026 ma tylko swój rok.
      final historia = await uprawy.historia('pole-2026-A');
      expect(historia.map((h) => h.sezon), [2026]);
    });

    test('po dopisaniu propozycja znika z listy', () async {
      final uprawy = RepozytoriumUprawPola(baza);
      final propozycja = (await uprawy.propozycjeZWnioskow('pole-2026-A'))
          .single;
      await uprawy.zapisz(
        poleId: 'pole-2026-A',
        sezon: propozycja.sezon,
        uprawa: propozycja.uprawa,
        kodEppo: propozycja.kodEppo,
        urzadzenie: 'telefon',
        zrodlo: 'wniosek',
      );

      expect(await uprawy.propozycjeZWnioskow('pole-2026-A'), isEmpty);
      expect((await uprawy.historia('pole-2026-A')).map((h) => h.sezon), [
        2026,
        2025,
      ]);
    });

    test('pole bez oznaczenia z wniosku nie dostaje propozycji', () async {
      await pole(baza, id: 'reczne', sezon: 2026);
      expect(
        await RepozytoriumUprawPola(baza).propozycjeZWnioskow('reczne'),
        isEmpty,
      );
    });
  });

  group('historia pola razem z przepisem', () {
    late Database baza;

    setUp(() async {
      baza = await BazaGospodarstwa.otworz(
        fabryka: fabryka,
        sciezka: plikBazy('usluga'),
      );
      await gospodarstwo(baza);
      await pole(baza);
    });

    tearDown(() => baza.close());

    UslugaHistoriiUpraw usluga() => UslugaHistoriiUpraw(
      pola: RepozytoriumPol(baza),
      uprawy: RepozytoriumUprawPola(baza),
      reguly: reguly,
    );

    test('zakres lat bierze się z przepisu, nie z kodu', () async {
      // GAEC 7: „bierze się pod uwagę uprawę prowadzoną nie wcześniej niż
      // w 2023 r." — rok stoi w słowniku reguł.
      expect(usluga().odRokuZPrzepisu, 2023);

      final historia = await usluga().dla(
        (await RepozytoriumPol(baza).jedno('p1'))!,
        teraz: DateTime(2026, 10, 17),
      );
      expect(historia.odRoku, 2023);
      expect(historia.doRoku, 2026);
      expect(historia.brakujaceLata, [2025, 2024, 2023]);
      expect(historia.kompletna, isFalse);
    });

    test('po dopisaniu wszystkich lat historia jest pełna', () async {
      final uprawy = RepozytoriumUprawPola(baza);
      for (final (rok, uprawa) in [
        (2025, 'rzepak ozimy'),
        (2024, 'kukurydza na ziarno'),
        (2023, 'burak cukrowy'),
      ]) {
        await uprawy.zapisz(
          poleId: 'p1',
          sezon: rok,
          uprawa: uprawa,
          urzadzenie: 'telefon',
        );
      }

      final historia = await usluga().dla(
        (await RepozytoriumPol(baza).jedno('p1'))!,
        teraz: DateTime(2026, 10, 17),
      );
      expect(historia.brakujaceLata, isEmpty);
      expect(historia.kompletna, isTrue);
      expect(historia.wRoku(2024)!.uprawa, 'kukurydza na ziarno');
    });

    test(
      'rodzaj użytku czeka na rolnika, a aplikacja tylko podpowiada',
      () async {
        var historia = await usluga().dla(
          (await RepozytoriumPol(baza).jedno('p1'))!,
        );
        expect(historia.pole.rodzajUzytku, RodzajUzytku.nieznany);
        expect(historia.rodzajUzytkuDoPodania, isTrue);
        expect(historia.podpowiedzRodzajuUzytku, RodzajUzytku.gruntyOrne);

        await RepozytoriumPol(baza).ustawRodzajUzytku(
          poleId: 'p1',
          rodzaj: RodzajUzytku.tuz,
          urzadzenie: 'telefon',
        );
        historia = await usluga().dla(
          (await RepozytoriumPol(baza).jedno('p1'))!,
        );
        expect(historia.pole.rodzajUzytku, RodzajUzytku.tuz);
        expect(historia.rodzajUzytkuDoPodania, isFalse);
      },
    );
  });

  group('podpowiedź rodzaju użytku', () {
    final podpowiedzi = reguly.warunkowosc.rodzajeUzytku;

    test('łąka i pastwisko to trwały użytek zielony', () {
      for (final nazwa in ['łąka trwała', 'pastwisko', 'Łąki kośne']) {
        expect(
          RodzajUzytku.podpowiedz(uprawa: nazwa, podpowiedzi: podpowiedzi),
          RodzajUzytku.tuz,
          reason: nazwa,
        );
      }
    });

    test('sad, chmiel i szkółka to uprawa trwała', () {
      for (final nazwa in ['sad jabłoniowy', 'chmiel', 'szkółka drzew']) {
        expect(
          RodzajUzytku.podpowiedz(uprawa: nazwa, podpowiedzi: podpowiedzi),
          RodzajUzytku.uprawyTrwale,
          reason: nazwa,
        );
      }
    });

    test('zboża i okopowe to grunty orne', () {
      for (final nazwa in [
        'pszenica zwyczajna ozima',
        'burak cukrowy',
        'kukurydza na ziarno',
      ]) {
        expect(
          RodzajUzytku.podpowiedz(uprawa: nazwa, podpowiedzi: podpowiedzi),
          RodzajUzytku.gruntyOrne,
          reason: nazwa,
        );
      }
    });

    test('dopasowanie idzie po całych słowach', () {
      // „sadzeniaki" nie mogą zrobić z pola sadu.
      expect(
        RodzajUzytku.podpowiedz(
          uprawa: 'ziemniak na sadzeniaki',
          podpowiedzi: podpowiedzi,
        ),
        RodzajUzytku.gruntyOrne,
      );
    });

    test('bez nazwy uprawy nie ma podpowiedzi', () {
      expect(
        RodzajUzytku.podpowiedz(uprawa: '', podpowiedzi: podpowiedzi),
        RodzajUzytku.nieznany,
      );
    });
  });
}
