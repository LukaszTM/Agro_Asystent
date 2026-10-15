import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:agro_asystent/funkcje/dokumenty/dokument_ewidencji.dart';
import 'package:agro_asystent/funkcje/dokumenty/eksport_csv.dart';
import 'package:agro_asystent/funkcje/dokumenty/eksport_xlsx.dart';
import 'package:agro_asystent/funkcje/dokumenty/usluga_dokumentow.dart';
import 'package:agro_asystent/funkcje/dokumenty/wydruk_pdf.dart';
import 'package:agro_asystent/funkcje/dokumenty/wyjscie_dokumentu.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:agro_asystent/rdzen/uslugi/pdf/tekst_pdf.dart';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Krok 4 etapu 1: podgląd, wydruk PDF i eksport CSV/XLSX.
///
/// Kolumny dokumentu to pola wymagane przepisem, wzięte ze słownika reguł —
/// te testy pilnują, że wydruk i eksport mówią to samo, co ewidencja
/// w aplikacji, razem z brakami.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late RepozytoriumZabiegow zabiegi;
  late _WyjscieDoPamieci wyjscie;
  late UslugaDokumentow dokumenty;

  Future<CzcionkiWydruku> czcionki() async => CzcionkiWydruku(
    zwykla: File('assets/czcionki/dejavu_sans_pl.ttf').readAsBytesSync(),
    pogrubiona: File('assets/czcionki/dejavu_sans_pl_bold.ttf')
        .readAsBytesSync(),
  );

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
    required DateTime kiedy,
    String? godzina = '08:30',
    String? rodzajZastosowania = 'opryskiwanie',
  }) async {
    await zabiegi.zapisz(
      zabieg: Zabieg(
        id: id,
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: kiedy,
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
      teraz: kiedy,
    );
  }

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo Łąki Górne',
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    zabiegi = RepozytoriumZabiegow(baza);
    wyjscie = _WyjscieDoPamieci();
    dokumenty = UslugaDokumentow(
      rejestr: RejestrZabiegow(baza),
      reguly: reguly,
      czcionki: czcionki,
      wyjscie: wyjscie,
    );
  });

  tearDown(() => baza.close());

  Future<DokumentEwidencji> zbuduj({int? rok, String? numerProducenta}) async {
    final dokument = await dokumenty.zbuduj(
      gospodarstwoId: 'g1',
      gospodarstwo: 'Gospodarstwo Łąki Górne',
      numerProducenta: numerProducenta,
      rodzaj: RodzajZabiegu.oprysk,
      rok: rok,
      sporzadzono: DateTime(2026, 10, 15),
    );
    return dokument!;
  }

  group('dokument', () {
    test(
      'kolumny to pola wymagane przepisem, nie wymyślone przez nas',
      () async {
        await dodajPole(id: 'p1', nazwa: 'Za stodołą');
        await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

        final dokument = await zbuduj();
        final zeSlownika = reguly.obowiazek('ewidencja_sor')!.wymaganePola;

        expect(
          [for (final kolumna in dokument.kolumny) kolumna.id],
          [for (final pole in zeSlownika) pole.id],
        );
        expect(dokument.tytul, 'Ewidencja zabiegów środkami ochrony roślin');
        expect(dokument.podstawa, contains('2023/564'));
        expect(dokument.wersjaRegul, reguly.wersja);
        expect(dokument.gospodarstwo, 'Gospodarstwo Łąki Górne');
      },
    );

    test('wiersze mają wartości w kolejności kolumn', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final dokument = await zbuduj();
      final wiersz = dokument.wiersze.single;
      String wartosc(String id) =>
          wiersz.wartosci[dokument.kolumny.indexWhere((k) => k.id == id)]!;

      expect(wiersz.kompletny, isTrue);
      expect(wartosc('srodek_nazwa'), 'Abydos 750 EC');
      expect(wartosc('data'), '10.05.2026');
      expect(wartosc('dawka'), '0,75 l/ha');
      expect(wartosc('dzialka_referencyjna'), '061506_2.0007.138');
    });

    test('braki w ewidencji wchodzą do dokumentu jako braki', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą', kodEppo: null);
      await dodajOprysk(
        id: 'z1',
        poleId: 'p1',
        kiedy: DateTime(2026, 5, 10),
        godzina: null,
      );

      final dokument = await zbuduj();
      expect(dokument.niekompletne, hasLength(1));
      expect(
        dokument.wiersze.single.braki,
        containsAll(['godzina zabiegu', 'kod EPPO uprawy']),
      );
    });

    test('rok zawęża dokument, a wpisy idą od najstarszego', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2025, 5, 10));
      await dodajOprysk(id: 'z2', poleId: 'p1', kiedy: DateTime(2026, 4, 1));
      await dodajOprysk(id: 'z3', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final wszystkie = await zbuduj();
      expect(wszystkie.liczbaWpisow, 3);
      final kolumnaDaty = wszystkie.kolumny.indexWhere((k) => k.id == 'data');
      expect(
        [for (final w in wszystkie.wiersze) w.wartosci[kolumnaDaty]],
        ['10.05.2025', '01.04.2026', '10.05.2026'],
      );

      final rok2026 = await zbuduj(rok: 2026);
      expect(rok2026.liczbaWpisow, 2);
      expect(rok2026.okres, 'rok 2026');
    });

    test('nazwa pliku mówi, co to za dokument', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final dokument = await zbuduj(rok: 2026);
      expect(dokument.nazwaPliku('pdf'), endsWith('_2026.pdf'));
      expect(dokument.nazwaPliku('csv'), startsWith('ewidencja_zabiegów'));
    });
  });

  group('dane gospodarstwa w nagłówku', () {
    test('numer producenta trafia do CSV, XLSX i na wydruk', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final dokument = await zbuduj(rok: 2026, numerProducenta: '012345678');
      expect(
        EksportCsv.tekst(dokument),
        contains('Numer producenta;012345678'),
      );

      final arkusz = utf8.decode(
        ZipDecoder()
            .decodeBytes(EksportXlsx.bajty(dokument))
            .files
            .firstWhere((p) => p.name == 'xl/worksheets/sheet1.xml')
            .content,
      );
      expect(arkusz, contains('012345678'));

      final bajty = await WydrukPdf.bajty(dokument, czcionki: await czcionki());
      final tekst = [
        for (final strona in OdczytTekstuPdf.strony(bajty))
          for (final wiersz in strona.wiersze())
            wiersz.map((s) => s.tekst).join(' '),
      ].join('\n');
      expect(tekst, contains('012345678'));
    });

    test('brak numeru to „brak", nie puste miejsce', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final dokument = await zbuduj(rok: 2026);
      expect(dokument.numerProducenta, isNull);
      expect(EksportCsv.tekst(dokument), contains('Numer producenta;brak'));
    });
  });

  group('eksport CSV', () {
    test('ma znacznik BOM, średniki i nagłówki kolumn', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final dokument = await zbuduj();
      final bajty = EksportCsv.bajty(dokument);
      final tekst = utf8.decode(bajty);

      // Dart przy odczycie zjada znacznik BOM, więc sprawdzamy same bajty.
      expect(bajty.take(3), [
        0xEF,
        0xBB,
        0xBF,
      ], reason: 'bez BOM Excel psuje polskie znaki');
      expect(tekst, contains('Gospodarstwo;Gospodarstwo Łąki Górne'));
      expect(tekst, contains('nazwa środka ochrony roślin;'));
      expect(tekst, contains('Abydos 750 EC;'));
      expect(tekst, contains('\r\n'));
    });

    test('wartość ze średnikiem albo cudzysłowem jest ujęta w cudzysłów', () {
      final dokument = DokumentEwidencji(
        tytul: 'Próba',
        podstawa: 'podstawa',
        wersjaRegul: '2026.10.15',
        gospodarstwo: 'Gospodarstwo',
        rok: 2026,
        kolumny: const [PoleWymagane(id: 'uwagi', nazwa: 'uwagi')],
        wiersze: const [
          WierszDokumentu(wartosci: ['oprysk; ranek "mglisty"'], braki: []),
        ],
        sporzadzono: DateTime(2026, 10, 15),
      );
      expect(
        EksportCsv.tekst(dokument),
        contains('"oprysk; ranek ""mglisty"""'),
      );
    });

    test('brakujące pole wychodzi jako „brak", a nie pusta kratka', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą', kodEppo: null);
      await dodajOprysk(
        id: 'z1',
        poleId: 'p1',
        kiedy: DateTime(2026, 5, 10),
        rodzajZastosowania: null,
      );

      final tekst = EksportCsv.tekst(await zbuduj());
      expect(tekst, contains('brak'));
      expect(tekst, contains('nie ma kompletu danych'));
    });
  });

  group('eksport XLSX', () {
    test('to poprawny skoroszyt z arkuszem i wartościami', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final bajty = EksportXlsx.bajty(await zbuduj());
      final archiwum = ZipDecoder().decodeBytes(bajty);
      final nazwy = [for (final plik in archiwum.files) plik.name];

      expect(
        nazwy,
        containsAll([
          '[Content_Types].xml',
          '_rels/.rels',
          'xl/workbook.xml',
          'xl/_rels/workbook.xml.rels',
          'xl/styles.xml',
          'xl/worksheets/sheet1.xml',
        ]),
      );

      final arkusz = utf8.decode(
        archiwum.files
            .firstWhere((p) => p.name == 'xl/worksheets/sheet1.xml')
            .content,
      );
      expect(arkusz, contains('Ewidencja zabiegów środkami ochrony roślin'));
      expect(arkusz, contains('Gospodarstwo Łąki Górne'));
      expect(arkusz, contains('Abydos 750 EC'));
      expect(arkusz, contains('061506_2.0007.138'));
    });

    test('znaki specjalne nie psują XML-a', () {
      final dokument = DokumentEwidencji(
        tytul: 'Próba & test',
        podstawa: 'podstawa',
        wersjaRegul: '2026.10.15',
        gospodarstwo: 'Gospodarstwo <Nowe>',
        rok: null,
        kolumny: const [PoleWymagane(id: 'uwagi', nazwa: 'uwagi')],
        wiersze: const [
          WierszDokumentu(wartosci: ['dawka < 1 l & "pełna"'], braki: []),
        ],
        sporzadzono: DateTime(2026, 10, 15),
      );
      final archiwum = ZipDecoder().decodeBytes(EksportXlsx.bajty(dokument));
      final arkusz = utf8.decode(
        archiwum.files
            .firstWhere((p) => p.name == 'xl/worksheets/sheet1.xml')
            .content,
      );
      expect(arkusz, contains('Próba &amp; test'));
      expect(arkusz, contains('Gospodarstwo &lt;Nowe&gt;'));
      expect(arkusz, isNot(contains('<Nowe>')));
    });
  });

  group('wydruk PDF', () {
    test('da się odczytać i zawiera to, czego chce przepis', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final bajty = await WydrukPdf.bajty(
        await zbuduj(rok: 2026),
        czcionki: await czcionki(),
      );

      // Czytamy własnym czytnikiem PDF z kroku 2 — jeśli wydruk da się
      // odczytać maszynowo, to i urząd go odczyta.
      final strony = OdczytTekstuPdf.strony(bajty);
      final tekst = [
        for (final strona in strony)
          for (final wiersz in strona.wiersze())
            wiersz.map((s) => s.tekst).join(' '),
      ].join('\n');

      expect(strony, isNotEmpty);
      expect(tekst, contains('Ewidencja zabiegów środkami ochrony roślin'));
      expect(tekst, contains('Gospodarstwo Łąki Górne'));
      expect(tekst, contains('rok 2026'));
      expect(tekst, contains('Abydos 750 EC'));
      expect(tekst, contains('061506_2.0007.138'));
      expect(tekst, contains('2023/564'));
      expect(tekst, contains(reguly.wersja));
    });

    test('polskie znaki wychodzą w całości', () async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));

      final bajty = await WydrukPdf.bajty(
        await zbuduj(),
        czcionki: await czcionki(),
      );
      final tekst = [
        for (final strona in OdczytTekstuPdf.strony(bajty))
          for (final wiersz in strona.wiersze())
            wiersz.map((s) => s.tekst).join(' '),
      ].join('\n');

      // Długie nazwy łamią się w kratce tabeli, więc sprawdzamy pojedyncze
      // słowa — chodzi o to, czy polskie znaki w ogóle wyszły z czcionki.
      for (final slowo in [
        'mączniak',
        'zbóż',
        'pszenica',
        'Łąki',
        'Górne',
        'środkami',
        'roślin',
      ]) {
        expect(tekst, contains(slowo), reason: slowo);
      }
    });

    test(
      'pusty okres daje dokument z wyjaśnieniem, a nie pustą kartkę',
      () async {
        final bajty = await WydrukPdf.bajty(
          await zbuduj(rok: 2024),
          czcionki: await czcionki(),
        );
        final tekst = [
          for (final strona in OdczytTekstuPdf.strony(bajty))
            for (final wiersz in strona.wiersze())
              wiersz.map((s) => s.tekst).join(' '),
        ].join('\n');

        expect(tekst, contains('nie ma żadnego wpisu'));
      },
    );
  });

  group('wyjście dokumentu', () {
    setUp(() async {
      await dodajPole(id: 'p1', nazwa: 'Za stodołą');
      await dodajOprysk(id: 'z1', poleId: 'p1', kiedy: DateTime(2026, 5, 10));
    });

    test('każdy format idzie z własnym typem pliku', () async {
      final dokument = await zbuduj(rok: 2026);

      await dokumenty.zapiszCsv(dokument);
      await dokumenty.zapiszXlsx(dokument);
      await dokumenty.zapiszPdf(dokument);
      await dokumenty.wydrukujPdf(dokument);

      expect(wyjscie.udostepnione, hasLength(3));
      expect(wyjscie.udostepnione[0].typMime, UslugaDokumentow.mimeCsv);
      expect(wyjscie.udostepnione[0].nazwa, endsWith('.csv'));
      expect(wyjscie.udostepnione[1].typMime, UslugaDokumentow.mimeXlsx);
      expect(wyjscie.udostepnione[2].typMime, UslugaDokumentow.mimePdf);
      expect(wyjscie.wydrukowane, hasLength(1));
      expect(wyjscie.wydrukowane.single.nazwa, endsWith('.pdf'));
      for (final plik in wyjscie.udostepnione) {
        expect(plik.dane, isNotEmpty);
      }
      expect(wyjscie.wydrukowane.single.dane, isNotEmpty);
    });

    test('nieznany rodzaj dokumentu to null, a nie pusty plik', () async {
      final dokument = await dokumenty.zbuduj(
        gospodarstwoId: 'g1',
        gospodarstwo: 'Gospodarstwo Łąki Górne',
        rodzaj: RodzajZabiegu.siew,
      );
      expect(dokument, isNull);
      expect(
        dokumenty.dostepneRodzaje,
        containsAll([RodzajZabiegu.oprysk, RodzajZabiegu.nawozenie]),
      );
    });
  });
}

/// Wyjście, które zamiast okien systemowych zapamiętuje, co dostało.
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
