import 'dart:convert';

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
  final double djp;
  final bool zadeklarowanyEkoschemat;
  final bool posiadaczZwierzat;

  /// `null`, gdy aplikacja nie zna tej miary.
  double? wartosc(Miara miara) => switch (miara) {
    Miara.powierzchniaUrHa => powierzchniaUrHa,
    Miara.powierzchniaUprawIntensywnychHa => powierzchniaUprawIntensywnychHa,
    Miara.djp => djp,
    Miara.zadeklarowanyEkoschemat => zadeklarowanyEkoschemat ? 1 : 0,
    Miara.posiadaczZwierzat => posiadaczZwierzat ? 1 : 0,
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

  /// Termin wymagający sprawdzenia u doradcy przed naborem (plan, pkt 10).
  bool get doWeryfikacji => statusWeryfikacji != 'potwierdzone';
}

/// Parametr liczbowy warunkowości, np. pas 3 m od wód.
class ParametrWarunkowosci {
  const ParametrWarunkowosci({
    required this.id,
    required this.nazwa,
    required this.wartosc,
    required this.jednostka,
  });

  factory ParametrWarunkowosci.zJson(Map<String, dynamic> json) =>
      ParametrWarunkowosci(
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

/// Cały słownik reguł prawnych — dane z numerem wersji, nie kod.
class SlownikRegul {
  const SlownikRegul({
    required this.wersja,
    required this.obowiazujeOd,
    required this.obowiazki,
    required this.terminy,
    required this.parametryWarunkowosci,
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
    parametryWarunkowosci:
        ((json['parametry_warunkowosci'] as List<dynamic>?) ?? const [])
            .map((p) => ParametrWarunkowosci.zJson(p as Map<String, dynamic>))
            .toList(growable: false),
  );

  final String wersja;
  final DateTime obowiazujeOd;
  final List<Obowiazek> obowiazki;
  final List<Termin> terminy;
  final List<ParametrWarunkowosci> parametryWarunkowosci;

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
