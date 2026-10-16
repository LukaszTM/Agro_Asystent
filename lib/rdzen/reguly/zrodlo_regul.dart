import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'gminy_terminy.dart';
import 'regula_prawna.dart';

/// Wczytuje słownik reguł prawnych z pliku danych dołączonego do aplikacji.
///
/// Plik można podmienić aktualizacją danych — bez przebudowy aplikacji
/// (CLAUDE.md, reguła 1).
class ZrodloRegul {
  ZrodloRegul({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/reguly_prawne.json';

  final AssetBundle _paczka;
  SlownikRegul? _wPamieci;

  Future<SlownikRegul> wczytaj() async {
    final juzWczytany = _wPamieci;
    if (juzWczytany != null) {
      return juzWczytany;
    }
    final tekst = await _paczka.loadString(sciezka);
    final slownik = SlownikRegul.zTekstuJson(tekst);
    _wPamieci = slownik;
    return slownik;
  }
}

/// Wczytuje wykazy gmin z załączników do programu azotanowego.
///
/// Osobny plik, bo to dane urzędowe o innym cyklu życia niż reszta słownika:
/// wykaz gmin zmienia się razem z rozporządzeniem, a nie z aplikacją.
class ZrodloGminTerminow {
  ZrodloGminTerminow({AssetBundle? paczka}) : _paczka = paczka ?? rootBundle;

  static const String sciezka = 'assets/dane/gminy_terminy_azotowe.json';

  final AssetBundle _paczka;
  SlownikGminTerminow? _wPamieci;

  Future<SlownikGminTerminow> wczytaj() async {
    final juzWczytany = _wPamieci;
    if (juzWczytany != null) {
      return juzWczytany;
    }
    final tekst = await _paczka.loadString(sciezka);
    final slownik = SlownikGminTerminow.zTekstuJson(tekst);
    _wPamieci = slownik;
    return slownik;
  }
}
