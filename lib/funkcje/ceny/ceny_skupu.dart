import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../dzialki/repozytorium_dzialek.dart';

/// Cena jednego produktu w jednym regionie.
class CenaRegionu {
  const CenaRegionu({
    required this.region,
    required this.cena,
    required this.status,
  });

  factory CenaRegionu.zJson(Map<String, dynamic> json) => CenaRegionu(
    region: (json['region'] as String).toLowerCase(),
    cena: (json['cena'] as num).toDouble(),
    status: json['status'] as String? ?? 'do_weryfikacji',
  );

  /// Nazwa regionu małymi literami: województwo albo „kraj".
  final String region;

  final double cena;

  /// `potwierdzone` albo `do_weryfikacji` — jak przy danych z przepisów.
  final String status;

  bool get doWeryfikacji => status != 'potwierdzone';
}

/// Produkt z notowań: zboże, rzepak, mleko, żywiec.
class ProduktCenowy {
  const ProduktCenowy({
    required this.nazwa,
    required this.jednostka,
    required this.ceny,
  });

  factory ProduktCenowy.zJson(Map<String, dynamic> json) => ProduktCenowy(
    nazwa: json['nazwa'] as String,
    jednostka: json['jednostka'] as String,
    ceny: [
      for (final wpis in json['ceny'] as List<dynamic>)
        CenaRegionu.zJson(wpis as Map<String, dynamic>),
    ],
  );

  final String nazwa;
  final String jednostka;
  final List<CenaRegionu> ceny;
}

/// Notowania cen skupu z pliku danych.
///
/// Plik przygotowuje skrypt `tools/ceny/ceny_skupu.py` na komputerze
/// dewelopera — aplikacja nigdy nie pobiera stron ministerstwa
/// z urządzenia rolnika (CLAUDE.md, reguła 3).
class SlownikCen {
  const SlownikCen({
    required this.wersja,
    required this.zrodlo,
    required this.zastrzezenie,
    required this.produkty,
    this.tydzienOd,
    this.tydzienDo,
  });

  factory SlownikCen.zTekstuJson(String tekst) {
    final json = jsonDecode(tekst) as Map<String, dynamic>;
    final tydzien = json['tydzien'] as Map<String, dynamic>?;
    return SlownikCen(
      wersja: json['wersja'] as String,
      zrodlo: json['zrodlo'] as String,
      zastrzezenie: json['zastrzezenie'] as String? ?? '',
      tydzienOd: tydzien == null
          ? null
          : DateTime.tryParse(tydzien['od'] as String),
      tydzienDo: tydzien == null
          ? null
          : DateTime.tryParse(tydzien['do'] as String),
      produkty: [
        for (final wpis in json['produkty'] as List<dynamic>)
          ProduktCenowy.zJson(wpis as Map<String, dynamic>),
      ],
    );
  }

  final String wersja;
  final String zrodlo;

  /// Zdanie, które musi stać przy notowaniach: to cena urzędowa dla
  /// regionu, a nie oferta skupu za miedzą.
  final String zastrzezenie;

  /// Tydzień, którego dotyczą notowania. `null`, gdy pliku jeszcze nie
  /// wypełniono — wtedy program mówi wprost, że notowań nie ma.
  final DateTime? tydzienOd;
  final DateTime? tydzienDo;

  final List<ProduktCenowy> produkty;

  bool get pusty => produkty.isEmpty || tydzienDo == null;
}

/// Cena dobrana do gospodarstwa: z jego województwa albo krajowa.
class CenaDlaGospodarstwa {
  const CenaDlaGospodarstwa({
    required this.produkt,
    required this.jednostka,
    required this.cena,
    required this.region,
    required this.zRegionuGospodarstwa,
    required this.doWeryfikacji,
  });

  final String produkt;
  final String jednostka;
  final double cena;
  final String region;

  /// Czy to notowanie z województwa gospodarstwa, czy zastępcze (krajowe).
  final bool zRegionuGospodarstwa;

  final bool doWeryfikacji;

  String get cenaOpis =>
      '${cena.toStringAsFixed(2).replaceAll('.', ',')} $jednostka';
}

/// Dobór notowań do gospodarstwa.
abstract final class CenySkupu {
  /// Nazwa regionu dla notowań krajowych.
  static const String kraj = 'kraj';

  /// Województwo gospodarstwa — najczęstsze wśród jego działek.
  ///
  /// Nie pytamy rolnika o region: wynika on z działek pobranych z ULDK.
  static String? wojewodztwo(List<DzialkaEwidencyjna> dzialki) {
    final ile = <String, int>{};
    for (final dzialka in dzialki) {
      final nazwa = dzialka.wojewodztwo?.trim().toLowerCase();
      if (nazwa != null && nazwa.isNotEmpty) {
        ile[nazwa] = (ile[nazwa] ?? 0) + 1;
      }
    }
    if (ile.isEmpty) {
      return null;
    }
    return ile.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Dla każdego produktu jedna cena: z województwa gospodarstwa, a gdy
  /// jej nie ma — krajowa. Produkt bez obu notowań wypada z listy;
  /// ceny z innego województwa nie podstawiamy (CLAUDE.md, reguła 5).
  static List<CenaDlaGospodarstwa> dlaGospodarstwa(
    SlownikCen slownik, {
    String? wojewodztwo,
  }) {
    final wybrane = <CenaDlaGospodarstwa>[];
    for (final produkt in slownik.produkty) {
      CenaRegionu? znaleziona;
      var zRegionu = false;
      if (wojewodztwo != null) {
        for (final cena in produkt.ceny) {
          if (cena.region == wojewodztwo) {
            znaleziona = cena;
            zRegionu = true;
            break;
          }
        }
      }
      znaleziona ??= produkt.ceny
          .where((cena) => cena.region == kraj)
          .firstOrNull;
      if (znaleziona == null) {
        continue;
      }
      wybrane.add(
        CenaDlaGospodarstwa(
          produkt: produkt.nazwa,
          jednostka: produkt.jednostka,
          cena: znaleziona.cena,
          region: znaleziona.region,
          zRegionuGospodarstwa: zRegionu,
          doWeryfikacji: znaleziona.doWeryfikacji,
        ),
      );
    }
    return wybrane;
  }
}

/// Wczytuje notowania z pliku dołączonego do aplikacji.
class ZrodloCen {
  ZrodloCen({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/ceny_skupu.json';

  final AssetBundle _paczka;
  SlownikCen? _wPamieci;

  Future<SlownikCen> wczytaj() async {
    final juz = _wPamieci;
    if (juz != null) {
      return juz;
    }
    final slownik = SlownikCen.zTekstuJson(await _paczka.loadString(sciezka));
    _wPamieci = slownik;
    return slownik;
  }
}
