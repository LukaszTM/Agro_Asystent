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

/// Działka znaleziona po nazwie obrębu i numerze — bez granic, tylko
/// to, po czym rolnik pozna, czy to jego.
///
/// Nazwy obrębów się powtarzają (w kraju są dziesiątki „Dąbrów"), więc
/// usługa oddaje wszystkie pasujące działki, a rolnik wybiera swoją po
/// gminie i powiecie. Granice pobiera się dopiero dla wybranej.
class DzialkaZnaleziona {
  const DzialkaZnaleziona({
    required this.teryt,
    required this.wojewodztwo,
    required this.powiat,
    required this.gmina,
    required this.obreb,
    required this.numer,
  });

  /// Pełny identyfikator działki — nim pytamy potem o granice.
  final String teryt;

  final String wojewodztwo;
  final String powiat;
  final String gmina;
  final String obreb;
  final String numer;

  /// Pierwsze dwie cyfry identyfikatora to kod województwa w TERYT.
  String get kodWojewodztwa => teryt.length >= 2 ? teryt.substring(0, 2) : '';

  /// Jak odróżnić tę działkę od innych o tej samej nazwie obrębu.
  String get polozenie =>
      [gmina, powiat, wojewodztwo].where((c) => c.isNotEmpty).join(', ');

  @override
  String toString() => '$teryt ($polozenie)';
}

/// Błąd, który trzeba pokazać rolnikowi w jednym zdaniu.
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

  /// Pobiera działkę z granicami po pełnym identyfikatorze. Zapis
  /// „nazwa obrębu numer" też przyjmuje, ale tylko gdy w kraju jest
  /// dokładnie jedna taka działka — inaczej mówi, że trzeba wybrać.
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

    if (!wzorzecIdentyfikatora.hasMatch(zapytanie)) {
      // „Brzeziny 138" to nie identyfikator. Usługa oddałaby na to listę
      // (pierwszy wiersz to liczba wyników, nie status), a wśród
      // dziesiątek obrębów o tej nazwie pierwszy z brzegu nie musi być
      // tym właściwym — wybór zostawiamy rolnikowi.
      final czesci = zapytanie.split(RegExp(r'\s+'));
      final znalezione = await szukajPoNazwie(
        obreb: czesci.take(czesci.length - 1).join(' '),
        numer: czesci.last,
      );
      if (znalezione.length > 1) {
        throw BladUldk(
          'Jest ${znalezione.length} działek nr ${czesci.last} w obrębach '
          'o nazwie „${czesci.take(czesci.length - 1).join(' ')}".',
          coZrobic:
              'Wybierz województwo i swoją gminę z listy albo wpisz pełny '
              'numer z wypisu.',
        );
      }
      return pobierz(znalezione.single.teryt, srid: srid);
    }

    final adresZapytania = Uri.parse(adres).replace(
      queryParameters: {
        'request': 'GetParcelById',
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

  /// Działki o danym numerze w obrębach o danej nazwie — bez granic.
  ///
  /// Rolnik dodaje działkę spoza wniosku (dzierżawa, zakup po jego
  /// złożeniu): nie zna zapisu `141201_2.0012.138`, ale zna miejscowość
  /// i ma numer na umowie. Usługa przyjmuje „nazwa obrębu numer" i oddaje
  /// wszystkie pasujące działki w kraju, każdą z gminą i powiatem.
  Future<List<DzialkaZnaleziona>> szukajPoNazwie({
    required String obreb,
    required String numer,
  }) async {
    final nazwa = obreb.trim();
    final nr = numer.trim();
    if (nazwa.isEmpty || nr.isEmpty) {
      throw const BladUldk(
        'Podaj nazwę miejscowości (obrębu) i numer działki.',
        coZrobic: 'Nazwę znajdziesz na umowie albo w wypisie z ewidencji.',
      );
    }
    final adresZapytania = Uri.parse(adres).replace(
      queryParameters: {
        'request': 'GetParcelByIdOrNr',
        'id': '$nazwa $nr',
        'result': _polaZnalezionej.join(','),
      },
    );

    final klient = _klient ?? http.Client();
    final http.Response odpowiedz;
    try {
      odpowiedz = await klient
          .get(adresZapytania)
          .timeout(const Duration(seconds: 60));
    } on Exception {
      throw const BladUldk(
        'Nie udało się połączyć z usługą granic działek.',
        coZrobic:
            'Szukanie po nazwie wymaga internetu. Bez zasięgu dodaj '
            'działkę, wpisując jej pełny numer z wypisu. Działki już '
            'dodane działają bez internetu.',
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
    // Usługa oddaje polskie nazwy w UTF-8. `odpowiedz.body` bez nagłówka
    // z kodowaniem rozłożyłby „Żyrzyn" na krzaki — a nazwa obrębu trafia
    // potem do bazy i na wydruk.
    return odczytajZnalezione(
      utf8.decode(odpowiedz.bodyBytes, allowMalformed: true),
      obreb: nazwa,
      numer: nr,
    );
  }

  static const List<String> _polaZnalezionej = [
    'teryt',
    'voivodeship',
    'county',
    'commune',
    'region',
    'parcel',
  ];

  /// Odpowiedź na „nazwa numer": w pierwszym wierszu **liczba** znalezionych
  /// działek (nie status), dalej po jednym wierszu na działkę. Brak wyników
  /// to „-1 brak wyników".
  static List<DzialkaZnaleziona> odczytajZnalezione(
    String tresc, {
    required String obreb,
    required String numer,
  }) {
    final wiersze = tresc
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList(growable: false);
    if (wiersze.isEmpty) {
      throw const BladUldk('Usługa nie zwróciła żadnych danych.');
    }
    final ile = int.tryParse(wiersze.first.split(' ').first) ?? -1;
    if (ile <= 0) {
      throw BladUldk(
        'Nie znaleziono działki nr $numer w obrębie „$obreb".',
        coZrobic:
            'Sprawdź pisownię nazwy — ma być taka jak na umowie albo '
            'w wypisie (nazwa obrębu to zwykle nazwa wsi). Gdy masz pełny '
            'numer z wypisu, wpisz go zamiast nazwy.',
      );
    }

    final znalezione = <DzialkaZnaleziona>[];
    for (final wiersz in wiersze.skip(1)) {
      final czesci = wiersz.split('|').map((c) => c.trim()).toList();
      if (czesci.length < _polaZnalezionej.length || czesci[0].isEmpty) {
        // Wiersza, którego nie rozumiemy, nie zgadujemy — pomijamy go.
        continue;
      }
      znalezione.add(
        DzialkaZnaleziona(
          teryt: czesci[0],
          wojewodztwo: czesci[1],
          powiat: czesci[2],
          gmina: czesci[3],
          obreb: czesci[4],
          numer: czesci[5],
        ),
      );
    }
    znalezione.sort((a, b) => a.polozenie.compareTo(b.polozenie));
    return znalezione;
  }

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
