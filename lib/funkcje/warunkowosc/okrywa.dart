import '../../rdzen/reguly/regula_prawna.dart';
import '../../rdzen/wspolne/daty.dart';
import '../../rdzen/wspolne/tekst.dart';
import '../dzialki/repozytorium_pol.dart';
import '../dzialki/rodzaj_uzytku.dart';
import '../dzialki/uprawy_pola.dart';
import 'okrywa_pola.dart';
import 'zmianowanie.dart' show StanWarunku;

/// Forma okrywy, którą aplikacja **podpowiada** z wpisów rolnika.
///
/// Podpowiedź nigdy nie staje się deklaracją sama z siebie — rolnik ją
/// potwierdza albo wybiera co innego (CLAUDE.md: nie zgadujemy).
class PodpowiedzOkrywy {
  const PodpowiedzOkrywy({required this.forma, required this.skad});

  final FormaOkrywy forma;

  /// Zdanie dla rolnika: skąd ta podpowiedź się wzięła.
  final String skad;
}

/// Jedno pole w ocenie okrywy ochronnej gleby.
class PoleWOkrywie {
  const PoleWOkrywie({
    required this.pole,
    required this.deklaracja,
    required this.forma,
    required this.limitPrzerwyDni,
    this.dataZbioruZWpisow,
    this.podpowiedz,
  });

  final Pole pole;

  /// Co podał rolnik — `null`, gdy jeszcze nic nie podał.
  final OkrywaPola? deklaracja;

  /// Forma ze słownika reguł albo `null`, gdy deklaracji nie ma (lub
  /// wskazuje formę, której słownik już nie zna).
  final FormaOkrywy? forma;

  /// Najdłuższa dozwolona przerwa bez okrywy — z przepisu, w dniach.
  final int limitPrzerwyDni;

  /// Dzień zbioru policzony z wpisów zabiegów.
  final DateTime? dataZbioruZWpisow;

  /// Podpowiedź formy dla pól bez deklaracji.
  final PodpowiedzOkrywy? podpowiedz;

  double get powierzchniaHa => pole.powierzchniaHa;

  bool get zadeklarowana => deklaracja != null;

  /// Przerwa dłuższa niż dopuszcza przepis (4 tygodnie na siew ozimin).
  bool get przerwaZaDluga {
    final dni = deklaracja?.przerwaDni;
    return dni != null && limitPrzerwyDni > 0 && dni > limitPrzerwyDni;
  }

  /// Czy pole liczy się do udziału okrywy.
  bool get liczySie => (forma?.liczJakoOkrywe ?? false) && !przerwaZaDluga;

  /// Rolnik powiedział wprost, że okrywy nie ma.
  bool get bezOkrywy => zadeklarowana && !liczySie;

  /// Dzień zbioru: z deklaracji, a gdy jej nie ma — z wpisów zabiegów.
  DateTime? get dataZbioru => deklaracja?.dataZbioru ?? dataZbioruZWpisow;

  bool get doSprawdzenia => !zadeklarowana;
}

/// Ocena normy GAEC 6 dla gospodarstwa w jednym sezonie.
class OcenaOkrywy {
  const OcenaOkrywy({
    required this.sezon,
    required this.powierzchniaGruntowOrnychHa,
    required this.powierzchniaUrHa,
    required this.pola,
    required this.udzialOkrywy,
    required this.udzialMozliwy,
    required this.wymaganyUdzial,
    required this.limitPrzerwyDni,
    required this.polaBezDeklaracji,
    required this.polaBezOkrywy,
    required this.polaZaDlugaPrzerwa,
    required this.polaBezRodzajuUzytku,
    required this.polaUprawTrwalych,
    required this.zwolnienia,
    required this.uwagi,
    this.terminDo,
  });

  final int sezon;
  final double powierzchniaGruntowOrnychHa;
  final double powierzchniaUrHa;
  final List<PoleWOkrywie> pola;

  /// Udział gruntów ornych z **potwierdzoną** okrywą.
  final double udzialOkrywy;

  /// Udział, jaki wyszedłby, gdyby wszystkie pola bez deklaracji miały
  /// okrywę. Powyżej wymaganego znaczy „jeszcze da się dojść do normy".
  final double udzialMozliwy;

  final double wymaganyUdzial;
  final int limitPrzerwyDni;

