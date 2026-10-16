import 'dart:typed_data';

/// Plik wybrany przez rolnika.
class WybranyPlik {
  const WybranyPlik({required this.nazwa, required this.bajty});

  final String nazwa;
  final Uint8List bajty;
}

/// Skąd bierzemy plik wniosku.
///
/// Wybór pliku jest sprawą urządzenia, więc logika modułów go nie zna —
/// w aplikacji podstawiamy okno systemowe, w testach zwykły plik z dysku.
abstract interface class ZrodloPliku {
  Future<WybranyPlik?> wybierzPdf();

  /// Plik kopii danych aplikacji (ZIP). `null`, gdy rolnik się rozmyślił.
  Future<WybranyPlik?> wybierzKopie();
}
