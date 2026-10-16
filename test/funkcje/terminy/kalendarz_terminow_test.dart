import 'dart:io';

import 'package:agro_asystent/funkcje/terminy/kalendarz_terminow.dart';
import 'package:agro_asystent/funkcje/ustawienia/zwierzeta_w_gospodarstwie.dart';
import 'package:agro_asystent/funkcje/zabiegi/rejestr_zabiegow.dart';
import 'package:agro_asystent/funkcje/zabiegi/repozytorium_zabiegow.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/modele/zabieg.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kalendarz obowiązków (krok 5 etapu 1). Terminy biorą się ze słownika
/// reguł i z karencji po własnych zabiegach — żadnej daty nie ma w kodzie.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;
  late KalendarzTerminow kalendarz;

  // Gospodarstwo powyżej 10 ha — warunkowość i program azotanowy się włączają.
  const duze = ProfilGospodarstwa(powierzchniaUrHa: 24);
  const male = ProfilGospodarstwa(powierzchniaUrHa: 4);

  setUp(() async {
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: inMemoryDatabasePath,
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-05-01T08:00:00',
      'zmieniono': '2026-05-01T08:00:00',
      'urzadzenie': 'telefon',
    });
    kalendarz = KalendarzTerminow(
      reguly: reguly,
      rejestr: RejestrZabiegow(baza),
    );
  });

  tearDown(() => baza.close());

  PozycjaKalendarza znajdz(List<PozycjaKalendarza> pozycje, String id) =>
      pozycje.firstWhere((p) => p.id == id);

  group('terminy z przepisów', () {
    test('data roczna wypada w tym roku, gdy jeszcze nie minęła', () {
      final pozycje = kalendarz.zPrzepisow(
        profil: duze,
        teraz: DateTime(2026, 9, 1),
      );
      final okrywa = znajdz(pozycje, 'gaec6_okrywa_gruntow');
      expect(okrywa.data, DateTime(2026, 10, 15));
      expect(okrywa.dniDo(DateTime(2026, 9, 1)), 44);
      expect(okrywa.zrodlo, ZrodloTerminu.przepis);
    });

    test('data roczna po terminie przechodzi na następny rok', () {
      final pozycje = kalendarz.zPrzepisow(
        profil: duze,
        teraz: DateTime(2026, 10, 16),
      );
      expect(
        znajdz(pozycje, 'gaec6_okrywa_gruntow').data,
        DateTime(2027, 10, 15),
      );
    });

    test('okres trwający dziś jest oznaczony jako pilny', () {
      final dzis = DateTime(2026, 5, 20);
      final zakaz = znajdz(
        kalendarz.zPrzepisow(profil: duze, teraz: dzis),
        'gaec8_zakaz_przycinania_drzew',
      );
      expect(zakaz.okres, isTrue);
      expect(zakaz.data, DateTime(2026, 4, 15));
      expect(zakaz.doKiedy, DateTime(2026, 7, 31));
      expect(zakaz.trwa(dzis), isTrue);
      expect(zakaz.pilnosc(dzis), PilnoscTerminu.dzis);
    });

    test('okres po zakończeniu przechodzi na następny rok', () {
      final zakaz = znajdz(
        kalendarz.zPrzepisow(profil: duze, teraz: DateTime(2026, 8, 1)),
        'gaec8_zakaz_przycinania_drzew',
      );
      expect(zakaz.data, DateTime(2027, 4, 15));
      expect(zakaz.trwa(DateTime(2026, 8, 1)), isFalse);
    });

    test('termin jednorazowy pokazuje się w swoim horyzoncie', () {
      final blisko = kalendarz.zPrzepisow(
        profil: duze,
        teraz: DateTime(2026, 10, 15),
      );
      expect(
        znajdz(blisko, 'ewidencja_sor_tylko_elektronicznie').data,
        DateTime(2027, 1, 1),
      );

      final daleko = kalendarz.zPrzepisow(
        profil: duze,
        teraz: DateTime(2025, 1, 1),
        dni: 30,
      );
      expect(
        daleko.where((p) => p.id == 'ewidencja_sor_tylko_elektronicznie'),
        isEmpty,
      );
    });

    test('małe gospodarstwo nie dostaje terminów warunkowości', () {
      final pozycje = kalendarz.zPrzepisow(
        profil: male,
        teraz: DateTime(2026, 9, 1),
      );
      expect(pozycje.where((p) => p.id.startsWith('gaec')), isEmpty);
      // Ewidencja środków dotyczy każdego — ten termin zostaje.
      expect(
        pozycje.where((p) => p.id == 'ewidencja_sor_tylko_elektronicznie'),
        isNotEmpty,
      );
    });

    test(
      'termin liczony od zdarzenia czeka na zwierzęta, nie jest zgadywany',
      () {
        final pozycje = kalendarz.zPrzepisow(
          profil: const ProfilGospodarstwa(
            powierzchniaUrHa: 24,
            posiadaczZwierzat: true,
          ),
          teraz: DateTime(2026, 9, 1),
        );
        expect(
          pozycje.where((p) => p.id == 'irzplus_urodzenie_cielecia'),
          isEmpty,
        );
      },
    );

    test('obowiązek, którego nie umiemy ocenić, jest oznaczony', () {
      // Ekoschematy zależą od deklaracji, której aplikacja jeszcze nie zna.
      final slownik = SlownikRegul.zJson({
        'wersja': '2026.10.15',
        'obowiazuje_od': '2026-10-15',
        'obowiazki': [
          {
            'id': 'nowy',
            'nazwa': 'Obowiązek z nowszego słownika',
            'podstawa': 'przepis',
            'progi': [
              {'miara': 'czego_nie_znamy', 'operator': '>', 'wartosc': 1},
            ],
          },
        ],
        'terminy': [
          {
            'id': 'nowy_termin',
            'obowiazek': 'nowy',
            'nazwa': 'Termin z nowszego słownika',
            'rodzaj': 'data_roczna',
            'data_roczna': '11-30',
          },
        ],
      });
      final pozycja = KalendarzTerminow(
        reguly: slownik,
        rejestr: RejestrZabiegow(baza),
      ).zPrzepisow(profil: duze, teraz: DateTime(2026, 11, 1)).single;
      expect(pozycja.obowiazekNiepewny, isTrue);
    });
  });

  group('karencje z własnych zabiegów', () {
    Future<void> dodajOprysk({required int karencjaDni}) async {
      await baza.insert('dzialka_rolna', {
        'id': 'p1',
        'gospodarstwo_id': 'g1',
        'nazwa_wlasna': 'Za stodołą',
        'sezon': 2026,
        'uprawa': 'pszenica zwyczajna ozima',
        'powierzchnia_ar': 250,
        'utworzono': '2026-05-01T08:00:00',
        'zmieniono': '2026-05-01T08:00:00',
        'urzadzenie': 'telefon',
      });
      await RepozytoriumZabiegow(baza).zapisz(
        zabieg: Zabieg(
          id: 'z1',
          gospodarstwoId: 'g1',
          rodzaj: RodzajZabiegu.oprysk,
          data: DateTime(2026, 5, 10),
          powierzchniaAr: 250,
          urzadzenie: 'telefon',
        ),
        pola: const [PoleZabiegu(dzialkaRolnaId: 'p1', powierzchniaAr: 250)],
        oprysk: SzczegolyOprysku(
          zabiegId: 'z1',
          srodekNazwa: 'Abydos 750 EC',
          nrZezwolenia: 'R-14/2025 h.r.',
          karencjaDni: karencjaDni,
          karencjaZrodlo: 'etykieta MRiRW',
        ),
        teraz: DateTime(2026, 5, 10),
      );
    }

    test('karencja wchodzi do kalendarza z dniem zbioru', () async {
      await dodajOprysk(karencjaDni: 42);
      final pozycje = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: duze,
        teraz: DateTime(2026, 6, 1),
      );
      final karencja = znajdz(pozycje, 'karencja-z1');
      expect(karencja.data, DateTime(2026, 6, 21));
      expect(karencja.nazwa, contains('Za stodołą'));
      expect(karencja.coZrobic, contains('Nie zbieraj'));
      expect(karencja.uwagi, 'Abydos 750 EC');
    });

    test('po karencji wpis mówi, że plon można zbierać', () async {
      await dodajOprysk(karencjaDni: 7);
      final pozycje = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: duze,
        teraz: DateTime(2026, 5, 20),
      );
      expect(
        znajdz(pozycje, 'karencja-z1').coZrobic,
        contains('można zbierać'),
      );
    });

    test('stare terminy znikają, świeżo minięte zostają', () async {
      await dodajOprysk(karencjaDni: 1);
      final tydzien = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: duze,
        teraz: DateTime(2026, 5, 18),
      );
      expect(tydzien.where((p) => p.id == 'karencja-z1'), isNotEmpty);

      final miesiac = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: duze,
        teraz: DateTime(2026, 7, 1),
      );
      expect(miesiac.where((p) => p.id == 'karencja-z1'), isEmpty);
    });

    test('lista jest uporządkowana po dacie', () async {
      await dodajOprysk(karencjaDni: 42);
      final pozycje = await kalendarz.najblizsze(
        gospodarstwoId: 'g1',
        profil: duze,
        teraz: DateTime(2026, 6, 1),
      );
      for (var i = 1; i < pozycje.length; i++) {
        expect(
          pozycje[i].data.isBefore(pozycje[i - 1].data),
          isFalse,
          reason: '${pozycje[i - 1].nazwa} przed ${pozycje[i].nazwa}',
        );
      }
    });
  });

  group('profil gospodarstwa', () {
    test('powierzchnia liczy się z pól bieżącego sezonu', () async {
      for (final (id, sezon, ar) in [
        ('p1', 2026, 1200),
        ('p2', 2026, 800),
        ('p3', 2025, 5000),
      ]) {
        await baza.insert('dzialka_rolna', {
          'id': id,
          'gospodarstwo_id': 'g1',
          'nazwa_wlasna': 'Pole $id',
          'sezon': sezon,
          'powierzchnia_ar': ar,
          'utworzono': '2026-05-01T08:00:00',
          'zmieniono': '2026-05-01T08:00:00',
          'urzadzenie': 'telefon',
        });
      }

      final profil = await ProfilZBazy(baza).policz('g1', sezon: 2026);
      expect(profil.powierzchniaUrHa, 20);
      expect(
        profil.djp,
        isNull,
        reason:
            'bez rejestru stada i bez odpowiedzi rolnika DJP jest '
            'nieznane — nie zerowe',
      );
    });
  });

  group('zwierzęta poza zakresem aplikacji', () {
    test('bez odpowiedzi rolnika obowiązki od DJP są niepewne', () {
      // Program azotanowy włącza się od 10 ha UR **albo** 10 DJP. Przy
      // zerowej powierzchni i nieznanych DJP nie wolno powiedzieć
      // „nie dotyczy".
      final obowiazek = reguly.obowiazek('program_azotanowy_ewidencja')!;
      expect(
        obowiazek.ocena(const ProfilGospodarstwa(djp: null)),
        Ocena.nieWiadomo,
      );

      final pozycje =
          KalendarzTerminow(
            reguly: reguly,
            rejestr: RejestrZabiegow(baza),
          ).zPrzepisow(
            profil: const ProfilGospodarstwa(djp: null),
            teraz: DateTime(2026, 10, 1),
          );
      final nawozenie = pozycje.where(
        (p) => p.nazwa.contains('Obornik na gruntach ornych'),
      );
      expect(nawozenie, hasLength(1));
      expect(nawozenie.single.obowiazekNiepewny, isTrue);
    });

    test('odpowiedź „nie mam zwierząt" daje pewne zero', () async {
      await ZwierzetaWGospodarstwie(baza).zapisz(OdpowiedzZwierzeta.nie);
      final profil = await ProfilZBazy(
        baza,
        zwierzeta: ZwierzetaWGospodarstwie(baza),
      ).policz('g1');

      expect(profil.djp, 0);
      expect(profil.posiadaczZwierzat, isFalse);
      expect(
        reguly.obowiazek('program_azotanowy_ewidencja')!.ocena(profil),
        Ocena.nieDotyczy,
      );
    });

    test('odpowiedź „mam zwierzęta" zostawia DJP nieznane', () async {
      await ZwierzetaWGospodarstwie(baza).zapisz(OdpowiedzZwierzeta.tak);
      final profil = await ProfilZBazy(
        baza,
        zwierzeta: ZwierzetaWGospodarstwie(baza),
      ).policz('g1');

      expect(
        profil.djp,
        isNull,
        reason: 'aplikacja nie prowadzi rejestru stada, więc nie zna DJP',
      );
      expect(profil.posiadaczZwierzat, isTrue);
      expect(
        reguly.obowiazek('program_azotanowy_ewidencja')!.ocena(profil),
        Ocena.nieWiadomo,
      );
    });
  });
}
