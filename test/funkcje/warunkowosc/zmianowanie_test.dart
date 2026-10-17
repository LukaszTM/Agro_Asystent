import 'dart:io';

import 'package:agro_asystent/funkcje/dzialki/repozytorium_pol.dart';
import 'package:agro_asystent/funkcje/dzialki/rodzaj_uzytku.dart';
import 'package:agro_asystent/funkcje/dzialki/uprawy_pola.dart';
import 'package:agro_asystent/funkcje/warunkowosc/zmianowanie.dart';
import 'package:agro_asystent/rdzen/baza/baza_gospodarstwa.dart';
import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Norma GAEC 7: zmianowanie i dywersyfikacja upraw na gruntach ornych —
/// etap 2, krok 3.
///
/// Wszystkie progi pochodzą ze słownika reguł (tekst jednolity, Dz.U.
/// z 2025 r. poz. 1674): próg 10 ha gruntów ornych, 40 % innej uprawy,
/// 3 lata tej samej uprawy, granica 30 ha i udziały 75 %/95 %.
void main() {
  sqfliteFfiInit();
  final fabryka = databaseFactoryFfi;
  final reguly = SlownikRegul.zTekstuJson(
    File('assets/dane/reguly_prawne.json').readAsStringSync(),
  );

  late Database baza;

  setUp(() async {
    final katalog = Directory.systemTemp.createTempSync('agro-zmianowanie');
    addTearDown(() => katalog.deleteSync(recursive: true));
    baza = await BazaGospodarstwa.otworz(
      fabryka: fabryka,
      sciezka: '${katalog.path}/gospodarstwo.db',
    );
    await baza.insert('gospodarstwo', {
      'id': 'g1',
      'nazwa': 'Gospodarstwo próbne',
      'utworzono': '2026-03-01T08:00:00',
      'zmieniono': '2026-03-01T08:00:00',
      'urzadzenie': 'telefon',
    });
  });

  tearDown(() => baza.close());

  /// Pole z historią upraw: `{rok: nazwa uprawy}`.
  Future<void> pole({
    required String id,
    required double ha,
    required Map<int, String> uprawy,
    RodzajUzytku rodzaj = RodzajUzytku.gruntyOrne,
    int sezon = 2026,
  }) async {
    await RepozytoriumPol(baza).dodaj(
      pole: Pole(
        id: id,
        gospodarstwoId: 'g1',
        nazwa: 'Pole $id',
        uprawa: uprawy[sezon] ?? '',
        powierzchniaAr: (ha * 100).round(),
        sezon: sezon,
        rodzajUzytku: rodzaj,
      ),
      urzadzenie: 'telefon',
    );
    for (final wpis in uprawy.entries) {
      await RepozytoriumUprawPola(baza).zapisz(
        poleId: id,
        sezon: wpis.key,
        uprawa: wpis.value,
        urzadzenie: 'telefon',
      );
    }
  }

  Zmianowanie silnik() => Zmianowanie(
    pola: RepozytoriumPol(baza),
    uprawy: RepozytoriumUprawPola(baza),
    reguly: reguly,
  );

  Future<OcenaZmianowania> ocen({int sezon = 2026}) =>
      silnik().ocen(gospodarstwoId: 'g1', sezon: sezon);

  group('kogo norma dotyczy', () {
    test('do 10 ha gruntów ornych norma nie dotyczy', () async {
      await pole(
        id: 'p1',
        ha: 9.5,
        uprawy: {2026: 'pszenica ozima', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.stan, StanWarunku.nieDotyczy);
      expect(ocena.stanZmianowania, StanWarunku.nieDotyczy);
      expect(ocena.powierzchniaGruntowOrnychHa, closeTo(9.5, 0.001));
      expect(ocena.uwagi.first, contains('powyżej 10,00 ha'));
    });

    test('łąka i sad nie powiększają gruntów ornych', () async {
      await pole(id: 'orne', ha: 6, uprawy: {2026: 'pszenica ozima'});
      await pole(
        id: 'laka',
        ha: 20,
        uprawy: {2026: 'łąka trwała'},
        rodzaj: RodzajUzytku.tuz,
      );
      await pole(
        id: 'sad',
        ha: 10,
        uprawy: {2026: 'sad jabłoniowy'},
        rodzaj: RodzajUzytku.uprawyTrwale,
      );

      final ocena = await ocen();
      expect(ocena.powierzchniaGruntowOrnychHa, closeTo(6, 0.001));
      expect(ocena.powierzchniaUrHa, closeTo(36, 0.001));
      expect(ocena.stan, StanWarunku.nieDotyczy);
    });

    test('pole bez rodzaju użytku nie pozwala orzec, że jest dobrze', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'rzepak ozimy', 2025: 'pszenica ozima'},
      );
      await pole(
        id: 'p2',
        ha: 5,
        uprawy: {2026: 'jęczmień jary'},
        rodzaj: RodzajUzytku.nieznany,
      );

      final ocena = await ocen();
      expect(ocena.polaBezRodzajuUzytku.map((p) => p.id), ['p2']);
      expect(ocena.stan, StanWarunku.doSprawdzenia);
    });

    test('zwolnienie z kontroli do 30 ha jest widoczne', () async {
      await pole(
        id: 'p1',
        ha: 25,
        uprawy: {2026: 'pszenica ozima', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.zwolnioneZKontroli, isTrue);
      expect(ocena.zwolnienia.map((z) => z.id), contains('gaec7_do_30ha'));
      // Zwolnienie dotyczy kontroli i kar, nie samego liczenia.
      expect(ocena.stanZmianowania, isNot(StanWarunku.nieDotyczy));
    });
  });

  group('warunek 40 % innej uprawy', () {
    test('cała powierzchnia ze zmianą: warunek spełniony', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'rzepak ozimy', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.udzialInnejUprawy, closeTo(100, 0.001));
      expect(ocena.wymaganyUdzial, 40);
      expect(ocena.stanZmianowania, StanWarunku.spelniony);
      expect(ocena.dywersyfikacja, isNull, reason: 'nie trzeba jej liczyć');
    });

    test('39 % to za mało, 40 % wystarcza', () async {
      // 7,8 ha z 20 ha = 39 %.
      await pole(
        id: 'zmiana',
        ha: 7.8,
        uprawy: {2026: 'rzepak ozimy', 2025: 'pszenica ozima'},
      );
      await pole(
        id: 'bezZmiany',
        ha: 12.2,
        uprawy: {2026: 'pszenica ozima', 2025: 'pszenica ozima'},
      );

      var ocena = await ocen();
      expect(ocena.udzialInnejUprawy, closeTo(39, 0.001));
      expect(ocena.stanZmianowania, StanWarunku.niespelniony);

      // Po przesunięciu 0,2 ha udział wychodzi dokładnie 40 %.
      await RepozytoriumPol(baza).dodaj(
        pole: Pole(
          id: 'zmiana',
          gospodarstwoId: 'g1',
          nazwa: 'Pole zmiana',
          uprawa: 'rzepak ozimy',
          powierzchniaAr: 800,
          sezon: 2026,
          rodzajUzytku: RodzajUzytku.gruntyOrne,
        ),
        urzadzenie: 'telefon',
      );
      await RepozytoriumPol(baza).dodaj(
        pole: Pole(
          id: 'bezZmiany',
          gospodarstwoId: 'g1',
          nazwa: 'Pole bezZmiany',
          uprawa: 'pszenica ozima',
          powierzchniaAr: 1200,
          sezon: 2026,
          rodzajUzytku: RodzajUzytku.gruntyOrne,
        ),
        urzadzenie: 'telefon',
      );
      ocena = await ocen();
      expect(ocena.udzialInnejUprawy, closeTo(40, 0.001));
      expect(ocena.stanZmianowania, StanWarunku.spelniony);
    });

    test('ozimina i jarzyna tego samego rodzaju to różne uprawy', () async {
      // § 5 ust. 5 pkt 2: forma jara i ozima tego samego rodzaju roślin.
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'pszenica jara', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.udzialInnejUprawy, closeTo(100, 0.001));
      expect(ocena.stanZmianowania, StanWarunku.spelniony);
    });

    test('ta sama uprawa innymi słowami to nadal ta sama uprawa', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'pszenica zwyczajna ozima', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.udzialInnejUprawy, 0);
      expect(ocena.stanZmianowania, StanWarunku.niespelniony);
    });

    test('w kapustowatych liczy się gatunek', () async {
      // § 5 ust. 5 pkt 3: gatunek z rodzin kapustowatych, psiankowatych
      // i dyniowatych.
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'kapusta pekińska', 2025: 'kapusta biała'},
      );

      final ocena = await ocen();
      expect(ocena.udzialInnejUprawy, closeTo(100, 0.001));
    });

    test(
      'brak uprawy z roku wcześniej to „do sprawdzenia", nie „dobrze"',
      () async {
        await pole(id: 'p1', ha: 20, uprawy: {2026: 'pszenica ozima'});

        final ocena = await ocen();
        expect(ocena.polaDoSprawdzenia.map((p) => p.pole.id), ['p1']);
        expect(ocena.stanZmianowania, StanWarunku.doSprawdzenia);
        expect(ocena.stan, StanWarunku.doSprawdzenia);
      },
    );
  });

  group('warunek trzech lat', () {
    test('czwarty rok tej samej uprawy to złamanie normy', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {
          2026: 'pszenica ozima',
          2025: 'pszenica ozima',
          2024: 'pszenica ozima',
          2023: 'pszenica ozima',
        },
      );

      final ocena = await ocen();
      expect(ocena.pola.single.lataTejSamejUprawy, 4);
      expect(ocena.stanTrzechLat, StanWarunku.niespelniony);
      expect(ocena.polaPonadTrzyLata.map((p) => p.pole.id), ['p1']);
      expect(ocena.stan, StanWarunku.niespelniony);
    });

    test('trzy lata z rzędu są jeszcze dozwolone', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {
          2026: 'pszenica ozima',
          2025: 'pszenica ozima',
          2024: 'pszenica ozima',
          2023: 'rzepak ozimy',
        },
      );

      final ocena = await ocen();
      expect(ocena.pola.single.lataTejSamejUprawy, 3);
      expect(ocena.stanTrzechLat, StanWarunku.spelniony);
    });

    test('lat przed 2023 r. nie liczymy', () async {
      // Przepis: „bierze się pod uwagę uprawę prowadzoną nie wcześniej
      // niż w 2023 r.".
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {
          2026: 'pszenica ozima',
          2025: 'pszenica ozima',
          2024: 'pszenica ozima',
          2023: 'pszenica ozima',
          2022: 'pszenica ozima',
        },
      );

      final ocena = await ocen();
      expect(ocena.pola.single.lataTejSamejUprawy, 4);
    });

    test('dziura w historii daje „do sprawdzenia"', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'pszenica ozima', 2025: 'rzepak ozimy'},
      );

      final ocena = await ocen();
      expect(ocena.stanTrzechLat, StanWarunku.doSprawdzenia);
      expect(ocena.uwagi.first, contains('brakuje uprawy z lat 2023–2025'));
    });
  });

  group('dywersyfikacja, gdy zmianowanie nie wyszło', () {
    test('do 30 ha: dwie uprawy i największa nie więcej niż 75 %', () async {
      // 20 ha: pszenica 14 ha (70 %), rzepak 6 ha (30 %).
      await pole(
        id: 'p1',
        ha: 14,
        uprawy: {
          2026: 'pszenica ozima',
          2025: 'pszenica ozima',
          2024: 'rzepak ozimy',
          2023: 'pszenica ozima',
        },
      );
      await pole(
        id: 'p2',
        ha: 6,
        uprawy: {
          2026: 'rzepak ozimy',
          2025: 'rzepak ozimy',
          2024: 'pszenica ozima',
          2023: 'rzepak ozimy',
        },
      );

      final ocena = await ocen();
      expect(ocena.stanZmianowania, StanWarunku.niespelniony);
      final dyw = ocena.dywersyfikacja!;
      expect(dyw.liczbaUpraw, 2);
      expect(dyw.wymaganaLiczbaUpraw, 2);
      expect(dyw.udzialNajwiekszej, closeTo(70, 0.001));
      expect(dyw.granicaNajwiekszej, 75);
      expect(dyw.udzialDwochNajwiekszych, isNull);
      expect(dyw.stan, StanWarunku.spelniony);
      expect(ocena.stan, StanWarunku.spelniony);
    });

    test('jedna uprawa na całości: dywersyfikacja niespełniona', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {
          2026: 'pszenica ozima',
          2025: 'pszenica ozima',
          2024: 'rzepak ozimy',
          2023: 'pszenica ozima',
        },
      );

      final ocena = await ocen();
      final dyw = ocena.dywersyfikacja!;
      expect(dyw.liczbaUpraw, 1);
      expect(dyw.udzialNajwiekszej, closeTo(100, 0.001));
      expect(dyw.stan, StanWarunku.niespelniony);
      expect(ocena.stan, StanWarunku.niespelniony);
    });

    test(
      'powyżej 30 ha trzeba trzech upraw i granicy 95 % dla dwóch',
      () async {
        // 40 ha: pszenica 20 (50 %), rzepak 18 (45 %), owies 2 (5 %).
        await pole(
          id: 'p1',
          ha: 20,
          uprawy: {
            2026: 'pszenica ozima',
            2025: 'pszenica ozima',
            2024: 'rzepak ozimy',
            2023: 'pszenica ozima',
          },
        );
        await pole(
          id: 'p2',
          ha: 18,
          uprawy: {
            2026: 'rzepak ozimy',
            2025: 'rzepak ozimy',
            2024: 'pszenica ozima',
            2023: 'rzepak ozimy',
          },
        );
        await pole(
          id: 'p3',
          ha: 2,
          uprawy: {
            2026: 'owies',
            2025: 'owies',
            2024: 'owies',
            2023: 'rzepak ozimy',
          },
        );

        final ocena = await ocen();
        final dyw = ocena.dywersyfikacja!;
        expect(dyw.wymaganaLiczbaUpraw, 3);
        expect(dyw.liczbaUpraw, 3);
        expect(dyw.udzialNajwiekszej, closeTo(50, 0.001));
        expect(dyw.udzialDwochNajwiekszych, closeTo(95, 0.001));
        expect(dyw.granicaDwochNajwiekszych, 95);
        expect(dyw.stan, StanWarunku.spelniony);
      },
    );

    test('dwie uprawy powyżej 30 ha nie wystarczą', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {
          2026: 'pszenica ozima',
          2025: 'pszenica ozima',
          2024: 'rzepak ozimy',
          2023: 'pszenica ozima',
        },
      );
      await pole(
        id: 'p2',
        ha: 15,
        uprawy: {
          2026: 'rzepak ozimy',
          2025: 'rzepak ozimy',
          2024: 'pszenica ozima',
          2023: 'rzepak ozimy',
        },
      );

      final ocena = await ocen();
      final dyw = ocena.dywersyfikacja!;
      expect(dyw.liczbaUpraw, 2);
      expect(dyw.wymaganaLiczbaUpraw, 3);
      expect(dyw.stan, StanWarunku.niespelniony);
    });
  });

  group('wyłączenia z paragrafu 5 ustęp 3', () {
    test('bobowate nie wchodzą do zmianowania', () async {
      await pole(
        id: 'bobowate',
        ha: 8,
        uprawy: {
          2026: 'łubin żółty',
          2025: 'łubin żółty',
          2024: 'łubin żółty',
          2023: 'łubin żółty',
        },
      );
      await pole(
        id: 'zboze',
        ha: 12,
        uprawy: {
          2026: 'rzepak ozimy',
          2025: 'pszenica ozima',
          2024: 'rzepak ozimy',
          2023: 'pszenica ozima',
        },
      );

      final ocena = await ocen();
      final bobowate = ocena.pola.firstWhere((p) => p.pole.id == 'bobowate');
      expect(bobowate.wylaczone, isTrue);
      expect(bobowate.wylaczenie!.id, 'bobowate');
      // Cztery lata łubinu nie łamią normy, bo warunku się nie stosuje.
      expect(ocena.polaPonadTrzyLata, isEmpty);
      expect(ocena.stanTrzechLat, StanWarunku.spelniony);
      // Licznik 40 % liczy się od wszystkich gruntów ornych: 12 z 20 ha.
      expect(ocena.udzialInnejUprawy, closeTo(60, 0.001));
    });

    test('ugór jest wyłączony', () async {
      await pole(id: 'p1', ha: 12, uprawy: {2026: 'grunt ugorowany'});
      await pole(
        id: 'p2',
        ha: 10,
        uprawy: {2026: 'rzepak ozimy', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      final ugor = ocena.pola.firstWhere((p) => p.pole.id == 'p1');
      expect(ugor.wylaczone, isTrue);
      expect(ugor.wylaczenie!.id, 'grunty_ugorowane');
      // Brak uprawy z 2025 r. na ugorze nie psuje rachunku.
      expect(ocena.polaDoSprawdzenia, isEmpty);
    });

    test('powyżej 75 % traw i ugorów warunków się nie stosuje', () async {
      await pole(
        id: 'trawy',
        ha: 16,
        uprawy: {2026: 'trawy w uprawie polowej'},
      );
      await pole(
        id: 'zboze',
        ha: 4,
        uprawy: {2026: 'pszenica ozima', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.stan, StanWarunku.nieDotyczy);
      expect(ocena.uwagi.first, contains('Ponad 75 %'));
    });
  });

  group('jak aplikacja mówi o swoim rachunku', () {
    test('mówi wprost, że porównuje po rodzaju, formie i gatunku', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'rzepak ozimy', 2025: 'pszenica ozima'},
      );

      final ocena = await ocen();
      expect(ocena.uwagi.any((u) => u.contains('po rodzaju i formie')), isTrue);
      expect(ocena.uwagi.any((u) => u.contains('u doradcy')), isTrue);
    });

    test('rozkład nazwy uprawy jest widoczny w wyniku', () async {
      await pole(
        id: 'p1',
        ha: 20,
        uprawy: {2026: 'pszenica zwyczajna ozima', 2025: 'rzepak ozimy'},
      );

      final ocena = await ocen();
      final uprawa = ocena.pola.single.wSezonie!;
      expect(uprawa.rodzaj, 'pszenica');
      expect(uprawa.forma, 'ozima');
      expect(uprawa.rodzina, isNull);
      expect(uprawa.klucz, 'pszenica ozima');

      final rzepak = ocena.pola.single.rokWczesniej!;
      // Rzepak jest kapustowaty, więc liczy się po gatunku — cała nazwa.
      expect(rzepak.rodzina, 'kapustowate');
      expect(rzepak.klucz, 'rzepak ozimy');
    });
  });
}
