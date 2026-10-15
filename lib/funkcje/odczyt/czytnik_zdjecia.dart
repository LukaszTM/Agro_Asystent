/// Skąd bierzemy zdjęcie.
enum ZrodloZdjecia { aparat, galeria }

/// Odczyt tekstu ze zdjęcia — granica między logiką a aparatem i biblioteką
/// rozpoznawania pisma.
///
/// Odczyt działa **na urządzeniu i bez internetu**: zdjęcie etykiety albo
/// worka nigdzie nie jest wysyłane (plan, pkt 2).
abstract interface class CzytnikZdjecia {
  /// Zwraca odczytany tekst albo `null`, gdy rolnik zrezygnował z robienia
  /// zdjęcia. Rzuca [BladOdczytuZdjecia], gdy odczyt się nie powiódł.
  Future<String?> tekst(ZrodloZdjecia zrodlo);
}

/// Odczyt się nie udał — pokazujemy rolnikowi jedno zdanie i co zrobić.
class BladOdczytuZdjecia implements Exception {
  const BladOdczytuZdjecia(this.wiadomosc, {this.coZrobic});

  final String wiadomosc;
  final String? coZrobic;

  @override
  String toString() => wiadomosc;
}
