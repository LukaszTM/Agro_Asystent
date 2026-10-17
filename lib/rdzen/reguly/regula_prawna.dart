import 'dart:convert';

import '../wspolne/tekst.dart';

/// Miara, po której sprawdzamy próg obowiązku.
enum Miara {
  powierzchniaUrHa('powierzchnia_ur_ha'),
  powierzchniaUprawIntensywnychHa('powierzchnia_upraw_intensywnych_ha'),
  djp('djp'),
  zadeklarowanyEkoschemat('zadeklarowany_ekoschemat'),
  posiadaczZwierzat('posiadacz_zwierzat'),

  /// Miara z nowszego słownika, której ta wersja aplikacji nie zna.
  nieznana('');

  const Miara(this.wJson);

  final String wJson;

  static Miara zJson(String? wartosc) => Miara.values.firstWhere(
    (m) => m.wJson == wartosc,
    orElse: () => Miara.nieznana,
  );
}

/// Sposób porównania wartości gospodarstwa z progiem.
enum Operator {
  wiekszy('>'),
  wiekszyLubRowny('>='),
  mniejszy('<'),
  mniejszyLubRowny('<='),
  jest('jest'),
  nieznany('');

  const Operator(this.wJson);

  final String wJson;

  static Operator zJson(String? wartosc) => Operator.values.firstWhere(
    (o) => o.wJson == wartosc,
    orElse: () => Operator.nieznany,
  );
}

/// Wynik sprawdzenia obowiązku. „Nie wiadomo" bierze się ze słownika nowszego
/// niż aplikacja — wtedy nie zgadujemy, tylko pytamy rolnika (CLAUDE.md, pkt 5).
enum Ocena { dotyczy, nieDotyczy, nieWiadomo }

/// Dane gospodarstwa potrzebne do włączenia obowiązków.
class ProfilGospodarstwa {
  const ProfilGospodarstwa({
    this.powierzchniaUrHa = 0,
    this.powierzchniaUprawIntensywnychHa = 0,
    this.djp = 0,
    this.zadeklarowanyEkoschemat = false,
    this.posiadaczZwierzat = false,
  });

  final double powierzchniaUrHa;
  final double powierzchniaUprawIntensywnychHa;

  /// Duże jednostki przeliczeniowe. `null` znaczy „aplikacja nie wie" —
  /// tak jest, gdy gospodarstwo ma zwierzęta, a ta wersja nie prowadzi
  /// rejestru stada. Obowiązek od DJP jest wtedy „do sprawdzenia", nigdy
  /// „nie dotyczy".
  final double? djp;

  final bool zadeklarowanyEkoschemat;

  /// `null`, dopóki rolnik nie odpowiedział, czy ma zwierzęta.
  final bool? posiadaczZwierzat;

  /// `null`, gdy aplikacja nie zna tej miary.
  double? wartosc(Miara miara) => switch (miara) {
    Miara.powierzchniaUrHa => powierzchniaUrHa,
    Miara.powierzchniaUprawIntensywnychHa => powierzchniaUprawIntensywnychHa,
    Miara.djp => djp,
    Miara.zadeklarowanyEkoschemat => zadeklarowanyEkoschemat ? 1 : 0,
    Miara.posiadaczZwierzat => switch (posiadaczZwierzat) {
      null => null,
      true => 1,
      false => 0,
    },
    Miara.nieznana => null,
  };
}

/// Próg włączający obowiązek, np. „od 10 ha użytków rolnych".
class Prog {
  const Prog({
    required this.miara,
    required this.operator,
    required this.wartosc,
  });

  factory Prog.zJson(Map<String, dynamic> json) => Prog(
    miara: Miara.zJson(json['miara'] as String?),
    operator: Operator.zJson(json['operator'] as String?),
    wartosc: (json['wartosc'] as num).toDouble(),
  );

  final Miara miara;
  final Operator operator;
  final double wartosc;

  Ocena oceny(ProfilGospodarstwa profil) {
    final zGospodarstwa = profil.wartosc(miara);
    if (zGospodarstwa == null || operator == Operator.nieznany) {
      return Ocena.nieWiadomo;
    }
    final spelniony = switch (operator) {
      Operator.wiekszy => zGospodarstwa > wartosc,
      Operator.wiekszyLubRowny => zGospodarstwa >= wartosc,
      Operator.mniejszy => zGospodarstwa < wartosc,
      Operator.mniejszyLubRowny => zGospodarstwa <= wartosc,
      Operator.jest => zGospodarstwa == wartosc,
      Operator.nieznany => false,
    };
    return spelniony ? Ocena.dotyczy : Ocena.nieDotyczy;
  }
}

/// Limit liczbowy z przepisu, np. 170 kg N/ha z nawozów naturalnych.
class Limit {
  const Limit({
    required this.id,
    required this.nazwa,
    required this.wartosc,
    required this.jednostka,
  });

  factory Limit.zJson(Map<String, dynamic> json) => Limit(
    id: json['id'] as String,
    nazwa: json['nazwa'] as String,
    wartosc: (json['wartosc'] as num).toDouble(),
    jednostka: json['jednostka'] as String,
  );

  final String id;
  final String nazwa;
  final double wartosc;
  final String jednostka;
}

/// Pole, które przepis każe zapisać w dokumencie. Lista pól jest **danymi**
/// ze słownika reguł, nie stałą w kodzie — gdy przepis doda pole, wystarczy
/// podmienić plik (CLAUDE.md, reguła 1).
class PoleWymagane {
  const PoleWymagane({required this.id, required this.nazwa});

  factory PoleWymagane.zJson(Map<String, dynamic> json) => PoleWymagane(
    id: json['id'] as String,
    nazwa: json['nazwa'] as String? ?? json['id'] as String,
  );

  final String id;
  final String nazwa;
}

/// Obowiązek dokumentacyjny wraz z progami, od których się włącza.
class Obowiazek {
  const Obowiazek({
    required this.id,
    required this.nazwa,
    required this.podstawa,
    required this.kogoDotyczy,
    required this.progi,
    required this.progiLaczoneLub,
    required this.limity,
    required this.przechowywanieLat,
    required this.statusWeryfikacji,
    required this.uwagi,
    this.wymaganePola = const [],
  });

