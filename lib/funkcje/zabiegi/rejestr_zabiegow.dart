import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/modele/zabieg.dart';

/// Pole objęte zabiegiem, tak jak ma wyglądać w ewidencji: nazwa dla rolnika,
/// uprawa z kodem EPPO i działki referencyjne z wniosku.
class PoleWpisu {
  const PoleWpisu({
    required this.id,
    required this.nazwa,
    required this.uprawa,
    required this.powierzchniaAr,
    this.kodEppo,
    this.dzialkiReferencyjne = const [],
  });

  final String id;
  final String nazwa;
  final String uprawa;
  final int powierzchniaAr;
  final String? kodEppo;

  /// Numery działek ewidencyjnych, na których pole leży (z importu wniosku).
  final List<String> dzialkiReferencyjne;

  String get powierzchniaOpis =>
      '${(powierzchniaAr / 100).toStringAsFixed(2).replaceAll('.', ',')} ha';
}

/// Jeden wpis rejestru: zabieg razem ze wszystkim, co trzeba pokazać przy
/// kontroli — bez dociągania danych ze słownika, bo ewidencja ma pokazywać
/// stan z dnia zabiegu (ADR-0004).
class WpisRejestru {
  const WpisRejestru({required this.zabieg, required this.pola, this.oprysk});

  final Zabieg zabieg;
  final List<PoleWpisu> pola;
  final SzczegolyOprysku? oprysk;

  String get opisPol =>
      pola.isEmpty ? 'bez pola' : pola.map((p) => p.nazwa).join(', ');

  String get uprawy {
    final nazwy = {
      for (final pole in pola)
        if (pole.uprawa.isNotEmpty) pole.uprawa,
    };
    return nazwy.join(', ');
  }

  List<String> get dzialkiReferencyjne {
    final numery = {for (final pole in pola) ...pole.dzialkiReferencyjne};
    return numery.toList()..sort();
  }

  String get powierzchniaOpis =>
      '${(zabieg.powierzchniaAr / 100).toStringAsFixed(2).replaceAll('.', ',')} ha';

  /// Dzień, od którego wolno zbierać plon — tylko gdy karencja jest znana.
  DateTime? get dzienZbioru => oprysk?.dzienZbioru(zabieg.data);

  /// Czy w dniu [kiedy] karencja jeszcze trwa.
  bool karencjaTrwa(DateTime kiedy) {
    final dzien = dzienZbioru;
    return dzien != null && kiedy.isBefore(dzien);
  }
}

/// Czego szukamy w rejestrze. Puste pola oznaczają „wszystko".
class FiltrRejestru {
  const FiltrRejestru({this.rodzaj, this.szukane = '', this.rok});

  final RodzajZabiegu? rodzaj;

  /// Fragment nazwy środka, pola albo uprawy.
  final String szukane;

  final int? rok;

  bool get pusty => rodzaj == null && szukane.trim().isEmpty && rok == null;
}

/// Rejestr zabiegów — odczyt wpisów do podglądu, wydruku i eksportu.
class RejestrZabiegow {
  const RejestrZabiegow(this._baza);

  final DatabaseExecutor _baza;

  /// Wpisy gospodarstwa od najnowszego, razem z polami i szczegółami oprysku.
  ///
  /// Dane zbieramy trzema zapytaniami, a nie jednym na wpis — przy kilkuset
  /// zabiegach w sezonie to różnica między „od razu" a „chwilę".
  Future<List<WpisRejestru>> wpisy(
    String gospodarstwoId, {
    FiltrRejestru filtr = const FiltrRejestru(),
    int limit = 500,
  }) async {
    final warunki = <String>['z.gospodarstwo_id = ?', 'z.usuniety = 0'];
    final argumenty = <Object?>[gospodarstwoId];

    if (filtr.rodzaj != null) {
      warunki.add('z.typ = ?');
      argumenty.add(filtr.rodzaj!.wBazie);
    }
    if (filtr.rok != null) {
      warunki.add("strftime('%Y', z.data) = ?");
      argumenty.add('${filtr.rok}');
    }
    final szukane = filtr.szukane.trim();
    if (szukane.isNotEmpty) {
      warunki.add(
        '(o.srodek_nazwa LIKE ? OR r.nazwa_wlasna LIKE ? OR r.uprawa LIKE ?)',
      );
      argumenty.addAll(['%$szukane%', '%$szukane%', '%$szukane%']);
    }

    final wiersze = await _baza.rawQuery(
      '''
      SELECT DISTINCT z.*
      FROM zabieg z
      LEFT JOIN zabieg_oprysk o ON o.zabieg_id = z.id
      LEFT JOIN zabieg_pole zp  ON zp.zabieg_id = z.id
      LEFT JOIN dzialka_rolna r ON r.id = zp.dzialka_rolna_id
      WHERE ${warunki.join(' AND ')}
      ORDER BY z.data DESC, z.godzina DESC
      LIMIT ?
    ''',
      [...argumenty, limit],
    );

    if (wiersze.isEmpty) {
      return const [];
    }

    final zabiegi = wiersze.map(Zabieg.zBazy).toList(growable: false);
    final identyfikatory = [for (final zabieg in zabiegi) zabieg.id];
    final pola = await _polaWpisow(identyfikatory);
    final opryski = await _opryskiWpisow(identyfikatory);

    return [
      for (final zabieg in zabiegi)
        WpisRejestru(
          zabieg: zabieg,
          pola: pola[zabieg.id] ?? const [],
          oprysk: opryski[zabieg.id],
        ),
    ];
  }