  /// Ostatni dzień, w którym okrywa ma być na polu (15 października).
  final DateTime? terminDo;

  final List<PoleWOkrywie> polaBezDeklaracji;
  final List<PoleWOkrywie> polaBezOkrywy;
  final List<PoleWOkrywie> polaZaDlugaPrzerwa;

  /// Pola, przy których rolnik nie powiedział jeszcze, jakim są użytkiem.
  final List<Pole> polaBezRodzajuUzytku;

  /// Sady i inne uprawy trwałe — tam przepis liczy okrywę w międzyrzędziach
  /// zimą, czego aplikacja z wpisów nie policzy.
  final List<Pole> polaUprawTrwalych;

  /// Zwolnienia z kontroli, które przy tej powierzchni obejmują GAEC 6.
  final List<ZwolnienieZKontroli> zwolnienia;

  /// Zdania, które aplikacja musi powiedzieć rolnikowi o swoim rachunku.
  final List<String> uwagi;

  bool get zwolnioneZKontroli => zwolnienia.isNotEmpty;

  /// Stan normy. Brak danych nigdy nie daje „spełniona", a norma uznana za
  /// spełnioną z samych potwierdzonych pól nie czeka na resztę deklaracji.
  StanWarunku get stan {
    if (powierzchniaGruntowOrnychHa <= 0 || wymaganyUdzial <= 0) {
      return StanWarunku.nieDotyczy;
    }
    if (udzialOkrywy + 1e-9 >= wymaganyUdzial) {
      return StanWarunku.spelniony;
    }
    if (udzialMozliwy + 1e-9 < wymaganyUdzial) {
      return StanWarunku.niespelniony;
    }
    return StanWarunku.doSprawdzenia;
  }

  /// Ile hektarów okrywy brakuje do normy. `0`, gdy norma jest spełniona.
  double get brakujeHa {
    final potrzebne = powierzchniaGruntowOrnychHa * wymaganyUdzial / 100;
    final jest = powierzchniaGruntowOrnychHa * udzialOkrywy / 100;
    final brak = potrzebne - jest;
    return brak <= 0 ? 0 : brak;
  }
}

/// Jedna odpowiedź na pytanie o przerwę bez okrywy.
///
/// Przepis mówi o tygodniach („nie dłużej niż 4 tygodnie"), więc i pytanie
/// idzie w tygodniach: rolnik nie liczy dni, a wybrana liczba tygodni jest
/// dokładna, nie przybliżona.
class WyborPrzerwy {
  const WyborPrzerwy({
    required this.etykieta,
    required this.dni,
    required this.ponadLimit,
  });

  final String etykieta;

  /// Ile dni pole było bez okrywy.
  final int dni;

  /// Czy ta odpowiedź znaczy przerwę dłuższą, niż dopuszcza przepis.
  final bool ponadLimit;
}

/// Co ekran pola ma powiedzieć o okrywie — te same zdania w obu wyglądach.
///
/// Treść stoi tutaj, a nie w ekranach, bo „Prosty" i „Nowoczesny" muszą
/// mówić rolnikowi to samo; różni się tylko sposób wyboru.
class OpisOkrywyPola {
  const OpisOkrywyPola({
    required this.sezon,
    required this.formy,
    required this.wymaganyUdzial,
    required this.limitPrzerwyDni,
    required this.deklaracja,
    required this.forma,
    required this.podpowiedz,
    required this.dataZbioru,
    required this.terminDo,
  });

  final int sezon;

  /// Formy do wyboru — ze słownika reguł, nie z listy w ekranie.
  final FormyOkrywy formy;

  final double wymaganyUdzial;
  final int limitPrzerwyDni;

  /// Co podał rolnik — `null`, gdy jeszcze nic nie podał.
  final OkrywaPola? deklaracja;

  final FormaOkrywy? forma;
  final PodpowiedzOkrywy? podpowiedz;

  /// Dzień zbioru z deklaracji albo z wpisów zabiegów.
  final DateTime? dataZbioru;

  /// Ostatni dzień, w którym okrywa ma być na polu.
  final DateTime? terminDo;

  bool get doPodania => deklaracja == null;

  String get naglowek => 'Co zostaje na polu po zbiorze';

