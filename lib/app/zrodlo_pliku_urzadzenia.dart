import 'package:file_selector/file_selector.dart';

import '../funkcje/dzialki/zrodlo_pliku.dart';

/// Wybór pliku przez okno systemowe (Android i Windows).
///
/// Pakiet `file_selector` jest utrzymywany przez autorów Fluttera,
/// na licencji BSD — wolno go używać także w wersji płatnej.
class ZrodloPlikuUrzadzenia implements ZrodloPliku {
  const ZrodloPlikuUrzadzenia();

  @override
  Future<WybranyPlik?> wybierzPdf() async {
    const rodzaj = XTypeGroup(
      label: 'Wniosek PDF',
      extensions: ['pdf'],
      mimeTypes: ['application/pdf'],
      uniformTypeIdentifiers: ['com.adobe.pdf'],
    );
    final plik = await openFile(acceptedTypeGroups: const [rodzaj]);
    if (plik == null) {
      return null;
    }
    return WybranyPlik(nazwa: plik.name, bajty: await plik.readAsBytes());
  }
}
