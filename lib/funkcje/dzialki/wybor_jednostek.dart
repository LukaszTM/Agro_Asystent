import 'klient_uldk.dart';

/// Wybór obrębu krok po kroku: województwo → powiat → gmina → obręb.
///
/// Po co: rolnik dodaje też działki **spoza wniosku** — dzierżawione,
/// kupione po złożeniu wniosku, przejęte po sąsiedzie. Pełnego
/// identyfikatora (`061506_2.0007.138`) nie zna i nie ma go gdzie
/// przepisać. Zna za to swoją gminę i obręb, a numer działki ma na
/// umowie dzierżawy.
///
/// Klasa trzyma sam wybór i listy — bez ekranów, żeby wszystkie trzy
/// wyglądy robiły to tak samo i żeby dało się to sprawdzić testem.
class WyborJednostek {
  WyborJednostek({required this.klient});

  final KlientUldk klient;

  final Map<PoziomPodzialu, JednostkaTerytorialna> _wybrane = {};

  /// Pobrane listy — żeby cofanie się nie pytało usługi drugi raz.
  final Map<String, List<JednostkaTerytorialna>> _listy = {};

  JednostkaTerytorialna? wybrana(PoziomPodzialu poziom) => _wybrane[poziom];

  /// Obręb, czyli ostatni szczebel. `null`, dopóki rolnik go nie wskazał.
  JednostkaTerytorialna? get obreb => _wybrane[PoziomPodzialu.obreb];

  bool get gotowy => obreb != null;

  /// Szczebel, na którym stoi wybór — pierwszy bez odpowiedzi.
  PoziomPodzialu get biezacy {
    for (final poziom in PoziomPodzialu.values) {
      if (!_wybrane.containsKey(poziom)) {
        return poziom;
      }
    }
    return PoziomPodzialu.obreb;
  }

  /// Lista do wyboru na danym szczeblu. Pyta usługę raz; przy powrocie
  /// bierze to, co już pobrane.
  Future<List<JednostkaTerytorialna>> lista(PoziomPodzialu poziom) async {
    final nadrzedna = _nadrzedna(poziom);
    if (poziom.parametrNadrzednej != null && nadrzedna == null) {
      return const [];
    }
    final klucz = '${poziom.name}:${nadrzedna?.teryt ?? ''}';
    final juz = _listy[klucz];
    if (juz != null) {
      return juz;
    }
    final pobrane = await klient.jednostki(
      poziom: poziom,
      terytNadrzednej: nadrzedna?.teryt,
    );
    _listy[klucz] = pobrane;
    return pobrane;
  }

  /// Zapisuje wybór i **czyści szczeble niższe** — po zmianie gminy
  /// poprzedni obręb nie ma już sensu.
  void wybierz(PoziomPodzialu poziom, JednostkaTerytorialna jednostka) {
    _wybrane[poziom] = jednostka;
    for (final nizszy in PoziomPodzialu.values.skip(poziom.index + 1)) {
      _wybrane.remove(nizszy);
    }
  }

  /// Cofnięcie do danego szczebla: kasuje jego wybór i wszystkie niższe.
  void cofnij(PoziomPodzialu poziom) {
    for (final od in PoziomPodzialu.values.skip(poziom.index)) {
      _wybrane.remove(od);
    }
  }

  /// Dotychczasowy wybór jednym zdaniem — żeby rolnik widział, gdzie jest.
  String get opisWyboru => [
    for (final poziom in PoziomPodzialu.values)
      if (_wybrane[poziom] case final JednostkaTerytorialna jednostka)
        jednostka.nazwa,
  ].join(' • ');

  /// Pełny identyfikator działki z wybranego obrębu i numeru z umowy.
  /// `null`, gdy obrębu jeszcze nie wybrano albo numer jest pusty.
  String? numerDzialki(String numer) {
    final wybranyObreb = obreb;
    if (wybranyObreb == null || numer.trim().isEmpty) {
      return null;
    }
    return KlientUldk.pelnyNumer(wybranyObreb, numer);
  }

  JednostkaTerytorialna? _nadrzedna(PoziomPodzialu poziom) => poziom.index == 0
      ? null
      : _wybrane[PoziomPodzialu.values[poziom.index - 1]];
}
