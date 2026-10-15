import 'dart:typed_data';

/// Co aplikacja robi z gotowym dokumentem: drukuje albo oddaje rolnikowi
/// jako plik (wysyłka, zapis na dysku, przeniesienie na komputer).
///
/// Sposób zależy od urządzenia, więc logika modułów go nie zna — w aplikacji
/// podstawiamy okno systemowe, w testach zapis do pamięci.
abstract interface class WyjscieDokumentu {
  /// Otwiera okno wydruku systemu (druk na papier albo zapis do PDF).
  Future<void> drukujPdf({required Uint8List dane, required String nazwa});

  /// Oddaje plik rolnikowi: wysyłka, zapis na dysku, przeniesienie.
  Future<void> udostepnij({
    required Uint8List dane,
    required String nazwa,
    required String typMime,
  });
}
