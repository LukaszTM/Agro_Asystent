import 'dart:io';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:path/path.dart' as sciezki;

/// Rozpakowuje słowniki dołączone do aplikacji do katalogu, z którego może je
/// czytać SQLite.
///
/// Plik w assetach jest spakowany (1,8 MB zamiast 9,6 MB). Rozpakowujemy go raz
/// — przy pierwszym uruchomieniu i po każdej aktualizacji danych. Nie wymaga
/// internetu: dane jadą razem z aplikacją (plan, pkt 11: nie pobieramy stron
/// ministerstwa z telefonu rolnika).
class PrzygotowanieSlownikow {
  const PrzygotowanieSlownikow({
    this.sciezkaAssetu = 'assets/dane/slowniki.sqlite.gz',
    AssetBundle? paczka,
  }) : _paczka = paczka; // ignore: prefer_initializing_formals

  /// Paczka assetów — podmieniana w testach.

  final String sciezkaAssetu;
  final AssetBundle? _paczka;

  AssetBundle get _bundle => _paczka ?? rootBundle;

  /// Zwraca ścieżkę gotowego pliku słowników, rozpakowując go w razie potrzeby.
  ///
  /// [katalog] to miejsce na dane aplikacji; podaje je wywołujący, żeby ta
  /// klasa nie zależała od platformy i dała się sprawdzić w testach.
  Future<String> przygotuj({
    required String katalog,
    String nazwaPliku = 'slowniki.sqlite',
    bool wymusPonownie = false,
  }) async {
    final cel = File(sciezki.join(katalog, nazwaPliku));
    final znacznik = File('${cel.path}.zrodlo');

    final dane = await _bundle.load(sciezkaAssetu);
    final rozmiarAssetu = dane.lengthInBytes.toString();

    final aktualny =
        cel.existsSync() &&
        znacznik.existsSync() &&
        znacznik.readAsStringSync() == rozmiarAssetu;
    if (aktualny && !wymusPonownie) {
      return cel.path;
    }

    await Directory(katalog).create(recursive: true);
    final spakowane = dane.buffer.asUint8List(
      dane.offsetInBytes,
      dane.lengthInBytes,
    );
    await cel.writeAsBytes(gzip.decode(spakowane), flush: true);
    await znacznik.writeAsString(rozmiarAssetu, flush: true);
    return cel.path;
  }
}
