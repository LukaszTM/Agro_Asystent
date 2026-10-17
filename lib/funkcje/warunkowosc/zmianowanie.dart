import '../../rdzen/reguly/regula_prawna.dart';
import '../../rdzen/wspolne/tekst.dart';
import '../dzialki/repozytorium_pol.dart';
import '../dzialki/rodzaj_uzytku.dart';
import '../dzialki/uprawy_pola.dart';

/// Wynik oceny jednego warunku normy.
enum StanWarunku {
  spelniony,
  niespelniony,

  /// Warunek nie dotyczy tego gospodarstwa (próg, zwolnienie, wyłączenie).
  nieDotyczy,

  /// Brakuje danych, żeby policzyć. **Nigdy nie udajemy, że jest dobrze.**
  doSprawdzenia,
}

/// Jak przepis widzi uprawę przy zmianowaniu: rodzaj, forma i — w trzech
/// rodzinach — gatunek (§ 5 ust. 5).
///
/// Klucz liczy się z danych, nie z listy w kodzie: słowa form i rodzin
/// stoją w słowniku reguł.
class UprawaWedlugPrzepisu {
  const UprawaWedlugPrzepisu({
    required this.klucz,
    required this.nazwa,
    required this.rodzaj,
    this.forma,
    this.rodzina,
  });

  /// Klucz do porównań. Dwie uprawy z tym samym kluczem to dla przepisu
  /// jedna uprawa.
  final String klucz;

  /// Nazwa, którą wpisał rolnik albo wniosek.
  final String nazwa;

  /// Rodzaj rośliny — pierwsze słowo nazwy.
  final String rodzaj;

  /// `ozima`, `jara` albo `null`.
  final String? forma;

  /// Rodzina liczona po gatunku albo `null`.
  final String? rodzina;

  bool get pusta => klucz.isEmpty;

  /// Rozkłada nazwę uprawy według reguły ze słownika.
  static UprawaWedlugPrzepisu z({
    required String nazwa,
    required KluczUprawy regula,
  }) {
    final slowa = Tekst.slowaDoSzukania(nazwa);
    if (slowa.isEmpty) {
      return const UprawaWedlugPrzepisu(klucz: '', nazwa: '', rodzaj: '');
    }
    final rodzaj = slowa.first;

    String? rodzina;
    for (final wpis in regula.rodzinyPoGatunku.entries) {
      if (wpis.value.any(slowa.contains)) {
        rodzina = wpis.key;
        break;
      }
    }

    String? forma;
    for (final wpis in regula.formy.entries) {
      if (wpis.value.any(slowa.contains)) {
        forma = wpis.key;
        break;
      }
    }

    // W trzech rodzinach liczy się gatunek, więc kluczem jest cała nazwa.
    // Poza nimi — rodzaj i forma, bo ozimina i jarzyna tego samego rodzaju
    // to dla przepisu dwie uprawy.
    final klucz = rodzina != null
        ? slowa.join(' ')
        : [rodzaj, ?forma].join(' ');

    return UprawaWedlugPrzepisu(
      klucz: klucz,
      nazwa: nazwa,
      rodzaj: rodzaj,
      forma: forma,
      rodzina: rodzina,
    );
  }
}

/// Jedno pole w ocenie zmianowania.
class PoleWZmianowaniu {
  const PoleWZmianowaniu({
    required this.pole,
    required this.uprawy,
    required this.wSezonie,
    required this.rokWczesniej,
    required this.lataTejSamejUprawy,
    required this.brakujaceLata,
    this.wylaczenie,
  });

  final Pole pole;

  /// Uprawy pola po sezonach, od najnowszej.
  final List<UprawaSezonu> uprawy;

  /// Uprawa w ocenianym sezonie — według przepisu.
  final UprawaWedlugPrzepisu? wSezonie;

  /// Uprawa rok wcześniej — według przepisu.
  final UprawaWedlugPrzepisu? rokWczesniej;

  /// Ile lat z rzędu (do ocenianego sezonu) rośnie ta sama uprawa.
  /// `0`, gdy nie wiadomo.
  final int lataTejSamejUprawy;

  /// Lata bez wpisu w zakresie, który liczy przepis.
  final List<int> brakujaceLata;

  /// Wyłączenie z § 5 ust. 3, jeśli uprawa pod nie podpada.
  final WylaczenieZeZmianowania? wylaczenie;

  double get powierzchniaHa => pole.powierzchniaHa;

