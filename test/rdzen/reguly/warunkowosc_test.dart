import 'dart:io';

import 'package:agro_asystent/rdzen/reguly/regula_prawna.dart';
import 'package:flutter_test/flutter_test.dart';

/// Normy GAEC (warunkowość) — etap 2, krok 1.
///
/// Wartości sprawdzamy wobec tekstu jednolitego rozporządzenia o normach
/// (Dz.U. z 2025 r. poz. 1674). Akt z 2023 r. jest w czterech miejscach
/// nieaktualny, więc testy pilnują brzmienia **obowiązującego**: okrywa do
/// 15 października (a nie 1.11–15.02), dywersyfikacja 75 %/95 % (a nie
/// 65 %/90 %), granica 30 ha i plantacje nasienne kukurydzy.
void main() {
  late Warunkowosc warunkowosc;

  setUpAll(() {
    final slownik = SlownikRegul.zTekstuJson(
      File('assets/dane/reguly_prawne.json').readAsStringSync(),
    );
    warunkowosc = slownik.warunkowosc;
  });

  group('dane norm', () {
    test('wszystkie dziewięć norm jest w słowniku, z podstawą', () {
      expect(warunkowosc.pusta, isFalse);
      expect(warunkowosc.normy, hasLength(9));
      expect(warunkowosc.normy.map((n) => n.numer), [
        'GAEC 1',
        'GAEC 2',
        'GAEC 3',
        'GAEC 4',
        'GAEC 5',
        'GAEC 6',
        'GAEC 7',
        'GAEC 8',
        'GAEC 9',
      ]);
      expect(warunkowosc.zrodlo, contains('poz. 1674'));
      expect(warunkowosc.zrodlo, contains('tekst jednolity'));
    });

    test('każda norma mówi, czy aplikacja ją policzy — albo dlaczego nie', () {
      for (final norma in warunkowosc.normy) {
        expect(norma.opis, isNotEmpty, reason: norma.numer);
        if (norma.aplikacjaLiczy) {
          expect(
            norma.coRolnikPodaje,
            isNotEmpty,
            reason: '${norma.numer}: nie wiadomo, czego trzeba od rolnika',
          );
        } else {
          expect(
            norma.dlaczegoNieLiczy,
            isNotEmpty,
            reason: '${norma.numer}: milczenie zamiast wyjaśnienia',
          );
        }
      }
    });

    test('aplikacja liczy cztery normy, dla których ma dane', () {
      expect(warunkowosc.liczone.map((n) => n.id), [
        'gaec_4',
        'gaec_6',
        'gaec_7',
        'gaec_8',
      ]);
    });
  });

  group('GAEC 7 — zmianowanie i dywersyfikacja', () {
    test('progi są z brzmienia obowiązującego, nie z aktu z 2023 r.', () {
      final gaec7 = warunkowosc.norma('gaec_7')!;
      expect(gaec7.paragraf, '§ 5');
      expect(gaec7.prog('od_ha_gruntow_ornych')!.calkowita, 10);
      expect(gaec7.prog('zmiana_uprawy_procent')!.calkowita, 40);
      expect(gaec7.prog('dywersyfikacja_granica_ha')!.calkowita, 30);
      expect(gaec7.prog('dywersyfikacja_do_30ha_upraw')!.calkowita, 2);
      expect(gaec7.prog('dywersyfikacja_powyzej_30ha_upraw')!.calkowita, 3);
      // Nowelizacja z 26.06.2024 podniosła 65 % → 75 % i 90 % → 95 %.
      expect(gaec7.prog('najwieksza_uprawa_procent')!.calkowita, 75);
      expect(gaec7.prog('dwie_najwieksze_uprawy_procent')!.calkowita, 95);
    });

    test('reguła trzech lat liczy się od 2023 r.', () {
      final lata = warunkowosc.norma('gaec_7')!.prog('ta_sama_uprawa_lata')!;
      expect(lata.calkowita, 3);
      expect(lata.liczOdRoku, 2023);
    });

    test('wyłączenia upraw obejmują plantacje nasienne kukurydzy', () {
      // Dodane nowelizacją z 26.06.2024, obowiązuje od 1.01.2025.
      final gaec7 = warunkowosc.norma('gaec_7')!;
      expect(gaec7.wylaczeniaUpraw, contains('plantacje nasienne kukurydzy'));
      expect(gaec7.wylaczeniaUpraw, contains('rośliny bobowate'));
      expect(gaec7.wylaczeniaUpraw, contains('uprawy wieloletnie'));
      expect(gaec7.uznanieZaUprawe, isNotEmpty);
    });

    test('spełnienie zastępcze wskazuje rejestr zabiegów agrotechnicznych', () {
      // To ten sam rejestr, który aplikacja już drukuje.
      expect(
        warunkowosc.norma('gaec_7')!.spelnienieZastepcze,
        contains('rejestr zabiegów agrotechnicznych'),
      );
    });
  });

  group('GAEC 6 — okrywa ochronna gleby', () {
    test('termin na gruntach ornych biegnie od zbioru do 15 października', () {
      final gaec6 = warunkowosc.norma('gaec_6')!;
      final naGruntach = gaec6.termin('okrywa_grunty_orne')!;
      expect(naGruntach.odZdarzenia, isTrue);
      expect(naGruntach.od, 'zbior');
      expect(naGruntach.doDnia, '10-15');
      expect(gaec6.prog('udzial_gruntow_ornych_procent')!.calkowita, 80);
      expect(gaec6.prog('przerwa_tygodnie')!.calkowita, 4);
    });

    test('w sadach termin przechodzi przez koniec roku', () {
      final sady = warunkowosc.norma('gaec_6')!.termin('okrywa_sady')!;
      expect(sady.obejmuje(DateTime(2026, 12, 20)), isTrue);
      expect(sady.obejmuje(DateTime(2026, 1, 20)), isTrue);
      expect(sady.obejmuje(DateTime(2026, 2, 15)), isTrue);
      expect(sady.obejmuje(DateTime(2026, 3, 1)), isFalse);
      expect(sady.obejmuje(DateTime(2026, 10, 20)), isFalse);
    });

    test('termin liczony od zdarzenia nie udaje daty z kalendarza', () {
      final naGruntach = warunkowosc
          .norma('gaec_6')!
          .termin('okrywa_grunty_orne')!;
      expect(naGruntach.obejmuje(DateTime(2026, 9, 1)), isFalse);
    });
  });

  group('GAEC 8 — okres lęgowy', () {
    test('zakaz przycinania obejmuje 15 kwietnia – 31 lipca', () {
      final zakaz = warunkowosc.norma('gaec_8')!.termin('zakaz_przycinania')!;
      expect(zakaz.obejmuje(DateTime(2026, 4, 14)), isFalse);
      expect(zakaz.obejmuje(DateTime(2026, 4, 15)), isTrue);
      expect(zakaz.obejmuje(DateTime(2026, 6, 1)), isTrue);
      expect(zakaz.obejmuje(DateTime(2026, 7, 31)), isTrue);
      expect(zakaz.obejmuje(DateTime(2026, 8, 1)), isFalse);
    });

    test('wierzby i drzewa owocowe są wyłączone z zakazu', () {
      expect(
        warunkowosc.norma('gaec_8')!.wylaczeniaUpraw,
        containsAll(['wierzby', 'drzewa owocowe']),
      );
    });
  });

  group('zwolnienia z kontroli', () {
    test('gospodarstwo do 10 ha jest zwolnione ze wszystkich norm', () {
      final zwolnienia = warunkowosc.zwolnieniaDla(
        idNormy: 'gaec_6',
        powierzchniaUrHa: 8,
      );
      expect(zwolnienia.map((z) => z.id), contains('male_gospodarstwo'));
    });

    test('25 ha: zwolnienie dotyczy GAEC 7, ale nie GAEC 6', () {
      expect(
        warunkowosc
            .zwolnieniaDla(idNormy: 'gaec_7', powierzchniaUrHa: 25)
            .map((z) => z.id),
        contains('gaec7_do_30ha'),
      );
      expect(
        warunkowosc.zwolnieniaDla(idNormy: 'gaec_6', powierzchniaUrHa: 25),
        isEmpty,
      );
    });

    test('powyżej 30 ha nie ma już zwolnienia z GAEC 7', () {
      expect(
        warunkowosc.zwolnieniaDla(idNormy: 'gaec_7', powierzchniaUrHa: 31),
        isEmpty,
      );
    });

    test('zwolnienia z prawa unijnego są oznaczone do weryfikacji', () {
      // EUR-Lexu nie dało się pobrać — wartość pochodzi z komunikatu ARiMR
      // i aplikacja ma o tym mówić, a nie udawać pewności.
      final unijne = warunkowosc.zwolnienia.where(
        (z) => z.id == 'male_gospodarstwo' || z.id == 'gaec7_do_30ha',
      );
      expect(unijne, hasLength(2));
      for (final zwolnienie in unijne) {
        expect(zwolnienie.doWeryfikacji, isTrue, reason: zwolnienie.id);
        expect(zwolnienie.zrodlo, contains('2025/2649'));
      }
    });

    test('produkcja ekologiczna nie jest stosowana po hektarach', () {
      // Zależy od certyfikatu, nie od powierzchni — aplikacja sama jej
      // nie zastosuje.
      final eko = warunkowosc.zwolnienia.firstWhere(
        (z) => z.id == 'ekologiczne',
      );
      expect(eko.doHa, isNull);
      expect(eko.dotyczyNormy('gaec_7'), isTrue);
      expect(eko.dotyczyNormy('gaec_2'), isFalse);
      expect(
        warunkowosc
            .zwolnieniaDla(idNormy: 'gaec_7', powierzchniaUrHa: 100)
            .map((z) => z.id),
        isNot(contains('ekologiczne')),
      );
    });
  });

  group('formy okrywy ochronnej gleby (GAEC 6)', () {
    test('lista jest w słowniku i ma formę „gleba odkryta"', () {
      final formy = warunkowosc.formyOkrywy;
      expect(formy.pusta, isFalse);
      expect(formy.liczone.length, greaterThan(1));
      expect(formy.formy.where((f) => !f.liczJakoOkrywe), hasLength(1));
    });

    test('rozporządzenie form nie wymienia — stąd „do weryfikacji"', () {
      expect(warunkowosc.formyOkrywy.doWeryfikacji, isTrue);
      expect(warunkowosc.formyOkrywy.zrodlo, contains('ARiMR'));
    });

    test('nieznana forma nie liczy się do udziału okrywy', () {
      final formy = warunkowosc.formyOkrywy;
      expect(formy.liczy('uprawa_ozima'), isTrue);
      expect(formy.liczy('brak'), isFalse);
      expect(formy.liczy('forma_z_przyszlej_wersji'), isFalse);
      expect(formy.liczy(null), isFalse);
    });

    test('gleba odkryta nie ma słów do podpowiadania', () {
      final odkryta = warunkowosc.formyOkrywy.formy.firstWhere(
        (f) => !f.liczJakoOkrywe,
      );
      expect(odkryta.slowa, isEmpty);
    });

    test('próg i przerwa z normy GAEC 6 są danymi, nie liczbami w kodzie', () {
      final gaec6 = warunkowosc.norma('gaec_6')!;
      expect(gaec6.prog('udzial_gruntow_ornych_procent')?.wartosc, 80);
      expect(gaec6.prog('przerwa_tygodnie')?.calkowita, 4);
    });

    test('termin okrywy zna swój ostatni dzień w podanym roku', () {
      final termin = warunkowosc.norma('gaec_6')!.termin('okrywa_grunty_orne')!;
      expect(termin.odZdarzenia, isTrue);
      expect(termin.koniecWRoku(2026), DateTime(2026, 10, 15));
    });

    test('okrywa w sadach przechodzi przez koniec roku', () {
      final sady = warunkowosc.norma('gaec_6')!.termin('okrywa_sady')!;
      expect(sady.obejmuje(DateTime(2026, 12, 20)), isTrue);
      expect(sady.obejmuje(DateTime(2026, 2, 1)), isTrue);
      expect(sady.obejmuje(DateTime(2026, 6, 1)), isFalse);
    });
  });

  group('prace przy elementach krajobrazu (GAEC 8)', () {
    test('praca wskazuje normę i jej termin, a nie własne daty', () {
      final praca = warunkowosc.praceKrajobrazowe.praca('przycinanie_drzew')!;
      expect(praca.idNormy, 'gaec_8');
      expect(praca.maZakazOkresowy, isTrue);
      final termin = warunkowosc
          .norma(praca.idNormy!)!
          .termin(praca.idTerminuZakazu!)!;
      expect(termin.od, '04-15');
      expect(termin.doDnia, '07-31');
    });

    test('usuwanie elementu ostrzega cały rok, wyłączone przycinanie nie', () {
      final prace = warunkowosc.praceKrajobrazowe;
      expect(prace.praca('usuwanie_elementu')!.zawszeOstrzegaj, isTrue);
      expect(prace.praca('przycinanie_wylaczone')!.maZakazOkresowy, isFalse);
      expect(prace.praca('inna')!.idNormy, isNull);
      expect(prace.praca('praca_z_przyszlej_wersji'), isNull);
    });

    test('progi chronionych elementów są danymi', () {
      final gaec8 = warunkowosc.norma('gaec_8')!;
      expect(gaec8.prog('row_chroniony_m')?.wartosc, 2);
      expect(gaec8.prog('oczko_wodne_m2')?.wartosc, 100);
    });
  });
}
