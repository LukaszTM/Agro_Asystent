import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Własna nazwa pola.
///
/// Pola wczytane z wniosku nazywają się „Pole A" — oznaczeniami, których
/// rolnik w rozmowie o gospodarstwie nie używa. Czego pilnują testy:
/// nazwę można zmienić, oznaczenie z wniosku zostaje nietknięte (po nim
/// kontrola odnajdzie pole w dokumentach ARiMR), a poprzednia nazwa idzie
/// do dziennika zmian.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-nazwa');
    addTearDown(() => katalog.deleteSync(recursive: true));
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: '${katalog.path}/gospodarstwo.db',
    );
    addTearDown(baza.close);
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await baza.insert('dzialka_rolna', {
      'id': 'p1',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Pole A',
      'oznaczenie_z_wniosku': 'A',
      'sezon': 2026,
      'uprawa': 'pszenica zwyczajna ozima',
      'kod_eppo': 'TRZAW',
      'powierzchnia_ar': 1200,
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
  });

  test(
    'rolnik nazywa pole po swojemu, a oznaczenie z wniosku zostaje',
    () async {
      final pola = RepozytoriumPol(baza);

      await pola.ustawNazwe(
        poleId: 'p1',
        nazwa: 'Za stodołą',
        urzadzenie: 'telefon',
      );

      final pole = await pola.jedno('p1');
      expect(pole!.nazwa, 'Za stodołą');
      expect(pole.oznaczenieZWniosku, 'A');
    },
  );

  test('poprzednia nazwa zostaje w dzienniku zmian', () async {
    await RepozytoriumPol(baza)
        .ustawNazwe(poleId: 'p1', nazwa: 'Za stodołą', urzadzenie: 'telefon');

    final wpisy = await baza.query(
      'historia_zmian',
      where: 'tabela = ? AND wiersz_id = ?',
      whereArgs: ['dzialka_rolna', 'p1'],
    );

    // Dokumentacja jest dopisywana, nie nadpisywana — kontrola musi
    // zobaczyć, jak pole nazywało się wcześniej.
    expect(wpisy, isNotEmpty);
    expect(
      wpisy.map((w) => w['dane_json'] as String?).join(),
      contains('Pole A'),
    );
  });

  test('pole dodane ręcznie nie ma oznaczenia z wniosku', () async {
    final pola = RepozytoriumPol(baza);
    await pola.dodaj(
      pole: const Pole(
        id: 'p2',
        gospodarstwoId: 'g1',
        nazwa: 'Pod lasem',
        uprawa: 'żyto ozime',
        powierzchniaAr: 300,
      ),
      urzadzenie: 'telefon',
    );

    final pole = await pola.jedno('p2');
    expect(pole!.nazwa, 'Pod lasem');
    expect(pole.oznaczenieZWniosku, isNull);
  });
}
