import '../../rdzen/reguly/regula_prawna.dart';
import '../../rdzen/wspolne/tekst.dart';

/// Rodzaj użytku rolnego na polu.
///
/// Od tego zależą **wszystkie** progi normy GAEC 7: próg 10 ha liczy się
/// od gruntów ornych, nie od całej powierzchni gospodarstwa, a udziały
/// 40 %, 75 % i 95 % — od gruntów ornych. Dopóki rolnik nie powie, czym
/// jest pole, aplikacja nie liczy: pisze „do sprawdzenia".
enum RodzajUzytku {
  gruntyOrne('grunty_orne', 'Grunty orne', 'grunty orne'),

  // Nazwy dla rolnika są krótkie, bo stają na przyciskach i „pigułkach":
  // «Łąka lub pastwisko (TUZ)» nie mieści się w jednym rzędzie na ekranie
  // 420 px. Pełne nazwy urzędowe idą na wydruk.
  tuz('tuz', 'Łąka lub pastwisko', 'trwały użytek zielony'),
  uprawyTrwale('uprawy_trwale', 'Sad lub uprawa trwała', 'uprawa trwała'),

  /// Rolnik jeszcze nie powiedział. Nie zgadujemy.
  nieznany('', 'Nie wiadomo', 'nieokreślony');

  const RodzajUzytku(this.wBazie, this.dlaRolnika, this.naWydruku);

  final String wBazie;
  final String dlaRolnika;
  final String naWydruku;

  static RodzajUzytku zBazy(String? wartosc) {
    if (wartosc == null || wartosc.isEmpty) {
      return nieznany;
    }
    return RodzajUzytku.values.firstWhere(
      (r) => r.wBazie == wartosc,
      orElse: () => nieznany,
    );
  }

  bool get znany => this != nieznany;

  /// Rodzaje do wyboru na ekranie — bez „nie wiadomo", bo tego się nie
  /// wybiera, to jest stan przed wyborem.
  static List<RodzajUzytku> get doWyboru =>
      RodzajUzytku.values.where((r) => r.znany).toList(growable: false);

  /// Podpowiedź rodzaju użytku po nazwie uprawy.
  ///
  /// Słowa kluczowe są **danymi** ze słownika reguł, nie listą w kodzie:
  /// „łąka" i „sad" to nie progi z przepisu, ale i tak nie chcemy ich
  /// zmieniać przez wydanie nowej aplikacji. Dopasowanie idzie po całych
  /// słowach nazwy znormalizowanej, więc „sadzeniaki" nie wezmą się za sad.
  ///
  /// Wynik jest **propozycją do potwierdzenia**, nigdy zapisem.
  static RodzajUzytku podpowiedz({
    required String uprawa,
    required PodpowiedziRodzajuUzytku podpowiedzi,
  }) {
    final slowa = Tekst.slowaDoSzukania(uprawa).toSet();
    if (slowa.isEmpty) {
      return nieznany;
    }
    for (final rodzaj in podpowiedzi.rodzaje) {
      for (final wzor in rodzaj.slowa) {
        final czesci = Tekst.slowaDoSzukania(wzor);
        if (czesci.isNotEmpty && czesci.every(slowa.contains)) {
          return zBazy(rodzaj.id);
        }
      }
    }
    final domyslny = podpowiedzi.domyslny;
    return domyslny == null ? nieznany : zBazy(domyslny.id);
  }
}