  /// Po co to pytanie — z progiem i terminem z przepisu.
  String get wyjasnienie {
    final czesci = <String>[
      if (wymaganyUdzial > 0)
        'Norma GAEC 6 chce okrywy na co najmniej '
            '${wymaganyUdzial.toStringAsFixed(0)} % gruntów ornych',
      if (terminDo != null) 'do ${Daty.zRokiem(terminDo!)}',
    ];
    final zdanie = czesci.isEmpty ? '' : '${czesci.join(' ')}. ';
    return '${zdanie}Zaznacz, co zostaje na tym polu — tego aplikacja '
        'nie zgadnie z uprawy.';
  }

  /// Zdanie o podpowiedzi albo `null`, gdy nie ma z czego podpowiedzieć.
  String? get opisPodpowiedzi {
    final p = podpowiedz;
    return p == null ? null : 'Podpowiedź: ${p.forma.nazwa} — ${p.skad}.';
  }

  /// Zdanie o dniu zbioru — od niego przepis liczy okrywę.
  String? get opisZbioru {
    final dzien = dataZbioru;
    if (dzien == null) {
      return null;
    }
    return 'Zbiór: ${Daty.krotko(dzien)} — od tego dnia liczy się okrywa.';
  }

  /// Zdanie o dopuszczalnej przerwie na siew ozimin.
  String? get opisPrzerwy => limitPrzerwyDni <= 0
      ? null
      : 'Przerwa na siew ozimin albo międzyplonu może trwać najwyżej '
            '$limitPrzerwyDni dni.';

  /// Odpowiedzi do wyboru — liczba tygodni z przepisu, nie z kodu.
  List<WyborPrzerwy> get wyboryPrzerwy {
    if (limitPrzerwyDni <= 0) {
      return const [];
    }
    final tygodni = limitPrzerwyDni ~/ 7;
    return [
      const WyborPrzerwy(etykieta: 'Bez przerwy', dni: 0, ponadLimit: false),
      for (var tydzien = 1; tydzien <= tygodni; tydzien++)
        WyborPrzerwy(
          etykieta: '$tydzien ${_tygodnie(tydzien)}',
          dni: tydzien * 7,
          ponadLimit: false,
        ),
      WyborPrzerwy(
        etykieta: 'Dłużej niż $tygodni ${_tygodnie(tygodni)}',
        dni: limitPrzerwyDni + 7,
        ponadLimit: true,
      ),
    ];
  }

  /// Którą odpowiedź rolnik już wybrał.
  WyborPrzerwy? get wybranaPrzerwa {
    final dni = deklaracja?.przerwaDni;
    if (dni == null) {
      return null;
    }
    return wyboryPrzerwy.where((w) => w.dni == dni).firstOrNull ??
        WyborPrzerwy(
          etykieta: '$dni dni',
          dni: dni,
          ponadLimit: dni > limitPrzerwyDni,
        );
  }

  /// Czy pytanie o przerwę ma sens: tylko przy formie, która liczy się do
  /// okrywy (po glebie odkrytej nie ma czego przerywać).
  bool get pytacOPrzerwe => (forma?.liczJakoOkrywe ?? false);

  static String _tygodnie(int ile) => ile == 1 ? 'tydzień' : 'tygodnie';
}

/// Liczy normę GAEC 6: okrywę ochronną gleby na gruntach ornych.
///
/// Udział, przerwa na siew i termin pochodzą ze słownika reguł. W kodzie
/// nie ma ani jednej liczby z przepisu.
class Okrywa {
  const Okrywa({
    required this.pola,
    required this.okrywy,
    required this.uprawy,
    required this.reguly,
  });

  final RepozytoriumPol pola;
  final RepozytoriumOkrywyPola okrywy;
  final RepozytoriumUprawPola uprawy;
  final SlownikRegul reguly;

  NormaGaec? get norma => reguly.warunkowosc.norma('gaec_6');

  FormyOkrywy get formy => reguly.warunkowosc.formyOkrywy;

  /// Najdłuższa dozwolona przerwa bez okrywy, w dniach.
  ///
  /// Przepis mówi o tygodniach, więc dni liczymy z progu — a nie z liczby
  /// wpisanej w kod.
  int get limitPrzerwyDni {
    final prog = norma?.prog('przerwa_tygodnie');
    return prog == null ? 0 : prog.calkowita * 7;
  }