  bool get wylaczone => wylaczenie != null;

  bool get zmienionaUprawa =>
      wSezonie != null &&
      rokWczesniej != null &&
      wSezonie!.klucz != rokWczesniej!.klucz;

  /// Czy o tym polu da się cokolwiek powiedzieć.
  bool get doSprawdzenia =>
      !wylaczone && (wSezonie == null || rokWczesniej == null);
}

/// Jak wypadła dywersyfikacja (§ 5 ust. 4).
class WynikDywersyfikacji {
  const WynikDywersyfikacji({
    required this.stan,
    required this.liczbaUpraw,
    required this.wymaganaLiczbaUpraw,
    required this.udzialNajwiekszej,
    required this.granicaNajwiekszej,
    this.udzialDwochNajwiekszych,
    this.granicaDwochNajwiekszych,
  });

  final StanWarunku stan;
  final int liczbaUpraw;
  final int wymaganaLiczbaUpraw;
  final double udzialNajwiekszej;
  final double granicaNajwiekszej;

  /// Tylko powyżej 30 ha gruntów ornych.
  final double? udzialDwochNajwiekszych;
  final double? granicaDwochNajwiekszych;
}

/// Ocena normy GAEC 7 dla gospodarstwa w jednym sezonie.
class OcenaZmianowania {
  const OcenaZmianowania({
    required this.sezon,
    required this.powierzchniaGruntowOrnychHa,
    required this.powierzchniaUrHa,
    required this.pola,
    required this.stanZmianowania,
    required this.udzialInnejUprawy,
    required this.wymaganyUdzial,
    required this.stanTrzechLat,
    required this.polaPonadTrzyLata,
    required this.dywersyfikacja,
    required this.polaDoSprawdzenia,
    required this.polaBezRodzajuUzytku,
    required this.zwolnienia,
    required this.uwagi,
  });

  final int sezon;
  final double powierzchniaGruntowOrnychHa;
  final double powierzchniaUrHa;
  final List<PoleWZmianowaniu> pola;

  /// Warunek z § 5 ust. 1 pkt 1 — inna uprawa niż rok wcześniej.
  final StanWarunku stanZmianowania;
  final double udzialInnejUprawy;
  final double wymaganyUdzial;

  /// Warunek z § 5 ust. 1 pkt 2 — ta sama uprawa nie dłużej niż 3 lata.
  final StanWarunku stanTrzechLat;
  final List<PoleWZmianowaniu> polaPonadTrzyLata;

  /// Dywersyfikacja — liczy się tylko wtedy, gdy warunek zmianowania
  /// nie jest spełniony.
  final WynikDywersyfikacji? dywersyfikacja;

  final List<PoleWZmianowaniu> polaDoSprawdzenia;

  /// Pola, przy których rolnik nie powiedział jeszcze, jakim są użytkiem.
  final List<Pole> polaBezRodzajuUzytku;

  /// Zwolnienia z kontroli, które przy tej powierzchni obejmują GAEC 7.
  final List<ZwolnienieZKontroli> zwolnienia;

  /// Zdania, które aplikacja musi powiedzieć rolnikowi o swoim rachunku.
  final List<String> uwagi;

  /// Stan całej normy — najgorszy ze składników, bo kontrola patrzy na
  /// całość. Brak danych nigdy nie daje „spełniona".
  StanWarunku get stan {
    if (stanZmianowania == StanWarunku.nieDotyczy &&
        stanTrzechLat == StanWarunku.nieDotyczy) {
      return StanWarunku.nieDotyczy;
    }
    final skladniki = [
      stanTrzechLat,
      if (stanZmianowania == StanWarunku.spelniony)
        StanWarunku.spelniony
      else
        dywersyfikacja?.stan ?? stanZmianowania,
    ];
    if (skladniki.contains(StanWarunku.niespelniony)) {
      return StanWarunku.niespelniony;
    }
    if (skladniki.contains(StanWarunku.doSprawdzenia) ||
        polaDoSprawdzenia.isNotEmpty ||
        polaBezRodzajuUzytku.isNotEmpty) {
      return StanWarunku.doSprawdzenia;
    }
    return skladniki.every((s) => s == StanWarunku.nieDotyczy)
        ? StanWarunku.nieDotyczy
        : StanWarunku.spelniony;
  }

  bool get zwolnioneZKontroli => zwolnienia.isNotEmpty;
}

