import 'dart:convert';

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

    test('po nazwie obrębu najpierw szuka, potem bierze granice po '
        'identyfikatorze', () async {
      // Usługa na „nazwa numer" oddaje listę (pierwszy wiersz to liczba
      // wyników), a granice daje dopiero GetParcelById.
      final zapytania = <String>[];
      final klient = KlientUldk(
        klient: MockClient((zadanie) async {
          final request = zadanie.url.queryParameters['request']!;
          zapytania.add(request);
          return http.Response.bytes(
            utf8.encode(switch (request) {
              'GetParcelByIdOrNr' => '1\n061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138',
              _ =>
                '0\n$obrys|061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138',
            }),
            200,
          );
        }),
      );

      final dzialka = await klient.pobierz('Brzeziny 138');

      expect(zapytania, ['GetParcelByIdOrNr', 'GetParcelById']);
      expect(dzialka.identyfikator, '061506_2.0007.138');
    });

    test('kilka działek o tej nazwie to wybór rolnika, nie pierwsza z brzegu', () async {
      final klient = KlientUldk(
        klient: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              '2\n'
              '061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n'
              '101106_2.0002.138|łódzkie|łowicki|Łowicz|Brzeziny|138\n',
            ),
            200,
          ),
        ),
      );

      await expectLater(
        klient.pobierz('Brzeziny 138'),
        throwsA(
          isA<BladUldk>().having(
            (b) => b.wiadomosc,
            'wiadomosc',
            contains('2 działek'),
          ),
        ),
      );
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

  group('szukanie po nazwie miejscowości i numerze', () {
    // Rolnik zna wieś i numer z umowy, ale nie zna zapisu „141201_2.0012".
    // Usługa nie ma list województw ani gmin — umie za to oddać wszystkie
    // działki o danym numerze w obrębach o danej nazwie.
    test('czyta listę znalezionych działek z gminą i powiatem', () {
      final znalezione = KlientUldk.odczytajZnalezione(
        '2\n'
        '101106_2.0002.138|łódzkie|łowicki|Łowicz|Brzeziny|138\n'
        '061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n',
        obreb: 'Brzeziny',
        numer: '138',
      );

      expect(znalezione, hasLength(2));
      // Ułożone po położeniu, żeby rolnik szukał gminy jak w spisie.
      expect(znalezione.first.gmina, 'Lubartów');
      expect(znalezione.first.teryt, '061506_2.0007.138');
      expect(znalezione.first.kodWojewodztwa, '06');
      expect(znalezione.first.polozenie, 'Lubartów, lubartowski, lubelskie');
    });

    test('brak wyników to zdanie dla rolnika, nie pusta lista', () {
      expect(
        () => KlientUldk.odczytajZnalezione(
          '-1 brak wyników',
          obreb: 'Brzeziny',
          numer: '999',
        ),
        throwsA(
          isA<BladUldk>()
              .having((b) => b.wiadomosc, 'wiadomosc', contains('nr 999'))
              .having((b) => b.coZrobic, 'coZrobic', contains('pełny numer')),
        ),
      );
    });

    test('wiersza, którego nie rozumiemy, nie zgadujemy', () {
      final znalezione = KlientUldk.odczytajZnalezione(
        '3\n'
        '061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n'
        'śmieć bez kresek\n'
        '|a|b\n',
        obreb: 'Brzeziny',
        numer: '138',
      );

      expect(znalezione, hasLength(1));
    });

    test('pyta usługę o „nazwa numer" i czyta polskie znaki', () async {
      late Uri zapytanie;
      final klient = KlientUldk(
        klient: MockClient((zadanie) async {
          zapytanie = zadanie.url;
          return http.Response.bytes(
            utf8.encode(
              '1\n061506_2.0010.5|lubelskie|lubartowski|Żyrzyn|Żerdź|5\n',
            ),
            200,
          );
        }),
      );

      final znalezione = await klient.szukajPoNazwie(
        obreb: ' Żerdź ',
        numer: ' 5 ',
      );

      expect(zapytanie.queryParameters['request'], 'GetParcelByIdOrNr');
      expect(zapytanie.queryParameters['id'], 'Żerdź 5');
      expect(zapytanie.queryParameters['result'], isNot(contains('geom')));
      expect(znalezione.single.gmina, 'Żyrzyn');
    });

    test('bez nazwy albo numeru nie pytamy usługi', () async {
      var pytano = false;
      final klient = KlientUldk(
        klient: MockClient((_) async {
          pytano = true;
          return http.Response('1\n', 200);
        }),
      );

      await expectLater(
        klient.szukajPoNazwie(obreb: 'Brzeziny', numer: '  '),
        throwsA(isA<BladUldk>()),
      );
      expect(pytano, isFalse);
    });

    test('brak sieci mówi, że szukanie wymaga internetu', () async {
      final klient = KlientUldk(
        klient: MockClient(
          (_) async => throw http.ClientException('brak sieci'),
        ),
      );

      await expectLater(
        klient.szukajPoNazwie(obreb: 'Brzeziny', numer: '138'),
        throwsA(
          isA<BladUldk>().having(
            (b) => b.coZrobic,
            'coZrobic',
            contains('pełny numer'),
          ),
        ),
      );
    });
  });
}
