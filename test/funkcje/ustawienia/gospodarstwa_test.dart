import 'package:agro_asystent/funkcje/ustawienia/gospodarstwa.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/dostep/dostep_funkcji.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Konta i kilka gospodarstw (krok 10 etapu 1).
///
/// Zasada z planu (pkt 8): kilka gospodarstw to dodatek premium, ale
/// dokumentacja gospodarstwa, które rolnik prowadzi, jest darmowa zawsze.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;

  late Database baza;

  Future<String> zalozPierwsze(RepozytoriumGospodarstw repozytorium) async {
    final wynik = await repozytorium.dodaj(
      nazwa: 'Gospodarstwo w Dąbrowie',
      urzadzenie: 'telefon',
      numerProducenta: '012345678',
    );
    expect(wynik.wynik, WynikDodania.dodane);
    return wynik.id!;
  }

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
  });

  tearDown(() async => baza.close());

  group('wersja darmowa', () {
    test('pierwsze gospodarstwo zakłada się bez premium', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);

      expect(await repozytorium.czyMoznaDodac(), isTrue);
      final id = await zalozPierwsze(repozytorium);

      final lista = await repozytorium.wszystkie();
      expect(lista.single.id, id);
      expect(lista.single.nazwa, 'Gospodarstwo w Dąbrowie');
      expect(lista.single.numerProducenta, '012345678');
    });

    test('drugie gospodarstwo wymaga premium', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      await zalozPierwsze(repozytorium);

      expect(await repozytorium.czyMoznaDodac(), isFalse);
      final drugie = await repozytorium.dodaj(
        nazwa: 'Gospodarstwo po dziadku',
        urzadzenie: 'telefon',
      );
      expect(drugie.wynik, WynikDodania.potrzebnePremium);
      expect(drugie.id, isNull);
      expect((await repozytorium.wszystkie()).length, 1);
    });

    test(
      'gospodarstwa założone w premium zostają dostępne po jego końcu',
      () async {
        final zPremium = RepozytoriumGospodarstw(
          baza: baza,
          dostep: const DostepFunkcji(maPremium: true),
        );
        await zalozPierwsze(zPremium);
        final drugie = await zPremium.dodaj(
          nazwa: 'Gospodarstwo po dziadku',
          urzadzenie: 'telefon',
        );
        expect(drugie.wynik, WynikDodania.dodane);

        // Premium się skończyło.
        final bezPremium = RepozytoriumGospodarstw(baza: baza);
        final lista = await bezPremium.wszystkie();
        expect(
          lista.length,
          2,
          reason: 'Dokumentacji nie wolno zamknąć za brak płatności.',
        );
        await bezPremium.ustawAktywne(drugie.id!);
        expect((await bezPremium.aktywne())!.id, drugie.id);
        expect(
          await bezPremium.czyMoznaDodac(),
          isFalse,
          reason: 'Blokujemy tylko dodanie kolejnego, nie dostęp do danych.',
        );
      },
    );

    test('poprawa nazwy i numeru producenta jest zawsze możliwa', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      final id = await zalozPierwsze(repozytorium);

      await repozytorium.popraw(
        gospodarstwoId: id,
        nazwa: 'Gospodarstwo Kowalskich',
        numerProducenta: '',
      );

      final poprawione = (await repozytorium.jedno(id))!;
      expect(poprawione.nazwa, 'Gospodarstwo Kowalskich');
      expect(
        poprawione.numerProducenta,
        isNull,
        reason: 'Puste pole znaczy „brak", nie zgadujemy numeru.',
      );
    });

    test('gospodarstwo bez nazwy nie powstaje', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      final wynik = await repozytorium.dodaj(
        nazwa: '   ',
        urzadzenie: 'telefon',
      );
      expect(wynik.wynik, WynikDodania.brakNazwy);
      expect(await repozytorium.wszystkie(), isEmpty);
    });
  });

  group('wybór gospodarstwa', () {
    test('wybór jest pamiętany między uruchomieniami', () async {
      final repozytorium = RepozytoriumGospodarstw(
        baza: baza,
        dostep: const DostepFunkcji(maPremium: true),
      );
      final pierwsze = await zalozPierwsze(repozytorium);
      final drugie = (await repozytorium.dodaj(
        nazwa: 'Gospodarstwo po dziadku',
        urzadzenie: 'telefon',
      )).id!;

      // Nowe gospodarstwo staje się aktywne od razu.
      expect((await repozytorium.aktywne())!.id, drugie);

      await repozytorium.ustawAktywne(pierwsze);
      // Nowy obiekt czyta ten sam zapis w bazie — tak jak po restarcie.
      final poRestarcie = RepozytoriumGospodarstw(baza: baza);
      expect((await poRestarcie.aktywne())!.id, pierwsze);
    });

    test('zniknięty wybór nie zostawia aplikacji bez gospodarstwa', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      final id = await zalozPierwsze(repozytorium);
      await repozytorium.ustawAktywne('gospodarstwo-z-innego-telefonu');

      final aktywne = await repozytorium.aktywne();
      expect(aktywne, isNotNull);
      expect(aktywne!.id, id);
    });

    test('ostatniego gospodarstwa nie da się usunąć', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      final id = await zalozPierwsze(repozytorium);

      expect(await repozytorium.usun(gospodarstwoId: id), isFalse);
      expect((await repozytorium.wszystkie()).length, 1);
    });

    test('usunięcie przełącza na gospodarstwo, które zostało', () async {
      final repozytorium = RepozytoriumGospodarstw(
        baza: baza,
        dostep: const DostepFunkcji(maPremium: true),
      );
      final pierwsze = await zalozPierwsze(repozytorium);
      final drugie = (await repozytorium.dodaj(
        nazwa: 'Gospodarstwo po dziadku',
        urzadzenie: 'telefon',
      )).id!;

      expect(await repozytorium.usun(gospodarstwoId: drugie), isTrue);
      expect((await repozytorium.wszystkie()).single.id, pierwsze);
      expect((await repozytorium.aktywne())!.id, pierwsze);
    });
  });

  group('konto', () {
    test('aplikacja działa bez konta', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      await zalozPierwsze(repozytorium);

      expect(await repozytorium.konto(), isNull);
      expect((await repozytorium.aktywne()), isNotNull);
    });

    test('konto obejmuje wszystkie gospodarstwa z telefonu', () async {
      final repozytorium = RepozytoriumGospodarstw(
        baza: baza,
        dostep: const DostepFunkcji(maPremium: true),
      );
      await zalozPierwsze(repozytorium);
      await repozytorium.dodaj(
        nazwa: 'Gospodarstwo po dziadku',
        urzadzenie: 'telefon',
      );

      final konto = await repozytorium.zapiszKonto(
        nazwa: 'Jan Kowalski',
        urzadzenie: 'telefon',
      );
      expect(konto!.nazwa, 'Jan Kowalski');
      expect((await repozytorium.gospodarstwaKonta(konto.id)).length, 2);
    });

    test(
      'gospodarstwo dodane po założeniu konta też do niego trafia',
      () async {
        final repozytorium = RepozytoriumGospodarstw(
          baza: baza,
          dostep: const DostepFunkcji(maPremium: true),
        );
        await zalozPierwsze(repozytorium);
        final konto = (await repozytorium.zapiszKonto(
          nazwa: 'Jan Kowalski',
          urzadzenie: 'telefon',
        ))!;

        await repozytorium.dodaj(
          nazwa: 'Gospodarstwo po dziadku',
          urzadzenie: 'telefon',
        );
        expect((await repozytorium.gospodarstwaKonta(konto.id)).length, 2);
      },
    );

    test('zmiana nazwy konta nie zakłada drugiego', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      await zalozPierwsze(repozytorium);
      final pierwsze = (await repozytorium.zapiszKonto(
        nazwa: 'Jan Kowalski',
        urzadzenie: 'telefon',
      ))!;
      final poZmianie = (await repozytorium.zapiszKonto(
        nazwa: 'Jan Kowalski i Syn',
        urzadzenie: 'telefon',
      ))!;

      expect(poZmianie.id, pierwsze.id);
      expect(poZmianie.nazwa, 'Jan Kowalski i Syn');
    });

    test('konto bez nazwy nie powstaje', () async {
      final repozytorium = RepozytoriumGospodarstw(baza: baza);
      expect(
        await repozytorium.zapiszKonto(nazwa: '  ', urzadzenie: 'telefon'),
        isNull,
      );
      expect(await repozytorium.konto(), isNull);
    });
  });
}
