import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'klient_uldk.dart';

/// Województwo z kodem TERYT — pierwszy krok szukania działki po nazwie.
class Wojewodztwo {
  const Wojewodztwo({required this.teryt, required this.nazwa});

  /// Dwie cyfry — te same, którymi zaczyna się identyfikator każdej
  /// działki w tym województwie.
  final String teryt;

  final String nazwa;
}

/// Lista województw — dane z pliku, zbudowane skryptem
/// `tools/dzialki/wojewodztwa.py` z odpowiedzi usługi ULDK.
///
/// Usługa nie umie podać listy województw (ani powiatów, gmin, obrębów);
/// umie tylko odpowiedzieć na kod. Kodów jest szesnaście, więc pytamy
/// o nie raz, na komputerze dewelopera, i wozimy wynik z aplikacją.
class SlownikWojewodztw {
  const SlownikWojewodztw({required this.wersja, required this.wojewodztwa});

  factory SlownikWojewodztw.zTekstuJson(String tekst) {
    final json = jsonDecode(tekst) as Map<String, dynamic>;
    return SlownikWojewodztw(
      wersja: json['wersja'] as String,
      wojewodztwa: [
        for (final wpis in json['wojewodztwa'] as List<dynamic>)
          Wojewodztwo(
            teryt: (wpis as Map<String, dynamic>)['teryt'] as String,
            nazwa: wpis['nazwa'] as String,
          ),
      ],
    );
  }

  static const SlownikWojewodztw pusty = SlownikWojewodztw(
    wersja: 'brak',
    wojewodztwa: [],
  );

  final String wersja;
  final List<Wojewodztwo> wojewodztwa;

  Wojewodztwo? poKodzie(String teryt) {
    for (final wojewodztwo in wojewodztwa) {
      if (wojewodztwo.teryt == teryt) {
        return wojewodztwo;
      }
    }
    return null;
  }
}

/// Wczytanie listy województw z pliku dołączonego do aplikacji.
class ZrodloWojewodztw {
  ZrodloWojewodztw({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/wojewodztwa.json';

  final AssetBundle _paczka;
  SlownikWojewodztw? _wPamieci;

  Future<SlownikWojewodztw> wczytaj() async {
    final juz = _wPamieci;
    if (juz != null) {
      return juz;
    }
    final slownik = SlownikWojewodztw.zTekstuJson(
      await _paczka.loadString(sciezka),
    );
    _wPamieci = slownik;
    return slownik;
  }
}

/// Szukanie działki spoza wniosku: województwo → nazwa miejscowości
/// (obrębu) → numer działki z umowy.
///
/// Po co: rolnik dodaje też działki, których nie ma we wniosku —
/// dzierżawione, kupione po złożeniu wniosku, przejęte po sąsiedzie.
/// Pełnego identyfikatora (`061506_2.0007.138`) nie zna i nie ma go gdzie
/// przepisać. Zna za to wieś (to zwykle nazwa obrębu), a numer działki ma
/// na umowie. Usługa ULDK odpowiada na „nazwa numer" listą wszystkich
/// pasujących działek w kraju — z gminą i powiatem, po których rolnik
/// pozna swoją. Województwo zawęża tę listę, bo „Dąbrowa 12" to w kraju
/// kilkadziesiąt działek.
///
/// Klasa trzyma to, co rolnik wpisał, i to, co usługa oddała — bez
/// ekranów, żeby wszystkie trzy wyglądy robiły to tak samo i żeby dało się
/// to sprawdzić testem.
class SzukanieDzialkiPoNazwie {
  SzukanieDzialkiPoNazwie({
    required this.klient,
    this.wojewodztwa = SlownikWojewodztw.pusty,
  });

  final KlientUldk klient;
  final SlownikWojewodztw wojewodztwa;

  Wojewodztwo? wojewodztwo;
  String obreb = '';
  String numer = '';

  /// Co usługa oddała przy ostatnim szukaniu — po zawężeniu do
  /// województwa, gdy je wybrano.
  List<DzialkaZnaleziona> znalezione = const [];

  /// Ile usługa oddała w całym kraju — żeby powiedzieć rolnikowi, że
  /// poza jego województwem też są takie działki.
  int znalezioneWKraju = 0;

  bool get moznaSzukac => obreb.trim().isNotEmpty && numer.trim().isNotEmpty;

  /// Pyta usługę i zostawia wynik w [znalezione]. Rzuca [BladUldk], gdy
  /// nic nie znaleziono albo nie ma połączenia — ekran pokazuje to jednym
  /// zdaniem.
  Future<List<DzialkaZnaleziona>> szukaj() async {
    final wszystkie = await klient.szukajPoNazwie(obreb: obreb, numer: numer);
    znalezioneWKraju = wszystkie.length;
    final kod = wojewodztwo?.teryt;
    final wZawezeniu = kod == null
        ? wszystkie
        : wszystkie
              .where((d) => d.kodWojewodztwa == kod)
              .toList(growable: false);
    if (wZawezeniu.isEmpty) {
      znalezione = const [];
      throw BladUldk(
        'W województwie ${wojewodztwo!.nazwa} nie ma działki nr '
        '${numer.trim()} w obrębie „${obreb.trim()}" — w kraju '
        '${_odmiana(wszystkie.length)}.',
        coZrobic:
            'Sprawdź województwo i pisownię nazwy. Gdy masz pełny numer '
            'z wypisu, wpisz go zamiast nazwy.',
      );
    }
    znalezione = wZawezeniu;
    return wZawezeniu;
  }

  /// Wpisane dane zmieniły się — stary wynik już nie pasuje.
  void wyczyscWynik() {
    znalezione = const [];
    znalezioneWKraju = 0;
  }

  static String _odmiana(int ile) => switch (ile) {
    1 => 'jest 1 taka',
    _ => 'jest $ile takich',
  };
}
