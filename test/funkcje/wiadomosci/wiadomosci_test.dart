import 'dart:convert';
import 'dart:io';

import 'package:agro_asystent/funkcje/wiadomosci/klient_wiadomosci.dart';
import 'package:agro_asystent/funkcje/wiadomosci/usluga_wiadomosci.dart';
import 'package:agro_asystent/funkcje/wiadomosci/wiadomosci.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Wiadomości rolnicze — dodatek, który musi znieść zepsuty kanał.
///
/// Czego pilnują testy: bierzemy tylko nagłówek, zajawkę i odnośnik
/// (cudzej treści nie przepisujemy), zepsuty kanał nie przewraca reszty,
/// a bez internetu zostają ostatnio pobrane nagłówki z datą.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-wiadomosci');
    addTearDown(() => katalog.deleteSync(recursive: true));
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: '${katalog.path}/gospodarstwo.db',
    );
  });

  tearDown(() => baza.close());

  const kanal = KanalWiadomosci(
    nazwa: 'Portal rolniczy',
    adres: 'https://przyklad.test/rss',
    strona: 'https://przyklad.test',
    status: 'do_weryfikacji',
  );

  const rss = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Portal rolniczy</title>
    <item>
      <title>Dopłaty bezpośrednie: nowy termin</title>
      <link>https://przyklad.test/doplaty</link>
      <description><![CDATA[<p>Agencja <b>wydłużyła</b> termin&nbsp;składania wniosków.</p>]]></description>
      <pubDate>Sat, 17 Oct 2026 07:30:00 +0200</pubDate>
    </item>
    <item>
      <title>Ceny pszenicy w górę</title>
      <link>https://przyklad.test/pszenica</link>
      <description>Notowania z giełd towarowych.</description>
      <pubDate>Fri, 16 Oct 2026 12:00:00 +0200</pubDate>
    </item>
  </channel>
