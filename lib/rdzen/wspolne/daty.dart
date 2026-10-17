/// Daty po polsku — tak, jak czyta je rolnik, i tak samo w obu wyglądach.
///
/// Dni i miesiące terminów stoją w słowniku reguł jako `MM-DD` (np.
/// `10-15`), bo przepis podaje dzień i miesiąc bez roku. Na ekranie ma
/// z tego wyjść „15 października", a nie „10-15".
abstract final class Daty {
  static const List<String> miesiaceWDopelniaczu = [
    'stycznia',
    'lutego',
    'marca',
    'kwietnia',
    'maja',
    'czerwca',
    'lipca',
    'sierpnia',
    'września',
    'października',
    'listopada',
    'grudnia',
  ];

  /// `10-15` → „15 października". Przy niezrozumiałym zapisie zwraca to,
  /// co dostała — lepiej pokazać surową daną niż wymyśloną datę.
  static String dzienIMiesiac(String dataRoczna) {
    final czesci = dataRoczna.split('-');
    if (czesci.length != 2) {
      return dataRoczna;
    }
    final miesiac = int.tryParse(czesci.first);
    final dzien = int.tryParse(czesci.last);
    if (miesiac == null || dzien == null || miesiac < 1 || miesiac > 12) {
      return dataRoczna;
    }
    return '$dzien ${miesiaceWDopelniaczu[miesiac - 1]}';
  }

  /// `DateTime` → „15 października 2026".
  static String zRokiem(DateTime dzien) =>
      '${dzien.day} ${miesiaceWDopelniaczu[dzien.month - 1]} ${dzien.year}';

  /// `DateTime` → „15.10.2026" — zapis na wydruki i do tabel.
  static String krotko(DateTime dzien) =>
      '${_dwie(dzien.day)}.${_dwie(dzien.month)}.${dzien.year}';

  static String _dwie(int liczba) => liczba.toString().padLeft(2, '0');
}