  Future<OcenaOkrywy> ocen({
    required String gospodarstwoId,
    int? sezon,
    DateTime? teraz,
  }) async {
    final rok = sezon ?? (teraz ?? DateTime.now()).year;
    final gaec6 = norma;
    final wszystkiePola = await pola.wszystkie(gospodarstwoId);
    final wymagany = gaec6?.prog('udzial_gruntow_ornych_procent')?.wartosc ?? 0;
    final limitDni = limitPrzerwyDni;

    final orne = wszystkiePola
        .where((p) => p.rodzajUzytku == RodzajUzytku.gruntyOrne)
        .toList(growable: false);
    final bezRodzaju = wszystkiePola
        .where((p) => !p.rodzajUzytku.znany)
        .toList(growable: false);
    final trwale = wszystkiePola
        .where((p) => p.rodzajUzytku == RodzajUzytku.uprawyTrwale)
        .toList(growable: false);

    final powierzchniaOrnych = orne.fold<double>(
      0,
      (suma, p) => suma + p.powierzchniaHa,
    );
    final powierzchniaUr = wszystkiePola.fold<double>(
      0,
      (suma, p) => suma + p.powierzchniaHa,
    );

    final deklaracje = {
      for (final deklaracja in await okrywy.wSezonie(
        gospodarstwoId: gospodarstwoId,
        sezon: rok,
      ))
        deklaracja.poleId: deklaracja,
    };

    final stanPol = <PoleWOkrywie>[];
    for (final pole in orne) {
      final deklaracja = deklaracje[pole.id];
      stanPol.add(
        PoleWOkrywie(
          pole: pole,
          deklaracja: deklaracja,
          forma: deklaracja == null ? null : formy.forma(deklaracja.forma),
          limitPrzerwyDni: limitDni,
          dataZbioruZWpisow: await okrywy.dzienZbioruZWpisow(
            poleId: pole.id,
            sezon: rok,
          ),
          podpowiedz: deklaracja != null
              ? null
              : await podpowiedz(pole: pole, sezon: rok),
        ),
      );
    }

    final zOkrywa = stanPol
        .where((p) => p.liczySie)
        .fold<double>(0, (suma, p) => suma + p.powierzchniaHa);
    final bezDeklaracji = stanPol
        .where((p) => p.doSprawdzenia)
        .toList(growable: false);
    final nieznana = bezDeklaracji.fold<double>(
      0,
      (suma, p) => suma + p.powierzchniaHa,
    );

    final udzial = powierzchniaOrnych == 0
        ? 0.0
        : zOkrywa / powierzchniaOrnych * 100;
    final udzialMozliwy = powierzchniaOrnych == 0
        ? 0.0
        : (zOkrywa + nieznana) / powierzchniaOrnych * 100;

    final termin = gaec6?.termin('okrywa_grunty_orne');
    final terminSadow = gaec6?.termin('okrywa_sady');

    return OcenaOkrywy(
      sezon: rok,
      powierzchniaGruntowOrnychHa: powierzchniaOrnych,
      powierzchniaUrHa: powierzchniaUr,
      pola: stanPol,
      udzialOkrywy: udzial,
      udzialMozliwy: udzialMozliwy,
      wymaganyUdzial: wymagany,
      limitPrzerwyDni: limitDni,
      terminDo: termin?.koniecWRoku(rok),
      polaBezDeklaracji: bezDeklaracji,
      polaBezOkrywy: stanPol.where((p) => p.bezOkrywy).toList(growable: false),
      polaZaDlugaPrzerwa: stanPol
          .where((p) => p.przerwaZaDluga)
          .toList(growable: false),
      polaBezRodzajuUzytku: bezRodzaju,
      polaUprawTrwalych: trwale,
      zwolnienia: reguly.warunkowosc.zwolnieniaDla(
        idNormy: 'gaec_6',
        powierzchniaUrHa: powierzchniaUr,
      ),
      uwagi: [
        if (bezDeklaracji.isNotEmpty)
          'Przy ${bezDeklaracji.length} polach nie wiadomo, co zostaje po '
              'zbiorze — bez tego nie policzymy udziału okrywy.',
        if (formy.doWeryfikacji && formy.formy.isNotEmpty)
          'Lista form okrywy pochodzi z ${formy.zrodlo} — rozporządzenie '
              'ich nie wymienia. Przy wątpliwości sprawdź u doradcy.',
        if (trwale.isNotEmpty && terminSadow != null)
          'W sadach i innych uprawach trwałych okrywa ma być '
              'w międzyrzędziach od ${Daty.dzienIMiesiac(terminSadow.od)} do '
              '${Daty.dzienIMiesiac(terminSadow.doDnia)} — tego aplikacja nie policzy '
              'z wpisów, sprawdź sam(a) na ${trwale.length} polach.',
      ],
    );
  }

