import 'package:agro_asystent/funkcje/dzialki/klient_uldk.dart';
import 'package:agro_asystent/funkcje/dzialki/repozytorium_dzialek.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Granice muszą zostać na urządzeniu razem ze źródłem i datą pobrania —
/// inaczej mapa po powrocie z pola byłaby pusta, a rolnik nie wiedziałby,
/// skąd wzięły się dane.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;
  late RepozytoriumDzialek repozytorium;

  const dzialkaZUldk = DzialkaZUldk(
    identyfikator: '061506_2.0007.138',
    wkt:
        'POLYGON((19.100 52.100,19.102 52.100,19.102 52.102,'
        '19.100 52.102,19.100 52.100))',
    srid: 4326,
    wojewodztwo: 'lubelskie',
    powiat: 'lubartowski',
    gmina: 'Lubartów',
    obreb: 'Brzeziny',
    nrDzialki: '138',
  );

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-10-15T08:00:00',
      'zmieniono': '2026-10-15T08:00:00',
      'urzadzenie': 'telefon',
    });
    repozytorium = RepozytoriumDzialek(baza);
  });

  tearDown(() => baza.close());

  test('zapisuje granice, układ, źródło i datę pobrania', () async {
    await repozytorium.zapisz(
      gospodarstwoId: 'g1',
      zUldk: dzialkaZUldk,
      urzadzenie: 'telefon',
      teraz: DateTime(2026, 10, 15, 9, 30),
    );

    final wiersze = await baza.query('dzialka_ewidencyjna');
    expect(wiersze, hasLength(1));
    expect(wiersze.first['geometria_wkt'], startsWith('POLYGON'));
    expect(wiersze.first['srid'], 4326);
    expect(wiersze.first['zrodlo_geometrii'], 'ULDK (GUGiK)');
    expect(wiersze.first['pobrano'], '2026-10-15T09:30:00.000');
    expect(wiersze.first['obreb'], 'Brzeziny');
  });

  test('zapisana działka wraca z granicami gotowymi do narysowania', () async {
    await repozytorium.zapisz(
      gospodarstwoId: 'g1',
      zUldk: dzialkaZUldk,
      urzadzenie: 'telefon',
    );

    final dzialki = await repozytorium.wszystkie('g1');
    expect(dzialki, hasLength(1));
    expect(dzialki.first.maGranice, isTrue);
    expect(dzialki.first.obrysy.first, hasLength(5));
    expect(dzialki.first.polozenie, 'Brzeziny, Lubartów');
    expect(dzialki.first.powierzchniaOpis, endsWith(' ha'));
    expect(dzialki.first.powierzchniaOpis, contains(','));
  });

  test('czyJuzJest poznaje działkę dodaną wcześniej', () async {
    expect(await repozytorium.czyJuzJest('g1', '061506_2.0007.138'), isFalse);
    await repozytorium.zapisz(
      gospodarstwoId: 'g1',
      zUldk: dzialkaZUldk,
      urzadzenie: 'telefon',
    );
    expect(await repozytorium.czyJuzJest('g1', '061506_2.0007.138'), isTrue);
  });

  test('ponowny zapis tej samej działki nie tworzy drugiego wiersza', () async {
    await repozytorium.zapisz(
      gospodarstwoId: 'g1',
      zUldk: dzialkaZUldk,
      urzadzenie: 'telefon',
    );
    await repozytorium.zapisz(
      gospodarstwoId: 'g1',
      zUldk: dzialkaZUldk,
      urzadzenie: 'telefon',
    );
    expect(await repozytorium.wszystkie('g1'), hasLength(1));
  });

  test('działka bez granic nie udaje, że je ma', () async {
    await baza.insert('dzialka_ewidencyjna', {
      'id': 'dz-bez',
      'gospodarstwo_id': 'g1',
      'identyfikator': '061506_2.0007.200',
      'utworzono': '2026-10-15T08:00:00',
      'zmieniono': '2026-10-15T08:00:00',
      'urzadzenie': 'telefon',
    });
    final dzialki = await repozytorium.wszystkie('g1');
    expect(dzialki.single.maGranice, isFalse);
    expect(dzialki.single.obrysy, isEmpty);
    expect(dzialki.single.powierzchniaOpis, 'powierzchnia nieznana');
  });
}