  /// Jeden wpis — do ekranu podglądu i poprawki.
  Future<WpisRejestru?> wpis(String zabiegId) async {
    final wiersze = await _baza.query(
      'zabieg',
      where: 'id = ?',
      whereArgs: [zabiegId],
      limit: 1,
    );
    if (wiersze.isEmpty) {
      return null;
    }
    final pola = await _polaWpisow([zabiegId]);
    final opryski = await _opryskiWpisow([zabiegId]);
    return WpisRejestru(
      zabieg: Zabieg.zBazy(wiersze.first),
      pola: pola[zabiegId] ?? const [],
      oprysk: opryski[zabiegId],
    );
  }

  /// Lata, w których są wpisy — do przełączania sezonu w rejestrze.
  Future<List<int>> lata(String gospodarstwoId) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT DISTINCT strftime('%Y', data) AS rok
      FROM zabieg
      WHERE gospodarstwo_id = ? AND usuniety = 0
      ORDER BY rok DESC
    ''',
      [gospodarstwoId],
    );
    return [
      for (final wiersz in wiersze)
        if (int.tryParse('${wiersz['rok']}') case final int rok) rok,
    ];
  }

  Future<Map<String, List<PoleWpisu>>> _polaWpisow(List<String> zabiegi) async {
    if (zabiegi.isEmpty) {
      return const {};
    }
    final znaki = List.filled(zabiegi.length, '?').join(', ');
    final wiersze = await _baza.rawQuery('''
      SELECT zp.zabieg_id, zp.powierzchnia_ar, r.id AS pole_id,
             r.nazwa_wlasna, r.uprawa, r.kod_eppo,
             (SELECT group_concat(de.identyfikator, '|')
                FROM dzialka_rolna_czesc c
                JOIN dzialka_ewidencyjna de ON de.id = c.dzialka_ewidencyjna_id
               WHERE c.dzialka_rolna_id = r.id AND de.usuniety = 0
             ) AS dzialki
      FROM zabieg_pole zp
      JOIN dzialka_rolna r ON r.id = zp.dzialka_rolna_id
      WHERE zp.zabieg_id IN ($znaki)
      ORDER BY r.nazwa_wlasna
    ''', zabiegi);

    final wynik = <String, List<PoleWpisu>>{};
    for (final wiersz in wiersze) {
      final zapis = (wiersz['dzialki'] as String?) ?? '';
      final dzialki = zapis.isEmpty ? <String>[] : zapis.split('|');
      dzialki.sort();
      wynik
          .putIfAbsent(wiersz['zabieg_id']! as String, () => [])
          .add(
            PoleWpisu(
              id: wiersz['pole_id']! as String,
              nazwa: (wiersz['nazwa_wlasna'] as String?) ?? 'Pole bez nazwy',
              uprawa: (wiersz['uprawa'] as String?) ?? '',
              powierzchniaAr: (wiersz['powierzchnia_ar'] as int?) ?? 0,
              kodEppo: wiersz['kod_eppo'] as String?,
              dzialkiReferencyjne: dzialki,
            ),
          );
    }
    return wynik;
  }

  Future<Map<String, SzczegolyOprysku>> _opryskiWpisow(
    List<String> zabiegi,
  ) async {
    if (zabiegi.isEmpty) {
      return const {};
    }
    final znaki = List.filled(zabiegi.length, '?').join(', ');
    final wiersze = await _baza.rawQuery(
      'SELECT * FROM zabieg_oprysk WHERE zabieg_id IN ($znaki)',
      zabiegi,
    );
    return {
      for (final wiersz in wiersze)
        wiersz['zabieg_id']! as String: SzczegolyOprysku.zBazy(wiersz),
    };
  }
}
