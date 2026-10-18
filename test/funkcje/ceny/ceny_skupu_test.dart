import 'dart:io';

import 'package:agro_asystent/funkcje/ceny/ceny_skupu.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ceny skupu — notowania urzędowe dobierane do regionu gospodarstwa.
///
/// Czego pilnują testy: regionu nie pytamy rolnika (wynika z działek),
/// ceny z obcego województwa nie podstawiamy, a pusty plik zostaje pusty.
void main() {
  DzialkaEwidencyjna dzialka(String id, String? wojewodztwo) =>
      DzialkaEwidencyjna(id: id, identyfikator: id, wojewodztwo: wojewodztwo);

  const slownik = SlownikCen(
    wersja: '2026.10.12.1',
    zrodlo: 'ZSRIR',
    zastrzezenie: 'To notowanie regionu, nie oferta skupu.',
    produkty: [
      ProduktCenowy(
        nazwa: 'Pszenica konsumpcyjna',
        jednostka: 'zł/t',
        ceny: [
          CenaRegionu(
            region: 'mazowieckie',
            cena: 920.5,
            status: 'potwierdzone',
          ),
          CenaRegionu(region: 'kraj', cena: 905, status: 'potwierdzone'),
        ],
      ),
      ProduktCenowy(
        nazwa: 'Żyto',
        jednostka: 'zł/t',
        ceny: [
          CenaRegionu(region: 'kraj', cena: 700, status: 'do_weryfikacji'),
        ],
      ),
      ProduktCenowy(
        nazwa: 'Mleko',
        jednostka: 'zł/l',
        ceny: [
          CenaRegionu(region: 'podlaskie', cena: 2.4, status: 'potwierdzone'),
        ],
      ),
    ],
  );

  group('region gospodarstwa', () {
    test('bierze się z działek, a przy kilku — ten najczęstszy', () {
      final wojewodztwo = CenySkupu.wojewodztwo([
        dzialka('a', 'Mazowieckie'),
        dzialka('b', 'mazowieckie'),
        dzialka('c', 'lubelskie'),
      ]);

      expect(wojewodztwo, 'mazowieckie');
    });

    test('bez działek z województwem nie zgadujemy regionu', () {
      expect(CenySkupu.wojewodztwo([dzialka('a', null)]), isNull);
      expect(CenySkupu.wojewodztwo(const []), isNull);
    });
  });

  group('dobór ceny', () {
    test('woli notowanie z województwa gospodarstwa', () {
      final ceny = CenySkupu.dlaGospodarstwa(
        slownik,
        wojewodztwo: 'mazowieckie',
      );

      final pszenica = ceny.firstWhere((c) => c.produkt.startsWith('Pszenica'));
      expect(pszenica.cena, 920.5);
      expect(pszenica.zRegionuGospodarstwa, isTrue);
      expect(pszenica.cenaOpis, '920,50 zł/t');
    });

    test('gdy regionu nie ma, bierze notowanie krajowe i mówi o tym', () {
      final ceny = CenySkupu.dlaGospodarstwa(slownik, wojewodztwo: 'lubelskie');

      final pszenica = ceny.firstWhere((c) => c.produkt.startsWith('Pszenica'));
      expect(pszenica.cena, 905);
      expect(pszenica.region, 'kraj');
      expect(pszenica.zRegionuGospodarstwa, isFalse);
    });

    test('ceny z obcego województwa nie podstawiamy', () {
      final ceny = CenySkupu.dlaGospodarstwa(slownik, wojewodztwo: 'lubelskie');

      // Mleko ma notowanie tylko dla podlaskiego — dla lubelskiego nie ma
      // nic i tak ma zostać.
      expect(ceny.where((c) => c.produkt == 'Mleko'), isEmpty);
    });

    test('odczyt do weryfikacji jedzie z ceną', () {
      final ceny = CenySkupu.dlaGospodarstwa(slownik, wojewodztwo: 'kraj');

      final zyto = ceny.firstWhere((c) => c.produkt == 'Żyto');
      expect(zyto.doWeryfikacji, isTrue);
    });
  });

  group('plik notowań w programie', () {
    test('jest pusty, dopóki nikt nie uruchomi skryptu', () {
      final zPliku = SlownikCen.zTekstuJson(
        File('assets/dane/ceny_skupu.json').readAsStringSync(),
      );

      // Cen nie wolno zmyślić — pusty plik jest uczciwszy niż wymyślona
      // liczba, na podstawie której ktoś sprzedaje zboże.
      expect(zPliku.pusty, isTrue);
      expect(zPliku.produkty, isEmpty);
      expect(zPliku.zastrzezenie, isNotEmpty);
      expect(zPliku.zrodlo, contains('ZSRIR'));
    });
  });
}
