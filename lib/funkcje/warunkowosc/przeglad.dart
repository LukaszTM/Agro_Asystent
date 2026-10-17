import '../../rdzen/reguly/regula_prawna.dart';
import '../../rdzen/wspolne/daty.dart';
import '../zabiegi/repozytorium_zabiegow.dart';
import 'okres_legowy.dart';
import 'okrywa.dart';
import 'pas_od_wody.dart';
import 'zmianowanie.dart';

/// Stan jednej normy GAEC dla gospodarstwa — na ekran i na wydruk.
///
/// Zdania stoją tutaj, a nie w ekranach: oba wyglądy i wydruk na kontrolę
/// muszą mówić to samo.
class StanNormy {
  const StanNormy({
    required this.norma,
    required this.stan,
    required this.coWiemy,
    required this.coZrobic,
    this.zwolnienia = const [],
  });

  final NormaGaec norma;
  final StanWarunku stan;

  /// Zdania o tym, co aplikacja policzyła albo czego jej brakuje.
  final List<String> coWiemy;

  /// Jedno zdanie: co rolnik ma z tym zrobić.
  final String coZrobic;

  /// Zwolnienia z kontroli, które przy tej powierzchni obejmują normę.
  final List<ZwolnienieZKontroli> zwolnienia;

  bool get liczona => norma.aplikacjaLiczy;

  String get stanDlaRolnika => switch (stan) {
    StanWarunku.spelniony => 'Spełniona',
    StanWarunku.niespelniony => 'Niespełniona',
    StanWarunku.nieDotyczy => 'Nie dotyczy',
    StanWarunku.doSprawdzenia => 'Do sprawdzenia',
  };
}

/// Przegląd warunkowości: wszystkie normy GAEC ze słownika razem ze
/// stanem, jaki aplikacja umie policzyć.
///
/// Czego nie policzy — mówi wprost. Normy, których dane ma urząd (udział
/// trwałych użytków zielonych w kraju, wykaz torfowisk, nachylenie stoku,
/// cenne TUZ na Natura 2000), dostają treść przepisu i zdanie, gdzie
/// szukać danych. Nigdy nie piszemy „spełniona" z braku danych.
class PrzegladWarunkowosci {
  const PrzegladWarunkowosci({
    required this.reguly,
    required this.zmianowanie,
    required this.okrywa,
    required this.pasOdWody,
    required this.okresLegowy,
    required this.zabiegi,
  });

  final SlownikRegul reguly;
  final Zmianowanie zmianowanie;
  final Okrywa okrywa;
  final PasOdWody pasOdWody;
  final OkresLegowy okresLegowy;
  final RepozytoriumZabiegow zabiegi;

  Warunkowosc get warunkowosc => reguly.warunkowosc;

  /// Stan wszystkich norm — w kolejności ze słownika (GAEC 1…9).
  Future<List<StanNormy>> stany({
    required String gospodarstwoId,
    int? sezon,
    DateTime? teraz,
  }) async {
    final rok = sezon ?? (teraz ?? DateTime.now()).year;
    final stany = <StanNormy>[];
    for (final norma in warunkowosc.normy) {
      stany.add(switch (norma.id) {
        'gaec_4' => await _pasOdWody(norma, gospodarstwoId),
        'gaec_6' => await _okrywa(norma, gospodarstwoId, rok),
        'gaec_7' => await _zmianowanie(norma, gospodarstwoId, rok),
        'gaec_8' => await _okresLegowy(norma, gospodarstwoId, rok),
        _ => _poza(norma),
      });
    }
    return stany;
  }

  /// Normy, których aplikacja nie policzy — dane ma urząd, nie telefon.
  StanNormy _poza(NormaGaec norma) => StanNormy(
    norma: norma,
    stan: StanWarunku.doSprawdzenia,
    coWiemy: [if (norma.dlaczegoNieLiczy.isNotEmpty) norma.dlaczegoNieLiczy],
    coZrobic:
        'Przeczytaj treść normy i sprawdź u doradcy albo w ARiMR, czy '
        'dotyczy twoich działek — tych danych telefon nie ma.',
  );