/// Ostrzeżenie przed zapisem uprawy, która byłaby czwartym rokiem z rzędu.
///
/// Treść stoi tutaj, a nie w ekranach, bo oba wyglądy muszą mówić
/// rolnikowi to samo.
class OstrzezenieOZmianowaniu {
  const OstrzezenieOZmianowaniu({
    required this.nazwaPola,
    required this.uprawa,
    required this.lata,
    required this.limitLat,
  });

  final String nazwaPola;
  final String uprawa;

  /// Ile lat z rzędu wyszłoby po zapisie.
  final int lata;

  /// Najdłuższy dozwolony czas tej samej uprawy (z przepisu).
  final int limitLat;

  String get tresc =>
      'Na polu $nazwaPola „$uprawa" byłaby wtedy $lata rok z rzędu, '
      'a norma GAEC 7 pozwala najwyżej $limitLat lata.';

  String get coZrobic =>
      'Zapisać możesz — dokumentacja ma być prawdziwa. Ale przy kontroli '
      'liczy się to jako złamanie normy, więc lepiej zasiać coś innego '
      'albo sprawdzić u doradcy.';
}

/// Liczy normę GAEC 7: zmianowanie i dywersyfikację upraw na gruntach
/// ornych.
///
/// Wszystkie progi, wyłączenia i reguła porównywania upraw pochodzą ze
/// słownika reguł. W kodzie nie ma ani jednej liczby z przepisu.
class Zmianowanie {
  const Zmianowanie({
    required this.pola,
    required this.uprawy,
    required this.reguly,
  });

  final RepozytoriumPol pola;
  final RepozytoriumUprawPola uprawy;
  final SlownikRegul reguly;

  NormaGaec? get norma => reguly.warunkowosc.norma('gaec_7');

