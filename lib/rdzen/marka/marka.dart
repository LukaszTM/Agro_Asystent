import 'dart:ui' show Color;

/// Identyfikacja wizualna projektu: logo i kolory marki.
///
/// Leży w `rdzen/`, bo korzystają z niej **oba wyglądy aplikacji i wydruki**
/// dokumentów — a `rdzen/` nie może zależeć od warstwy ekranów (CLAUDE.md).
///
/// Kolory marki pochodzą z logo (wyłuskane z pliku, nie dobrane z pamięci).
/// Kolory ekranów są osobne i opisane w `lib/wyglad/*/motyw.dart`: identyfikacja
/// ma znaczyć aplikację, a nie decydować o czytelności w słońcu.
abstract final class Marka {
  /// Nazwa używana wszędzie: w aplikacji, na wydrukach i w sklepie.
  static const String nazwa = 'Agro Asystent';

  /// Pełne logo: znak i nazwa. Używamy go tam, gdzie jest miejsce na nazwę —
  /// pasek ekranu głównego, ekran powitalny, README.
  static const String logo = 'assets/logo/agro_asystent.png';

  /// Sam znak, bez nazwy. Z niego powstają ikony: w kwadracie 48 × 48 px
  /// napis zlewa się w kreskę, więc tam zostaje sama litera „A" z liściem.
  static const String znak = 'assets/logo/agro_asystent_znak.png';

  /// Ciemna zieleń z litery „A" i napisu — główny kolor marki.
  static const Color zielenCiemna = Color(0xFF0A3C20);

  /// Jasna zieleń liścia — akcent.
  static const Color zielenLiscia = Color(0xFF69A31E);

  /// Złoto pola na logo — używane oszczędnie, do wyróżnień.
  static const Color zloto = Color(0xFFC3912E);

  /// Biel karty, na której stoi logo.
  static const Color biel = Color(0xFFFFFFFF);

  /// Warianty wytwarza `tools/zbuduj_ikony.py` z tych dwóch plików —
  /// nie rysujemy ich ręcznie (CLAUDE.md, identyfikacja wizualna).
  static const String skryptWariantow = 'tools/zbuduj_ikony.py';
}
