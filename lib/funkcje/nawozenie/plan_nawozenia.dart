import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/reguly/regula_prawna.dart';
import '../dzialki/repozytorium_pol.dart';

/// Ile azotu trafiło na jedno pole w sezonie.
class AzotNaPolu {
  const AzotNaPolu({
    required this.poleId,
    required this.nazwa,
    required this.uprawa,
    required this.powierzchniaHa,
    required this.azotKg,
    required this.azotNaturalnyKg,
    this.limit = LimitAzotuDlaUprawy.brak,
  });

  final String poleId;
  final String nazwa;
  final String uprawa;
  final double powierzchniaHa;
  final double azotKg;
  final double azotNaturalnyKg;

  /// Co tabela 14 programu azotanowego mówi o limicie dla tej uprawy.
  /// Przy nieznanej uprawie zostaje [LimitAzotuDlaUprawy.brak] — limitu
  /// nie zgadujemy.
  final LimitAzotuDlaUprawy limit;

  double get azotKgNaHa => powierzchniaHa <= 0 ? 0 : azotKg / powierzchniaHa;

  double get azotNaturalnyKgNaHa =>
      powierzchniaHa <= 0 ? 0 : azotNaturalnyKg / powierzchniaHa;

  /// Czy azot na tym polu przekroczył limit z tabeli 14.
  bool get limitPrzekroczony => limit.przekroczony(azotKgNaHa);
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

  /// Pola, na których azot przekroczył limit z tabeli 14.
  List<AzotNaPolu> get polaPonadLimit =>
      pola.where((pole) => pole.limitPrzekroczony).toList(growable: false);
}

/// Co stanie się z maksymalną dawką azotu dla uprawy (tabela 14), gdy
/// rolnik zapisze wpisywaną dawkę.
///
/// Liczymy to **przed** zapisem, żeby ostrzeżenie padło w chwili, w której
/// rolnik może jeszcze dawkę zmienić.
class SkutekDlaMaksymalnejDawki {
  const SkutekDlaMaksymalnejDawki({
    required this.nazwaPola,
    required this.uprawa,
    required this.limit,
    required this.azotWSezonieKgNaHa,
    required this.azotWpisuKgNaHa,
  });

  final String nazwaPola;
  final String uprawa;
  final LimitAzotuDlaUprawy limit;

  /// Azot już zapisany na tym polu w sezonie.
  final double azotWSezonieKgNaHa;

  /// Azot, który wniesie wpisywana dawka.
  final double azotWpisuKgNaHa;

  double get azotRazemKgNaHa => azotWSezonieKgNaHa + azotWpisuKgNaHa;

  int? get limitKgNaHa => limit.kgNHa;

  bool get przekroczony => limit.przekroczony(azotRazemKgNaHa);

  /// Jedno zdanie dla rolnika — `null`, gdy nie ma czego ostrzegać.
  ///
  /// Treść jest tutaj, a nie w ekranach, bo oba wyglądy muszą mówić
  /// rolnikowi to samo.
  String? get ostrzezenie {
    if (przekroczony) {
      return 'Na polu $nazwaPola wyjdzie ${_kg(azotRazemKgNaHa)} kg azotu '
          'na hektar, a dla uprawy ${uprawa.toLowerCase()} wolno dać '
          'najwyżej $limitKgNaHa kg.';
    }
    final najnizszy = limit.najnizszyKgNHa;
    if (limit.stan == StanMaksymalnejDawki.niejednoznaczny &&
        najnizszy != null &&
        azotRazemKgNaHa > najnizszy) {
      return 'Dla uprawy ${uprawa.toLowerCase()} tabela podaje różne limity '
          '(${limit.opisDopasowan}), a na polu $nazwaPola wyjdzie '
          '${_kg(azotRazemKgNaHa)} kg azotu na hektar.';
    }
    return null;
  }

  /// Co rolnik ma z tym zrobić — druga połowa ostrzeżenia.
  String? get coZrobic {
    if (przekroczony) {
      final zostalo = pozostaloKgNaHa;
      return zostalo == null || zostalo <= 0
          ? 'Nie dawaj na to pole więcej azotu w tym sezonie.'
          : 'Zmniejsz dawkę — do limitu zostało ${_kg(zostalo)} kg azotu '
                'na hektar.';
    }
    if (ostrzezenie != null) {
      return 'Sprawdź, która grupa upraw dotyczy twojego pola.';
    }
    return null;
  }

  static String _kg(double wartosc) => wartosc.toStringAsFixed(0);

  /// Ten sam stan pola przy innej dawce — ekran przelicza ostrzeżenie
  /// przy każdym dotknięciu „+", a azot już zapisany w sezonie czyta
  /// z bazy tylko raz.
  SkutekDlaMaksymalnejDawki zDawka(double azotWpisuKgNaHa) =>
      SkutekDlaMaksymalnejDawki(
        nazwaPola: nazwaPola,
        uprawa: uprawa,
        limit: limit,
        azotWSezonieKgNaHa: azotWSezonieKgNaHa,
        azotWpisuKgNaHa: azotWpisuKgNaHa,
      );

  /// Ile jeszcze wolno dać na hektar. `null`, gdy limitu nie znamy.
  double? get pozostaloKgNaHa {
    final granica = limitKgNaHa;
    return granica == null
        ? null
        : (granica - azotWSezonieKgNaHa).clamp(0, granica).toDouble();
  }
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
          limit: reguly.maksymalneDawkiAzotu.dlaUprawy(
            (wiersz['uprawa'] as String?) ?? '',
          ),
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

  /// Co wpisywana dawka zrobi z maksymalną dawką azotu dla uprawy.
  ///
  /// Zwraca wiersz dla każdego wybranego pola — także wtedy, gdy tabela
  /// limitu dla uprawy nie podaje. Ekran sam decyduje, co pokazać; tu
  /// nie zgadujemy niczego za rolnika.
  Future<List<SkutekDlaMaksymalnejDawki>> skutkiDlaMaksymalnejDawki({
    required List<Pole> pola,
    required double azotWpisuKgNaHa,
    DateTime? kiedy,
  }) async {
    if (pola.isEmpty) {
      return const [];
    }
    final rok = (kiedy ?? DateTime.now()).year;
    final znaki = List.filled(pola.length, '?').join(', ');

    final wiersze = await baza.rawQuery(
      '''
      SELECT zp.dzialka_rolna_id AS pole_id,
             COALESCE(SUM(n.azot_kg_ha), 0) AS azot_kg_ha
      FROM zabieg_pole zp
      JOIN zabieg z ON z.id = zp.zabieg_id AND z.usuniety = 0
      JOIN zabieg_nawozenie n ON n.zabieg_id = z.id
      WHERE zp.dzialka_rolna_id IN ($znaki)
        AND strftime('%Y', z.data) = ?
      GROUP BY zp.dzialka_rolna_id
    ''',
      [...pola.map((pole) => pole.id), '$rok'],
    );

    final wSezonie = {
      for (final wiersz in wiersze)
        wiersz['pole_id']! as String:
            (wiersz['azot_kg_ha'] as num?)?.toDouble() ?? 0,
    };

    return [
      for (final pole in pola)
        SkutekDlaMaksymalnejDawki(
          nazwaPola: pole.nazwa,
          uprawa: pole.uprawa,
          limit: reguly.maksymalneDawkiAzotu.dlaUprawy(pole.uprawa),
          azotWSezonieKgNaHa: wSezonie[pole.id] ?? 0,
          azotWpisuKgNaHa: azotWpisuKgNaHa,
        ),
    ];
  }
}
