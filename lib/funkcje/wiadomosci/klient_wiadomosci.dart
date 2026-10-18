import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import 'wiadomosci.dart';

/// Czyta kanał RSS albo Atom i oddaje same nagłówki wiadomości.
///
/// Pobieramy wyłącznie tytuł, krótką zajawkę, datę i odnośnik. Treści
/// artykułu nie zapisujemy i nie pokazujemy — to cudzy tekst, a rolnik
/// i tak klika do wydawcy.
class KlientWiadomosci {
  const KlientWiadomosci({http.Client? klient, this.ilePoKanale = 5})
    : _klient = klient; // ignore: prefer_initializing_formals

  final http.Client? _klient;

  /// Ile wiadomości bierzemy z jednego kanału — pulpit ma pokazać przegląd,
  /// nie całą prasę.
  final int ilePoKanale;

  static const int _dlugoscZajawki = 180;

  /// Wiadomości z jednego kanału. Zwraca pustą listę, gdy kanał nie
  /// odpowiada albo jego zapisu nie da się odczytać — brak wiadomości nie
  /// może popsuć pulpitu.
  Future<List<Wiadomosc>> zKanalu(KanalWiadomosci kanal) async {
    final klient = _klient ?? http.Client();
    http.Response odpowiedz;
    try {
      odpowiedz = await klient.get(
        Uri.parse(kanal.adres),
        headers: const {'Accept': 'application/rss+xml, application/xml'},
      );
    } on Exception {
      return const [];
    } finally {
      if (_klient == null) {
        klient.close();
      }
    }

    if (odpowiedz.statusCode != 200) {
      return const [];
    }
    try {
      return _zXml(
        utf8.decode(odpowiedz.bodyBytes, allowMalformed: true),
        kanal,
      );
    } on Object {
      return const [];
    }
  }

  List<Wiadomosc> _zXml(String tresc, KanalWiadomosci kanal) {
    final dokument = XmlDocument.parse(tresc);
    // RSS trzyma wpisy w <item>, Atom w <entry> — bierzemy jedno i drugie.
    final wpisy = <XmlElement>[
      ...dokument.findAllElements('item'),
      ...dokument.findAllElements('entry'),
    ];

    final wiadomosci = <Wiadomosc>[];
    for (final wpis in wpisy.take(ilePoKanale)) {
      final tytul = _tekst(wpis, 'title');
      final odnosnik = _odnosnik(wpis);
      if (tytul == null || odnosnik == null) {
        continue;
      }
      wiadomosci.add(
        Wiadomosc(
          tytul: tytul,
          odnosnik: odnosnik,
          zrodlo: kanal.nazwa,
          zajawka: _zajawka(wpis),
          data: _data(wpis),
        ),
      );
    }
    return wiadomosci;
  }

  static String? _tekst(XmlElement wpis, String nazwa) {
    final element = wpis.getElement(nazwa);
    final tekst = element?.innerText.trim();
    return tekst == null || tekst.isEmpty ? null : tekst;
  }

  static String? _odnosnik(XmlElement wpis) {
    final wprost = _tekst(wpis, 'link');
    if (wprost != null && wprost.startsWith('http')) {
      return wprost;
    }
    // Atom trzyma adres w atrybucie href.
    for (final link in wpis.findElements('link')) {
      final adres = link.getAttribute('href');
      if (adres != null && adres.startsWith('http')) {
        return adres;
      }
    }
    return null;
  }

  /// Zajawka: kilka pierwszych zdań bez znaczników HTML.
  static String? _zajawka(XmlElement wpis) {
    final surowa =
        _tekst(wpis, 'description') ??
        _tekst(wpis, 'summary') ??
        _tekst(wpis, 'subtitle');
    if (surowa == null) {
      return null;
    }
    final bezZnacznikow = surowa
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (bezZnacznikow.isEmpty) {
      return null;
    }
    return bezZnacznikow.length <= _dlugoscZajawki
        ? bezZnacznikow
        : '${bezZnacznikow.substring(0, _dlugoscZajawki).trimRight()}…';
  }

  static DateTime? _data(XmlElement wpis) {
    final zapis =
        _tekst(wpis, 'pubDate') ??
        _tekst(wpis, 'published') ??
        _tekst(wpis, 'updated') ??
        _tekst(wpis, 'date');
    if (zapis == null) {
      return null;
    }
    final isoLubNic = DateTime.tryParse(zapis);
    if (isoLubNic != null) {
      return isoLubNic.toLocal();
    }
    return _zFormatuRfc(zapis);
  }

  static const List<String> _miesiaceRfc = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// RSS podaje datę po angielsku: „Sat, 18 Oct 2026 07:30:00 +0200".
  static DateTime? _zFormatuRfc(String zapis) {
    final dopasowanie = RegExp(
      r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?',
    ).firstMatch(zapis);
    if (dopasowanie == null) {
      return null;
    }
    final miesiac = _miesiaceRfc.indexOf(dopasowanie.group(2)!);
    if (miesiac < 0) {
      return null;
    }
    return DateTime(
      int.parse(dopasowanie.group(3)!),
      miesiac + 1,
      int.parse(dopasowanie.group(1)!),
      int.tryParse(dopasowanie.group(4) ?? '') ?? 0,
      int.tryParse(dopasowanie.group(5) ?? '') ?? 0,
    );
  }
}
