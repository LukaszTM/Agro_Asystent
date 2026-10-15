import 'package:sqflite_common/sqlite_api.dart';

import '../zabiegi/slownik_srodkow.dart';
import 'czytnik_wniosku.dart';

/// Co import zrobił w bazie — pokazujemy to rolnikowi, zamiast kazać mu
/// zgadywać, czy coś się zmieniło.
class WynikImportu {
  WynikImportu({required this.sezon});

  final int sezon;
  int dzialkiDodane = 0;
  int dzialkiUzupelnione = 0;
  int polaDodane = 0;
  int polaZastapione = 0;
  int czesciPolaczone = 0;

  /// Uprawy, dla których słownik nie podał kodu EPPO. Nie zgadujemy ich —
  /// pole zostaje bez kodu i czeka na potwierdzenie (plan, pkt 11).
  final List<String> uprawyBezKodu = [];

  /// Działki z tabeli X, dla których wniosek nie podał pełnego numeru.
  /// Bez niego nie da się pobrać granic z ULDK.
  final List<String> dzialkiBezPelnegoNumeru = [];

  int get dzialkiRazem => dzialkiDodane + dzialkiUzupelnione;
  int get polaRazem => polaDodane + polaZastapione;
}

/// Zapisuje odczytany wniosek do bazy gospodarstwa.
///
/// Import nie rusza granic działek już pobranych z ULDK — wniosek podaje
/// powierzchnię i położenie, granice zostają z usługi (krok 1 etapu 1).
class ImportWniosku {
  const ImportWniosku({required this.baza, required this.srodki});

  final Database baza;

  /// Słownik upraw — stąd bierzemy kod EPPO dla nazwy uprawy z wniosku.
  final SlownikSrodkow srodki;

