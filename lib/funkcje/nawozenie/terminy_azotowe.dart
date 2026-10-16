import 'package:sqflite_common/sqlite_api.dart';

import '../../rdzen/reguly/gminy_terminy.dart';
import '../../rdzen/reguly/regula_prawna.dart';

/// Termin, który aplikacja pokazuje rolnikowi dla jednej gminy.
class TerminDlaGminy {
  const TerminDlaGminy({
    required this.kodGminy,
    required this.dataRoczna,
    required this.zrodlo,
  });

  final String kodGminy;

  /// „MM-DD".
  final String dataRoczna;

  /// Skąd ta data: wykaz z załącznika albo termin domyślny z programu.
  final String zrodlo;
}

/// Jak wyszło w całym gospodarstwie: jedna data albo kilka, gdy działki leżą
/// w gminach z różnymi wykazami.
class TerminyGospodarstwa {
  const TerminyGospodarstwa({
    required this.terminy,
    required this.dzialkiBezKoduGminy,
  });

  final List<TerminDlaGminy> terminy;

  /// Działki, których identyfikator nie dał się rozczytać — mówimy o nich
  /// wprost, zamiast podawać datę „na wszelki wypadek".
  final int dzialkiBezKoduGminy;

  bool get pusty => terminy.isEmpty;

  /// Czy gminy gospodarstwa mają różne terminy.
  bool get rozneTerminy => terminy.map((t) => t.dataRoczna).toSet().length > 1;

  /// Najwcześniejszy termin — ten wiąże, jeśli rolnik nie pilnuje osobno
  /// każdego pola.
  String? get najwczesniejszy {
    if (terminy.isEmpty) {
      return null;
    }
    final daty = terminy.map((t) => t.dataRoczna).toList()..sort();
    return daty.first;
  }
}

/// Wylicza graniczne terminy stosowania nawozów azotowych dla gospodarstwa:
/// z terminu domyślnego ze słownika reguł i z wykazów gmin.
class TerminyAzotowe {
  const TerminyAzotowe({
    required this.baza,
    required this.reguly,
    required this.gminy,
  });

  final DatabaseExecutor baza;
  final SlownikRegul reguly;
  final SlownikGminTerminow gminy;

  /// Termin, przy którym program azotanowy przewiduje wykazy gmin.
  Termin? get terminZWykazami {
    for (final termin in reguly.terminy) {
      if (termin.wariantyGmin != null) {
        return termin;
      }
    }
    return null;
  }

  Future<TerminyGospodarstwa> dlaGospodarstwa(String gospodarstwoId) async {
    final termin = terminZWykazami;
    if (termin == null || termin.dataRoczna == null) {
      return const TerminyGospodarstwa(terminy: [], dzialkiBezKoduGminy: 0);
    }

    final wiersze = await baza.query(
      'dzialka_ewidencyjna',
      columns: ['identyfikator'],
      where: 'gospodarstwo_id = ? AND usuniety = 0',
      whereArgs: [gospodarstwoId],
    );

    var bezKodu = 0;
    final kody = <String>{};
    for (final wiersz in wiersze) {
      final kod = SlownikGminTerminow.kodGminy(
        (wiersz['identyfikator'] as String?) ?? '',
      );
      if (kod == null) {
        bezKodu++;
      } else {
        kody.add(kod);
      }
    }

    final terminy = <TerminDlaGminy>[];
    for (final kod in kody.toList()..sort()) {
      final wariant = gminy.dlaGminy(kod);
      terminy.add(
        TerminDlaGminy(
          kodGminy: kod,
          dataRoczna: wariant?.dataRoczna ?? termin.dataRoczna!,
          zrodlo: wariant?.zrodlo ?? 'termin domyślny programu azotanowego',
        ),
      );
    }
    return TerminyGospodarstwa(terminy: terminy, dzialkiBezKoduGminy: bezKodu);
  }
}