  Future<StanNormy> _zmianowanie(
    NormaGaec norma,
    String gospodarstwoId,
    int rok,
  ) async {
    final ocena = await zmianowanie.ocen(
      gospodarstwoId: gospodarstwoId,
      sezon: rok,
    );
    final zdania = <String>[
      'Grunty orne: ${_ha(ocena.powierzchniaGruntowOrnychHa)} ha.',
      if (ocena.stanZmianowania != StanWarunku.nieDotyczy)
        'Inna uprawa niż rok wcześniej na '
            '${_procent(ocena.udzialInnejUprawy)} % gruntów ornych '
            '(przepis wymaga ${_procent(ocena.wymaganyUdzial)} %).',
      if (ocena.polaPonadTrzyLata.isNotEmpty)
        'Na ${ocena.polaPonadTrzyLata.length} polach ta sama uprawa trwa '
            'dłużej, niż pozwala norma.',
      if (ocena.dywersyfikacja case final WynikDywersyfikacji d)
        'Dywersyfikacja: ${d.liczbaUpraw} upraw '
            '(wymagane ${d.wymaganaLiczbaUpraw}), największa '
            '${_procent(d.udzialNajwiekszej)} % '
            '(granica ${_procent(d.granicaNajwiekszej)} %).',
      if (ocena.polaBezRodzajuUzytku.isNotEmpty)
        'Przy ${ocena.polaBezRodzajuUzytku.length} polach nie wiadomo, '
            'czy to grunt orny, łąka czy sad.',
      ...ocena.uwagi,
    ];
    return StanNormy(
      norma: norma,
      stan: ocena.stan,
      coWiemy: zdania,
      coZrobic: switch (ocena.stan) {
        StanWarunku.niespelniony =>
          'Zaplanuj inną uprawę na polach, gdzie ta sama trwa najdłużej, '
              'albo sprawdź plan zmianowania u doradcy.',
        StanWarunku.doSprawdzenia =>
          'Uzupełnij rodzaj użytku i uprawy z poprzednich lat na ekranach '
              'pól — bez nich nie policzymy zmianowania.',
        _ => 'Nic nie trzeba robić; wróć tu po zmianie upraw.',
      },
      zwolnienia: ocena.zwolnienia,
    );
  }

  Future<StanNormy> _okrywa(
    NormaGaec norma,
    String gospodarstwoId,
    int rok,
  ) async {
    final ocena = await okrywa.ocen(gospodarstwoId: gospodarstwoId, sezon: rok);
    final zdania = <String>[
      'Okrywa na ${_procent(ocena.udzialOkrywy)} % gruntów ornych '
          '(przepis wymaga ${_procent(ocena.wymaganyUdzial)} %).',
      if (ocena.terminDo case final DateTime termin)
        'Okrywa ma być na polu do ${Daty.zRokiem(termin)}.',
      if (ocena.brakujeHa > 0)
        'Do normy brakuje okrywy na ${_ha(ocena.brakujeHa)} ha.',
      if (ocena.polaZaDlugaPrzerwa.isNotEmpty)
        'Na ${ocena.polaZaDlugaPrzerwa.length} polach przerwa bez okrywy '
            'była dłuższa niż ${ocena.limitPrzerwyDni} dni.',
      ...ocena.uwagi,
    ];
    return StanNormy(
      norma: norma,
      stan: ocena.stan,
      coWiemy: zdania,
      coZrobic: switch (ocena.stan) {
        StanWarunku.niespelniony =>
          'Zasiej międzyplon albo zostaw ściernisko na kolejnych polach — '
              'inaczej norma nie wyjdzie.',
        StanWarunku.doSprawdzenia =>
          'Powiedz na ekranach pól, co zostaje po zbiorze — bez tego nie '
              'policzymy udziału okrywy.',
        _ => 'Nic nie trzeba robić; wróć tu po zbiorach.',
      },
      zwolnienia: ocena.zwolnienia,
    );
  }

