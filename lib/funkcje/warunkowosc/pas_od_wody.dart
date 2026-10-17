import '../../rdzen/modele/zabieg.dart';
import '../../rdzen/reguly/regula_prawna.dart';
import '../dzialki/granica_z_woda.dart';
import '../dzialki/repozytorium_pol.dart';
import 'zmianowanie.dart' show StanWarunku;

/// Ostrzeżenie o pasie od wody — pokazywane **przed** zapisem oprysku
/// albo nawożenia na polu, które graniczy z wodą.
///
/// Treść stoi tutaj, a nie w ekranach, bo oba wyglądy muszą mówić to samo.
/// Ostrzeżenie nie blokuje zapisu: zabieg mógł być wykonany poza pasem,
/// a dokumentacja ma być prawdziwa.
class OstrzezenieOPasieOdWody {
  const OstrzezenieOPasieOdWody({
    required this.nazwyPol,
    required this.szerokoscPasaM,
    required this.rodzaj,
    this.rowBezPasaM,
  });

  /// Pola objęte ostrzeżeniem — tylko te, przy których rolnik powiedział,
  /// że graniczą z wodą.
  final List<String> nazwyPol;

  /// Szerokość pasa z przepisu, w metrach.
  final double szerokoscPasaM;

  /// Szerokość rowu, od której przepis pasa nie wymaga.
  final double? rowBezPasaM;

  final RodzajZabiegu rodzaj;

  String get _pola => nazwyPol.length == 1
      ? 'Pole ${nazwyPol.single} graniczy z wodą'
      : 'Pola ${nazwyPol.join(', ')} graniczą z wodą';

  String get tresc =>
      '$_pola, a norma GAEC 4 zabrania tu $_coZabronione '
      'w pasie ${_metry(szerokoscPasaM)} m od brzegu.';

  String get coZrobic {
    final rowy = rowBezPasaM == null
        ? ''
        : ' Rowów szerszych niż ${_metry(rowBezPasaM!)} m to nie dotyczy.';
    return 'Zapisz zabieg tak, jak był — dokumentacja ma być prawdziwa. '
        'Jeśli zabieg sięgnął brzegu, przy kontroli liczy się to jako '
        'złamanie normy.$rowy';
  }

  String get _coZabronione => rodzaj == RodzajZabiegu.nawozenie
      ? 'stosowania nawozów'
      : 'stosowania środków ochrony roślin';

  static String _metry(double wartosc) => wartosc == wartosc.roundToDouble()
      ? wartosc.toStringAsFixed(0)
      : wartosc.toStringAsFixed(1).replaceAll('.', ',');
}

/// Stan normy GAEC 4 w gospodarstwie.
class OcenaPasaOdWody {
  const OcenaPasaOdWody({
    required this.polaPrzyWodzie,
    required this.polaBezOdpowiedzi,
    required this.szerokoscPasaM,
    required this.uwagi,
  });

  /// Pola, przy których rolnik powiedział, że graniczą z wodą.
  final List<Pole> polaPrzyWodzie;

  /// Pola, przy których jeszcze nie odpowiedział.
  final List<Pole> polaBezOdpowiedzi;

  final double szerokoscPasaM;
  final List<String> uwagi;

  /// Norma to zakaz czynności, a nie liczba do policzenia: aplikacja nie
  /// wie, czy opryskiwacz sięgnął brzegu. Dlatego stan mówi tylko, czy
  /// rolnik odpowiedział na pytanie i czy jest gdzie uważać.
  StanWarunku get stan {
    if (polaBezOdpowiedzi.isNotEmpty) {
      return StanWarunku.doSprawdzenia;
    }
    return polaPrzyWodzie.isEmpty
        ? StanWarunku.nieDotyczy
        : StanWarunku.doSprawdzenia;
  }
}

