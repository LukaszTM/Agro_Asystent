import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../rdzen/uslugi/geometria.dart';

/// Działka ewidencyjna pobrana z usługi ULDK (GUGiK).
class DzialkaZUldk {
  const DzialkaZUldk({
    required this.identyfikator,
    required this.wkt,
    required this.srid,
    this.wojewodztwo,
    this.powiat,
    this.gmina,
    this.obreb,
    this.nrDzialki,
  });

  final String identyfikator;
  final String wkt;
  final int srid;
  final String? wojewodztwo;
  final String? powiat;
  final String? gmina;
  final String? obreb;
  final String? nrDzialki;

  List<Pierscien> get obrysy => Geometria.zWkt(wkt);

  double get powierzchniaHa => Geometria.powierzchniaHa(obrysy.first);

  String get polozenie => [
    obreb,
    gmina,
    powiat,
  ].whereType<String>().where((c) => c.isNotEmpty).join(', ');
}

/// Błąd, który trzeba pokazać rolnikowi w jednym zdaniu.
/// Jednostka podziału administracyjnego: województwo, powiat, gmina
/// albo obręb ewidencyjny.
class JednostkaTerytorialna {
  const JednostkaTerytorialna({required this.nazwa, required this.teryt});

  final String nazwa;

  /// Identyfikator TERYT. Dla obrębu ma postać `WWPPGG_R.OOOO` — razem
  /// z numerem działki tworzy pełny identyfikator działki.
  final String teryt;

  @override
  String toString() => '$nazwa ($teryt)';
}

/// Który szczebel podziału wybieramy.
enum PoziomPodzialu {
  wojewodztwo('GetVoivodeships', 'voivodeship', null),
  powiat('GetCounties', 'county', 'voivodeship'),
  gmina('GetCommunes', 'commune', 'county'),
  obreb('GetRegions', 'region', 'commune');

  const PoziomPodzialu(this.zadanie, this.pole, this.parametrNadrzednej);

  /// Nazwa żądania w usłudze ULDK.
  final String zadanie;

  /// Nazwa kolumny z nazwą jednostki.
  final String pole;

  /// Pod jakim parametrem usługa chce identyfikatora jednostki wyżej.
  /// `null` dla województw — tych nic nie poprzedza.
  final String? parametrNadrzednej;

  String get dlaRolnika => switch (this) {
    PoziomPodzialu.wojewodztwo => 'województwo',
    PoziomPodzialu.powiat => 'powiat',
    PoziomPodzialu.gmina => 'gmina',
    PoziomPodzialu.obreb => 'obręb',
  };
}

class BladUldk implements Exception {
  const BladUldk(this.wiadomosc, {this.coZrobic});

  final String wiadomosc;
  final String? coZrobic;

  @override
  String toString() => wiadomosc;
}

/// Pobiera granice działek z bezpłatnej usługi ULDK.
///
/// Usługa jest potrzebna **tylko w chwili dodawania działki**. Potem granice
/// leżą w bazie na urządzeniu i mapa działa bez zasięgu (plan, pkt 2).
class KlientUldk {
  const KlientUldk({
    http.Client? klient,
    this.adres = 'https://uldk.gugik.gov.pl/',
  }) : _klient = klient; // ignore: prefer_initializing_formals

  /// Klient HTTP — podmieniany w testach, żeby nie łączyć się z usługą.
  final http.Client? _klient;
  final String adres;

  static const List<String> _pola = [
    'geom_wkt',
    'teryt',
    'voivodeship',
    'county',
    'commune',
    'region',
    'parcel',
  ];

  /// Identyfikator działki: WWPPGG_R.OOOO[.AR_NR].NR_DZ
  static final RegExp wzorzecIdentyfikatora = RegExp(
    r'^\d{6}_\d\.\d{4}(?:\.AR_\d+)?\.\d+(?:/\d+)?$',
  );

