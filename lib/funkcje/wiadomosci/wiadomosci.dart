import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:sqflite_common/sqlite_api.dart';

/// Kanał RSS z wiadomościami rolniczymi.
class KanalWiadomosci {
  const KanalWiadomosci({
    required this.nazwa,
    required this.adres,
    required this.strona,
    required this.status,
  });

  factory KanalWiadomosci.zJson(Map<String, dynamic> json) => KanalWiadomosci(
    nazwa: json['nazwa'] as String,
    adres: json['adres'] as String,
    strona: json['strona'] as String,
    status: json['status'] as String? ?? 'do_weryfikacji',
  );

  final String nazwa;
  final String adres;

  /// Strona wydawcy — odnośnik dla rolnika i ukłon wobec prawa autorskiego.
  final String strona;

  /// `potwierdzone` albo `do_weryfikacji` — tak samo jak przy danych
  /// z przepisów. Adres kanału bywa zmieniany bez uprzedzenia.
  final String status;

  bool get potwierdzony => status == 'potwierdzone';
}

/// Lista kanałów z pliku danych.
class SlownikKanalow {
  const SlownikKanalow({required this.wersja, required this.kanaly});

  factory SlownikKanalow.zTekstuJson(String tekst) {
    final json = jsonDecode(tekst) as Map<String, dynamic>;
    return SlownikKanalow(
      wersja: json['wersja'] as String,
      kanaly: [
        for (final wpis in json['kanaly'] as List<dynamic>)
          KanalWiadomosci.zJson(wpis as Map<String, dynamic>),
      ],
    );
  }

  final String wersja;
  final List<KanalWiadomosci> kanaly;
}

/// Jedna wiadomość: tytuł, zajawka i odnośnik do źródła.
///
/// Całej treści nie pobieramy i nie pokazujemy — to cudzy tekst. Rolnik
/// czyta zajawkę i klika do wydawcy.
class Wiadomosc {
  const Wiadomosc({
    required this.tytul,
    required this.odnosnik,
    required this.zrodlo,
    this.zajawka,
    this.data,
  });

  factory Wiadomosc.zJson(Map<String, dynamic> json) => Wiadomosc(
    tytul: json['tytul'] as String,
    odnosnik: json['odnosnik'] as String,
    zrodlo: json['zrodlo'] as String,
    zajawka: json['zajawka'] as String?,
    data: json['data'] == null
        ? null
        : DateTime.tryParse(json['data'] as String),
  );

  final String tytul;
  final String odnosnik;

  /// Nazwa kanału — musi stać przy każdej wiadomości.
  final String zrodlo;

  final String? zajawka;
  final DateTime? data;

  Map<String, dynamic> doJson() => {
    'tytul': tytul,
    'odnosnik': odnosnik,
    'zrodlo': zrodlo,
    if (zajawka != null) 'zajawka': zajawka,
    if (data != null) 'data': data!.toIso8601String(),
  };
}

/// Ostatnio pobrane wiadomości — żeby bez internetu było co czytać.
///
/// To nie są wpisy rolnika, więc w kopii danych nie jadą.
class RepozytoriumWiadomosci {
  const RepozytoriumWiadomosci(this._baza);

  static const String _klucz = 'wszystkie';

  final DatabaseExecutor _baza;

  Future<({DateTime pobrano, List<Wiadomosc> wiadomosci})?> ostatnie() async {
    final wiersze = await _baza.query(
      'wiadomosci_zapis',
      where: 'klucz = ?',
      whereArgs: [_klucz],
      limit: 1,
    );
    if (wiersze.isEmpty) {
      return null;
    }
    try {
      final json =
          jsonDecode(wiersze.first['dane_json']! as String) as List<dynamic>;
      return (
        pobrano: DateTime.parse(wiersze.first['pobrano']! as String),
        wiadomosci: [
          for (final wpis in json)
            Wiadomosc.zJson(wpis as Map<String, dynamic>),
        ],
      );
    } on Object {
      return null;
    }
  }

  Future<void> zapisz({
    required List<Wiadomosc> wiadomosci,
    required DateTime pobrano,
  }) async {
    await _baza.insert('wiadomosci_zapis', {
      'klucz': _klucz,
      'pobrano': pobrano.toIso8601String(),
      'dane_json': jsonEncode([
        for (final wiadomosc in wiadomosci) wiadomosc.doJson(),
      ]),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

/// Wczytuje listę kanałów z pliku dołączonego do aplikacji.
class ZrodloKanalow {
  ZrodloKanalow({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/kanaly_wiadomosci.json';

  final AssetBundle _paczka;
  SlownikKanalow? _wPamieci;

  Future<SlownikKanalow> wczytaj() async {
    final juz = _wPamieci;
    if (juz != null) {
      return juz;
    }
    final slownik = SlownikKanalow.zTekstuJson(
      await _paczka.loadString(sciezka),
    );
    _wPamieci = slownik;
    return slownik;
  }
}
