import 'dart:typed_data';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../funkcje/dokumenty/wyjscie_dokumentu.dart';

/// Wydruk i przekazanie pliku przez okna systemowe (Android i Windows).
///
/// `printing` otwiera okno wydruku systemu — tam jest i drukarka, i „zapisz
/// jako PDF". `share_plus` oddaje plik innym programom: poczcie, dyskowi,
/// menedżerowi plików.
class WyjscieDokumentuUrzadzenia implements WyjscieDokumentu {
  const WyjscieDokumentuUrzadzenia();

  @override
  Future<void> drukujPdf({
    required Uint8List dane,
    required String nazwa,
  }) async {
    await Printing.layoutPdf(onLayout: (_) async => dane, name: nazwa);
  }

  @override
  Future<void> udostepnij({
    required Uint8List dane,
    required String nazwa,
    required String typMime,
  }) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(dane, mimeType: typMime, name: nazwa)],
        // Bez tego plik dostaje nazwę tymczasową i rolnik nie wie, co dostał.
        fileNameOverrides: [nazwa],
      ),
    );
  }
}
