import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../rdzen/wspolne/tekst.dart';
import 'slownik_upraw.dart';

/// Uprawy dopisane do słownika poza rejestrem środków ochrony roślin.
///
/// Rejestr MRiRW mówi, czym wolno opryskiwać — nazwy upraw bierzemy z niego
/// (`tools/zbuduj_slowniki.py`). Trwałych użytków zielonych prawie w nim nie
/// ma, bo łąk i pastwisk zwykle nie opryskuje się, a dokumentację trzeba
/// prowadzić i dla nich. Dlatego takie uprawy trzymamy w pliku danych
/// z numerem wersji — dopisanie kolejnej nie wymaga zmiany kodu ani
/// przebudowy słownika (CLAUDE.md, reguła 1).
class SlownikUprawDopisanych {
  const SlownikUprawDopisanych({
    required this.wersja,
    required this.poCo,
    required this.zastrzezenie,
    required this.uprawy,
  });

  factory SlownikUprawDopisanych.zTekstuJson(String tekst) {
    final json = jsonDecode(tekst) as Map<String, dynamic>;
    return SlownikUprawDopisanych(
      wersja: json['wersja'] as String,
      poCo: json['po_co'] as String,
      zastrzezenie: json['zastrzezenie'] as String,
      uprawy: [
        for (final wpis in json['uprawy'] as List<dynamic>)
          _zJson(wpis as Map<String, dynamic>),
      ],
    );
  }

  static const SlownikUprawDopisanych pusty = SlownikUprawDopisanych(
    wersja: 'brak',
    poCo: '',
    zastrzezenie: '',
    uprawy: [],
  );

  final String wersja;
  final String poCo;

  /// Zdanie o tym, czego taka uprawa nie daje: kodu EPPO ani listy środków.
  final String zastrzezenie;

  /// Uprawy w kolejności z pliku.
  final List<UprawaDoWyboru> uprawy;

  /// Dopisane uprawy pasujące do tego, co rolnik wpisał. Puste szukanie
  /// zwraca wszystkie.
  List<UprawaDoWyboru> pasujace(String szukane) {
    final slowa = Tekst.slowaDoSzukania(szukane);
    if (slowa.isEmpty) {
      return uprawy;
    }
    return [
      for (final uprawa in uprawy)
        if (slowa.every(Tekst.znormalizuj(uprawa.nazwa).contains)) uprawa,
    ];
  }

  /// Uprawa po nazwie — `null`, gdy w pliku jej nie ma.
  UprawaDoWyboru? jedna(String nazwa) {
    for (final uprawa in uprawy) {
      if (uprawa.nazwa == nazwa) {
        return uprawa;
      }
    }
    return null;
  }

  /// Kod EPPO bierzemy tylko wtedy, gdy stoi w pliku. Pusty zapis znaczy
  /// „nie znamy" i w ewidencji wyjdzie „brak" — nigdy go nie zgadujemy
  /// (CLAUDE.md, reguła 5).
  static UprawaDoWyboru _zJson(Map<String, dynamic> json) {
    final kod = (json['kod_eppo'] as String?)?.trim();
    return UprawaDoWyboru(
      nazwa: json['nazwa'] as String,
      stan: kod == null || kod.isEmpty ? StanUprawy.brak : StanUprawy.kod,
      kodEppo: kod == null || kod.isEmpty ? null : kod,
    );
  }
}

/// Wczytanie dopisanych upraw z pliku dołączonego do aplikacji.
class ZrodloUprawDopisanych {
  ZrodloUprawDopisanych({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/uprawy_dopisane.json';

  final AssetBundle _paczka;
  SlownikUprawDopisanych? _wPamieci;

  Future<SlownikUprawDopisanych> wczytaj() async {
    final juz = _wPamieci;
    if (juz != null) {
      return juz;
    }
    final slownik = SlownikUprawDopisanych.zTekstuJson(
      await _paczka.loadString(sciezka),
    );
    _wPamieci = slownik;
    return slownik;
  }
}
