import '../zabiegi/slownik_srodkow.dart';

/// Co udało się rozpoznać na etykiecie środka ochrony roślin.
///
/// Rozpoznanie jest **propozycją**: dopóki rolnik go nie potwierdzi, nic nie
/// trafia do ewidencji. Nie wyciągamy też z etykiety karencji „na oko" —
/// karencja pochodzi ze sprawdzonej bazy etykiet (zadanie P2).
class OdczytEtykiety {
  const OdczytEtykiety({
    required this.tekst,
    this.nazwa,
    this.nrZezwolenia,
    this.dopasowania = const [],
  });

  /// Pełny odczytany tekst — pokazujemy go, gdy nic nie rozpoznaliśmy.
  final String tekst;

  /// Nazwa handlowa odczytana z etykiety.
  final String? nazwa;

  /// Numer zezwolenia, np. „R-14/2025 h.r." — najpewniejszy ślad na etykiecie.
  final String? nrZezwolenia;

  /// Środki ze słownika pasujące do odczytu, od najlepszego dopasowania.
  final List<DopuszczonySrodek> dopasowania;

  bool get cokolwiekZnaleziono => nazwa != null || nrZezwolenia != null;

  bool get pewne => dopasowania.length == 1;
}

/// Rozpoznaje etykietę środka ochrony roślin z tekstu ze zdjęcia.
class CzytnikEtykiety {
  const CzytnikEtykiety(this._srodki);

  final SlownikSrodkow _srodki;

  /// Numer zezwolenia MRiRW: „R-14/2025", czasem z dopiskiem „h.r.".
  static final RegExp wzorzecZezwolenia = RegExp(
    r'\bR\s?-\s?(\d{1,4})\s*/\s*(\d{4})\b(\s*h\.?\s?r\.?)?',
    caseSensitive: false,
  );

  /// Nazwa handlowa: słowo z wielkiej litery i oznaczenie postaci
  /// („EC", „WG", „SC") z liczbą, np. „Abydos 750 EC".
  static final RegExp wzorzecNazwy = RegExp(
    r'\b([A-ZĄĆĘŁŃÓŚŹŻ][\wĄĆĘŁŃÓŚŹŻąćęłńóśźż-]{2,})\s+(\d{2,4})\s*'
    r'(EC|SC|WG|WP|SL|EW|OD|SE|CS|FS|ME|ZC|WS)\b',
  );

  /// Czyta tekst i szuka środka w słowniku dopuszczonym dla danej uprawy.
  Future<OdczytEtykiety> rozpoznaj(String tekst, {String? uprawa}) async {
    final zezwolenie = wzorzecZezwolenia.firstMatch(tekst);
    final nazwa = wzorzecNazwy.firstMatch(tekst);

    final nrZezwolenia = zezwolenie == null
        ? null
        : 'R-${zezwolenie.group(1)}/${zezwolenie.group(2)}'
              '${zezwolenie.group(3) == null ? '' : ' h.r.'}';
    final nazwaHandlowa = nazwa == null
        ? null
        : '${nazwa.group(1)} ${nazwa.group(2)} ${nazwa.group(3)}';

    final dopasowania = <DopuszczonySrodek>[];
    if (uprawa != null && nazwaHandlowa != null) {
      // Szukamy po samej nazwie bez postaci — na zdjęciu bywa rozstrzelona.
      dopasowania.addAll(await _srodki.szukaj(uprawa, nazwa!.group(1)!));
    }

    // Numer zezwolenia rozstrzyga, gdy po nazwie wyszło kilka środków.
    if (nrZezwolenia != null && dopasowania.length > 1) {
      final poNumerze = dopasowania
          .where(
            (s) => _porownywalny(s.nrZezwolenia) == _porownywalny(nrZezwolenia),
          )
          .toList(growable: false);
      if (poNumerze.isNotEmpty) {
        dopasowania
          ..clear()
          ..addAll(poNumerze);
      }
    }

    return OdczytEtykiety(
      tekst: tekst,
      nazwa: nazwaHandlowa,
      nrZezwolenia: nrZezwolenia,
      dopasowania: dopasowania,
    );
  }

  static String _porownywalny(String numer) =>
      numer.toLowerCase().replaceAll(RegExp(r'[\s.]'), '');
}
