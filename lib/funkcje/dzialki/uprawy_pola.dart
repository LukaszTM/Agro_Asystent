import 'package:sqflite_common/sqlite_api.dart';

/// Uprawa na polu w jednym sezonie.
///
/// Kolumna `uprawa` w `dzialka_rolna` mówi tylko, co rośnie **teraz**.
/// Norma GAEC 7 porównuje uprawę w plonie głównym rok po roku i pyta, czy
/// ta sama nie trwa dłużej niż trzy lata — licząc od 2023 r. Bez osobnej
/// tabeli nie da się tego policzyć, a z dziennika zmian wychodzi tylko to,
/// co rolnik zmienił w aplikacji.
class UprawaSezonu {
  const UprawaSezonu({
    required this.id,
    required this.poleId,
    required this.sezon,
    required this.uprawa,
    this.kodEppo,
    this.plonGlowny = true,
    this.zrodlo,
  });

  factory UprawaSezonu.zBazy(Map<String, Object?> w) => UprawaSezonu(
    id: w['id']! as String,
    poleId: w['dzialka_rolna_id']! as String,
    sezon: (w['sezon'] as num).toInt(),
    uprawa: (w['uprawa'] as String?) ?? '',
    kodEppo: w['kod_eppo'] as String?,
    plonGlowny: ((w['plon_glowny'] as num?) ?? 1) == 1,
    zrodlo: w['zrodlo'] as String?,
  );

  final String id;
  final String poleId;
  final int sezon;
  final String uprawa;
  final String? kodEppo;

  /// Plon główny — tylko on liczy się do GAEC 7. Międzyplon i wsiewka to
  /// osobna sprawa (krok 4: okrywa ochronna gleby).
  final bool plonGlowny;

  /// Skąd wiemy: `pole` (z pola przy przejściu na nowy schemat),
  /// `dziennik zmian`, `wniosek`, `rolnik`.
  final String? zrodlo;

  bool get maKod => (kodEppo ?? '').isNotEmpty;

  /// Identyfikator wyliczany, nie losowy: dwa urządzenia dopisujące tę
  /// samą uprawę na ten sam sezon dadzą ten sam wiersz, więc scalanie
  /// danych nie zrobi z tego dwóch wpisów.
  static String identyfikator({
    required String poleId,
    required int sezon,
    bool plonGlowny = true,
  }) => 'up-$poleId-$sezon-${plonGlowny ? 'g' : 'p'}';
}

/// Uprawy pola po sezonach.
class RepozytoriumUprawPola {
  const RepozytoriumUprawPola(this._baza);

  final DatabaseExecutor _baza;

  /// Historia upraw pola, od najnowszego sezonu.
  Future<List<UprawaSezonu>> historia(String poleId) async {
    final wiersze = await _baza.query(
      'uprawa_pola',
      where: 'dzialka_rolna_id = ? AND usuniety = 0',
      whereArgs: [poleId],
      orderBy: 'sezon DESC, plon_glowny DESC',
    );
    return wiersze.map(UprawaSezonu.zBazy).toList(growable: false);
  }

  /// Uprawy w plonie głównym wszystkich pól gospodarstwa w danym sezonie.
  ///
  /// Zapytanie idzie przez `dzialka_rolna`, bo gospodarstwo wisi na polu,
  /// nie na uprawie.
  Future<List<UprawaSezonu>> plonGlownyWSezonie({
    required String gospodarstwoId,
    required int sezon,
  }) async {
    final wiersze = await _baza.rawQuery(
      '''
      SELECT u.*
      FROM uprawa_pola u
      JOIN dzialka_rolna r ON r.id = u.dzialka_rolna_id
      WHERE r.gospodarstwo_id = ? AND r.usuniety = 0
        AND u.usuniety = 0 AND u.plon_glowny = 1 AND u.sezon = ?
      ''',
      [gospodarstwoId, sezon],
    );
    return wiersze.map(UprawaSezonu.zBazy).toList(growable: false);
  }

