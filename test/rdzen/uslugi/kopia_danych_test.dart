import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/baza/migracje.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/uslugi/kopia/kopia_danych.dart';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kopia danych do pliku (plan, pkt 8 — zawsze darmowa).
///
/// Rolnik ma odzyskać dokumentację po zgubieniu telefonu. Dlatego kopia
/// musi wrócić w całości, razem z dziennikiem zmian, a wczytanie nie może
/// po cichu zdublować danych, które już są.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  Future<void> wypelnij() async {
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo Łąki Górne',
      'numer_producenta': '012345678',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await baza.insert('dzialka_rolna', {
      'id': 'pole-1',
      'gospodarstwo_id': 'g1',
      'nazwa_wlasna': 'Za stodołą',
      'sezon': 2026,
      'uprawa': 'pszenica zwyczajna ozima',
      'powierzchnia_ar': 250,
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    await RepozytoriumZabiegow(baza).zapisz(
      zabieg: Zabieg(
        id: 'z1',
        gospodarstwoId: 'g1',
        rodzaj: RodzajZabiegu.oprysk,
        data: DateTime(2026, 5, 10),
        godzina: '08:30',
        powierzchniaAr: 250,
        urzadzenie: 'telefon',
      ),
      pola: const [PoleZabiegu(dzialkaRolnaId: 'pole-1', powierzchniaAr: 250)],
      oprysk: const SzczegolyOprysku(
        zabiegId: 'z1',
        srodekNazwa: 'Abydos 750 EC',
        nrZezwolenia: 'R-14/2025 h.r.',
        karencjaDni: 42,
      ),
      teraz: DateTime(2026, 5, 10, 8, 35),
    );
  }

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
  });

  tearDown(() => baza.close());

  /// Ścieżka do świeżej bazy na dysku — jedna na wywołanie.
  String pustaBaza() {
    final katalog = Directory.systemTemp.createTempSync('agro-kopia');
    addTearDown(() => katalog.deleteSync(recursive: true));
    return '${katalog.path}/gospodarstwo.db';
  }

  KopiaDanych usluga(DatabaseExecutor gdzie) =>
      KopiaDanych(baza: gdzie, wersjaSchematu: najnowszaWersja);

  test('kopia mówi, co w niej jest, bez zmieniania bazy', () async {
    await wypelnij();

    final bajty = await usluga(baza).zrob(teraz: DateTime(2026, 10, 16, 9, 5));
    final opis = usluga(baza).przeczytaj(bajty)!;

    expect(opis.gospodarstwa, ['Gospodarstwo Łąki Górne']);
    expect(opis.liczbaZabiegow, 1);
    expect(opis.liczbaPol, 1);
    expect(opis.wersjaSchematu, najnowszaWersja);
    expect(opis.zrobiona, DateTime(2026, 10, 16, 9, 5));
    expect(
      KopiaDanych.nazwaPliku(DateTime(2026, 10, 16, 9, 5)),
      'agro-asystent-kopia-20261016-0905.zip',
    );
  });

  test('kopia wraca w całości do pustej aplikacji', () async {
    await wypelnij();
    final przedKopia = await baza.query('historia_zmian');
    final bajty = await usluga(baza).zrob();

    // Nowy telefon: pusta baza na tym samym schemacie. Osobny plik, bo
    // bazy „w pamięci" o tej samej nazwie to w sqflite jedna i ta sama baza.
    final nowa = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: pustaBaza(),
    );
    addTearDown(nowa.close);

    final wynik = await usluga(nowa).wczytaj(bajty);
    expect(wynik, isA<KopiaWczytana>());

    expect(
      (await nowa.query('gospodarstwo')).single['nazwa'],
      'Gospodarstwo Łąki Górne',
    );
    expect((await nowa.query('dzialka_rolna')).single['id'], 'pole-1');
    expect((await nowa.query('zabieg')).single['id'], 'z1');
    expect(
      (await nowa.query('zabieg_oprysk')).single['srodek_nazwa'],
      'Abydos 750 EC',
    );
    expect((await nowa.query('zabieg_oprysk')).single['karencja_dni'], 42);

    // Dziennik zmian ma być taki jak w kopii — wyzwalacze nie mogą dopisać
    // swoich wierszy przy wczytywaniu.
    final poWczytaniu = await nowa.query('historia_zmian');
    expect(poWczytaniu, hasLength(przedKopia.length));
    expect(
      poWczytaniu.first['czas'],
      przedKopia.first['czas'],
      reason: 'czas zmiany pochodzi z kopii, nie z chwili wczytania',
    );
  });

  test('nie wczytujemy kopii na dane, które już są', () async {
    await wypelnij();
    final bajty = await usluga(baza).zrob();

    final wynik = await usluga(baza).wczytaj(bajty);
    expect(wynik, isA<KopiaOdrzucona>());
    expect((wynik as KopiaOdrzucona).blad, BladKopii.saJuzDane);
    expect(
      (await baza.query('zabieg')).length,
      1,
      reason: 'odmowa nie może niczego zdublować',
    );
  });

  test('obcy plik jest odrzucony, a nie wczytany połowicznie', () async {
    final wynik = await usluga(baza)
        .wczytaj(Uint8List.fromList([1, 2, 3, 4, 5]));
    expect((wynik as KopiaOdrzucona).blad, BladKopii.nieNaszPlik);
    expect(await baza.query('gospodarstwo'), isEmpty);
  });

  test('kopia z nowszego schematu nie jest przerabiana na siłę', () async {
    await wypelnij();
    final bajty = await usluga(baza).zrob();

    final staraAplikacja = KopiaDanych(
      baza: baza,
      wersjaSchematu: najnowszaWersja - 1,
    );
    final pusta = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: pustaBaza(),
    );
    addTearDown(pusta.close);

    final wynik = await KopiaDanych(
      baza: pusta,
      wersjaSchematu: staraAplikacja.wersjaSchematu,
    ).wczytaj(bajty);
    expect((wynik as KopiaOdrzucona).blad, BladKopii.nowszaWersja);
    expect(wynik.szczegoly, contains('${najnowszaWersja - 1}'));
  });
}