</rss>
''';

  const atom = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Drugi portal</title>
  <entry>
    <title>Susza na Podlasiu</title>
    <link href="https://drugi.test/susza"/>
    <summary>Komisje szacują straty.</summary>
    <updated>2026-10-18T06:00:00Z</updated>
  </entry>
</feed>
''';

  group('czytanie kanału', () {
    test(
      'z RSS bierze tytuł, odnośnik, zajawkę bez znaczników i datę',
      () async {
        final klient = KlientWiadomosci(
          klient: MockClient((_) async => _odpowiedz(rss)),
        );

        final wiadomosci = await klient.zKanalu(kanal);

        expect(wiadomosci, hasLength(2));
        final pierwsza = wiadomosci.first;
        expect(pierwsza.tytul, 'Dopłaty bezpośrednie: nowy termin');
        expect(pierwsza.odnosnik, 'https://przyklad.test/doplaty');
        expect(pierwsza.zrodlo, 'Portal rolniczy');
        expect(
          pierwsza.zajawka,
          'Agencja wydłużyła termin składania wniosków.',
        );
        expect(pierwsza.data, DateTime(2026, 10, 17, 7, 30));
      },
    );

    test('Atom czyta się tak samo jak RSS', () async {
      final klient = KlientWiadomosci(
        klient: MockClient((_) async => _odpowiedz(atom)),
      );

      final wiadomosci = await klient.zKanalu(kanal);

      expect(wiadomosci.single.tytul, 'Susza na Podlasiu');
      expect(wiadomosci.single.odnosnik, 'https://drugi.test/susza');
      expect(wiadomosci.single.zajawka, 'Komisje szacują straty.');
    });

    test('zepsuty kanał daje pustą listę, a nie wyjątek', () async {
      final niedziala = KlientWiadomosci(
        klient: MockClient((_) async => throw http.ClientException('brak')),
      );
      final blad404 = KlientWiadomosci(
        klient: MockClient((_) async => http.Response('nie ma', 404)),
      );
      final smiec = KlientWiadomosci(
        klient: MockClient((_) async => http.Response('to nie jest xml', 200)),
      );

      expect(await niedziala.zKanalu(kanal), isEmpty);
      expect(await blad404.zKanalu(kanal), isEmpty);
      expect(await smiec.zKanalu(kanal), isEmpty);
    });

    test('z jednego kanału bierzemy tylko kilka wiadomości', () async {
      final klient = KlientWiadomosci(
        ilePoKanale: 1,
        klient: MockClient((_) async => _odpowiedz(rss)),
      );

      expect(await klient.zKanalu(kanal), hasLength(1));
    });
  });

  group('usługa wiadomości', () {
    const drugiKanal = KanalWiadomosci(
      nazwa: 'Drugi portal',
      adres: 'https://drugi.test/atom',
      strona: 'https://drugi.test',
      status: 'do_weryfikacji',
    );

    UslugaWiadomosci uslugaZ(
      MockClient klient, {
      List<KanalWiadomosci> kanaly = const [kanal, drugiKanal],
    }) => UslugaWiadomosci(
      zapis: RepozytoriumWiadomosci(baza),
      kanaly: SlownikKanalow(wersja: 'test', kanaly: kanaly),
      klient: KlientWiadomosci(klient: klient),
    );

    MockClient dwaKanaly() => MockClient(
      (zadanie) async =>
          _odpowiedz(zadanie.url.host == 'drugi.test' ? atom : rss),
    );

    test('łączy kanały i układa najnowsze na górze', () async {
      final stan = await uslugaZ(dwaKanaly())
          .najnowsze(teraz: DateTime(2026, 10, 18, 9));

      expect(stan.wiadomosci, hasLength(3));
      expect(stan.wiadomosci.first.tytul, 'Susza na Podlasiu');
      expect(stan.wiadomosci.last.tytul, 'Ceny pszenicy w górę');
      expect(stan.pobrano, DateTime(2026, 10, 18, 9));
    });

    test('świeży zapis wystarcza — kanałów nie odpytujemy co chwilę', () async {
      var pobrania = 0;
      final usluga = uslugaZ(
        MockClient((zadanie) async {
          pobrania++;
          return _odpowiedz(zadanie.url.host == 'drugi.test' ? atom : rss);
        }),
      );

      await usluga.najnowsze(teraz: DateTime(2026, 10, 18, 9));
      await usluga.najnowsze(teraz: DateTime(2026, 10, 18, 11));

      expect(pobrania, 2, reason: 'dwa kanały, jedno pobranie każdego');
    });

    test('gdy nic nie odpowiada, zostają ostatnie nagłówki z datą', () async {
      await uslugaZ(dwaKanaly()).najnowsze(teraz: DateTime(2026, 10, 18, 9));

      final stan = await uslugaZ(
        MockClient((_) async => throw http.ClientException('brak sieci')),
      ).najnowsze(teraz: DateTime(2026, 10, 19, 9));

      expect(stan.nicNieOdpowiedzialo, isTrue);
      expect(stan.wiadomosci, hasLength(3));
      expect(stan.pobrano, DateTime(2026, 10, 18, 9));
    });

    test('bez kanałów w pliku mówimy wprost, że nie ma źródeł', () async {
      final stan = await uslugaZ(
        dwaKanaly(),
        kanaly: const [],
      ).najnowsze(teraz: DateTime(2026, 10, 18, 9));

      expect(stan.brakZrodel, isTrue);
      expect(stan.pusty, isTrue);
    });
  });

  group('lista kanałów z pliku', () {
    test('plik programu daje się odczytać i ma adresy', () {
      final slownik = SlownikKanalow.zTekstuJson(
        File('assets/dane/kanaly_wiadomosci.json').readAsStringSync(),
      );

      expect(slownik.kanaly, isNotEmpty);
      for (final kanal in slownik.kanaly) {
        expect(kanal.adres, startsWith('https://'));
        expect(kanal.nazwa, isNotEmpty);
        expect(kanal.status, anyOf('potwierdzone', 'do_weryfikacji'));
      }
    });
  });
}

/// Serwisy oddają polskie znaki w UTF-8 — `http.Response` z napisem
/// koduje je jako Latin-1, więc w teście składamy odpowiedź z bajtów.
http.Response _odpowiedz(String tresc) =>
    http.Response.bytes(utf8.encode(tresc), 200);
