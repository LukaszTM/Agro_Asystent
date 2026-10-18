import 'dart:convert';
import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/funkcje/pogoda/klient_pogody.dart';
import 'package:agro_asystent/funkcje/pogoda/pogoda.dart';
import 'package:agro_asystent/funkcje/pogoda/usluga_pogody.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pogoda — dodatek, który nie może popsuć reszty programu.
///
/// Czego pilnują testy: położenie liczymy z granic działek (bez pytania
/// rolnika o adres), bez internetu pokazujemy ostatni zapis z datą,
/// a brakujących wartości nie zastępujemy zerami.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-pogoda');
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
      'urzadzenie': 'komputer',
    });
  });

  tearDown(() => baza.close());

  /// Odpowiedź w kształcie, w jakim daje ją serwis MET.
  String odpowiedzSerwisu({int godzin = 30}) {
    final poczatek = DateTime.utc(2026, 10, 18, 6);
    return jsonEncode({
      'properties': {
        'timeseries': [
          for (var numer = 0; numer < godzin; numer++)
            {
              'time': poczatek
                  .add(Duration(hours: numer))
                  .toIso8601String()
                  .replaceFirst('.000', ''),
              'data': {
                'instant': {
                  'details': {
                    'air_temperature': 8.0 + numer % 5,
                    'wind_speed': 2.0 + numer % 3,
                    'relative_humidity': 80.0,
                    'cloud_area_fraction': 50.0,
                  },
                },
                if (numer < godzin - 1)
                  'next_1_hours': {
                    'summary': {'symbol_code': 'cloudy'},
                    'details': {'precipitation_amount': numer == 2 ? 1.5 : 0.0},
                  },
              },
            },
        ],
      },
    });
  }

  Future<void> dodajDzialke({
    required String identyfikator,
    required double dlugosc,
    required double szerokosc,
  }) => RepozytoriumDzialek(baza).zapisz(
    gospodarstwoId: 'g1',
    zUldk: DzialkaZUldk(
      identyfikator: identyfikator,
      wkt:
          'POLYGON(($dlugosc $szerokosc, ${dlugosc + 0.002} $szerokosc, '
          '${dlugosc + 0.002} ${szerokosc + 0.002}, '
          '$dlugosc ${szerokosc + 0.002}, $dlugosc $szerokosc))',
      srid: 4326,
    ),
    urzadzenie: 'komputer',
  );

  group('położenie gospodarstwa', () {
    test('liczy się ze środków działek, bez pytania rolnika', () async {
      await dodajDzialke(
        identyfikator: '141201_2.0012.1',
        dlugosc: 21.0,
        szerokosc: 52.0,
      );
      await dodajDzialke(
        identyfikator: '141201_2.0012.2',
        dlugosc: 21.1,
        szerokosc: 52.1,
      );

      final polozenie = PolozenieGospodarstwa.zDzialek(
        await RepozytoriumDzialek(baza).wszystkie('g1'),
      );

      expect(polozenie, isNotNull);
      expect(polozenie!.dlugosc, closeTo(21.051, 0.01));
      expect(polozenie.szerokosc, closeTo(52.051, 0.01));
    });

    test('bez działek z granicami nie zgadujemy miejsca', () {
      expect(PolozenieGospodarstwa.zDzialek(const []), isNull);
    });
  });

  group('klient serwisu', () {
    test('czyta godziny, opad i wiatr', () async {
      late http.Request zadanie;
      final klient = KlientPogody(
        klient: MockClient((wyslane) async {
          zadanie = wyslane;
          return http.Response(odpowiedzSerwisu(), 200);
        }),
      );

      final prognoza = await klient.pobierz(
        szerokosc: 52.0512345,
        dlugosc: 21.0512345,
        teraz: DateTime(2026, 10, 18, 9),
      );

      // Regulamin usługi każe skracać współrzędne i przedstawiać się.
      expect(zadanie.url.queryParameters['lat'], '52.0512');
      expect(zadanie.url.queryParameters['lon'], '21.0512');
      expect(zadanie.headers['User-Agent'], contains('AgroAsystent'));

      expect(prognoza.godziny, hasLength(30));
      expect(prognoza.zrodlo, contains('MET'));
      expect(prognoza.dni.length, greaterThanOrEqualTo(2));
      expect(prognoza.godziny.first.wiatr, 2.0);
    });

    test(
      'ostatnia godzina bez opadu zostaje bez opadu, a nie z zerem',
      () async {
        final klient = KlientPogody(
          klient: MockClient(
            (_) async => http.Response(odpowiedzSerwisu(), 200),
          ),
        );

        final prognoza = await klient.pobierz(
          szerokosc: 52.0,
          dlugosc: 21.0,
          teraz: DateTime(2026, 10, 18, 9),
        );

        expect(prognoza.godziny.last.opad, isNull);
        expect(prognoza.godziny.last.opadOpis, 'brak danych');
      },
    );

    test(
      'brak sieci to zdanie dla rolnika, nie wyjątek z biblioteki',
      () async {
        final klient = KlientPogody(
          klient: MockClient(
            (_) async => throw http.ClientException('brak sieci'),
          ),
        );

        await expectLater(
          klient.pobierz(szerokosc: 52.0, dlugosc: 21.0),
          throwsA(
            isA<BladPogody>().having(
              (blad) => blad.coZrobic,
              'coZrobic',
              contains('internet'),
            ),
          ),
        );
      },
    );

    test('prośba serwisu o przerwę ma własny komunikat', () async {
      final klient = KlientPogody(
        klient: MockClient((_) async => http.Response('', 429)),
      );

      await expectLater(
        klient.pobierz(szerokosc: 52.0, dlugosc: 21.0),
        throwsA(
          isA<BladPogody>().having(
            (blad) => blad.wiadomosc,
            'wiadomość',
            contains('przerwę'),
          ),
        ),
      );
    });
  });

  group('usługa pogody', () {
    UslugaPogody uslugaZ(MockClient klient) => UslugaPogody(
      zapis: RepozytoriumPogody(baza),
      dzialki: RepozytoriumDzialek(baza),
      klient: KlientPogody(klient: klient),
    );

    test('bez działek mówi, że nie wie, gdzie leży gospodarstwo', () async {
      var pytano = false;
      final stan = await uslugaZ(
        MockClient((_) async {
          pytano = true;
          return http.Response(odpowiedzSerwisu(), 200);
        }),
      ).dla('g1', teraz: DateTime(2026, 10, 18, 9));

      expect(stan.brakPolozenia, isTrue);
      expect(stan.pusty, isTrue);
      expect(pytano, isFalse, reason: 'nie ma po co pytać serwisu');
    });

    test('świeży zapis wystarcza — serwisu nie męczymy co minutę', () async {
      await dodajDzialke(
        identyfikator: '141201_2.0012.1',
        dlugosc: 21.0,
        szerokosc: 52.0,
      );
      var pobrania = 0;
      final usluga = uslugaZ(
        MockClient((_) async {
          pobrania++;
          return http.Response(odpowiedzSerwisu(), 200);
        }),
      );

      await usluga.dla('g1', teraz: DateTime(2026, 10, 18, 9));
      await usluga.dla('g1', teraz: DateTime(2026, 10, 18, 10));

      expect(pobrania, 1);
    });

    test(
      'bez internetu zostaje ostatni zapis — z datą, nie z pustką',
      () async {
        await dodajDzialke(
          identyfikator: '141201_2.0012.1',
          dlugosc: 21.0,
          szerokosc: 52.0,
        );
        await uslugaZ(
          MockClient((_) async => http.Response(odpowiedzSerwisu(), 200)),
        ).dla('g1', teraz: DateTime(2026, 10, 18, 9));

        final stan = await uslugaZ(
          MockClient((_) async => throw http.ClientException('brak sieci')),
        ).dla('g1', teraz: DateTime(2026, 10, 19, 9));

        expect(stan.prognoza, isNotNull);
        expect(stan.prognoza!.pobrano, DateTime(2026, 10, 18, 9));
        expect(stan.prognoza!.starsza(DateTime(2026, 10, 19, 9)), isTrue);
        expect(stan.blad, isNotNull);
      },
    );
  });
}
