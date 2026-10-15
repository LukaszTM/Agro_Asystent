/// Co udało się odczytać z worka nawozu.
///
/// Wszystko jest **propozycją do potwierdzenia** — rolnik widzi odczytane
/// wartości i je zatwierdza albo poprawia. Nigdy nie zapisujemy ich po cichu
/// (CLAUDE.md, reguła 5).
class OdczytNawozu {
  const OdczytNawozu({
    this.nazwa,
    this.azotProcent,
    this.fosforProcent,
    this.potasProcent,
    this.naturalny,
    required this.tekst,
  });

  final String? nazwa;
  final double? azotProcent;
  final double? fosforProcent;
  final double? potasProcent;

  /// `null`, gdy ze zdjęcia nie wynika, czy nawóz jest naturalny.
  final bool? naturalny;

  /// Pełny odczytany tekst — do pokazania, gdy rozpoznanie zawiedzie.
  final String tekst;

  bool get cokolwiekZnaleziono =>
      nazwa != null || azotProcent != null || fosforProcent != null;
}

/// Czyta skład nawozu z tekstu odebranego ze zdjęcia opakowania.
///
/// Rozpoznajemy trzy zapisy spotykane na workach: „NPK 20-10-10",
/// „N 34%" oraz „azot całkowity (N) 34". Czego nie rozpoznamy, zostaje puste.
abstract final class CzytnikNawozu {
  static final RegExp _npk = RegExp(
    r'\bN\s*[-–]?\s*P\s*[-–]?\s*K\b[^0-9]{0,20}(\d{1,2}(?:[.,]\d)?)'
    r'\s*[-–/]\s*(\d{1,2}(?:[.,]\d)?)\s*[-–/]\s*(\d{1,2}(?:[.,]\d)?)',
    caseSensitive: false,
  );

  static final RegExp _azotSlownie = RegExp(
    r'azot[^0-9%]{0,40}?(\d{1,2}(?:[.,]\d{1,2})?)\s*%',
    caseSensitive: false,
  );

  static final RegExp _azotSkrot = RegExp(
    r'(?:^|[^A-Za-z])N\s*[:=]?\s*(\d{1,2}(?:[.,]\d{1,2})?)\s*%',
  );

  static final RegExp _fosfor = RegExp(
    r'(?:P2O5|fosfor)[^0-9%]{0,40}?(\d{1,2}(?:[.,]\d{1,2})?)\s*%',
    caseSensitive: false,
  );

  static final RegExp _potas = RegExp(
    r'(?:K2O|potas)[^0-9%]{0,40}?(\d{1,2}(?:[.,]\d{1,2})?)\s*%',
    caseSensitive: false,
  );

  /// Słowa, po których poznajemy nawóz naturalny.
  static const List<String> _naturalne = [
    'obornik',
    'gnojowica',
    'gnojówka',
    'pomiot',
    'kompost',
  ];

  static OdczytNawozu zTekstu(String tekst) {
    final wiersze = tekst
        .split('\n')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList(growable: false);

    double? azot;
    double? fosfor;
    double? potas;

    final npk = _npk.firstMatch(tekst);
    if (npk != null) {
      azot = _liczba(npk.group(1));
      fosfor = _liczba(npk.group(2));
      potas = _liczba(npk.group(3));
    }
    azot ??=
        _liczba(_azotSlownie.firstMatch(tekst)?.group(1)) ??
        _liczba(_azotSkrot.firstMatch(tekst)?.group(1));
    fosfor ??= _liczba(_fosfor.firstMatch(tekst)?.group(1));
    potas ??= _liczba(_potas.firstMatch(tekst)?.group(1));

    final naturalny = _naturalne.any(
      (slowo) => tekst.toLowerCase().contains(slowo),
    );

    return OdczytNawozu(
      nazwa: _nazwa(wiersze),
      azotProcent: azot,
      fosforProcent: fosfor,
      potasProcent: potas,
      naturalny: naturalny ? true : null,
      tekst: tekst,
    );
  }

  /// Nazwą jest pierwszy wiersz, który wygląda na nazwę handlową: ma litery,
  /// nie jest samą liczbą i nie jest zdaniem z instrukcji.
  static String? _nazwa(List<String> wiersze) {
    for (final wiersz in wiersze) {
      final oczyszczony = wiersz.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (oczyszczony.length < 3 || oczyszczony.length > 40) {
        continue;
      }
      if (!RegExp(r'[A-Za-zĄĆĘŁŃÓŚŹŻąćęłńóśźż]{3}').hasMatch(oczyszczony)) {
        continue;
      }
      if (RegExp(
        r'\b(stosowa|przechowywa|uwaga|masa netto|producent|dawka)',
        caseSensitive: false,
      ).hasMatch(oczyszczony)) {
        continue;
      }
      return oczyszczony;
    }
    return null;
  }

  static double? _liczba(String? zapis) =>
      zapis == null ? null : double.tryParse(zapis.replaceAll(',', '.'));
}
