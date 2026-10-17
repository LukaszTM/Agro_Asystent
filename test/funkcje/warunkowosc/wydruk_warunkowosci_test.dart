import 'dart:convert';
import 'dart:io';

import 'package:agro_asystent/funkcje/dokumenty/eksport_csv.dart';
import 'package:agro_asystent/funkcje/warunkowosc/przeglad.dart';
import 'package:agro_asystent/funkcje/warunkowosc/wydruk_warunkowosci.dart';
import 'package:agro_asystent/funkcje/warunkowosc/zmianowanie.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wydruk warunkowości na kontrolę — etap 2, krok 6.
///
/// Dokument powstaje w tym samym formacie co trzy rejestry, więc PDF, CSV
/// i XLSX składają go bez osobnego kodu. Tu sprawdzamy treść: czy wiersze
/// odpowiadają normom i czy widać, czego aplikacja nie policzyła.
void main() {
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  StanNormy stanNormy(String id, StanWarunku stan) => StanNormy(
    norma: reguly.warunkowosc.norma(id)!,
    stan: stan,
    coWiemy: ['Grunty orne: 24,00 ha.'],
    coZrobic: 'Nic nie trzeba robić.',
  );

  test('dokument ma pięć kolumn i wiersz na każdą normę', () {
    final dokument = WydrukWarunkowosci.zbuduj(
      stany: [
        stanNormy('gaec_7', StanWarunku.spelniony),
        stanNormy('gaec_2', StanWarunku.doSprawdzenia),
      ],
      reguly: reguly,
      gospodarstwo: 'Gospodarstwo próbne',
      rok: 2026,
      sporzadzono: DateTime(2026, 10, 17),
    )!;

    expect(dokument.kolumny, hasLength(5));
    expect(dokument.wiersze, hasLength(2));
    expect(dokument.wiersze.first.wartosci.first, 'GAEC 7');
    expect(dokument.wiersze.first.wartosci[2], 'Spełniona');
    expect(dokument.tytul, contains('Warunkowość'));
    expect(dokument.wersjaRegul, reguly.wersja);
    expect(dokument.okres, 'rok 2026');
  });

  test('norma policzona przez aplikację nie ma braków, nieliczona ma', () {
    final dokument = WydrukWarunkowosci.zbuduj(
      stany: [
        stanNormy('gaec_7', StanWarunku.spelniony),
        stanNormy('gaec_2', StanWarunku.doSprawdzenia),
      ],
      reguly: reguly,
      gospodarstwo: 'Gospodarstwo próbne',
      rok: 2026,
    )!;

    expect(dokument.wiersze.first.kompletny, isTrue);
    expect(dokument.niekompletne, hasLength(1));
    expect(
      dokument.niekompletne.single.braki.single,
      contains('policzony przez aplikację'),
    );
  });

  test('eksport CSV składa się z tych samych wierszy', () {
    final dokument = WydrukWarunkowosci.zbuduj(
      stany: [stanNormy('gaec_6', StanWarunku.niespelniony)],
      reguly: reguly,
      gospodarstwo: 'Gospodarstwo próbne',
      rok: 2026,
    )!;

    final csv = utf8.decode(EksportCsv.bajty(dokument));
    expect(csv, contains('GAEC 6'));
    expect(csv, contains('Niespełniona'));
    expect(dokument.nazwaPliku('csv'), endsWith('_2026.csv'));
  });
}