  Future<OcenaZmianowania> ocen({
    required String gospodarstwoId,
    int? sezon,
    DateTime? teraz,
  }) async {
    final rok = sezon ?? (teraz ?? DateTime.now()).year;
    final gaec7 = norma;
    final wszystkiePola = await pola.wszystkie(gospodarstwoId);

    final uwagi = <String>[];
    final klucz = reguly.warunkowosc.kluczUprawy;
    if (klucz.doWeryfikacji) {
      uwagi.add(
        'Uprawy porównujemy po rodzaju i formie, a w rodzinach '
        'kapustowatych, psiankowatych i dyniowatych po gatunku '
        '(${klucz.zrodlo}). Wykazu gatunków tych rodzin przepis nie '
        'podaje — przy wątpliwości sprawdź u doradcy.',
      );
    }

    // Grunty orne to **tylko** pola, przy których rolnik to potwierdził.
    final orne = wszystkiePola
        .where((p) => p.rodzajUzytku == RodzajUzytku.gruntyOrne)
        .toList(growable: false);
    final bezRodzaju = wszystkiePola
        .where((p) => !p.rodzajUzytku.znany)
        .toList(growable: false);
    final powierzchniaOrnych = orne.fold<double>(
      0,
      (suma, p) => suma + p.powierzchniaHa,
    );
    final powierzchniaUr = wszystkiePola.fold<double>(
      0,
      (suma, p) => suma + p.powierzchniaHa,
    );

    final zwolnienia = reguly.warunkowosc.zwolnieniaDla(
      idNormy: 'gaec_7',
      powierzchniaUrHa: powierzchniaUr,
    );

    final prog = gaec7?.prog('od_ha_gruntow_ornych')?.wartosc;
    final wymagany = gaec7?.prog('zmiana_uprawy_procent')?.wartosc ?? 0;
    final latMaksimum = gaec7?.prog('ta_sama_uprawa_lata')?.calkowita ?? 0;
    final odRoku = gaec7?.prog('ta_sama_uprawa_lata')?.liczOdRoku ?? rok;

    final stanPol = <PoleWZmianowaniu>[];
    for (final pole in orne) {
      stanPol.add(
        await _ocenPole(
          pole: pole,
          sezon: rok,
          odRoku: odRoku,
          latMaksimum: latMaksimum,
          klucz: klucz,
        ),
      );
    }

    // Norma dotyczy gospodarstw powyżej progu gruntów ornych. Przy braku
    // progu w słowniku nie wymyślamy własnego.
    if (prog == null || powierzchniaOrnych <= prog) {
      return OcenaZmianowania(
        sezon: rok,
        powierzchniaGruntowOrnychHa: powierzchniaOrnych,
        powierzchniaUrHa: powierzchniaUr,
        pola: stanPol,
        stanZmianowania: StanWarunku.nieDotyczy,
        udzialInnejUprawy: 0,
        wymaganyUdzial: wymagany,
        stanTrzechLat: StanWarunku.nieDotyczy,
        polaPonadTrzyLata: const [],
        dywersyfikacja: null,
        polaDoSprawdzenia: const [],
        polaBezRodzajuUzytku: bezRodzaju,
        zwolnienia: zwolnienia,
        uwagi: [
          if (prog != null)
            'Grunty orne w gospodarstwie to '
                '${_ha(powierzchniaOrnych)} ha, a norma dotyczy gospodarstw '
                'powyżej ${_ha(prog)} ha.',
          ...uwagi,
        ],
      );
    }

    // Zwolnienie z § 5 ust. 11: powyżej 75 % gruntów ornych pod trawami,
    // ugorem albo bobowatymi.
    final udzialZwolnienia = gaec7?.prog('zwolnienie_udzial_procent')?.wartosc;
    final wylaczonaPowierzchnia = stanPol
        .where((p) => p.wylaczone)
        .fold<double>(0, (suma, p) => suma + p.powierzchniaHa);
    if (udzialZwolnienia != null &&
        powierzchniaOrnych > 0 &&
        wylaczonaPowierzchnia / powierzchniaOrnych * 100 > udzialZwolnienia) {
      return OcenaZmianowania(
        sezon: rok,
        powierzchniaGruntowOrnychHa: powierzchniaOrnych,
        powierzchniaUrHa: powierzchniaUr,
        pola: stanPol,
        stanZmianowania: StanWarunku.nieDotyczy,
        udzialInnejUprawy: 0,
        wymaganyUdzial: wymagany,
        stanTrzechLat: StanWarunku.nieDotyczy,
        polaPonadTrzyLata: const [],
        dywersyfikacja: null,
        polaDoSprawdzenia: const [],
        polaBezRodzajuUzytku: bezRodzaju,
        zwolnienia: zwolnienia,
        uwagi: [
          'Ponad ${_liczba(udzialZwolnienia)} % gruntów ornych zajmują '
              'trawy, ugór albo bobowate — warunków nie stosuje się '
              '(§ 5 ust. 11).',
          ...uwagi,
        ],
      );
    }

    final doSprawdzenia = stanPol
        .where((p) => p.doSprawdzenia)
        .toList(growable: false);

    // Warunek 1: udział gruntów ornych z inną uprawą niż rok wcześniej.
    // Liczymy od **wszystkich** gruntów ornych, tak jak mówi przepis
    // („na powierzchni co najmniej 40 % gruntów ornych"); uprawy wylaczone
    // nie wchodzą do licznika.
    final zmieniona = stanPol
        .where((p) => !p.wylaczone && p.zmienionaUprawa)
        .fold<double>(0, (suma, p) => suma + p.powierzchniaHa);
    final udzial = powierzchniaOrnych == 0
        ? 0.0
        : zmieniona / powierzchniaOrnych * 100;
    final stanZmianowania = udzial + 1e-9 >= wymagany
        ? StanWarunku.spelniony
        : (doSprawdzenia.isNotEmpty
              ? StanWarunku.doSprawdzenia
              : StanWarunku.niespelniony);

    // Warunek 2: ta sama uprawa nie dłużej niż trzy lata.
    final ponadTrzyLata = stanPol
        .where((p) => !p.wylaczone && p.lataTejSamejUprawy > latMaksimum)
        .toList(growable: false);
    final bezHistorii = stanPol
        .where((p) => !p.wylaczone && p.brakujaceLata.isNotEmpty)
        .toList(growable: false);
    final stanTrzechLat = ponadTrzyLata.isNotEmpty
        ? StanWarunku.niespelniony
        : (bezHistorii.isNotEmpty
              ? StanWarunku.doSprawdzenia
              : StanWarunku.spelniony);

    final dywersyfikacja = stanZmianowania == StanWarunku.spelniony
        ? null
        : _dywersyfikacja(
            gaec7: gaec7,
            pola: stanPol,
            powierzchniaOrnych: powierzchniaOrnych,
            doSprawdzenia: doSprawdzenia.isNotEmpty,
          );

    return OcenaZmianowania(
      sezon: rok,
      powierzchniaGruntowOrnychHa: powierzchniaOrnych,
      powierzchniaUrHa: powierzchniaUr,
      pola: stanPol,
      stanZmianowania: stanZmianowania,
      udzialInnejUprawy: udzial,
      wymaganyUdzial: wymagany,
      stanTrzechLat: stanTrzechLat,
      polaPonadTrzyLata: ponadTrzyLata,
      dywersyfikacja: dywersyfikacja,
      polaDoSprawdzenia: doSprawdzenia,
      polaBezRodzajuUzytku: bezRodzaju,
      zwolnienia: zwolnienia,
      uwagi: [
        if (bezHistorii.isNotEmpty)
          'Przy ${bezHistorii.length} polach brakuje uprawy z lat '
              '$odRoku–${rok - 1} — bez tego nie policzymy reguły '
              '$latMaksimum lat.',
        ...uwagi,
      ],
    );
  }