  /// Wszystko, co ekran pola musi pokazać o okrywie na tym polu.
  Future<OpisOkrywyPola> dlaPola({required Pole pole, int? sezon}) async {
    final rok = sezon ?? pole.sezon ?? DateTime.now().year;
    final deklaracja = await okrywy.dlaPola(poleId: pole.id, sezon: rok);
    final zbior = await okrywy.dzienZbioruZWpisow(poleId: pole.id, sezon: rok);
    return OpisOkrywyPola(
      sezon: rok,
      formy: formy,
      wymaganyUdzial:
          norma?.prog('udzial_gruntow_ornych_procent')?.wartosc ?? 0,
      limitPrzerwyDni: limitPrzerwyDni,
      deklaracja: deklaracja,
      forma: deklaracja == null ? null : formy.forma(deklaracja.forma),
      podpowiedz: deklaracja != null
          ? null
          : await podpowiedz(pole: pole, sezon: rok),
      dataZbioru: deklaracja?.dataZbioru ?? zbior,
      terminDo: norma?.termin('okrywa_grunty_orne')?.koniecWRoku(rok),
    );
  }

  /// Podpowiedź formy okrywy dla pola — z wpisów rolnika, nie z domysłu.
  ///
  /// Kolejność szukania: najpierw to, co rolnik zapisał po zbiorze (siew,
  /// uprawa gleby), potem uprawa następnego sezonu (ozimina zasiana tą
  /// jesienią), na końcu uprawa tego sezonu (trawy, ugór zostają na polu).
  /// `null` znaczy „nie mamy z czego podpowiedzieć".
  Future<PodpowiedzOkrywy?> podpowiedz({
    required Pole pole,
    required int sezon,
  }) async {
    if (formy.pusta) {
      return null;
    }

    final zbior = await okrywy.dzienZbioruZWpisow(
      poleId: pole.id,
      sezon: sezon,
    );
    final wpisy = await okrywy.wpisyPoZbiorze(
      poleId: pole.id,
      sezon: sezon,
      odDnia: zbior,
    );
    for (final wpis in wpisy) {
      final forma = _dopasuj(wpis);
      if (forma != null) {
        return PodpowiedzOkrywy(forma: forma, skad: 'z twojego wpisu: „$wpis"');
      }
    }

    final historia = await uprawy.historia(pole.id);
    final nastepny = historia
        .where((u) => u.sezon == sezon + 1 && u.plonGlowny)
        .firstOrNull;
    if (nastepny != null) {
      final forma = _dopasuj(nastepny.uprawa);
      if (forma != null) {
        return PodpowiedzOkrywy(
          forma: forma,
          skad:
              'z uprawy zapisanej na ${nastepny.sezon} r.: '
              '„${nastepny.uprawa}"',
        );
      }
    }

    final wSezonie = historia
        .where((u) => u.sezon == sezon && u.plonGlowny)
        .firstOrNull;
    final uprawa = wSezonie?.uprawa ?? pole.uprawa;
    if (uprawa.isNotEmpty) {
      final forma = _dopasuj(uprawa);
      if (forma != null) {
        return PodpowiedzOkrywy(
          forma: forma,
          skad: 'z uprawy na tym polu: „$uprawa"',
        );
      }
    }
    return null;
  }

  /// Dopasowanie tekstu do formy po słowach ze słownika reguł.
  ///
  /// Formy bez słów (gleba odkryta) nie dopasują się nigdy — tego rolnik
  /// musi powiedzieć sam.
  FormaOkrywy? _dopasuj(String tekst) {
    final slowa = Tekst.slowaDoSzukania(tekst).toSet();
    if (slowa.isEmpty) {
      return null;
    }
    for (final forma in formy.formy) {
      if (forma.slowa.any(slowa.contains)) {
        return forma;
      }
    }
    return null;
  }
}
