import 'dart:convert';

import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dzialki/wybor_jednostek.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Wybór obrębu krok po kroku — dla działek spoza wniosku
/// (dzierżawa, kupno po złożeniu wniosku).
void main() {
  /// Usługa odpowiada inaczej na każdym szczeblu; liczymy też zapytania,
  /// żeby sprawdzić, czy listy nie pobierają się po kilka razy.
  ({WyborJednostek wybor, List<String> zapytania}) zbuduj() {
    final zapytania = <String>[];
    final klient = KlientUldk(
      klient: MockClient((zadanie) async {
        final request = zadanie.url.queryParameters['request']!;
        zapytania.add(request);
        final tresc = switch (request) {
          'GetVoivodeships' => '0\nlubelskie|06\nmazowieckie|14\n',
          'GetCounties' => '0\nlubartowski|0615\n',
          'GetCommunes' => '0\nLubartów|061506_2\nKamionka|061504_5\n',
          'GetRegions' => '0\nBrzeziny|061506_2.0007\n',
          _ => '-1\n',
        };
        return http.Response.bytes(
          // Polskie znaki idą w UTF-8, tak jak z prawdziwej usługi.
          utf8.encode(tresc),
          200,
        );
      }),
    );
    return (wybor: WyborJednostek(klient: klient), zapytania: zapytania);
  }

  test('prowadzi przez cztery szczeble i składa numer działki', () async {
    final (:wybor, :zapytania) = zbuduj();

    expect(wybor.biezacy, PoziomPodzialu.wojewodztwo);
    final wojewodztwa = await wybor.lista(PoziomPodzialu.wojewodztwo);
    wybor.wybierz(PoziomPodzialu.wojewodztwo, wojewodztwa.first);

    expect(wybor.biezacy, PoziomPodzialu.powiat);
    final powiaty = await wybor.lista(PoziomPodzialu.powiat);
    wybor.wybierz(PoziomPodzialu.powiat, powiaty.single);

    final gminy = await wybor.lista(PoziomPodzialu.gmina);
    wybor.wybierz(
      PoziomPodzialu.gmina,
      gminy.firstWhere((g) => g.nazwa == 'Lubartów'),
    );

    final obreby = await wybor.lista(PoziomPodzialu.obreb);
    wybor.wybierz(PoziomPodzialu.obreb, obreby.single);

    expect(wybor.gotowy, isTrue);
    expect(wybor.opisWyboru, 'lubelskie • lubartowski • Lubartów • Brzeziny');
    expect(wybor.numerDzialki('138'), '061506_2.0007.138');
    expect(zapytania, hasLength(4));
  });

  test('zmiana gminy kasuje wybrany wcześniej obręb', () async {
    final (:wybor, :zapytania) = zbuduj();
    wybor.wybierz(
      PoziomPodzialu.wojewodztwo,
      const JednostkaTerytorialna(nazwa: 'lubelskie', teryt: '06'),
    );
    wybor.wybierz(
      PoziomPodzialu.powiat,
      const JednostkaTerytorialna(nazwa: 'lubartowski', teryt: '0615'),
    );
    final gminy = await wybor.lista(PoziomPodzialu.gmina);
    wybor.wybierz(PoziomPodzialu.gmina, gminy.first);
    final obreby = await wybor.lista(PoziomPodzialu.obreb);
    wybor.wybierz(PoziomPodzialu.obreb, obreby.single);

    wybor.wybierz(PoziomPodzialu.gmina, gminy.last);

    expect(wybor.obreb, isNull);
    expect(wybor.gotowy, isFalse);
    expect(wybor.biezacy, PoziomPodzialu.obreb);
  });

  test('powrót na wyższy szczebel nie pyta usługi drugi raz', () async {
    final (:wybor, :zapytania) = zbuduj();
    final wojewodztwa = await wybor.lista(PoziomPodzialu.wojewodztwo);
    wybor.wybierz(PoziomPodzialu.wojewodztwo, wojewodztwa.first);
    await wybor.lista(PoziomPodzialu.powiat);

    wybor.cofnij(PoziomPodzialu.wojewodztwo);
    await wybor.lista(PoziomPodzialu.wojewodztwo);

    expect(zapytania, ['GetVoivodeships', 'GetCounties']);
  });

  test('bez wybranego obrębu nie ma numeru działki', () async {
    final (:wybor, zapytania: _) = zbuduj();

    expect(wybor.numerDzialki('138'), isNull);
    expect(await wybor.lista(PoziomPodzialu.gmina), isEmpty);
  });

  test('pusty numer działki to brak numeru, a nie sam obręb', () {
    final (:wybor, zapytania: _) = zbuduj();
    wybor.wybierz(
      PoziomPodzialu.obreb,
      const JednostkaTerytorialna(nazwa: 'Brzeziny', teryt: '061506_2.0007'),
    );

    expect(wybor.numerDzialki('   '), isNull);
  });
}
