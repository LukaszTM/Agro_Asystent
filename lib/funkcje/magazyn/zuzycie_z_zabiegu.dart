import '../../rdzen/dostep/dostep_funkcji.dart';
import '../../rdzen/dostep/funkcja.dart';
import '../nawozenie/nawoz.dart';
import '../zabiegi/dane_wpisu.dart';
import 'magazyn.dart';

/// Odpisanie towaru z magazynu po zapisie zabiegu — jedno miejsce dla obu
/// wyglądów i dla wszystkich ekranów wpisu.
///
/// Zasady, których tu pilnujemy:
/// * magazyn jest funkcją premium, więc pytamy o to [DostepFunkcji] —
///   warunek „czy kupił" zostaje w `lib/rdzen/dostep/`;
/// * ewidencja zabiegu zapisuje się **zawsze**, niezależnie od magazynu;
/// * czego nie umiemy policzyć (niepewna dawka, dawka liczona nie na
///   hektar), tego nie zgadujemy — ruchu wtedy nie ma;
/// * pozycji magazynu nie zakładamy sami: magazyn pokazuje to, co rolnik
///   do niego wpisał.
abstract final class ZuzycieZZabiegu {
  static Future<String?> odpisz({
    required Magazyn magazyn,
    required DostepFunkcji dostep,
    required DaneWpisu dane,
    required String zabiegId,
    required String urzadzenie,
  }) async {
    if (!dostep.czyDostepna(Funkcja.magazyn)) {
      return null;
    }

    final srodek = dane.srodek;
    if (srodek != null) {
      return magazyn.odpiszZabieg(
        gospodarstwoId: dane.gospodarstwoId,
        zabiegId: zabiegId,
        rodzaj: RodzajPozycji.srodek,
        nazwa: srodek.nazwa,
        ilosc: dane.iloscSrodkaRazem,
        kiedy: dane.kiedy,
        urzadzenie: urzadzenie,
      );
    }

    final nawoz = dane.nawoz;
    if (nawoz != null) {
      return magazyn.odpiszZabieg(
        gospodarstwoId: dane.gospodarstwoId,
        zabiegId: zabiegId,
        rodzaj: RodzajPozycji.nawoz,
        nazwa: nawoz.nazwa,
        ilosc: dane.iloscNawozuRazem,
        kiedy: dane.kiedy,
        urzadzenie: urzadzenie,
      );
    }
    return null;
  }

  /// Jednostka, w której magazyn trzyma nawóz podany w tej dawce.
  static String jednostkaNawozu(JednostkaDawki jednostka) =>
      jednostka.opis.split('/').first;
}