  /// Dopisanie albo poprawienie uprawy pola w danym sezonie.
  ///
  /// Poprawka nie nadpisuje historii po cichu: wyzwalacz bazy zapisuje
  /// poprzednią wartość do dziennika zmian.
  Future<void> zapisz({
    required String poleId,
    required int sezon,
    required String uprawa,
    required String urzadzenie,
    String? kodEppo,
    bool plonGlowny = true,
    String zrodlo = 'rolnik',
    DateTime? teraz,
  }) async {
    final czas = (teraz ?? DateTime.now()).toIso8601String();
    final id = UprawaSezonu.identyfikator(
      poleId: poleId,
      sezon: sezon,
      plonGlowny: plonGlowny,
    );
    final istnieje = await _baza.query(
      'uprawa_pola',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (istnieje.isEmpty) {
      await _baza.insert('uprawa_pola', {
        'id': id,
        'dzialka_rolna_id': poleId,
        'sezon': sezon,
        'uprawa': uprawa,
        'kod_eppo': kodEppo,
        'plon_glowny': plonGlowny ? 1 : 0,
        'zrodlo': zrodlo,
        'utworzono': czas,
        'zmieniono': czas,
        'urzadzenie': urzadzenie,
      });
      return;
    }
    await _baza.update(
      'uprawa_pola',
      {
        'uprawa': uprawa,
        'kod_eppo': kodEppo,
        'zrodlo': zrodlo,
        'zmieniono': czas,
        'urzadzenie': urzadzenie,
        'usuniety': 0,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Cofnięcie wpisu o uprawie — wiersz zostaje w bazie ze śladem.
  Future<void> usun({
    required String poleId,
    required int sezon,
    required String urzadzenie,
    bool plonGlowny = true,
    DateTime? teraz,
  }) => _baza.update(
    'uprawa_pola',
    {
      'usuniety': 1,
      'zmieniono': (teraz ?? DateTime.now()).toIso8601String(),
      'urzadzenie': urzadzenie,
    },
    where: 'id = ?',
    whereArgs: [
      UprawaSezonu.identyfikator(
        poleId: poleId,
        sezon: sezon,
        plonGlowny: plonGlowny,
      ),
    ],
  );

  /// Uprawy tego samego pola z wniosków z wcześniejszych lat.
  ///
  /// Import wniosku zakłada osobny wiersz pola na każdy sezon (identyfikator
  /// `pole-<sezon>-<oznaczenie>`), więc historia pola z wniosku leży
  /// w innych wierszach. Aplikacja ich **nie scala sama** — pokazuje je
  /// rolnikowi jako propozycję, a on potwierdza. Oznaczenia działek rolnych
  /// zmieniają się między latami i tylko rolnik wie, czy „A" z 2025 r. to
  /// ten sam kawałek pola co „A" z 2026 r.
  Future<List<UprawaSezonu>> propozycjeZWnioskow(String poleId) async {
    final pole = await _baza.query(
      'dzialka_rolna',
      columns: ['gospodarstwo_id', 'oznaczenie_z_wniosku', 'sezon'],
      where: 'id = ?',
      whereArgs: [poleId],
      limit: 1,
    );
    if (pole.isEmpty) {
      return const [];
    }
    final oznaczenie = pole.single['oznaczenie_z_wniosku'] as String?;
    if (oznaczenie == null || oznaczenie.isEmpty) {
      return const [];
    }

    final wiersze = await _baza.rawQuery(
      '''
      SELECT u.*
      FROM uprawa_pola u
      JOIN dzialka_rolna r ON r.id = u.dzialka_rolna_id
      WHERE r.gospodarstwo_id = ?
        AND r.oznaczenie_z_wniosku = ?
        AND r.id <> ?
        AND r.usuniety = 0 AND u.usuniety = 0 AND u.plon_glowny = 1
        AND u.sezon < ?
        AND NOT EXISTS (
          SELECT 1 FROM uprawa_pola w
          WHERE w.dzialka_rolna_id = ? AND w.sezon = u.sezon
            AND w.plon_glowny = 1 AND w.usuniety = 0
        )
      ORDER BY u.sezon DESC
      ''',
      [
        pole.single['gospodarstwo_id'],
        oznaczenie,
        poleId,
        (pole.single['sezon'] as num).toInt(),
        poleId,
      ],
    );
    return wiersze.map(UprawaSezonu.zBazy).toList(growable: false);
  }
}