  /// Pobiera działkę po pełnym identyfikatorze albo po zapisie
  /// „nazwa obrębu numer" — usługa przyjmuje oba.
  ///
  /// Nazwy obrębów się powtarzają w kraju, więc wynik **musi** potwierdzić
  /// rolnik na mapie (plan, pkt 6.1).
  Future<DzialkaZUldk> pobierz(String szukane, {int srid = 4326}) async {
    final zapytanie = szukane.trim();
    if (zapytanie.isEmpty) {
      throw const BladUldk(
        'Nie podano numeru działki.',
        coZrobic: 'Wpisz numer z wniosku albo nazwę obrębu i numer działki.',
      );
    }

    final poIdentyfikatorze = wzorzecIdentyfikatora.hasMatch(zapytanie);
    final adresZapytania = Uri.parse(adres).replace(
      queryParameters: {
        'request': poIdentyfikatorze ? 'GetParcelById' : 'GetParcelByIdOrNr',
        'id': zapytanie,
        'result': _pola.join(','),
        'srid': '$srid',
      },
    );

    final klient = _klient ?? http.Client();
    final http.Response odpowiedz;
    try {
      odpowiedz = await klient
          .get(adresZapytania)
          .timeout(const Duration(seconds: 30));
    } on Exception {
      throw const BladUldk(
        'Nie udało się połączyć z usługą granic działek.',
        coZrobic:
            'Sprawdź połączenie z internetem i spróbuj ponownie. '
            'Działki już dodane działają bez internetu.',
      );
    } finally {
      if (_klient == null) {
        klient.close();
      }
    }

    if (odpowiedz.statusCode != 200) {
      throw BladUldk(
        'Usługa granic działek odpowiedziała błędem (${odpowiedz.statusCode}).',
        coZrobic: 'Spróbuj ponownie za chwilę.',
      );
    }
    return odczytaj(
      utf8.decode(odpowiedz.bodyBytes, allowMalformed: true),
      zapytanie,
      srid,
    );
  }

  /// Lista jednostek jednego szczebla — do wyboru z listy zamiast
  /// wpisywania identyfikatora TERYT.
  ///
  /// Rolnik zna swoją gminę i obręb, ale nie zna zapisu
  /// `141201_2.0012`. Działkę dzierżawioną, której nie ma we wniosku,
  /// dodaje się więc tak: województwo → powiat → gmina → obręb → numer.
  Future<List<JednostkaTerytorialna>> jednostki({
    required PoziomPodzialu poziom,
    String? terytNadrzednej,
  }) async {
    final parametrNadrzednej = poziom.parametrNadrzednej;
    if (parametrNadrzednej != null &&
        (terytNadrzednej == null || terytNadrzednej.isEmpty)) {
      throw BladUldk(
        'Najpierw wybierz jednostkę wyżej (${poziom.dlaRolnika}).',
      );
    }

    final parametry = <String, String>{
      'request': poziom.zadanie,
      'result': '${poziom.pole},teryt',
    };
    if (parametrNadrzednej != null) {
      parametry[parametrNadrzednej] = terytNadrzednej!;
    }
    final adresZapytania = Uri.parse(adres).replace(queryParameters: parametry);

    final klient = _klient ?? http.Client();
    final http.Response odpowiedz;
    try {
      odpowiedz = await klient
          .get(adresZapytania)
          .timeout(const Duration(seconds: 30));
    } on Exception {
      throw const BladUldk(
        'Nie udało się pobrać listy z usługi granic działek.',
        coZrobic:
            'Lista pobiera się raz, przez internet. Bez zasięgu dodaj '
            'działkę, wpisując jej pełny numer z wypisu.',
      );
    } finally {
      if (_klient == null) {
        klient.close();
      }
    }

    if (odpowiedz.statusCode != 200) {
      throw BladUldk(
        'Usługa odpowiedziała błędem (${odpowiedz.statusCode}).',
        coZrobic: 'Spróbuj ponownie za chwilę.',
      );
    }
    // Usługa oddaje polskie nazwy w UTF-8. `odpowiedz.body` bez nagłówka
    // z kodowaniem rozłożyłby „Żyrzyn" na krzaki — a nazwa obrębu trafia
    // potem do bazy i na wydruk.
    return odczytajJednostki(
      utf8.decode(odpowiedz.bodyBytes, allowMalformed: true),
      poziom,
    );
  }

