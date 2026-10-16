import 'dart:io';

import 'package:agro_asystent/app/platforma.dart';
import 'package:agro_asystent/app/start.dart';
import 'package:flutter_test/flutter_test.dart';

/// Start programu na komputerze (plan, pkt 1: „potem Windows").
///
/// To ta sama droga, którą pójdzie program na Windows: baza z biblioteki
/// dołączonej do programu, słowniki rozpakowane z zasobów, gospodarstwo
/// zakładane przy pierwszym uruchomieniu. Zanim ten test powstał,
/// `uruchom()` brało bazę tylko z `sqflite` — na Windows program nie
/// wstałby wcale.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('aplikacja wstaje na komputerze i zakłada gospodarstwo', () async {
    final katalog = Directory.systemTemp.createTempSync('agro-komputer');
    addTearDown(() => katalog.deleteSync(recursive: true));

    final uslugi = await uruchom(
      platforma: Platforma.komputer,
      katalogDanych: katalog.path,
    );

    // Wpisy z komputera muszą być rozpoznawalne po scaleniu z telefonem.
    expect(uslugi.urzadzenie, 'komputer');
    expect(uslugi.gospodarstwoId, isNotEmpty);
    expect(uslugi.reguly.wersja, isNotEmpty);
    expect(uslugi.reguly.maksymalneDawkiAzotu.pusta, isFalse);

    // Baza i słowniki naprawdę leżą w katalogu danych programu.
    expect(
      Directory(katalog.path).listSync().map((p) => p.path.split('/').last),
      containsAll(['gospodarstwo.sqlite', 'slowniki.sqlite']),
    );
    expect(await uslugi.pola.wszystkie(uslugi.gospodarstwoId), isEmpty);
    expect(await uslugi.gospodarstwa.wszystkie(), hasLength(1));

    // Słownik upraw po rozpakowaniu umie szukać — bez tego wybór uprawy
    // na komputerze byłby pustą listą.
    final wynik = await uslugi.uprawy.doWyboru(szukane: 'pszenica');
    expect(wynik.uprawy, isNotEmpty);
  });

  test('odczyt zdjęcia na komputerze odmawia z wyjaśnieniem', () async {
    final katalog = Directory.systemTemp.createTempSync('agro-komputer2');
    addTearDown(() => katalog.deleteSync(recursive: true));

    final uslugi = await uruchom(
      platforma: Platforma.komputer,
      katalogDanych: katalog.path,
    );

    expect(uslugi.czytnikZdjecia, isA<CzytnikTylkoWTelefonie>());
  });
}