  Future<WynikImportu> zapisz({
    required WniosekZPdf wniosek,
    required String gospodarstwoId,
    required String urzadzenie,
    int? sezon,
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final rok = sezon ?? wniosek.rok ?? (teraz ?? DateTime.now()).year;
    final wynik = WynikImportu(sezon: rok);

    // Pełne numery działek (z kodem gminy) są tylko w tabeli XI; tabela X
    // podaje numer obrębu, więc łączymy jedno z drugim po końcówce.
    final pelneNumery = wniosek.identyfikatoryDzialek;
    final numerDlaDzialki = <String, String>{};
    for (final dzialka in wniosek.dzialki) {
      final koncowka = dzialka.koncowkaIdentyfikatora;
      final pelny = pelneNumery.firstWhere(
        (numer) => numer.endsWith(koncowka),
        orElse: () => '',
      );
      if (pelny.isEmpty) {
        wynik.dzialkiBezPelnegoNumeru.add(koncowka);
      }
      numerDlaDzialki[koncowka] = pelny.isEmpty ? koncowka : pelny;
    }

    final kodyUpraw = <String, String?>{};
    for (final uprawa in wniosek.uprawy) {
      kodyUpraw[uprawa] = await srodki.kodEppo(uprawa);
      if (kodyUpraw[uprawa] == null) {
        wynik.uprawyBezKodu.add(uprawa);
      }
    }

    await baza.transaction((t) async {
      for (final dzialka in wniosek.dzialki) {
        final identyfikator = numerDlaDzialki[dzialka.koncowkaIdentyfikatora]!;
        await _zapiszDzialke(
          t,
          gospodarstwoId: gospodarstwoId,
          identyfikator: identyfikator,
          dzialka: dzialka,
          urzadzenie: urzadzenie,
          czas: czas,
          wynik: wynik,
        );
      }

      for (final pole in wniosek.pola) {
        await _zapiszPole(
          t,
          gospodarstwoId: gospodarstwoId,
          pole: pole,
          sezon: rok,
          kodEppo: kodyUpraw[CzytnikWniosku.oczyscUprawe(pole.uprawa)],
          urzadzenie: urzadzenie,
          czas: czas,
          wynik: wynik,
        );
      }
    });

    return wynik;
  }

  Future<void> _zapiszDzialke(
    DatabaseExecutor t, {
    required String gospodarstwoId,
    required String identyfikator,
    required DzialkaZWniosku dzialka,
    required String urzadzenie,
    required String czas,
    required WynikImportu wynik,
  }) async {
    final opis = {
      'wojewodztwo': dzialka.wojewodztwo,
      'powiat': dzialka.powiat,
      'gmina': dzialka.gmina,
      'obreb': dzialka.obreb,
      'nr_dzialki': dzialka.nrDzialki,
      'powierzchnia_ha': dzialka.powierzchniaHa,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    };

    final istniejace = await t.query(
      'dzialka_ewidencyjna',
      columns: ['id'],
      where: 'gospodarstwo_id = ? AND identyfikator = ?',
      whereArgs: [gospodarstwoId, identyfikator],
      limit: 1,
    );
    if (istniejace.isNotEmpty) {
      // Granic i źródła nie ruszamy — mogą pochodzić z ULDK.
      await t.update(
        'dzialka_ewidencyjna',
        {...opis, 'usuniety': 0},
        where: 'id = ?',
        whereArgs: [istniejace.first['id']],
      );
      wynik.dzialkiUzupelnione++;
      return;
    }

    await t.insert('dzialka_ewidencyjna', {
      'id': 'dz-$identyfikator',
      'gospodarstwo_id': gospodarstwoId,
      'identyfikator': identyfikator,
      ...opis,
      'utworzono': czas,
    });
    wynik.dzialkiDodane++;
  }

  Future<void> _zapiszPole(
    DatabaseExecutor t, {
    required String gospodarstwoId,
    required PoleZWniosku pole,
    required int sezon,
    required String? kodEppo,
    required String urzadzenie,
    required String czas,
    required WynikImportu wynik,
  }) async {
    final uprawa = CzytnikWniosku.oczyscUprawe(pole.uprawa);
    final dane = {
      'gospodarstwo_id': gospodarstwoId,
      'nazwa_wlasna': 'Pole ${pole.oznaczenie}',
      'oznaczenie_z_wniosku': pole.oznaczenie,
      'sezon': sezon,
      'uprawa': uprawa,
      'kod_eppo': kodEppo,
      'powierzchnia_ar': pole.powierzchniaAr,
      'zmieniono': czas,
      'urzadzenie': urzadzenie,
    };

    final istniejace = await t.query(
      'dzialka_rolna',
      columns: ['id', 'nazwa_wlasna'],
      where: 'gospodarstwo_id = ? AND oznaczenie_z_wniosku = ? AND sezon = ?',
      whereArgs: [gospodarstwoId, pole.oznaczenie, sezon],
      limit: 1,
    );

    final String id;
    if (istniejace.isNotEmpty) {
      id = istniejace.first['id']! as String;
      // Nazwę nadaną przez rolnika zostawiamy — jego nazwa jest ważniejsza
      // niż oznaczenie z wniosku.
      final nazwa = istniejace.first['nazwa_wlasna'] as String?;
      await t.update(
        'dzialka_rolna',
        {
          ...dane,
          if (nazwa != null && nazwa.isNotEmpty) 'nazwa_wlasna': nazwa,
          'usuniety': 0,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      await t.delete(
        'dzialka_rolna_czesc',
        where: 'dzialka_rolna_id = ?',
        whereArgs: [id],
      );
      wynik.polaZastapione++;
    } else {
      id = 'pole-$sezon-${pole.oznaczenie}';
      await t.insert('dzialka_rolna', {'id': id, ...dane, 'utworzono': czas});
      wynik.polaDodane++;
    }

    for (final czesc in pole.czesci) {
      if (czesc.identyfikator.isEmpty) {
        continue;
      }
      final dzialka = await t.query(
        'dzialka_ewidencyjna',
        columns: ['id'],
        where: 'gospodarstwo_id = ? AND identyfikator = ?',
        whereArgs: [gospodarstwoId, czesc.identyfikator],
        limit: 1,
      );
      if (dzialka.isEmpty) {
        continue;
      }
      await t.insert('dzialka_rolna_czesc', {
        'dzialka_rolna_id': id,
        'dzialka_ewidencyjna_id': dzialka.first['id'],
        'powierzchnia_ar': czesc.powierzchniaAr,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      wynik.czesciPolaczone++;
    }
  }
}