  /// Czy zapis tej uprawy na tym polu zrobiłby z niej czwarty rok z rzędu.
  ///
  /// `null` znaczy „nie ma o czym ostrzegać": pole nie jest gruntem ornym
  /// (albo rolnik jeszcze nie powiedział, czym jest), uprawa jest wyłączona
  /// z warunku, brakuje historii albo lat jest tyle, ile wolno.
  Future<OstrzezenieOZmianowaniu?> ostrzezeniePrzedZapisem({
    required Pole pole,
    required String uprawa,
    int? sezon,
    DateTime? teraz,
  }) async {
    if (pole.rodzajUzytku != RodzajUzytku.gruntyOrne) {
      return null;
    }
    final gaec7 = norma;
    final limit = gaec7?.prog('ta_sama_uprawa_lata')?.calkowita;
    final odRoku = gaec7?.prog('ta_sama_uprawa_lata')?.liczOdRoku;
    if (limit == null || odRoku == null) {
      return null;
    }
    if (_wylaczenie(pole: pole, uprawa: uprawa) != null) {
      return null;
    }

    final rok = sezon ?? pole.sezon ?? (teraz ?? DateTime.now()).year;
    final klucz = reguly.warunkowosc.kluczUprawy;
    final nowa = UprawaWedlugPrzepisu.z(nazwa: uprawa, regula: klucz);
    if (nowa.pusta) {
      return null;
    }

    final historia = (await uprawy.historia(pole.id))
        .where((u) => u.plonGlowny)
        .toList(growable: false);

    var lata = 1;
    for (var wczesniej = rok - 1; wczesniej >= odRoku; wczesniej--) {
      final wpis = historia.where((u) => u.sezon == wczesniej).firstOrNull;
      if (wpis == null) {
        // Dziura w historii — nie zgadujemy, czego tam nie ma.
        return null;
      }
      final poprzednia = UprawaWedlugPrzepisu.z(
        nazwa: wpis.uprawa,
        regula: klucz,
      );
      if (poprzednia.klucz != nowa.klucz) {
        break;
      }
      lata++;
    }

    return lata > limit
        ? OstrzezenieOZmianowaniu(
            nazwaPola: pole.nazwa,
            uprawa: uprawa,
            lata: lata,
            limitLat: limit,
          )
        : null;
  }

  Future<PoleWZmianowaniu> _ocenPole({
    required Pole pole,
    required int sezon,
    required int odRoku,
    required int latMaksimum,
    required KluczUprawy klucz,
  }) async {
    final historia = (await uprawy.historia(pole.id))
        .where((u) => u.plonGlowny)
        .toList(growable: false);

    UprawaWedlugPrzepisu? wRoku(int rok) {
      final wpis = historia.where((u) => u.sezon == rok).firstOrNull;
      if (wpis == null) {
        return null;
      }
      final rozlozona = UprawaWedlugPrzepisu.z(
        nazwa: wpis.uprawa,
        regula: klucz,
      );
      return rozlozona.pusta ? null : rozlozona;
    }

    final wSezonie = wRoku(sezon);
    final rokWczesniej = wRoku(sezon - 1);

    // Ile lat z rzędu ta sama uprawa — licząc wstecz od ocenianego sezonu
    // i nie dalej niż rok, od którego każe liczyć przepis.
    var lata = 0;
    if (wSezonie != null) {
      lata = 1;
      for (var rok = sezon - 1; rok >= odRoku; rok--) {
        final wczesniej = wRoku(rok);
        if (wczesniej == null || wczesniej.klucz != wSezonie.klucz) {
          break;
        }
        lata++;
      }
    }

    final znane = historia.map((u) => u.sezon).toSet();
    final brakujace = [
      for (var rok = sezon; rok >= odRoku; rok--)
        if (!znane.contains(rok)) rok,
    ];

    return PoleWZmianowaniu(
      pole: pole,
      uprawy: historia,
      wSezonie: wSezonie,
      rokWczesniej: rokWczesniej,
      lataTejSamejUprawy: lata,
      brakujaceLata: brakujace,
      wylaczenie: _wylaczenie(pole: pole, uprawa: wSezonie?.nazwa ?? ''),
    );
  }

