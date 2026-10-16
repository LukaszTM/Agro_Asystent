import '../modele/zabieg.dart';

/// Jak opisać karencję wpisu w rejestrze i na wydruku.
abstract final class OpisKarencji {
  static String dlaWpisu(SzczegolyOprysku oprysk) {
    final dni = oprysk.karencjaDni;
    if (dni == null) {
      return 'karencja nieznana';
    }
    if (dni == 0) {
      return 'karencja nie obowiązuje';
    }
    final zrodlo = oprysk.karencjaZrodlo ?? 'źródło nieznane';
    final potwierdzenie = oprysk.karencjaPotwierdzona
        ? 'potwierdzona'
        : 'do potwierdzenia';
    return '$dni dni • $zrodlo • $potwierdzenie';
  }
}
