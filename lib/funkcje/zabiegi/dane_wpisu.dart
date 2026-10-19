import '../../rdzen/modele/zabieg.dart';
import '../dzialki/repozytorium_pol.dart';
import '../nawozenie/nawoz.dart';
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

  /// Chwila zabiegu. Na telefonie „teraz" (uzupełnia się sama); na
  /// komputerze rolnik dopisuje zabiegi z kilku dni, więc da się ją zmienić.
  DateTime kiedy;

  final List<Pole> pola = [];
  RodzajZabiegu? rodzaj;
  DopuszczonySrodek? srodek;

  /// Nawóz — przy wpisie nawożenia (krok 6 etapu 1).
  Nawoz? nawoz;

  JednostkaDawki jednostkaDawki = JednostkaDawki.kilogramyNaHektar;

  double? dawka;
  String? przyczyna;

  /// Dzień przyorania nawozu naturalnego (tabela 15 programu azotanowego).
  /// `null` znaczy „jeszcze nie" — datę da się dopisać z rejestru.
  DateTime? dataPrzyorania;

  /// Jednostka dawki odczytanej z etykiety — ustawiana tylko wtedy, gdy
  /// rejestr nie podał dawki w jednoznacznej postaci. Wtedy liczbę wpisuje
  /// rolnik i musi powiedzieć, w czym ją podaje.
  JednostkaDawkiSrodka? jednostkaZEtykiety;

  /// Czy dawkę trzeba odczytać z etykiety, bo rejestr jej nie podaje.
  bool get dawkaZEtykiety {
    final wybrany = srodek;
    return wybrany != null && !wybrany.dawkaZnana;
  }

  /// Jednostka, która pójdzie do ewidencji: z rejestru, a gdy rejestr jej
  /// nie podaje — ta, którą wskazał rolnik przy etykiecie.
  String? get dawkaJednostka =>
      srodek?.dawkaJednostka ?? jednostkaZEtykiety?.jednostka;

  /// Na co ta dawka wypada („ha", „stezenie"). Tak samo jak jednostka:
  /// z rejestru albo od rolnika.
  String? get dawkaOdniesienie =>
      srodek?.dawkaOdniesienie ?? jednostkaZEtykiety?.odniesienie;

  /// Powierzchnia liczona z wybranych pól — rolnik jej nie wpisuje.
  int get powierzchniaAr =>
      pola.fold(0, (suma, pole) => suma + pole.powierzchniaAr);

  String get powierzchniaOpis =>
      '${(powierzchniaAr / 100).toStringAsFixed(2).replaceAll('.', ',')} ha';

  bool get gotowyDoZapisu =>
      pola.isNotEmpty &&
      rodzaj != null &&
      (rodzaj != RodzajZabiegu.oprysk || srodek != null) &&
      (rodzaj != RodzajZabiegu.nawozenie || nawoz != null);

  /// Ile azotu wniesie ta dawka na hektar — `null`, gdy nawóz nie ma znanej
  /// zawartości azotu (wtedy niczego nie zgadujemy).
  double? get azotKgNaHa {
    final wybrany = nawoz;
    final wartosc = dawka;
    if (wybrany == null || wartosc == null) {
      return null;
    }
    return wybrany.azotKgNaHa(wartosc, jednostkaDawki);
  }

  /// Ile razem nawozu idzie na wybrane pola — w jednostce, którą wybrał
  /// rolnik (kg albo t). `null`, gdy nie ma jeszcze dawki.
  double? get iloscNawozuRazem {
    final wartosc = dawka;
    if (nawoz == null || wartosc == null) {
      return null;
    }
    return wartosc * powierzchniaAr / 100;
  }

  /// Ile razem środka trzeba na wybrane pola — rolnik pyta o to przy nalewaniu.
  double? get iloscSrodkaRazem {
    final wartosc = dawka;
    if (wartosc == null || srodek == null || dawkaOdniesienie != 'ha') {
      return null;
    }
    return wartosc * powierzchniaAr / 100;
  }
}
