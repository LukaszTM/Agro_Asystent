import 'dart:io';

import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SlownikRegul slownik;

  setUpAll(() {
    final tekst = File('assets/dane/reguly_prawne.json').readAsStringSync();
    slownik = SlownikRegul.zTekstuJson(tekst);
  });

  group('słownik reguł', () {
    test('ma wersję i datę obowiązywania', () {
      expect(slownik.wersja, isNotEmpty);
      expect(slownik.obowiazujeOd.year, greaterThanOrEqualTo(2026));
    });

    test('każdy obowiązek ma podstawę prawną i status weryfikacji', () {
      for (final obowiazek in slownik.obowiazki) {
        expect(obowiazek.podstawa, isNotEmpty, reason: obowiazek.id);
        expect(obowiazek.statusWeryfikacji, isNotEmpty, reason: obowiazek.id);
      }
    });

    test('każdy termin wskazuje istniejący obowiązek', () {
      for (final termin in slownik.terminy) {
        expect(
          slownik.obowiazek(termin.idObowiazku),
          isNotNull,
          reason: 'Termin ${termin.id} wskazuje na ${termin.idObowiazku}.',
        );
      }
    });

    test('limit azotu z nawozów naturalnych jest w danych, nie w kodzie', () {
      final limit = slownik
          .obowiazek('program_azotanowy_ewidencja')
          ?.limit('limit_azotu_z_nawozow_naturalnych');
      expect(limit, isNotNull);
      expect(limit!.wartosc, 170);
      expect(limit.jednostka, 'kg N/ha/rok');
    });
  });

  group('włączanie obowiązków', () {
    test('małe gospodarstwo bez zwierząt: tylko obowiązki powszechne', () {
      const profil = ProfilGospodarstwa(powierzchniaUrHa: 4.5);
      final idki = slownik.obowiazkiDla(profil).map((o) => o.id);
      expect(idki, contains('ewidencja_sor'));
      expect(idki, contains('wniosek_o_platnosci'));
      expect(idki, isNot(contains('program_azotanowy_ewidencja')));
      expect(idki, isNot(contains('warunkowosc')));
    });

    test('10 ha włącza ewidencję nawożenia, ale nie warunkowość', () {
      const profil = ProfilGospodarstwa(powierzchniaUrHa: 10);
      final idki = slownik.obowiazkiDla(profil).map((o) => o.id);
      // Program azotanowy: „od 10 ha"; warunkowość: „powyżej 10 ha".
      expect(idki, contains('program_azotanowy_ewidencja'));
      expect(idki, isNot(contains('warunkowosc')));
    });

    test('duże gospodarstwo wymaga planu nawożenia azotem', () {
      const profil = ProfilGospodarstwa(powierzchniaUrHa: 120);
      final idki = slownik.obowiazkiDla(profil).map((o) => o.id);
      expect(idki, contains('program_azotanowy_plan'));
      expect(idki, contains('warunkowosc'));
    });

    test('60 DJP samo nie wystarcza do planu, 61 już tak', () {
      const szescdziesiat = ProfilGospodarstwa(djp: 60);
      const szescdziesiatJeden = ProfilGospodarstwa(djp: 61);
      expect(
        slownik.obowiazek('program_azotanowy_plan')!.ocena(szescdziesiat),
        Ocena.nieDotyczy,
      );
      expect(
        slownik.obowiazek('program_azotanowy_plan')!.ocena(szescdziesiatJeden),
        Ocena.dotyczy,
      );
    });

    test('ekoschemat włącza rejestr zabiegów agrotechnicznych', () {
      const profil = ProfilGospodarstwa(
        powierzchniaUrHa: 8,
        zadeklarowanyEkoschemat: true,
      );
      expect(
        slownik.obowiazkiDla(profil).map((o) => o.id),
        contains('ekoschematy_rejestr'),
      );
    });
  });

  group('nieznane dane nie są zgadywane', () {
    test('miara z nowszego słownika daje wynik „nie wiadomo"', () {
      final obowiazek = Obowiazek.zJson({
        'id': 'nowy_obowiazek',
        'nazwa': 'Obowiązek z przyszłej aktualizacji',
        'progi': [
          {'miara': 'liczba_ulow', 'operator': '>=', 'wartosc': 5},
        ],
      });
      expect(
        obowiazek.ocena(const ProfilGospodarstwa(powierzchniaUrHa: 50)),
        Ocena.nieWiadomo,
      );
    });

    test('obowiązek bez progów dotyczy każdego', () {
      final obowiazek = Obowiazek.zJson({
        'id': 'powszechny',
        'nazwa': 'Obowiązek powszechny',
        'progi': <Map<String, dynamic>>[],
      });
      expect(obowiazek.ocena(const ProfilGospodarstwa()), Ocena.dotyczy);
    });
  });
}