/// Norma GAEC 4: pas bez nawozów i środków ochrony roślin od brzegu wody.
///
/// Szerokość pasa i wyłączenie wąskich rowów pochodzą ze słownika reguł.
class PasOdWody {
  const PasOdWody({required this.pola, required this.reguly});

  final RepozytoriumPol pola;
  final SlownikRegul reguly;

  NormaGaec? get norma => reguly.warunkowosc.norma('gaec_4');

  double? get szerokoscPasaM => norma?.prog('pas_od_wody_m')?.wartosc;

  double? get rowBezPasaM => norma?.prog('row_bez_pasa_m')?.wartosc;

  /// Pytanie, które ekran pola zadaje rolnikowi — z liczbami z przepisu.
  String get pytanie {
    final pas = szerokoscPasaM;
    final row = rowBezPasaM;
    final pasOpis = pas == null
        ? ''
        : ' Norma GAEC 4 zabrania wtedy nawozów i środków ochrony roślin '
              'w pasie ${OstrzezenieOPasieOdWody._metry(pas)} m od brzegu.';
    final rowOpis = row == null
        ? ''
        : ' Rowy do ${OstrzezenieOPasieOdWody._metry(row)} m szerokości '
              'się nie liczą.';
    return 'Czy to pole graniczy z jeziorem, rzeką, kanałem albo rowem?'
        '$pasOpis$rowOpis';
  }

  /// Ostrzeżenie przed zapisem zabiegu albo `null`, gdy nie ma o czym
  /// ostrzegać: zabieg nie jest opryskiem ani nawożeniem, żadne pole nie
  /// graniczy z wodą albo słownik nie podaje szerokości pasa.
  OstrzezenieOPasieOdWody? ostrzezeniePrzedZapisem({
    required List<Pole> pola,
    required RodzajZabiegu? rodzaj,
  }) {
    if (rodzaj != RodzajZabiegu.oprysk && rodzaj != RodzajZabiegu.nawozenie) {
      return null;
    }
    final pas = szerokoscPasaM;
    if (pas == null) {
      return null;
    }
    final przyWodzie = pola
        .where((p) => p.granicaZWoda == GranicaZWoda.tak)
        .toList(growable: false);
    if (przyWodzie.isEmpty) {
      return null;
    }
    return OstrzezenieOPasieOdWody(
      nazwyPol: przyWodzie.map((p) => p.nazwa).toList(growable: false),
      szerokoscPasaM: pas,
      rowBezPasaM: rowBezPasaM,
      rodzaj: rodzaj!,
    );
  }

  /// Stan normy w gospodarstwie — na ekran „Warunkowość" i na wydruk.
  Future<OcenaPasaOdWody> ocen({required String gospodarstwoId}) async {
    final wszystkie = await pola.wszystkie(gospodarstwoId);
    final przyWodzie = wszystkie
        .where((p) => p.granicaZWoda == GranicaZWoda.tak)
        .toList(growable: false);
    final bezOdpowiedzi = wszystkie
        .where((p) => !p.granicaZWoda.znana)
        .toList(growable: false);
    final pas = szerokoscPasaM;
    return OcenaPasaOdWody(
      polaPrzyWodzie: przyWodzie,
      polaBezOdpowiedzi: bezOdpowiedzi,
      szerokoscPasaM: pas ?? 0,
      uwagi: [
        if (bezOdpowiedzi.isNotEmpty)
          'Przy ${bezOdpowiedzi.length} polach nie wiemy, czy graniczą '
              'z wodą — dopóki nie powiesz, aplikacja o pasie nie ostrzega.',
        if (przyWodzie.isNotEmpty && pas != null)
          'Na ${przyWodzie.length} polach trzeba zostawić pas '
              '${OstrzezenieOPasieOdWody._metry(pas)} m od brzegu bez '
              'nawozów i środków ochrony roślin. Czy opryskiwacz sięgnął '
              'brzegu, wie tylko ten, kto jechał — tego aplikacja nie '
              'policzy.',
      ],
    );
  }
}
