import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Odpowiedzi wzorowane na prawdziwych odpowiedziach ULDK zebranych w P5:
/// pierwszy wiersz to status, drugi — dane rozdzielone „|" w kolejności
/// podanej w parametrze `result`, a geometria ma przedrostek `SRID=`.
void main() {
  const obrys =
      'SRID=4326;POLYGON((19.100 52.100,19.102 52.100,19.102 52.102,'
      '19.100 52.102,19.100 52.100))';

  group('odczytaj', () {
    test('czyta działkę razem z położeniem', () {
      final dzialka = KlientUldk.odczytaj(
        '0\n$obrys|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n',
        '061506_2.0007.138',
        4326,
      );
      expect(dzialka.identyfikator, '061506_2.0007.138');
      expect(dzialka.srid, 4326);
      expect(dzialka.wkt, startsWith('POLYGON'));
      expect(dzialka.obreb, 'Brzeziny');
      expect(dzialka.gmina, 'Lubartów');
      expect(dzialka.powiat, 'lubartowski');
      expect(dzialka.wojewodztwo, 'lubelskie');
      expect(dzialka.nrDzialki, '138');
      expect(dzialka.polozenie, 'Brzeziny, Lubartów, lubartowski');
      expect(dzialka.obrysy, hasLength(1));
      expect(dzialka.powierzchniaHa, greaterThan(0));
    });

    test(
      'status inny niż 0 to komunikat dla rolnika, nie wyjątek techniczny',
      () {
        try {
          KlientUldk.odczytaj(
            '-1 nie znaleziono dzialki',
            '061506_2.0007.999',
            4326,
          );
          fail('powinien polecieć BladUldk');
        } on BladUldk catch (blad) {
          expect(blad.wiadomosc, contains('Nie znaleziono'));
          expect(blad.coZrobic, isNotNull);
        }
      },
    );

    test('brak geometrii w odpowiedzi to błąd, nie puste granice', () {
      expect(
        () => KlientUldk.odczytaj(
          '0\n|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138',
          '061506_2.0007.138',
          4326,
        ),
        throwsA(isA<BladUldk>()),
      );
    });

    test('pusta odpowiedź to błąd', () {
      expect(
        () => KlientUldk.odczytaj('', '061506_2.0007.138', 4326),
        throwsA(isA<BladUldk>()),
      );
    });
  });

  group('wzorzec identyfikatora', () {
    test('rozpoznaje numery z wniosku', () {
      for (final numer in [
        '061506_2.0007.138',
        '061506_2.0007.138/2',
        '146509_8.0601.AR_12.55',
      ]) {
        expect(
          KlientUldk.wzorzecIdentyfikatora.hasMatch(numer),
          isTrue,
          reason: numer,
        );
      }
    });

    test('nazwa obrębu z numerem nie jest identyfikatorem', () {
      expect(
        KlientUldk.wzorzecIdentyfikatora.hasMatch('Brzeziny 138'),
        isFalse,
      );
    });
  });

  group('pobierz', () {
    test('po pełnym identyfikatorze pyta o GetParcelById', () async {
      Uri? zapytanie;
      final klient = KlientUldk(
        klient: MockClient((zadanie) async {
          zapytanie = zadanie.url;
          return http.Response(
            '0\n$obrys|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138',
            200,
          );
        }),
      );

      final dzialka = await klient.pobierz('061506_2.0007.138');
      expect(dzialka.identyfikator, '061506_2.0007.138');
      expect(zapytanie!.queryParameters['request'], 'GetParcelById');
      expect(zapytanie!.queryParameters['result'], contains('geom_wkt'));
    });

    test('po nazwie obrębu pyta o GetParcelByIdOrNr', () async {
      Uri? zapytanie;
      final klient = KlientUldk(
        klient: MockClient((zadanie) async {
          zapytanie = zadanie.url;
          return http.Response(
            '0\n$obrys|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138',
            200,
          );
        }),
      );

      await klient.pobierz('Brzeziny 138');
      expect(zapytanie!.queryParameters['request'], 'GetParcelByIdOrNr');
    });

    test(
      'brak sieci kończy się zdaniem o internecie i uwagą o trybie offline',
      () async {
        final klient = KlientUldk(
          klient: MockClient(
            (_) async => throw http.ClientException('brak sieci'),
          ),
        );
        try {
          await klient.pobierz('061506_2.0007.138');
          fail('powinien polecieć BladUldk');
        } on BladUldk catch (blad) {
          expect(blad.wiadomosc, contains('połączyć'));
          expect(blad.coZrobic, contains('bez internetu'));
        }
      },
    );

    test('błąd usługi 500 mówi, co zrobić', () async {
      final klient = KlientUldk(
        klient: MockClient((_) async => http.Response('awaria', 500)),
      );
      try {
        await klient.pobierz('061506_2.0007.138');
        fail('powinien polecieć BladUldk');
      } on BladUldk catch (blad) {
        expect(blad.wiadomosc, contains('500'));
        expect(blad.coZrobic, isNotNull);
      }
    });

    test('puste pole szukania nie łączy się z usługą', () async {
      var proby = 0;
      final klient = KlientUldk(
        klient: MockClient((_) async {
          proby++;
          return http.Response('0\n', 200);
        }),
      );
      await expectLater(klient.pobierz('   '), throwsA(isA<BladUldk>()));
      expect(proby, 0);
    });
  });

  group('wybór z listy: województwo → powiat → gmina → obręb', () {
    // Rolnik zna swoją gminę i obręb, ale nie zna zapisu „141201_2.0012".
    // Działkę dzierżawioną, której nie ma we wniosku, dodaje się właśnie
    // przez wybór z listy.
    test('czyta listę jednostek i układa ją alfabetycznie', () {
      final gminy = KlientUldk.odczytajJednostki(
        '0\nŻyrzyn|061506_2\nLubartów|061505_1\nKamionka|061504_5\n',
        PoziomPodzialu.gmina,
      );

      expect(
        [for (final g in gminy) g.nazwa],
        ['Kamionka', 'Lubartów', 'Żyrzyn'],
      );
      expect(gminy.first.teryt, '061504_5');
    });

    test('wiersza, którego nie rozumiemy, nie zgadujemy', () {
      final obreby = KlientUldk.odczytajJednostki(
        '0\nBrzeziny|061506_2.0007\nśmieć bez kreski\n|061506_2.0008\n',
        PoziomPodzialu.obreb,
      );

      expect(obreby, hasLength(1));
      expect(obreby.single.nazwa, 'Brzeziny');
    });

    test('zła odpowiedź usługi to zdanie dla rolnika', () {
      expect(
        () => KlientUldk.odczytajJednostki('-1\nbłąd', PoziomPodzialu.powiat),
        throwsA(
          isA<BladUldk>().having(
            (b) => b.coZrobic,
            'coZrobic',
            contains('pełny numer'),
          ),
        ),
      );
    });

    test('pyta usługę o właściwy szczebel i jednostkę nadrzędną', () async {
      late Uri zapytanie;
      final klient = KlientUldk(
        klient: MockClient((zadanie) async {
          zapytanie = zadanie.url;
          return http.Response('0\nBrzeziny|061506_2.0007\n', 200);
        }),
      );

      final obreby = await klient.jednostki(
        poziom: PoziomPodzialu.obreb,
        terytNadrzednej: '061506_2',
      );

      expect(zapytanie.queryParameters['request'], 'GetRegions');
      expect(zapytanie.queryParameters['result'], 'region,teryt');
      expect(zapytanie.queryParameters['commune'], '061506_2');
      expect(obreby.single.nazwa, 'Brzeziny');
    });

    test('województw nic nie poprzedza', () async {
      late Uri zapytanie;
      final klient = KlientUldk(
        klient: MockClient((zadanie) async {
          zapytanie = zadanie.url;
          return http.Response('0\nlubelskie|06\n', 200);
        }),
      );

      await klient.jednostki(poziom: PoziomPodzialu.wojewodztwo);

      expect(zapytanie.queryParameters['request'], 'GetVoivodeships');
      expect(zapytanie.queryParameters.containsKey('voivodeship'), isFalse);
    });

    test('bez jednostki nadrzędnej nie pytamy usługi', () async {
      var pytano = false;
      final klient = KlientUldk(
        klient: MockClient((_) async {
          pytano = true;
          return http.Response('0\n', 200);
        }),
      );

      await expectLater(
        klient.jednostki(poziom: PoziomPodzialu.gmina),
        throwsA(isA<BladUldk>()),
      );
      expect(pytano, isFalse);
    });

    test('obręb i numer składają się w pełny identyfikator działki', () {
      const obreb = JednostkaTerytorialna(
        nazwa: 'Brzeziny',
        teryt: '061506_2.0007',
      );

      final numer = KlientUldk.pelnyNumer(obreb, ' 138 ');

      expect(numer, '061506_2.0007.138');
      // Taki zapis usługa rozpoznaje jako pełny identyfikator.
      expect(KlientUldk.wzorzecIdentyfikatora.hasMatch(numer), isTrue);
    });

    test('numer z ułamkiem też jest pełnym identyfikatorem', () {
      const obreb = JednostkaTerytorialna(
        nazwa: 'Brzeziny',
        teryt: '061506_2.0007',
      );

      final numer = KlientUldk.pelnyNumer(obreb, '138/4');

      expect(KlientUldk.wzorzecIdentyfikatora.hasMatch(numer), isTrue);
    });
  });
}
