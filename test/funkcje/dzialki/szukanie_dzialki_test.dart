import 'dart:convert';
import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dzialki/szukanie_dzialki.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Szukanie działki spoza wniosku: województwo → miejscowość → numer.
///
/// Czego pilnują testy: lista województw jedzie z aplikacją jako dane
/// (usługa nie umie jej podać), wybór województwa zawęża wynik, a gdy
/// w województwie nic nie ma, mówimy, ile jest w kraju — zamiast
/// podstawić działkę z innego końca Polski.
void main() {
  const odpowiedz =
      '3\n'
      '061506_2.0007.138|lubelskie|lubartowski|Lubartów|Brzeziny|138\n'
      '101106_2.0002.138|łódzkie|łowicki|Łowicz|Brzeziny|138\n'
      '061602_2.0004.138|lubelskie|łukowski|Adamów|Brzeziny|138\n';

  KlientUldk klient([String tresc = odpowiedz]) => KlientUldk(
    klient: MockClient(
      (_) async => http.Response.bytes(utf8.encode(tresc), 200),
    ),
  );

  group('lista województw z pliku', () {
    final zPliku = SlownikWojewodztw.zTekstuJson(
      File('assets/dane/wojewodztwa.json').readAsStringSync(),
    );

    test('ma szesnaście województw z kodami TERYT', () {
      expect(zPliku.wojewodztwa, hasLength(16));
      expect(zPliku.poKodzie('06')?.nazwa, 'lubelskie');
      expect(zPliku.poKodzie('14')?.nazwa, 'mazowieckie');
      expect(zPliku.poKodzie('99'), isNull);
      // Kody parzyste 02–32 — każdy identyfikator działki zaczyna się
      // od jednego z nich.
      expect(zPliku.wojewodztwa.map((w) => w.teryt), [
        for (var kod = 2; kod <= 32; kod += 2) kod.toString().padLeft(2, '0'),
      ]);
    });
  });

  group('zawężanie do województwa', () {
    final wojewodztwa = SlownikWojewodztw.zTekstuJson(
      File('assets/dane/wojewodztwa.json').readAsStringSync(),
    );

    test('bez województwa oddaje wszystko z kraju', () async {
      final szukanie =
          SzukanieDzialkiPoNazwie(klient: klient(), wojewodztwa: wojewodztwa)
            ..obreb = 'Brzeziny'
            ..numer = '138';

      final znalezione = await szukanie.szukaj();

      expect(znalezione, hasLength(3));
      expect(szukanie.znalezioneWKraju, 3);
    });

    test('z województwem zostają tylko działki z jego kodu', () async {
      final szukanie =
          SzukanieDzialkiPoNazwie(klient: klient(), wojewodztwa: wojewodztwa)
            ..wojewodztwo = wojewodztwa.poKodzie('06')
            ..obreb = 'Brzeziny'
            ..numer = '138';

      final znalezione = await szukanie.szukaj();

      expect(znalezione.map((d) => d.gmina), ['Adamów', 'Lubartów']);
      expect(szukanie.znalezioneWKraju, 3);
    });

    test('w złym województwie nie podstawiamy działki z innego', () async {
      final szukanie =
          SzukanieDzialkiPoNazwie(klient: klient(), wojewodztwa: wojewodztwa)
            ..wojewodztwo = wojewodztwa.poKodzie('14')
            ..obreb = 'Brzeziny'
            ..numer = '138';

      await expectLater(
        szukanie.szukaj(),
        throwsA(
          isA<BladUldk>().having(
            (b) => b.wiadomosc,
            'wiadomosc',
            allOf(contains('mazowieckie'), contains('jest 3 takich')),
          ),
        ),
      );
      expect(szukanie.znalezione, isEmpty);
    });

    test('nie szuka bez nazwy albo numeru', () {
      final szukanie = SzukanieDzialkiPoNazwie(klient: klient());

      expect(szukanie.moznaSzukac, isFalse);
      szukanie.obreb = 'Brzeziny';
      expect(szukanie.moznaSzukac, isFalse);
      szukanie.numer = '138';
      expect(szukanie.moznaSzukac, isTrue);
    });

    test('zmiana wpisu czyści stary wynik', () async {
      final szukanie = SzukanieDzialkiPoNazwie(klient: klient())
        ..obreb = 'Brzeziny'
        ..numer = '138';
      await szukanie.szukaj();
      expect(szukanie.znalezione, isNotEmpty);

      szukanie.wyczyscWynik();

      expect(szukanie.znalezione, isEmpty);
      expect(szukanie.znalezioneWKraju, 0);
    });
  });
}
