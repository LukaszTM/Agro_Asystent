import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pogoda.dart';

/// Pogoda się nie udała — z gotowym zdaniem dla rolnika.
class BladPogody implements Exception {
  const BladPogody(this.wiadomosc, {this.coZrobic});

  final String wiadomosc;
  final String? coZrobic;

  @override
  String toString() => wiadomosc;
}

/// Prognoza z Norweskiego Instytutu Meteorologicznego (MET Norway).
///
/// Wybór źródła i licencję opisuje `docs/decyzje/ADR-0008-pogoda.md`.
/// Dane są na licencji CC BY 4.0 — stąd wymóg, żeby nazwa źródła stała na
/// ekranie, oraz obowiązek przedstawiania się w nagłówku `User-Agent`.
///
/// Pogoda jest **dodatkiem**: program bez niej działa w całości, a bez
/// internetu pokazuje ostatni zapisany odczyt z datą.
class KlientPogody {
  const KlientPogody({
    http.Client? klient,
    this.adres = 'https://api.met.no/weatherapi/locationforecast/2.0/compact',
    this.przedstawienie = domyslnePrzedstawienie,
  }) : _klient = klient; // ignore: prefer_initializing_formals

  /// Klient HTTP — podmieniany w testach, żeby nie łączyć się z usługą.
  final http.Client? _klient;

  final String adres;

  /// Czym program przedstawia się usłudze. Wymóg regulaminu MET: nazwa
  /// aplikacji i sposób kontaktu.
  final String przedstawienie;

  static const String domyslnePrzedstawienie =
      'MojLan/0.1 (github.com/LukaszTM/Agro_Asystent)';

  static const String nazwaZrodla = 'MET Norway (CC BY 4.0)';

  Future<Prognoza> pobierz({
    required double szerokosc,
    required double dlugosc,
    DateTime? teraz,
  }) async {
    // Regulamin usługi każe skracać współrzędne — inaczej każde
    // gospodarstwo jest osobnym punktem i psuje pamięć podręczną serwera.
    final zapytanie = Uri.parse(adres).replace(
      queryParameters: {
        'lat': szerokosc.toStringAsFixed(4),
        'lon': dlugosc.toStringAsFixed(4),
      },
    );

    final klient = _klient ?? http.Client();
    final http.Response odpowiedz;
    try {
      odpowiedz = await klient.get(
        zapytanie,
        headers: {'User-Agent': przedstawienie, 'Accept': 'application/json'},
      );
    } on Exception {
      throw const BladPogody(
        'Nie udało się połączyć z serwisem pogodowym.',
        coZrobic: 'Sprawdź internet. Program działa dalej bez pogody.',
      );
    } finally {
      if (_klient == null) {
        klient.close();
      }
    }

    if (odpowiedz.statusCode == 429) {
      throw const BladPogody(
        'Serwis pogodowy prosi o przerwę w zapytaniach.',
        coZrobic: 'Spróbuj za kilkanaście minut.',
      );
    }
    if (odpowiedz.statusCode != 200) {
      throw BladPogody(
        'Serwis pogodowy odpowiedział błędem (${odpowiedz.statusCode}).',
        coZrobic: 'Spróbuj później — to nie jest usterka gospodarstwa.',
      );
    }

    try {
      return _zOdpowiedzi(
        jsonDecode(utf8.decode(odpowiedz.bodyBytes)) as Map<String, dynamic>,
        szerokosc: szerokosc,
        dlugosc: dlugosc,
        teraz: teraz ?? DateTime.now(),
      );
    } on BladPogody {
      rethrow;
    } on Object {
      throw const BladPogody(
        'Nie rozumiem odpowiedzi serwisu pogodowego.',
        coZrobic: 'Spróbuj później albo zgłoś to jako usterkę programu.',
      );
    }
  }

  Prognoza _zOdpowiedzi(
    Map<String, dynamic> json, {
    required double szerokosc,
    required double dlugosc,
    required DateTime teraz,
  }) {
    final wlasciwosci = json['properties'] as Map<String, dynamic>?;
    final szereg = wlasciwosci?['timeseries'] as List<dynamic>?;
    if (szereg == null || szereg.isEmpty) {
      throw const BladPogody('Serwis pogodowy nie podał prognozy.');
    }

    final godziny = <GodzinaPogody>[];
    for (final wpis in szereg) {
      final punkt = wpis as Map<String, dynamic>;
      final dane = punkt['data'] as Map<String, dynamic>?;
      final chwila = dane?['instant'] as Map<String, dynamic>?;
      final szczegoly = chwila?['details'] as Map<String, dynamic>?;
      final temperatura = (szczegoly?['air_temperature'] as num?)?.toDouble();
      final wiatr = (szczegoly?['wind_speed'] as num?)?.toDouble();
      if (temperatura == null || wiatr == null) {
        // Bez temperatury i wiatru godzina nic nie mówi — pomijamy ją
        // zamiast dopisywać zera.
        continue;
      }
      final nastepnaGodzina = dane?['next_1_hours'] as Map<String, dynamic>?;
      final opadSzczegoly =
          nastepnaGodzina?['details'] as Map<String, dynamic>?;
      final podsumowanie = nastepnaGodzina?['summary'] as Map<String, dynamic>?;

      godziny.add(
        GodzinaPogody(
          czas: DateTime.parse(punkt['time'] as String).toLocal(),
          temperatura: temperatura,
          wiatr: wiatr,
          porywy: (szczegoly?['wind_speed_of_gust'] as num?)?.toDouble(),
          wilgotnosc: (szczegoly?['relative_humidity'] as num?)?.toDouble(),
          zachmurzenie: (szczegoly?['cloud_area_fraction'] as num?)?.toDouble(),
          opad: (opadSzczegoly?['precipitation_amount'] as num?)?.toDouble(),
          symbol: podsumowanie?['symbol_code'] as String?,
        ),
      );
    }

    if (godziny.isEmpty) {
      throw const BladPogody('Serwis pogodowy nie podał prognozy.');
    }

    return Prognoza(
      pobrano: teraz,
      szerokosc: szerokosc,
      dlugosc: dlugosc,
      godziny: godziny,
      zrodlo: nazwaZrodla,
    );
  }
}
