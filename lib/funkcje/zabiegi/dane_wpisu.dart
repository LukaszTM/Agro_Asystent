import '../../rdzen/modele/zabieg.dart';
import '../dzialki/repozytorium_pol.dart';
import 'slownik_srodkow.dart';

/// Stan wpisywanego zabiegu, przenoszony między ekranami.
///
/// Miara powodzenia z planu: zapis w najwyżej pięciu dotknięciach. Dlatego
/// wszystko, co da się uzupełnić samo (data, godzina, powierzchnia, dawka),
/// jest tu wypełnione od razu.
class DaneWpisu {
  DaneWpisu({
    required this.gospodarstwoId,
    required this.urzadzenie,
    DateTime? kiedy,
  }) : kiedy = kiedy ?? DateTime.now();

  final String gospodarstwoId;
  final String urzadzenie;
  final DateTime kiedy;

  final List<Pole> pola = [];
  RodzajZabiegu? rodzaj;
  DopuszczonySrodek? srodek;
  double? dawka;
  String? przyczyna;

  /// Powierzchnia liczona z wybranych pól — rolnik jej nie wpisuje.
  int get powierzchniaAr =>
      pola.fold(0, (suma, pole) => suma + pole.powierzchniaAr);

  String get powierzchniaOpis =>
      '${(powierzchniaAr / 100).toStringAsFixed(2).replaceAll('.', ',')} ha';

  bool get gotowyDoZapisu =>
      pola.isNotEmpty &&
      rodzaj != null &&
      (rodzaj != RodzajZabiegu.oprysk || srodek != null);

  /// Ile razem środka trzeba na wybrane pola — rolnik pyta o to przy nalewaniu.
  double? get iloscSrodkaRazem {
    final wartosc = dawka;
    if (wartosc == null || srodek?.dawkaOdniesienie != 'ha') {
      return null;
    }
    return wartosc * powierzchniaAr / 100;
  }
}
