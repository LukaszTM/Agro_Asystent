import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../rdzen/wspolne/tekst.dart';

/// Jedno hasło słowniczka: skrót albo nazwa urzędowa z wyjaśnieniem.
class HasloSlownika {
  const HasloSlownika({
    required this.skrot,
    required this.nazwa,
    required this.wyjasnienie,
    required this.gdzie,
    required this.status,
  });

  factory HasloSlownika.zJson(Map<String, dynamic> json) => HasloSlownika(
    skrot: json['skrot'] as String,
    nazwa: json['nazwa'] as String,
    wyjasnienie: json['wyjasnienie'] as String,
    gdzie: json['gdzie'] as String,
    status: json['status'] as String,
  );

  /// To, co rolnik widzi w piśmie: „TUZ", „GAEC 6", „DJP".
  final String skrot;

  /// Rozwinięcie skrótu — nazwa urzędowa.
  final String nazwa;

  /// Wyjaśnienie językiem rolnika: co to jest i gdzie tego szukać
  /// w aplikacji.
  final String wyjasnienie;

  /// Miejsca, w których pojęcie się pojawia.
  final String gdzie;

  /// `potwierdzone` albo `do_weryfikacji` — tak samo jak w pozostałych
  /// słownikach danych.
  final String status;

  /// Hasła nieopisane jeszcze na podstawie przepisu oznaczamy na ekranie,
  /// żeby rolnik wiedział, czego nie sprawdziliśmy (plan, pkt 11.5).
  bool get doWeryfikacji => status != 'potwierdzone';

  /// Czy hasło odpowiada temu, co rolnik wpisał. Szuka bez ogonków
  /// i bez znaczenia wielkich liter — w skrócie, nazwie i wyjaśnieniu.
  bool pasuje(String szukane) {
    final slowa = Tekst.slowaDoSzukania(szukane);
    if (slowa.isEmpty) {
      return true;
    }
    final gdzieSzukamy = Tekst.znormalizuj('$skrot $nazwa $wyjasnienie $gdzie');
    return slowa.every(gdzieSzukamy.contains);
  }
}

/// Słowniczek pojęć — dane z numerem wersji, nie tekst wpisany w ekrany.
///
/// Nowe hasło dopisuje się do `assets/dane/slowniczek.json` i podnosi
/// numer wersji; kod się nie zmienia. Tak samo trzymamy reguły prawne
/// i kalendarz biodynamiczny.
class SlownikPojec {
  const SlownikPojec({
    required this.wersja,
    required this.poCo,
    required this.zastrzezenie,
    required this.hasla,
  });

  factory SlownikPojec.zTekstuJson(String tekst) {
    final json = jsonDecode(tekst) as Map<String, dynamic>;
    return SlownikPojec(
      wersja: json['wersja'] as String,
      poCo: json['po_co'] as String,
      zastrzezenie: json['zastrzezenie'] as String,
      hasla: [
        for (final wpis in json['hasla'] as List<dynamic>)
          HasloSlownika.zJson(wpis as Map<String, dynamic>),
      ],
    );
  }

  final String wersja;

  /// Po co ten słowniczek jest — zdanie na górze ekranu.
  final String poCo;

  /// Zdanie, które musi stać przy słowniczku: tłumaczy pojęcia, nie
  /// zastępuje przepisu.
  final String zastrzezenie;

  /// Hasła w kolejności z pliku — pierwsze są te, o które rolnik pyta
  /// najczęściej.
  final List<HasloSlownika> hasla;

  /// Hasła pasujące do tego, co rolnik wpisał. Puste szukanie zwraca
  /// wszystko.
  List<HasloSlownika> szukaj(String szukane) =>
      hasla.where((haslo) => haslo.pasuje(szukane)).toList(growable: false);

  /// Hasło po skrócie — `null`, gdy go nie ma. Nie zgadujemy wyjaśnienia:
  /// brak hasła znaczy brak podpowiedzi na ekranie.
  HasloSlownika? haslo(String skrot) {
    final szukany = Tekst.znormalizuj(skrot);
    for (final haslo in hasla) {
      if (Tekst.znormalizuj(haslo.skrot) == szukany) {
        return haslo;
      }
    }
    return null;
  }
}

/// Wczytanie słowniczka z pliku dołączonego do aplikacji.
class ZrodloSlowniczka {
  ZrodloSlowniczka({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/slowniczek.json';

  final AssetBundle _paczka;
  SlownikPojec? _wPamieci;

  Future<SlownikPojec> wczytaj() async {
    final juz = _wPamieci;
    if (juz != null) {
      return juz;
    }
    final slownik = SlownikPojec.zTekstuJson(await _paczka.loadString(sciezka));
    _wPamieci = slownik;
    return slownik;
  }
}