  /// Czy uprawa pola podpada pod wyłączenie z § 5 ust. 3.
  WylaczenieZeZmianowania? _wylaczenie({
    required Pole pole,
    required String uprawa,
  }) {
    final slowa = Tekst.slowaDoSzukania(uprawa).toSet();
    for (final wylaczenie
        in reguly.warunkowosc.wylaczeniaZeZmianowania.wylaczenia) {
      final poRodzaju = wylaczenie.poRodzajuUzytku;
      if (poRodzaju != null && pole.rodzajUzytku.wBazie == poRodzaju) {
        return wylaczenie;
      }
      for (final wzor in wylaczenie.slowa) {
        final czesci = Tekst.slowaDoSzukania(wzor);
        if (czesci.isNotEmpty && czesci.every(slowa.contains)) {
          return wylaczenie;
        }
      }
    }
    return null;
  }

  WynikDywersyfikacji _dywersyfikacja({
    required NormaGaec? gaec7,
    required List<PoleWZmianowaniu> pola,
    required double powierzchniaOrnych,
    required bool doSprawdzenia,
  }) {
    final granicaHa = gaec7?.prog('dywersyfikacja_granica_ha')?.wartosc ?? 0;
    final duze = powierzchniaOrnych > granicaHa;
    final wymaganaLiczba = duze
        ? gaec7?.prog('dywersyfikacja_powyzej_30ha_upraw')?.calkowita ?? 0
        : gaec7?.prog('dywersyfikacja_do_30ha_upraw')?.calkowita ?? 0;
    final granicaNajwiekszej =
        gaec7?.prog('najwieksza_uprawa_procent')?.wartosc ?? 100;
    final granicaDwoch = duze
        ? gaec7?.prog('dwie_najwieksze_uprawy_procent')?.wartosc
        : null;

    // Udziały liczymy po kluczu uprawy, bo tak przepis rozumie „różne
    // uprawy" (§ 5 ust. 5).
    final powierzchnie = <String, double>{};
    for (final pole in pola) {
      final klucz = pole.wSezonie?.klucz;
      if (klucz == null) {
        continue;
      }
      powierzchnie[klucz] = (powierzchnie[klucz] ?? 0) + pole.powierzchniaHa;
    }
    final udzialy =
        powierzchnie.values
            .map(
              (ha) =>
                  powierzchniaOrnych == 0 ? 0.0 : ha / powierzchniaOrnych * 100,
            )
            .toList(growable: false)
          ..sort((a, b) => b.compareTo(a));

    final najwieksza = udzialy.isEmpty ? 0.0 : udzialy.first;
    final dwieNajwieksze = udzialy.length < 2
        ? najwieksza
        : udzialy[0] + udzialy[1];

    final zgodne =
        powierzchnie.length >= wymaganaLiczba &&
        najwieksza <= granicaNajwiekszej + 1e-9 &&
        (granicaDwoch == null || dwieNajwieksze <= granicaDwoch + 1e-9);

    return WynikDywersyfikacji(
      stan: doSprawdzenia
          ? StanWarunku.doSprawdzenia
          : (zgodne ? StanWarunku.spelniony : StanWarunku.niespelniony),
      liczbaUpraw: powierzchnie.length,
      wymaganaLiczbaUpraw: wymaganaLiczba,
      udzialNajwiekszej: najwieksza,
      granicaNajwiekszej: granicaNajwiekszej,
      udzialDwochNajwiekszych: granicaDwoch == null ? null : dwieNajwieksze,
      granicaDwochNajwiekszych: granicaDwoch,
    );
  }

  static String _ha(double wartosc) =>
      wartosc.toStringAsFixed(2).replaceAll('.', ',');

  static String _liczba(double wartosc) => wartosc.toStringAsFixed(0);
}
