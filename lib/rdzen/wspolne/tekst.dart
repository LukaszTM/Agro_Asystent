/// Porównywanie nazw zapisanych na różne sposoby.
///
/// Rolnik szuka tak, jak mu wygodnie: „lubin" bez ogonka, „ZYTO" wielkimi
/// literami, „psz ozim" na skróty. Słownik w aplikacji trzyma przy każdej
/// nazwie jej postać znormalizowaną (kolumna `szukanie`, liczy ją
/// `tools/zbuduj_slowniki.py`), a ta funkcja sprowadza do tej samej postaci
/// to, co rolnik wpisał.
///
/// Postać znormalizowana **nie służy do wyświetlania** — na ekranie i na
/// wydruku zawsze stoi zapis urzędowy.
abstract final class Tekst {
  /// Polskie znaki na odpowiedniki bez ogonków. Dart nie ma w rdzeniu
  /// rozkładu Unicode (NFKD), a nazwy upraw są polskie, więc wystarczy
  /// tablica — ta sama, którą stosuje skrypt budujący słownik.
  static const Map<String, String> _ogonki = {
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

  /// Małe litery, bez ogonków, bez podwójnych spacji.
  static String znormalizuj(String nazwa) {
    final male = nazwa.toLowerCase();
    final bezOgonkow = StringBuffer();
    for (final znak in male.split('')) {
      bezOgonkow.write(_ogonki[znak] ?? znak);
    }
    return bezOgonkow.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Słowa, których szuka rolnik — każde musi wystąpić w nazwie.
  ///
  /// Dzięki temu „psz ozim" znajduje „pszenica ozima", a kolejność słów
  /// nie ma znaczenia.
  static List<String> slowaDoSzukania(String szukane) =>
      znormalizuj(szukane)
          .split(' ')
          .where((slowo) => slowo.isNotEmpty)
          .toList(growable: false);
}