  factory Obowiazek.zJson(Map<String, dynamic> json) => Obowiazek(
    id: json['id'] as String,
    nazwa: json['nazwa'] as String,
    podstawa: json['podstawa'] as String? ?? '',
    kogoDotyczy: json['kogo_dotyczy'] as String? ?? '',
    progi: ((json['progi'] as List<dynamic>?) ?? const [])
        .map((p) => Prog.zJson(p as Map<String, dynamic>))
        .toList(growable: false),
    progiLaczoneLub: (json['polaczenie_progow'] as String? ?? 'lub') == 'lub',
    limity: ((json['limity'] as List<dynamic>?) ?? const [])
        .map((l) => Limit.zJson(l as Map<String, dynamic>))
        .toList(growable: false),
    przechowywanieLat: json['przechowywanie_lat'] as int? ?? 0,
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    uwagi: json['uwagi'] as String? ?? '',
    wymaganePola: ((json['wymagane_pola'] as List<dynamic>?) ?? const [])
        .map((p) => PoleWymagane.zJson(p as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String id;
  final String nazwa;
  final String podstawa;
  final String kogoDotyczy;
  final List<Prog> progi;

  /// `true` — wystarczy jeden próg; `false` — muszą być spełnione wszystkie.
  final bool progiLaczoneLub;
  final List<Limit> limity;
  final int przechowywanieLat;
  final String statusWeryfikacji;
  final String uwagi;

  /// Pola, które przepis każe zapisać. Puste, gdy słownik ich nie podaje.
  final List<PoleWymagane> wymaganePola;

  /// Obowiązek bez progów dotyczy każdego.
  Ocena ocena(ProfilGospodarstwa profil) {
    if (progi.isEmpty) {
      return Ocena.dotyczy;
    }
    final oceny = progi.map((p) => p.oceny(profil)).toList(growable: false);
    if (progiLaczoneLub) {
      if (oceny.contains(Ocena.dotyczy)) {
        return Ocena.dotyczy;
      }
      return oceny.contains(Ocena.nieWiadomo)
          ? Ocena.nieWiadomo
          : Ocena.nieDotyczy;
    }
    if (oceny.contains(Ocena.nieDotyczy)) {
      return Ocena.nieDotyczy;
    }
    return oceny.contains(Ocena.nieWiadomo) ? Ocena.nieWiadomo : Ocena.dotyczy;
  }

  Limit? limit(String idLimitu) =>
      limity.where((l) => l.id == idLimitu).firstOrNull;
}

/// Rodzaj terminu: data w roku, okres w roku, liczba dni od zdarzenia
/// albo jednorazowa data z przepisu.
enum RodzajTerminu {
  dataRoczna('data_roczna'),
  okresRoczny('okres_roczny'),
  dniOdZdarzenia('dni_od_zdarzenia'),
  dataJednorazowa('data_jednorazowa'),
  nieznany('');

  const RodzajTerminu(this.wJson);

  final String wJson;

  static RodzajTerminu zJson(String? wartosc) =>
      RodzajTerminu.values.firstWhere(
        (r) => r.wJson == wartosc,
        orElse: () => RodzajTerminu.nieznany,
      );
}

/// Termin przypisany do obowiązku.
class Termin {
  const Termin({
    required this.id,
    required this.idObowiazku,
    required this.nazwa,
    required this.rodzaj,
    required this.statusWeryfikacji,
    required this.uwagi,
    this.dataRoczna,
    this.okresOd,
    this.okresDo,
    this.dni,
    this.data,
    this.zdarzenie,
    this.rodzajNawozu,
    this.rodzajGruntu,
    this.coToZaNawoz,
    this.wariantyGmin,
    this.zrodlo = '',
  });

  factory Termin.zJson(Map<String, dynamic> json) => Termin(
    id: json['id'] as String,
    idObowiazku: json['obowiazek'] as String? ?? '',
    nazwa: json['nazwa'] as String,
    rodzaj: RodzajTerminu.zJson(json['rodzaj'] as String?),
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    uwagi: json['uwagi'] as String? ?? '',
    dataRoczna: json['data_roczna'] as String?,
    okresOd: json['okres_od'] as String?,
    okresDo: json['okres_do'] as String?,
    dni: json['dni'] as int?,
    data: json['data'] as String?,
    zdarzenie: json['zdarzenie'] as String?,
    rodzajNawozu: json['rodzaj_nawozu'] as String?,
    rodzajGruntu: json['rodzaj_gruntu'] as String?,
    coToZaNawoz: json['co_to_za_nawoz'] as String?,
    wariantyGmin: json['warianty_gmin'] as String?,
    zrodlo: json['zrodlo'] as String? ?? '',
  );

  final String id;
  final String idObowiazku;
  final String nazwa;
  final RodzajTerminu rodzaj;
  final String statusWeryfikacji;
  final String uwagi;

  /// „MM-DD" dla terminu powtarzającego się co roku.
  final String? dataRoczna;
  final String? okresOd;
  final String? okresDo;
  final int? dni;

  /// „RRRR-MM-DD" dla terminu jednorazowego.
  final String? data;

  /// Zdarzenie, od którego liczy się termin (np. „urodzenie”). Mapowanie
  /// jest danymi, więc nowy termin nie wymaga zmiany kodu.
  final String? zdarzenie;

  /// Czego termin dotyczy: rodzaj nawozu i rodzaj gruntu ze słownika.
  /// Terminy nawożenia zależą od obu, więc muszą być danymi.
  final String? rodzajNawozu;
  final String? rodzajGruntu;

  /// Nazwy nawozów po rolniczemu — na ekran, nie na wydruk.
  final String? coToZaNawoz;

  /// Nazwa zestawu wykazów gmin, które zmieniają ten termin
  /// (`assets/dane/gminy_terminy_azotowe.json`).
  final String? wariantyGmin;

  /// Skąd wzięliśmy datę — pokazujemy to przy terminie do sprawdzenia.
  final String zrodlo;

  /// Termin wymagający sprawdzenia u doradcy przed naborem (plan, pkt 10).
  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';
}

/// Grupa zwierząt i jej współczynnik przeliczeniowy na DJP.
class GrupaDjp {
  const GrupaDjp({
    required this.id,
    required this.gatunek,
    required this.nazwa,
    required this.wspolczynnik,
  });

  factory GrupaDjp.zJson(Map<String, dynamic> json) => GrupaDjp(
    id: json['id'] as String,
    gatunek: json['gatunek'] as String? ?? '',
    nazwa: json['nazwa'] as String? ?? '',
    wspolczynnik: (json['wspolczynnik'] as num?)?.toDouble() ?? 0,
  );

  final String id;
  final String gatunek;
  final String nazwa;
  final double wspolczynnik;
}

/// Współczynniki DJP razem ze stanem ich sprawdzenia.
///
/// Dopóki `statusWeryfikacji` nie jest „potwierdzone", aplikacja pokazuje
/// wynik z adnotacją „do sprawdzenia" — nie udaje, że liczba jest pewna.
class WspolczynnikiDjp {
  const WspolczynnikiDjp({
    required this.grupy,
    required this.statusWeryfikacji,
    required this.zrodlo,
    required this.uwagi,
  });

  factory WspolczynnikiDjp.zJson(Map<String, dynamic> json) => WspolczynnikiDjp(
    grupy: ((json['grupy'] as List<dynamic>?) ?? const [])
        .map((g) => GrupaDjp.zJson(g as Map<String, dynamic>))
        .toList(growable: false),
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    zrodlo: json['zrodlo'] as String? ?? '',
    uwagi: json['uwagi'] as String? ?? '',
  );

  static const WspolczynnikiDjp puste = WspolczynnikiDjp(
    grupy: [],
    statusWeryfikacji: 'brak',
    zrodlo: '',
    uwagi: '',
  );

  final List<GrupaDjp> grupy;
  final String statusWeryfikacji;
  final String zrodlo;
  final String uwagi;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  GrupaDjp? grupa(String id) => grupy.where((g) => g.id == id).firstOrNull;

  List<String> get gatunki {
    final nazwy = <String>[];
    for (final grupa in grupy) {
      if (!nazwy.contains(grupa.gatunek)) {
        nazwy.add(grupa.gatunek);
      }
    }
    return nazwy;
  }

  List<GrupaDjp> grupyGatunku(String gatunek) =>
      grupy.where((g) => g.gatunek == gatunek).toList(growable: false);
}

/// Odstępstwo od granicznego terminu nawożenia — kiedy wolno później
/// i czego przepis wtedy wymaga.
class OdstepstwoNawozenia {
  const OdstepstwoNawozenia({
    required this.id,
    required this.nazwa,
    required this.kiedy,
    required this.doDnia,
    required this.wymagaDokumentowania,
    required this.wymaganeZapisy,
    required this.statusWeryfikacji,
    this.dotyczyGruntow,
    this.limitAzotuKgNaHa,
    this.limitDotyczy,
    this.zrodlo = '',
    this.uwagi = '',
  });

  factory OdstepstwoNawozenia.zJson(Map<String, dynamic> json) =>
      OdstepstwoNawozenia(
        id: json['id'] as String,
        nazwa: json['nazwa'] as String,
        kiedy: json['kiedy'] as String? ?? '',
        doDnia: json['do_dnia'] as String?,
        wymagaDokumentowania: json['dokumentowanie'] == 'wymaga',
        wymaganeZapisy:
            ((json['wymagane_zapisy'] as List<dynamic>?) ?? const [])
                .map((z) => z as String)
                .toList(growable: false),
        statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
        dotyczyGruntow: json['dotyczy_gruntow'] as String?,
        limitAzotuKgNaHa: (json['limit_azotu_kg_na_ha'] as num?)?.toDouble(),
        limitDotyczy: json['limit_dotyczy'] as String?,
        zrodlo: json['zrodlo'] as String? ?? '',
        uwagi: json['uwagi'] as String? ?? '',
      );

  final String id;
  final String nazwa;

  /// W jakiej sytuacji odstępstwo działa.
  final String kiedy;

  /// „MM-DD" — do kiedy wolno nawozić w tej sytuacji. `null` znaczy, że
  /// przepis znosi termin, ale nowego nie podaje; wtedy nie wymyślamy daty.
  final String? doDnia;

  /// Rodzaj gruntów, którego odstępstwo dotyczy (oba dotyczą gruntów ornych).
  final String? dotyczyGruntow;

  final String statusWeryfikacji;
  final String zrodlo;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  final bool wymagaDokumentowania;

  /// Co trzeba zapisać, gdy rolnik korzysta z odstępstwa.
  final List<String> wymaganeZapisy;

  final double? limitAzotuKgNaHa;
  final String? limitDotyczy;
  final String uwagi;
}

/// Zakaz nawożenia niezależny od terminu.
class ZakazNawozenia {
  const ZakazNawozenia({
    required this.id,
    required this.nazwa,
    required this.opis,
    required this.statusWeryfikacji,
    this.zrodlo = '',
    this.uwagi = '',
  });

  factory ZakazNawozenia.zJson(Map<String, dynamic> json) => ZakazNawozenia(
    id: json['id'] as String,
    nazwa: json['nazwa'] as String,
    opis: json['opis'] as String? ?? '',
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    zrodlo: json['zrodlo'] as String? ?? '',
    uwagi: json['uwagi'] as String? ?? '',
  );

  final String id;
  final String nazwa;
  final String opis;
  final String statusWeryfikacji;
  final String zrodlo;
  final String uwagi;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';
}

/// Wcześniejsze nawożenie w lutym: wolno przed terminem z tabeli 2, gdy
/// średnia dobowa temperatura przejdzie przez próg. Progi, liczba dni
/// i udział powierzchni powiatu są danymi.
class WczesniejszeWiosna {
  const WczesniejszeWiosna({
    required this.okresOd,
    required this.okresDo,
    required this.opis,
    required this.progi,
    required this.dniPowyzejProgu,
    required this.udzialPowiatuProcent,
    required this.ktoOglasza,
    required this.statusWeryfikacji,
    this.uwagi = '',
  });

  static const WczesniejszeWiosna puste = WczesniejszeWiosna(
    okresOd: '',
    okresDo: '',
    opis: '',
    progi: [],
    dniPowyzejProgu: 0,
    udzialPowiatuProcent: 0,
    ktoOglasza: '',
    statusWeryfikacji: 'brak',
  );

  factory WczesniejszeWiosna.zJson(Map<String, dynamic> json) =>
      WczesniejszeWiosna(
        okresOd: json['okres_od'] as String? ?? '',
        okresDo: json['okres_do'] as String? ?? '',
        opis: json['opis'] as String? ?? '',
        progi: ((json['progi_temperatury'] as List<dynamic>?) ?? const [])
            .map((p) => ProgTemperatury.zJson(p as Map<String, dynamic>))
            .toList(growable: false),
        dniPowyzejProgu: (json['dni_powyzej_progu'] as num?)?.toInt() ?? 0,
        udzialPowiatuProcent:
            (json['udzial_powiatu_procent'] as num?)?.toInt() ?? 0,
        ktoOglasza: json['kto_oglasza'] as String? ?? '',
        statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
        uwagi: json['uwagi'] as String? ?? '',
      );

  final String okresOd;
  final String okresDo;
  final String opis;
  final List<ProgTemperatury> progi;
  final int dniPowyzejProgu;
  final int udzialPowiatuProcent;
  final String ktoOglasza;
  final String statusWeryfikacji;
  final String uwagi;

  bool get jest => progi.isNotEmpty;
  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';
}

/// Próg temperatury i uprawy, których dotyczy.
class ProgTemperatury {
  const ProgTemperatury({required this.stopnieC, required this.dotyczy});

  factory ProgTemperatury.zJson(Map<String, dynamic> json) => ProgTemperatury(
    stopnieC: (json['stopnie_c'] as num).toDouble(),
    dotyczy: json['dotyczy'] as String? ?? '',
  );

  final double stopnieC;
  final String dotyczy;
}

/// Odległość, w jakiej nie stosuje się nawozów w pobliżu wód (tabela 1).
class OdlegloscOdWody {
  const OdlegloscOdWody({
    required this.id,
    required this.nazwa,
    required this.metry,
    required this.odCzego,
  });

  factory OdlegloscOdWody.zJson(Map<String, dynamic> json) => OdlegloscOdWody(
    id: json['id'] as String,
    nazwa: json['nazwa'] as String,
    metry: (json['metry'] as num).toDouble(),
    odCzego: json['od_czego'] as String? ?? '',
  );

  final String id;
  final String nazwa;
  final double metry;
  final String odCzego;
}

/// Odległości od wód razem z warunkami ich zmniejszenia.
class OdlegosciOdWod {
  const OdlegosciOdWod({
    required this.statusWeryfikacji,
    required this.zrodlo,
    required this.odleglosci,
    required this.zmniejszenieNieMniejNizM,
    required this.warunkiZmniejszenia,
  });

  static const OdlegosciOdWod puste = OdlegosciOdWod(
    statusWeryfikacji: 'brak',
    zrodlo: '',
    odleglosci: [],
    zmniejszenieNieMniejNizM: 0,
    warunkiZmniejszenia: [],
  );

  factory OdlegosciOdWod.zJson(Map<String, dynamic> json) {
    final zmniejszenie =
        (json['zmniejszenie'] as Map<String, dynamic>?) ?? const {};
    return OdlegosciOdWod(
      statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
      zrodlo: json['zrodlo'] as String? ?? '',
      odleglosci: ((json['odleglosci'] as List<dynamic>?) ?? const [])
          .map((o) => OdlegloscOdWody.zJson(o as Map<String, dynamic>))
          .toList(growable: false),
      zmniejszenieNieMniejNizM:
          (zmniejszenie['nie_mniej_niz_m'] as num?)?.toDouble() ?? 0,
      warunkiZmniejszenia:
          ((zmniejszenie['warunki'] as List<dynamic>?) ?? const [])
              .map((w) => w as String)
              .toList(growable: false),
    );
  }

  final String statusWeryfikacji;
  final String zrodlo;
  final List<OdlegloscOdWody> odleglosci;

  /// Odległość wolno zmniejszyć o połowę, ale nie poniżej tej wartości.
  final double zmniejszenieNieMniejNizM;

  final List<String> warunkiZmniejszenia;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';
}

/// Zasady stosowania nawozów azotowych poza samymi datami: odstępstwa,
/// zakazy i wyłączenia. Wszystko danymi, bo zmienia się z przepisem.
class ZasadyNawozeniaAzotem {
  const ZasadyNawozeniaAzotem({
    required this.statusWeryfikacji,
    required this.zrodlo,
    required this.odstepstwa,
    required this.zakazy,
    required this.nieDotyczy,
    this.wczesniejszeWiosna = WczesniejszeWiosna.puste,
    this.odleglosciOdWod = OdlegosciOdWod.puste,
  });

  static const ZasadyNawozeniaAzotem puste = ZasadyNawozeniaAzotem(
    statusWeryfikacji: 'brak',
    zrodlo: '',
    odstepstwa: [],
    zakazy: [],
    nieDotyczy: [],
  );

  factory ZasadyNawozeniaAzotem.zJson(Map<String, dynamic> json) =>
      ZasadyNawozeniaAzotem(
        statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
        zrodlo: json['zrodlo'] as String? ?? '',
        odstepstwa: ((json['odstepstwa'] as List<dynamic>?) ?? const [])
            .map((o) => OdstepstwoNawozenia.zJson(o as Map<String, dynamic>))
            .toList(growable: false),
        zakazy: ((json['zakazy'] as List<dynamic>?) ?? const [])
            .map((z) => ZakazNawozenia.zJson(z as Map<String, dynamic>))
            .toList(growable: false),
        nieDotyczy: ((json['nie_dotyczy'] as List<dynamic>?) ?? const [])
            .map((w) => w as String)
            .toList(growable: false),
        wczesniejszeWiosna: json['wczesniejsze_wiosna'] == null
            ? WczesniejszeWiosna.puste
            : WczesniejszeWiosna.zJson(
                json['wczesniejsze_wiosna'] as Map<String, dynamic>,
              ),
        odleglosciOdWod: json['odleglosci_od_wod'] == null
            ? OdlegosciOdWod.puste
            : OdlegosciOdWod.zJson(
                json['odleglosci_od_wod'] as Map<String, dynamic>,
              ),
      );

  final String statusWeryfikacji;
  final String zrodlo;
  final List<OdstepstwoNawozenia> odstepstwa;
  final List<ZakazNawozenia> zakazy;

  /// Uprawy, których terminy nie dotyczą (np. pod osłonami).
  final List<String> nieDotyczy;

  /// Wcześniejsze nawożenie w lutym po przejściu temperatury przez próg.
  final WczesniejszeWiosna wczesniejszeWiosna;

  /// Odległości od wód powierzchniowych (tabela 1).
  final OdlegosciOdWod odleglosciOdWod;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';
}

/// Uprawa intensywna z załącznika nr 7 do programu azotanowego.
///
/// Przy części upraw „intensywna" zależy od dawki azotu: pszenica jest
/// intensywna powyżej 120 kg N/ha, kukurydza powyżej 160. Dlatego próg
/// jest danymi, a nie liczbą w kodzie.
class UprawaIntensywna {
  const UprawaIntensywna({
    required this.nazwa,
    this.progAzotuKgNaHa,
    this.podOslonami = false,
  });

  factory UprawaIntensywna.zJson(Map<String, dynamic> json) => UprawaIntensywna(
    nazwa: json['nazwa'] as String,
    progAzotuKgNaHa: (json['prog_azotu_kg_na_ha'] as num?)?.toDouble(),
    podOslonami: json['pod_oslonami'] as bool? ?? false,
  );

  final String nazwa;

  /// Dawka azotu, powyżej której uprawa liczy się jako intensywna.
  /// `null` znaczy „zawsze intensywna".
  final double? progAzotuKgNaHa;

  final bool podOslonami;

  /// Czy ta uprawa liczy się przy danej dawce azotu na hektar.
  bool liczySie({required double azotKgNaHa}) {
    final prog = progAzotuKgNaHa;
    return prog == null || azotKgNaHa > prog;
  }
}

/// Lista upraw intensywnych — od ich powierzchni zależy obowiązek planu
/// nawożenia azotem (Prawo wodne, art. 105a ust. 1 pkt 2).
class UprawyIntensywne {
  const UprawyIntensywne({
    required this.statusWeryfikacji,
    required this.zrodlo,
    required this.uprawy,
  });

  static const UprawyIntensywne puste = UprawyIntensywne(
    statusWeryfikacji: 'brak',
    zrodlo: '',
    uprawy: [],
  );

  factory UprawyIntensywne.zJson(Map<String, dynamic> json) => UprawyIntensywne(
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    zrodlo: json['zrodlo'] as String? ?? '',
    uprawy: ((json['uprawy'] as List<dynamic>?) ?? const [])
        .map((u) => UprawaIntensywna.zJson(u as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String statusWeryfikacji;
  final String zrodlo;
  final List<UprawaIntensywna> uprawy;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  /// Uprawa z listy pasująca do nazwy uprawy na polu.
  ///
  /// Nazwy pól pochodzą z wniosku („pszenica zwyczajna ozima"), a lista
  /// z przepisu jest ogólna („pszenica"), więc szukamy nazwy z przepisu
  /// **w** nazwie uprawy. Dopasowanie jest dosłowne: „żyto mieszańcowe"
  /// nie złapie zwykłego żyta, a „ziemniak późny" nie złapie ziemniaka.
  UprawaIntensywna? dopasuj(String nazwaUprawyNaPolu) {
    final szukane = _bezOgonkow(nazwaUprawyNaPolu);
    if (szukane.isEmpty) {
      return null;
    }
    for (final uprawa in uprawy) {
      if (szukane.contains(_bezOgonkow(uprawa.nazwa))) {
        return uprawa;
      }
    }
    return null;
  }

  static String _bezOgonkow(String tekst) {
    const pary = {
      'ą': 'a',
      'ć': 'c',
      'ę': 'e',
      'ł': 'l',
      'ń': 'n',
      'ó': 'o',
      'ś': 's',
      'ź': 'z',
      'ż': 'z',
    };
    final male = tekst.toLowerCase();
    final wynik = StringBuffer();
    for (final znak in male.split('')) {
      wynik.write(pary[znak] ?? znak);
    }
    return wynik.toString();
  }
}

/// O ile program każe pomniejszyć limit azotu na słabszych glebach.
class ObnizkaDawkiAzotu {
  const ObnizkaDawkiAzotu({
    required this.rodzajGleby,
    required this.procent,
    required this.opis,
  });

  factory ObnizkaDawkiAzotu.zJson(Map<String, dynamic> json) =>
      ObnizkaDawkiAzotu(
        rodzajGleby: json['rodzaj_gleby'] as String? ?? '',
        procent: (json['procent'] as num?)?.toInt() ?? 0,
        opis: json['opis'] as String? ?? '',
      );

  final String rodzajGleby;
  final int procent;
  final String opis;
}

/// Limit dla roślin bobowatych — tabela podaje go nie w kilogramach na
/// hektar ze wszystkich źródeł, a osobno dla nawozów mineralnych
/// i naturalnych.
class LimitBobowatych {
  const LimitBobowatych({
    required this.kgNHaMineralne,
    required this.kgNHaNaturalne,
    required this.opis,
  });

  factory LimitBobowatych.zJson(Map<String, dynamic> json) => LimitBobowatych(
    kgNHaMineralne: (json['kg_n_ha_mineralne'] as num?)?.toInt(),
    kgNHaNaturalne: (json['kg_n_ha_naturalne'] as num?)?.toInt(),
    opis: json['opis'] as String? ?? '',
  );

  final int? kgNHaMineralne;
  final int? kgNHaNaturalne;
  final String opis;
}

/// Jeden wiersz tabeli 14: ile azotu działającego wolno dać pod tę uprawę.
class MaksymalnaDawkaAzotu {
  const MaksymalnaDawkaAzotu({
    required this.grupa,
    required this.uprawa,
    this.kgNHa,
    this.bobowate = false,
    this.ogolna = false,
  });

  factory MaksymalnaDawkaAzotu.zJson(Map<String, dynamic> json) =>
      MaksymalnaDawkaAzotu(
        grupa: json['grupa'] as String? ?? '',
        uprawa: json['uprawa'] as String? ?? '',
        kgNHa: (json['kg_n_ha'] as num?)?.toInt(),
        bobowate: json['bobowate'] as bool? ?? false,
        ogolna: json['ogolna'] as bool? ?? false,
      );

  final String grupa;
  final String uprawa;

  /// Limit ze wszystkich źródeł. `null` przy bobowatych — tam limit ma
  /// inną postać, patrz [LimitBobowatych].
  final int? kgNHa;

  final bool bobowate;

  /// Wiersz zbiorczy („Inne oleiste") — wybiera go tylko rolnik wprost,
  /// nigdy dopasowanie po fragmencie nazwy.
  final bool ogolna;
}

/// Co tabela mówi o uprawie z pola.
enum StanMaksymalnejDawki {
  /// Tabela podaje jedną liczbę.
  znany,

  /// Uprawa bobowata — limit osobno dla nawozów mineralnych i naturalnych.
  bobowate,

  /// Nazwa pasuje do kilku wierszy o różnych limitach (np. „rzepak" jest
  /// w oleistych z limitem 240 i w pastewnych z limitem 200). Aplikacja
  /// nie wybiera za rolnika.
  niejednoznaczny,

  /// Tabela nie zna tej uprawy. Nie zgadujemy limitu.
  brak,
}

/// Odpowiedź na pytanie „ile azotu wolno dać pod tę uprawę".
class LimitAzotuDlaUprawy {
  const LimitAzotuDlaUprawy({
    required this.stan,
    this.dopasowania = const [],
    this.bobowate,
  });

  static const LimitAzotuDlaUprawy brak = LimitAzotuDlaUprawy(
    stan: StanMaksymalnejDawki.brak,
  );

  final StanMaksymalnejDawki stan;

  /// Wiersze tabeli, które pasują do nazwy uprawy.
  final List<MaksymalnaDawkaAzotu> dopasowania;

  /// Limit bobowatych — wypełniony tylko przy [StanMaksymalnejDawki.bobowate].
  final LimitBobowatych? bobowate;

  /// Limit w kilogramach azotu na hektar. `null`, gdy tabela limitu nie
  /// podaje albo gdy dopasowań jest więcej niż jedno.
  int? get kgNHa =>
      stan == StanMaksymalnejDawki.znany ? dopasowania.single.kgNHa : null;

  /// Najniższy z dopasowanych limitów — przy dopasowaniu
  /// niejednoznacznym pozwala powiedzieć rolnikowi, że dawka na pewno
  /// przekracza *któryś* z limitów z tabeli.
  int? get najnizszyKgNHa {
    final liczby = dopasowania
        .map((u) => u.kgNHa)
        .whereType<int>()
        .toList(growable: false);
    if (liczby.isEmpty) {
      return null;
    }
    return liczby.reduce((a, b) => a < b ? a : b);
  }

  /// Dopasowania w postaci „240 kg w oleistych, 200 kg w pastewnych" —
  /// do pokazania przy limicie niejednoznacznym.
  String get opisDopasowan => dopasowania
      .map((u) => '${u.kgNHa} kg: ${u.grupa.toLowerCase()}')
      .join(', ');

  /// Czy dawka przekracza limit. `false`, gdy limitu nie znamy — brak
  /// wiedzy nie jest ostrzeżeniem.
  bool przekroczony(double azotKgNaHa) {
    final limit = kgNHa;
    return limit != null && azotKgNaHa > limit;
  }
}

/// Tabela 14 programu azotanowego: maksymalne ilości azotu działającego
/// ze wszystkich źródeł dla upraw w plonie głównym.
class MaksymalneDawkiAzotu {
  const MaksymalneDawkiAzotu({
    required this.statusWeryfikacji,
    required this.zrodlo,
    required this.opis,
    required this.obnizki,
    required this.uprawy,
    this.bobowate,
  });

  static const MaksymalneDawkiAzotu puste = MaksymalneDawkiAzotu(
    statusWeryfikacji: 'brak',
    zrodlo: '',
    opis: '',
    obnizki: [],
    uprawy: [],
  );

  factory MaksymalneDawkiAzotu.zJson(Map<String, dynamic> json) =>
      MaksymalneDawkiAzotu(
        statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
        zrodlo: json['zrodlo'] as String? ?? '',
        opis: json['opis'] as String? ?? '',
        obnizki: ((json['obnizki'] as List<dynamic>?) ?? const [])
            .map((o) => ObnizkaDawkiAzotu.zJson(o as Map<String, dynamic>))
            .toList(growable: false),
        uprawy: ((json['uprawy'] as List<dynamic>?) ?? const [])
            .map((u) => MaksymalnaDawkaAzotu.zJson(u as Map<String, dynamic>))
            .toList(growable: false),
        bobowate: json['bobowate'] == null
            ? null
            : LimitBobowatych.zJson(json['bobowate'] as Map<String, dynamic>),
      );

  final String statusWeryfikacji;
  final String zrodlo;
  final String opis;
  final List<ObnizkaDawkiAzotu> obnizki;
  final List<MaksymalnaDawkaAzotu> uprawy;
  final LimitBobowatych? bobowate;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  bool get pusta => uprawy.isEmpty;

  /// Limit dla uprawy zapisanej na polu.
  ///
  /// Nazwy na polach bywają dłuższe niż w tabeli („pszenica zwyczajna
  /// ozima" wobec „Pszenica ozima"), więc po nieudanym dopasowaniu
  /// dosłownym szukamy nazwy z tabeli w nazwie z pola — ale całymi
  /// słowami i wybierając dopasowanie najdłuższe, żeby „burak cukrowy"
  /// nie trafił w sam „burak pastewny". Gdy po takim zawężeniu zostaje
  /// kilka różnych limitów, oddajemy je wszystkie z [StanMaksymalnejDawki
  /// .niejednoznaczny] — wybór należy do rolnika.
  LimitAzotuDlaUprawy dlaUprawy(String nazwaUprawy) {
    final slowa = Tekst.slowaDoSzukania(nazwaUprawy);
    if (slowa.isEmpty) {
      return LimitAzotuDlaUprawy.brak;
    }

    final dokladne = uprawy
        .where((u) => Tekst.znormalizuj(u.uprawa) == slowa.join(' '))
        .toList(growable: false);
    final pasujace = dokladne.isNotEmpty ? dokladne : _poFragmencie(slowa);

    if (pasujace.isEmpty) {
      return LimitAzotuDlaUprawy.brak;
    }
    final limity = pasujace.map((u) => u.bobowate ? null : u.kgNHa).toSet();
    if (limity.length > 1) {
      return LimitAzotuDlaUprawy(
        stan: StanMaksymalnejDawki.niejednoznaczny,
        dopasowania: pasujace,
      );
    }
    if (pasujace.first.bobowate) {
      return LimitAzotuDlaUprawy(
        stan: StanMaksymalnejDawki.bobowate,
        dopasowania: pasujace,
        bobowate: bobowate,
      );
    }
    return LimitAzotuDlaUprawy(
      stan: StanMaksymalnejDawki.znany,
      dopasowania: [pasujace.first],
    );
  }

  /// Wiersze, których nazwa stoi całymi słowami w nazwie uprawy z pola.
  /// Zostawiamy tylko te z najdłuższą pasującą nazwą.
  List<MaksymalnaDawkaAzotu> _poFragmencie(List<String> slowa) {
    var najdluzsze = 0;
    final znalezione = <MaksymalnaDawkaAzotu>[];
    for (final uprawa in uprawy) {
      if (uprawa.ogolna) {
        continue;
      }
      final wzor = Tekst.slowaDoSzukania(uprawa.uprawa);
      if (wzor.isEmpty || !_zawiera(slowa, wzor)) {
        continue;
      }
      if (wzor.length > najdluzsze) {
        najdluzsze = wzor.length;
        znalezione.clear();
      }
      if (wzor.length == najdluzsze) {
        znalezione.add(uprawa);
      }
    }
    return znalezione;
  }

  /// Czy [wzor] stoi w [slowa] jako ciąg kolejnych słów.
  static bool _zawiera(List<String> slowa, List<String> wzor) {
    for (var i = 0; i + wzor.length <= slowa.length; i++) {
      var zgodne = true;
      for (var j = 0; j < wzor.length; j++) {
        if (slowa[i + j] != wzor[j]) {
          zgodne = false;
          break;
        }
      }
      if (zgodne) {
        return true;
      }
    }
    return false;
  }
}

/// Próg albo limit liczbowy z normy GAEC — zawsze z danych, nigdy z kodu.
class ProgNormy {
  const ProgNormy({
    required this.id,
    required this.wartosc,
    required this.jednostka,
    required this.opis,
    this.liczOdRoku,
  });

  factory ProgNormy.zJson(Map<String, dynamic> json) => ProgNormy(
    id: json['id'] as String? ?? '',
    wartosc: (json['wartosc'] as num?)?.toDouble() ?? 0,
    jednostka: json['jednostka'] as String? ?? '',
    opis: json['opis'] as String? ?? '',
    liczOdRoku: (json['licz_od_roku'] as num?)?.toInt(),
  );

  final String id;
  final double wartosc;
  final String jednostka;
  final String opis;

  /// Rok, od którego przepis każe liczyć (GAEC 7: uprawy od 2023 r.).
  final int? liczOdRoku;

  int get calkowita => wartosc.round();
}

/// Termin z normy: dzień–miesiąc albo zdarzenie w gospodarstwie.
///
/// GAEC 6 liczy okrywę „od dnia zbioru uprawy w plonie głównym", więc
/// początkiem bywa zdarzenie (`zbior`), nie data z kalendarza.
class TerminNormy {
  const TerminNormy({
    required this.id,
    required this.od,
    required this.doDnia,
    required this.opis,
  });

  factory TerminNormy.zJson(Map<String, dynamic> json) => TerminNormy(
    id: json['id'] as String? ?? '',
    od: json['od'] as String? ?? '',
    doDnia: json['do'] as String? ?? '',
    opis: json['opis'] as String? ?? '',
  );

  final String id;

  /// `MM-DD` albo nazwa zdarzenia (np. `zbior`).
  final String od;

  /// `MM-DD`.
  final String doDnia;

  final String opis;

  bool get odZdarzenia => !od.contains('-');

  /// Czy dzień mieści się w terminie. Terminy przechodzące przez koniec
  /// roku (1 listopada – 15 lutego) liczą się jako jeden okres.
  bool obejmuje(DateTime dzien) {
    if (odZdarzenia) {
      return false;
    }
    final teraz = _numer(dzien.month, dzien.day);
    final poczatek = _zTekstu(od);
    final koniec = _zTekstu(doDnia);
    if (poczatek == null || koniec == null) {
      return false;
    }
    return poczatek <= koniec
        ? teraz >= poczatek && teraz <= koniec
        : teraz >= poczatek || teraz <= koniec;
  }

  static int _numer(int miesiac, int dzien) => miesiac * 100 + dzien;

  static int? _zTekstu(String dataRoczna) {
    final czesci = dataRoczna.split('-');
    if (czesci.length != 2) {
      return null;
    }
    final miesiac = int.tryParse(czesci.first);
    final dzien = int.tryParse(czesci.last);
    return miesiac == null || dzien == null ? null : _numer(miesiac, dzien);
  }
}

/// Jedna norma GAEC ze słownika reguł.
class NormaGaec {
  const NormaGaec({
    required this.id,
    required this.numer,
    required this.nazwa,
    required this.opis,
    required this.statusWeryfikacji,
    this.paragraf,
    this.aplikacjaLiczy = false,
    this.dlaczegoNieLiczy = '',
    this.coRolnikPodaje = const [],
    this.progi = const [],
    this.terminy = const [],
    this.wylaczeniaUpraw = const [],
    this.uznanieZaUprawe = const [],
    this.spelnienieZastepcze = '',
    this.zrodlo = '',
    this.uwagi = '',
  });

  factory NormaGaec.zJson(Map<String, dynamic> json) => NormaGaec(
    id: json['id'] as String? ?? '',
    numer: json['numer'] as String? ?? '',
    nazwa: json['nazwa'] as String? ?? '',
    opis: json['opis'] as String? ?? '',
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    paragraf: json['paragraf'] as String?,
    aplikacjaLiczy: json['aplikacja_liczy'] as bool? ?? false,
    dlaczegoNieLiczy: json['dlaczego_nie_liczy'] as String? ?? '',
    coRolnikPodaje: _napisy(json['co_rolnik_podaje']),
    progi: ((json['progi'] as List<dynamic>?) ?? const [])
        .map((p) => ProgNormy.zJson(p as Map<String, dynamic>))
        .toList(growable: false),
    terminy: ((json['terminy'] as List<dynamic>?) ?? const [])
        .map((t) => TerminNormy.zJson(t as Map<String, dynamic>))
        .toList(growable: false),
    wylaczeniaUpraw: _napisy(json['wylaczenia_upraw']),
    uznanieZaUprawe: _napisy(json['uznanie_za_uprawe']),
    spelnienieZastepcze: json['spelnienie_zastepcze'] as String? ?? '',
    zrodlo: json['zrodlo'] as String? ?? '',
    uwagi: json['uwagi'] as String? ?? '',
  );

  final String id;

  /// „GAEC 7" — tak normę nazywa ARiMR i tak pyta o nią kontrola.
  final String numer;

  final String nazwa;
  final String opis;
  final String statusWeryfikacji;

  /// Przepis, z którego norma pochodzi („§ 5"). `null`, gdy norma nie jest
  /// w rozporządzeniu o normach (GAEC 1 jest wskaźnikiem krajowym).
  final String? paragraf;

  /// Czy aplikacja umie sama policzyć spełnienie normy.
  final bool aplikacjaLiczy;

  /// Dlaczego nie umie — pokazujemy to rolnikowi zamiast udawać wynik.
  final String dlaczegoNieLiczy;

  /// Czego aplikacja potrzebuje od rolnika, żeby policzyć normę.
  final List<String> coRolnikPodaje;

  final List<ProgNormy> progi;
  final List<TerminNormy> terminy;

  /// Uprawy, do których warunku nie stosuje się (GAEC 7 § 5 ust. 3).
  final List<String> wylaczeniaUpraw;

  /// Co przepis uznaje za „uprawę" przy liczeniu zmianowania.
  final List<String> uznanieZaUprawe;

  /// Spełnienie zastępcze — przy GAEC 7 rejestr zabiegów agrotechnicznych
  /// z wsiewką albo międzyplonem zastępuje warunek 40 %.
  final String spelnienieZastepcze;

  final String zrodlo;
  final String uwagi;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  ProgNormy? prog(String id) => progi.where((p) => p.id == id).firstOrNull;

  TerminNormy? termin(String id) =>
      terminy.where((t) => t.id == id).firstOrNull;

  static List<String> _napisy(Object? wartosc) => [
    for (final element in (wartosc as List<dynamic>?) ?? const []) '$element',
  ];
}

/// Zwolnienie z kontroli warunkowości — np. gospodarstwa do 10 ha.
class ZwolnienieZKontroli {
  const ZwolnienieZKontroli({
    required this.id,
    required this.nazwa,
    required this.opis,
    required this.statusWeryfikacji,
    this.doHa,
    this.normy = const [],
    this.wszystkieNormy = false,
    this.zrodlo = '',
    this.uwagi = '',
  });

  factory ZwolnienieZKontroli.zJson(Map<String, dynamic> json) {
    final dotyczy = json['dotyczy_norm'];
    return ZwolnienieZKontroli(
      id: json['id'] as String? ?? '',
      nazwa: json['nazwa'] as String? ?? '',
      opis: json['opis'] as String? ?? '',
      statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
      doHa: (json['do_ha'] as num?)?.toDouble(),
      normy: dotyczy is List
          ? [for (final n in dotyczy) '$n']
          : const <String>[],
      wszystkieNormy: dotyczy == 'wszystkich',
      zrodlo: json['zrodlo'] as String? ?? '',
      uwagi: json['uwagi'] as String? ?? '',
    );
  }

  final String id;
  final String nazwa;
  final String opis;
  final String statusWeryfikacji;

  /// Próg powierzchni, do którego zwolnienie działa. `null` — zwolnienie
  /// nie zależy od powierzchni (produkcja ekologiczna).
  final double? doHa;

  /// Normy objęte zwolnieniem; puste, gdy [wszystkieNormy].
  final List<String> normy;

  final bool wszystkieNormy;
  final String zrodlo;
  final String uwagi;

  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';

  bool dotyczyNormy(String idNormy) =>
      wszystkieNormy || normy.contains(idNormy);
}

/// Normy GAEC razem ze zwolnieniami — dane z wersją, nie kod.
class Warunkowosc {
  const Warunkowosc({
    required this.statusWeryfikacji,
    required this.zrodlo,
    required this.opis,
    required this.normy,
    required this.zwolnienia,
  });

  static const Warunkowosc puste = Warunkowosc(
    statusWeryfikacji: 'brak',
    zrodlo: '',
    opis: '',
    normy: [],
    zwolnienia: [],
  );

  factory Warunkowosc.zJson(Map<String, dynamic> json) => Warunkowosc(
    statusWeryfikacji: json['status_weryfikacji'] as String? ?? 'nieznany',
    zrodlo: json['zrodlo'] as String? ?? '',
    opis: json['opis'] as String? ?? '',
    normy: ((json['normy'] as List<dynamic>?) ?? const [])
        .map((n) => NormaGaec.zJson(n as Map<String, dynamic>))
        .toList(growable: false),
    zwolnienia: ((json['zwolnienia'] as List<dynamic>?) ?? const [])
        .map((z) => ZwolnienieZKontroli.zJson(z as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String statusWeryfikacji;
  final String zrodlo;
  final String opis;
  final List<NormaGaec> normy;
  final List<ZwolnienieZKontroli> zwolnienia;

  bool get pusta => normy.isEmpty;

  NormaGaec? norma(String id) => normy.where((n) => n.id == id).firstOrNull;

  /// Normy, które aplikacja umie policzyć sama.
  List<NormaGaec> get liczone =>
      normy.where((n) => n.aplikacjaLiczy).toList(growable: false);

  /// Zwolnienia, które przy tej powierzchni zdejmują kontrolę z normy.
  ///
  /// Zwolnienie bez progu powierzchni (produkcja ekologiczna) zależy od
  /// certyfikatu, a nie od hektarów — aplikacja go sama nie stosuje.
  List<ZwolnienieZKontroli> zwolnieniaDla({
    required String idNormy,
    required double powierzchniaUrHa,
  }) => zwolnienia
      .where(
        (z) =>
            z.dotyczyNormy(idNormy) &&
            z.doHa != null &&
            powierzchniaUrHa <= z.doHa!,
      )
      .toList(growable: false);
}

/// Cały słownik reguł prawnych — dane z numerem wersji, nie kod.
class SlownikRegul {
  const SlownikRegul({
    required this.wersja,
    required this.obowiazujeOd,
    required this.obowiazki,
    required this.terminy,
    this.wspolczynnikiDjp = WspolczynnikiDjp.puste,
    this.zasadyNawozeniaAzotem = ZasadyNawozeniaAzotem.puste,
    this.uprawyIntensywne = UprawyIntensywne.puste,
    this.maksymalneDawkiAzotu = MaksymalneDawkiAzotu.puste,
    this.warunkowosc = Warunkowosc.puste,
  });

  factory SlownikRegul.zTekstuJson(String tekst) =>
      SlownikRegul.zJson(jsonDecode(tekst) as Map<String, dynamic>);

  factory SlownikRegul.zJson(Map<String, dynamic> json) => SlownikRegul(
    wersja: json['wersja'] as String,
    obowiazujeOd: DateTime.parse(json['obowiazuje_od'] as String),
    obowiazki: ((json['obowiazki'] as List<dynamic>?) ?? const [])
        .map((o) => Obowiazek.zJson(o as Map<String, dynamic>))
        .toList(growable: false),
    terminy: ((json['terminy'] as List<dynamic>?) ?? const [])
        .map((t) => Termin.zJson(t as Map<String, dynamic>))
        .toList(growable: false),
    wspolczynnikiDjp: json['wspolczynniki_djp'] == null
        ? WspolczynnikiDjp.puste
        : WspolczynnikiDjp.zJson(
            json['wspolczynniki_djp'] as Map<String, dynamic>,
          ),
    zasadyNawozeniaAzotem: json['zasady_nawozenia_azotem'] == null
        ? ZasadyNawozeniaAzotem.puste
        : ZasadyNawozeniaAzotem.zJson(
            json['zasady_nawozenia_azotem'] as Map<String, dynamic>,
          ),
    uprawyIntensywne: json['uprawy_intensywne'] == null
        ? UprawyIntensywne.puste
        : UprawyIntensywne.zJson(
            json['uprawy_intensywne'] as Map<String, dynamic>,
          ),
    maksymalneDawkiAzotu: json['maksymalne_dawki_azotu'] == null
        ? MaksymalneDawkiAzotu.puste
        : MaksymalneDawkiAzotu.zJson(
            json['maksymalne_dawki_azotu'] as Map<String, dynamic>,
          ),
    warunkowosc: json['warunkowosc'] == null
        ? Warunkowosc.puste
        : Warunkowosc.zJson(json['warunkowosc'] as Map<String, dynamic>),
  );

  final String wersja;
  final DateTime obowiazujeOd;
  final List<Obowiazek> obowiazki;
  final List<Termin> terminy;

  /// Przeliczniki zwierząt na DJP — dane, nie stałe w kodzie.
  final WspolczynnikiDjp wspolczynnikiDjp;

  /// Odstępstwa, zakazy i wyłączenia przy nawożeniu azotem.
  final ZasadyNawozeniaAzotem zasadyNawozeniaAzotem;

  /// Lista upraw intensywnych (załącznik nr 7 programu azotanowego).
  final UprawyIntensywne uprawyIntensywne;

  /// Maksymalne dawki azotu dla upraw (tabela 14, załącznik nr 9).
  final MaksymalneDawkiAzotu maksymalneDawkiAzotu;

  /// Normy GAEC (warunkowość) — etap 2, krok 1.
  final Warunkowosc warunkowosc;

  /// Graniczne terminy stosowania nawozów — te, które mówią o rodzaju
  /// nawozu i rodzaju gruntu.
  List<Termin> get terminyNawozenia =>
      terminy.where((t) => t.rodzajNawozu != null).toList(growable: false);

  Obowiazek? obowiazek(String id) =>
      obowiazki.where((o) => o.id == id).firstOrNull;

  /// Obowiązki włączone dla danego gospodarstwa.
  List<Obowiazek> obowiazkiDla(ProfilGospodarstwa profil) => obowiazki
      .where((o) => o.ocena(profil) == Ocena.dotyczy)
      .toList(growable: false);

  /// Obowiązki, których ta wersja aplikacji nie umie ocenić — do pokazania
  /// rolnikowi jako „sprawdź u doradcy", nigdy do cichego pominięcia.
  List<Obowiazek> obowiazkiNiepewneDla(ProfilGospodarstwa profil) => obowiazki
      .where((o) => o.ocena(profil) == Ocena.nieWiadomo)
      .toList(growable: false);

  List<Termin> terminyObowiazku(String idObowiazku) => terminy
      .where((t) => t.idObowiazku == idObowiazku)
      .toList(growable: false);
}