  Future<StanNormy> _pasOdWody(NormaGaec norma, String gospodarstwoId) async {
    final ocena = await pasOdWody.ocen(gospodarstwoId: gospodarstwoId);
    return StanNormy(
      norma: norma,
      stan: ocena.stan,
      coWiemy: [
        'Pola graniczące z wodą: ${ocena.polaPrzyWodzie.length}.',
        ...ocena.uwagi,
      ],
      coZrobic: ocena.polaBezOdpowiedzi.isNotEmpty
          ? 'Powiedz na ekranach pól, które z nich graniczą z wodą — wtedy '
                'aplikacja przypomni o pasie przy wpisie zabiegu.'
          : (ocena.polaPrzyWodzie.isEmpty
                ? 'Nic nie trzeba robić.'
                : 'Przy opryskach i nawożeniu zostaw pas '
                      '${_metry(ocena.szerokoscPasaM)} m od brzegu.'),
    );
  }

  /// GAEC 8 liczymy **z wpisów**: jeśli w okresie zakazu jest wpis
  /// przycinania, norma jest złamana. Brak wpisu nie znaczy, że nikt nie
  /// przycinał — i tak to mówimy, zamiast pisać samo „spełniona".
  Future<StanNormy> _okresLegowy(
    NormaGaec norma,
    String gospodarstwoId,
    int rok,
  ) async {
    final zakazane = [
      for (final praca in okresLegowy.prace.prace)
        if (praca.maZakazOkresowy) praca.id,
    ];
    final wpisy = await zabiegi.poPodrodzaju(
      gospodarstwoId: gospodarstwoId,
      podrodzaje: zakazane,
      rok: rok,
    );
    final wOkresie = [
      for (final zabieg in wpisy)
        if (okresLegowy.ostrzezeniePrzedZapisem(
              idPracy: zabieg.podrodzaj,
              kiedy: zabieg.data,
            ) !=
            null)
          zabieg,
    ];
    final termin = okresLegowy.terminZakazu(
      okresLegowy.prace.prace.firstWhere((p) => p.maZakazOkresowy),
    );
    final okres = termin == null
        ? ''
        : 'od ${Daty.dzienIMiesiac(termin.od)} do '
              '${Daty.dzienIMiesiac(termin.doDnia)}';

    return StanNormy(
      norma: norma,
      stan: wOkresie.isEmpty ? StanWarunku.spelniony : StanWarunku.niespelniony,
      coWiemy: [
        if (wOkresie.isEmpty)
          'Według wpisów w $rok r. nie było przycinania drzew ani '
              'żywopłotów w okresie lęgowym ptaków ($okres).'
        else
          'W okresie lęgowym ptaków ($okres) jest '
              '${wOkresie.length} wpisów przycinania.',
        'Zakaz niszczenia pomników przyrody, wąskich rowów i małych oczek '
            'wodnych obowiązuje cały rok — tego aplikacja nie sprawdzi.',
      ],
      coZrobic: wOkresie.isEmpty
          ? 'Przycinanie zaplanuj poza okresem lęgowym; przy wpisie '
                'aplikacja i tak przypomni.'
          : 'Sprawdź te wpisy: jeśli dotyczyły wierzb, drzew owocowych '
                'albo zagajnika, popraw rodzaj pracy — przepis je wyłącza.',
    );
  }

  static String _ha(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');

  static String _procent(double wartosc) => wartosc.toStringAsFixed(0);

  static String _metry(double wartosc) => wartosc == wartosc.roundToDouble()
      ? wartosc.toStringAsFixed(0)
      : wartosc.toStringAsFixed(1).replaceAll('.', ',');
}
