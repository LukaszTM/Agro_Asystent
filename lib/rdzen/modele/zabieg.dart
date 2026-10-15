/// Encje zabiegu — rdzeń aplikacji. Z jednego wpisu powstają wszystkie
/// wymagane dokumenty (plan, pkt 1).
library;

/// Rodzaj zabiegu. Nazwy w bazie są stałe; etykiety dla rolnika są w języku
/// potocznym („oprysk"), nazwy urzędowe pojawiają się dopiero na wydrukach.
enum RodzajZabiegu {
  oprysk('oprysk', 'Oprysk', 'Zabieg środkiem ochrony roślin'),
  nawozenie('nawozenie', 'Nawożenie', 'Zabieg nawożenia'),
  siew('siew', 'Siew', 'Siew lub sadzenie'),
  zbior('zbior', 'Zbiór', 'Zbiór plonu'),
  uprawaGleby('uprawa_gleby', 'Uprawa gleby', 'Zabieg uprawowy'),
  inny('inny', 'Inny', 'Inny zabieg agrotechniczny');

  const RodzajZabiegu(this.wBazie, this.dlaRolnika, this.naWydruku);

  final String wBazie;
  final String dlaRolnika;
  final String naWydruku;

  static RodzajZabiegu zBazy(String wartosc) =>
      RodzajZabiegu.values.firstWhere(
        (r) => r.wBazie == wartosc,
        orElse: () => RodzajZabiegu.inny,
      );
}

/// Zabieg wykonany na jednym lub kilku polach.
class Zabieg {
  const Zabieg({
    required this.id,
    required this.gospodarstwoId,
    required this.rodzaj,
    required this.data,
    required this.urzadzenie,
    this.godzina,
    this.powierzchniaAr = 0,
    this.uwagi,
    this.usuniety = false,
  });

  final String id;
  final String gospodarstwoId;
  final RodzajZabiegu rodzaj;
  final DateTime data;
  final String? godzina;
  final int powierzchniaAr;
  final String? uwagi;
  final String urzadzenie;
  final bool usuniety;

  Map<String, Object?> doBazy({required DateTime teraz}) => {
        'id': id,
        'gospodarstwo_id': gospodarstwoId,
        'typ': rodzaj.wBazie,
        'data': data.toIso8601String().split('T').first,
        'godzina': godzina,
        'powierzchnia_ar': powierzchniaAr,
        'uwagi': uwagi,
        'utworzono': teraz.toIso8601String(),
        'zmieniono': teraz.toIso8601String(),
        'urzadzenie': urzadzenie,
        'usuniety': usuniety ? 1 : 0,
      };

  static Zabieg zBazy(Map<String, Object?> wiersz) => Zabieg(
        id: wiersz['id']! as String,
        gospodarstwoId: wiersz['gospodarstwo_id']! as String,
        rodzaj: RodzajZabiegu.zBazy(wiersz['typ']! as String),
        data: DateTime.parse(wiersz['data']! as String),
        godzina: wiersz['godzina'] as String?,
        powierzchniaAr: (wiersz['powierzchnia_ar'] as int?) ?? 0,
        uwagi: wiersz['uwagi'] as String?,
        urzadzenie: wiersz['urzadzenie']! as String,
        usuniety: (wiersz['usuniety'] as int? ?? 0) == 1,
      );
}

/// Szczegóły oprysku wymagane w ewidencji (rozp. UE 2023/564).
///
/// Dane środka **przepisujemy ze słownika w chwili zabiegu**: ewidencja ma
/// pokazywać stan z dnia zabiegu, a nie dzisiejszy (ADR-0004).
class SzczegolyOprysku {
  const SzczegolyOprysku({
    required this.zabiegId,
    required this.srodekNazwa,
    required this.nrZezwolenia,
    this.dawka,
    this.dawkaJednostka,
    this.dawkaOdniesienie,
    this.przyczyna,
    this.agrofag,
    this.bbchOd,
    this.bbchDo,
    this.kodEppo,
    this.rodzajZastosowania,
    this.karencjaDni,
    this.karencjaZrodlo,
    this.karencjaDataEtykiety,
    this.karencjaPotwierdzona = false,
  });

  final String zabiegId;
  final String srodekNazwa;
  final String nrZezwolenia;
  final double? dawka;
  final String? dawkaJednostka;
  final String? dawkaOdniesienie;
  final String? przyczyna;
  final String? agrofag;
  final int? bbchOd;
  final int? bbchDo;
  final String? kodEppo;
  final String? rodzajZastosowania;
  final int? karencjaDni;
  final String? karencjaZrodlo;
  final String? karencjaDataEtykiety;

  /// Czy rolnik potwierdził karencję. Niepotwierdzonej nie pokazujemy jako
  /// pewnej — przy niepewnym odczycie nie zgadujemy (CLAUDE.md).
  final bool karencjaPotwierdzona;

  /// Dzień, od którego wolno zbierać plon. `null`, gdy karencja nieznana.
  DateTime? dzienZbioru(DateTime dataZabiegu) =>
      karencjaDni == null ? null : dataZabiegu.add(Duration(days: karencjaDni!));

  Map<String, Object?> doBazy() => {
        'zabieg_id': zabiegId,
        'srodek_nazwa': srodekNazwa,
        'nr_zezwolenia': nrZezwolenia,
        'dawka': dawka,
        'dawka_jednostka': dawkaJednostka,
        'dawka_odniesienie': dawkaOdniesienie,
        'przyczyna': przyczyna,
        'agrofag': agrofag,
        'bbch_od': bbchOd,
        'bbch_do': bbchDo,
        'kod_eppo': kodEppo,
        'rodzaj_zastosowania': rodzajZastosowania,
        'karencja_dni': karencjaDni,
        'karencja_zrodlo': karencjaZrodlo,
        'karencja_data_etykiety': karencjaDataEtykiety,
        'karencja_potwierdzona': karencjaPotwierdzona ? 1 : 0,
      };

  static SzczegolyOprysku zBazy(Map<String, Object?> wiersz) => SzczegolyOprysku(
        zabiegId: wiersz['zabieg_id']! as String,
        srodekNazwa: wiersz['srodek_nazwa']! as String,
        nrZezwolenia: wiersz['nr_zezwolenia']! as String,
        dawka: (wiersz['dawka'] as num?)?.toDouble(),
        dawkaJednostka: wiersz['dawka_jednostka'] as String?,
        dawkaOdniesienie: wiersz['dawka_odniesienie'] as String?,
        przyczyna: wiersz['przyczyna'] as String?,
        agrofag: wiersz['agrofag'] as String?,
        bbchOd: wiersz['bbch_od'] as int?,
        bbchDo: wiersz['bbch_do'] as int?,
        kodEppo: wiersz['kod_eppo'] as String?,
        rodzajZastosowania: wiersz['rodzaj_zastosowania'] as String?,
        karencjaDni: wiersz['karencja_dni'] as int?,
        karencjaZrodlo: wiersz['karencja_zrodlo'] as String?,
        karencjaDataEtykiety: wiersz['karencja_data_etykiety'] as String?,
        karencjaPotwierdzona: (wiersz['karencja_potwierdzona'] as int? ?? 0) == 1,
      );
}

/// Pole objęte zabiegiem wraz z powierzchnią, na której zabieg wykonano.
class PoleZabiegu {
  const PoleZabiegu({required this.dzialkaRolnaId, required this.powierzchniaAr});

  final String dzialkaRolnaId;
  final int powierzchniaAr;
}