  /// Odpowiedź usługi: pierwszy wiersz to status, dalej po jednym wierszu
  /// na jednostkę — „nazwa|TERYT".
  static List<JednostkaTerytorialna> odczytajJednostki(
    String tresc,
    PoziomPodzialu poziom,
  ) {
    final wiersze = tresc
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    if (wiersze.isEmpty || !wiersze.first.startsWith('0')) {
      throw BladUldk(
        'Usługa nie podała listy (${poziom.dlaRolnika}).',
        coZrobic: 'Spróbuj ponownie albo wpisz pełny numer działki.',
      );
    }

    final jednostki = <JednostkaTerytorialna>[];
    for (final wiersz in wiersze.skip(1)) {
      final czesci = wiersz.split('|').map((c) => c.trim()).toList();
      if (czesci.length < 2 || czesci[0].isEmpty || czesci[1].isEmpty) {
        // Wiersza, którego nie rozumiemy, nie zgadujemy — pomijamy go.
        continue;
      }
      jednostki.add(JednostkaTerytorialna(nazwa: czesci[0], teryt: czesci[1]));
    }
    jednostki.sort(
      (a, b) => a.nazwa.toLowerCase().compareTo(b.nazwa.toLowerCase()),
    );
    return jednostki;
  }

  /// Pełny identyfikator działki z obrębu i numeru — w takiej postaci
  /// pyta o nią usługa i w takiej stoi na wypisie.
  static String pelnyNumer(JednostkaTerytorialna obreb, String numerDzialki) =>
      '${obreb.teryt}.${numerDzialki.trim()}';

  /// Odpowiedź: w pierwszym wierszu status (0 = w porządku), w drugim dane
  /// rozdzielone znakiem „|", w kolejności, w jakiej je zamówiono.
  static DzialkaZUldk odczytaj(String tresc, String szukane, int srid) {
    final wiersze = tresc
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList(growable: false);

    if (wiersze.isEmpty) {
      throw const BladUldk('Usługa nie zwróciła żadnych danych.');
    }
    if (!wiersze.first.startsWith('0')) {
      throw BladUldk(
        'Nie znaleziono działki „$szukane".',
        coZrobic:
            'Sprawdź numer — powinien wyglądać tak jak we wniosku, '
            'na przykład 061506_2.0007.138.',
      );
    }
    if (wiersze.length < 2) {
      throw const BladUldk('Usługa nie podała granic tej działki.');
    }

    final czesci = wiersze[1]
        .split('|')
        .map((c) => c.trim())
        .toList(growable: false);
    final dane = <String, String>{
      for (var i = 0; i < _pola.length && i < czesci.length; i++)
        _pola[i]: czesci[i],
    };

    final (wkt, sridZOdpowiedzi) = Geometria.rozdzielSrid(
      dane['geom_wkt'] ?? '',
    );
    if (!wkt.toUpperCase().startsWith('POLYGON') &&
        !wkt.toUpperCase().startsWith('MULTIPOLYGON')) {
      throw const BladUldk('W odpowiedzi usługi nie ma granic działki.');
    }

    return DzialkaZUldk(
      identyfikator: (dane['teryt'] ?? '').isEmpty ? szukane : dane['teryt']!,
      wkt: wkt,
      srid: sridZOdpowiedzi ?? srid,
      wojewodztwo: dane['voivodeship'],
      powiat: dane['county'],
      gmina: dane['commune'],
      obreb: dane['region'],
      nrDzialki: dane['parcel'],
    );
  }
}
