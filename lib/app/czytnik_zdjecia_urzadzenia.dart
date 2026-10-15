import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../funkcje/odczyt/czytnik_zdjecia.dart';

/// Odczyt tekstu ze zdjęcia na urządzeniu.
///
/// Rozpoznawanie pisma działa lokalnie (model w aplikacji), więc zdjęcie
/// etykiety ani worka nigdzie nie wyjeżdża — tak jak cała reszta danych.
class CzytnikZdjeciaUrzadzenia implements CzytnikZdjecia {
  CzytnikZdjeciaUrzadzenia({ImagePicker? aparat, TextRecognizer? rozpoznawanie})
    : _aparat = aparat ?? ImagePicker(),
      _rozpoznawanie =
          rozpoznawanie ?? TextRecognizer(script: TextRecognitionScript.latin);

  final ImagePicker _aparat;
  final TextRecognizer _rozpoznawanie;

  @override
  Future<String?> tekst(ZrodloZdjecia zrodlo) async {
    final XFile? zdjecie;
    try {
      zdjecie = await _aparat.pickImage(
        source: zrodlo == ZrodloZdjecia.aparat
            ? ImageSource.camera
            : ImageSource.gallery,
        // Etykiety bywają drobne; nie zmniejszamy zdjęcia, żeby litery
        // zostały czytelne dla rozpoznawania.
        imageQuality: 100,
      );
    } on Exception {
      throw const BladOdczytuZdjecia(
        'Nie udało się otworzyć aparatu.',
        coZrobic:
            'Sprawdź, czy aplikacja ma zgodę na aparat w ustawieniach '
            'telefonu.',
      );
    }
    if (zdjecie == null) {
      return null;
    }

    try {
      final odczyt = await _rozpoznawanie.processImage(
        InputImage.fromFilePath(zdjecie.path),
      );
      return odczyt.text;
    } on Exception {
      throw const BladOdczytuZdjecia(
        'Nie udało się odczytać tekstu ze zdjęcia.',
        coZrobic: 'Zrób zdjęcie z bliska, w świetle i bez cienia.',
      );
    }
  }

  Future<void> zamknij() => _rozpoznawanie.close();
}
