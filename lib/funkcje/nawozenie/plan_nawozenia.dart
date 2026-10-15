import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/reguly/regula_prawna.dart';

/// Ile azotu trafiło na jedno pole w sezonie.
class AzotNaPolu {
  const AzotNaPolu({
    required this.poleId,
    required this.nazwa,
    required this.uprawa,
    required this.powierzchniaHa,
    required this.azotKg,
    required this.azotNaturalnyKg,
  });

  final String poleId;
  final String nazwa;
  final String uprawa;
  final double powierzchniaHa;
  final double azotKg;
  final double azotNaturalnyKg;

  double get azotKgNaHa => powierzchniaHa <= 0 ? 0 : azotKg / powierzchniaHa;

  double get azotNaturalnyKgNaHa =>
      powierzchniaHa <= 0 ? 0 : azotNaturalnyKg / powierzchniaHa;
}

/// Zestawienie azotu dla gospodarstwa wraz z informacją, czy przepis wymaga
/// planu nawożenia azotem.
///
/// **To zestawienie nie jest planem nawożenia.** Plan sporządza się na
/// podstawie analizy gleby i potrzeb pokarmowych uprawy — aplikacja podaje
/// tylko to, co wie z ewidencji, żeby rolnik miał z czym iść do doradcy.
class ZestawienieAzotu {
  const ZestawienieAzotu({
    required this.sezon,
    required this.pola,
    required this.planWymagany,
    required this.planNiepewny,
    required this.kogoDotyczyPlan,
  });

  final int sezon;
  final List<AzotNaPolu> pola;

  /// Czy gospodarstwo przekroczyło próg, od którego przepis wymaga planu.
  final bool planWymagany;

  /// Aplikacja nie umiała ocenić progu (np. brak danych o zwierzętach).
  final bool planNiepewny;

  final String kogoDotyczyPlan;

  double get azotRazemKg => pola.fold(0, (suma, pole) => suma + pole.azotKg);

  double get azotNaturalnyRazemKg =>
      pola.fold(0, (suma, pole) => suma + pole.azotNaturalnyKg);

  double get powierzchniaHa =>
      pola.fold(0, (suma, pole) => suma + pole.powierzchniaHa);
}

/// Liczy azot na polach i sprawdza, czy przepis wymaga planu nawożenia.
class PlanNawozenia {
  const PlanNawozenia({required this.baza, required this.reguly});

  final DatabaseExecutor baza;
  final SlownikRegul reguly;

  static const String idObowiazku = 'program_azotanowy_plan';

  Future<ZestawienieAzotu> zestawienie({
    required String gospodarstwoId,
    required ProfilGospodarstwa profil,
    int? sezon,
  }) async {
    final rok = sezon ?? DateTime.now().year;

    final wiersze = await baza.rawQuery(
      '''
      -- Powierzchnie trzymamy w arach, a azot liczymy na hektar, stąd
      -- dzielenie przez sto. To przeliczenie jednostek, nie próg z przepisu.
      SELECT r.id, r.nazwa_wlasna, r.uprawa, r.powierzchnia_ar,
             COALESCE(SUM(n.azot_kg_ha * zp.powierzchnia_ar / 100), 0) AS azot_kg,
             COALESCE(SUM(
               CASE WHEN n.naturalny = 1
                    THEN n.azot_kg_ha * zp.powierzchnia_ar / 100
                    ELSE 0 END), 0) AS azot_naturalny_kg
      FROM dzialka_rolna r
      LEFT JOIN zabieg_pole zp ON zp.dzialka_rolna_id = r.id
      LEFT JOIN zabieg z ON z.id = zp.zabieg_id
                        AND z.usuniety = 0
                        AND strftime('%Y', z.data) = ?
      LEFT JOIN zabieg_nawozenie n ON n.zabieg_id = z.id
      WHERE r.gospodarstwo_id = ? AND r.usuniety = 0 AND r.sezon = ?
      GROUP BY r.id
      ORDER BY r.nazwa_wlasna
    ''',
      ['$rok', gospodarstwoId, rok],
    );

    final pola = [
      for (final wiersz in wiersze)
        AzotNaPolu(
          poleId: wiersz['id']! as String,
          nazwa: (wiersz['nazwa_wlasna'] as String?) ?? 'Pole bez nazwy',
          uprawa: (wiersz['uprawa'] as String?) ?? '',
          powierzchniaHa: ((wiersz['powierzchnia_ar'] as int?) ?? 0) / 100,
          azotKg: (wiersz['azot_kg'] as num?)?.toDouble() ?? 0,
          azotNaturalnyKg:
              (wiersz['azot_naturalny_kg'] as num?)?.toDouble() ?? 0,
        ),
    ];

    final obowiazek = reguly.obowiazek(idObowiazku);
    final ocena = obowiazek?.ocena(profil) ?? Ocena.nieWiadomo;

    return ZestawienieAzotu(
      sezon: rok,
      pola: pola,
      planWymagany: ocena == Ocena.dotyczy,
      planNiepewny: ocena == Ocena.nieWiadomo,
      kogoDotyczyPlan: obowiazek?.kogoDotyczy ?? '',
    );
  }
}
