import '../../rdzen/reguly/regula_prawna.dart';
import '../dokumenty/dokument_ewidencji.dart';
import 'przeglad.dart';

/// Przegląd warunkowości na kontrolę — ten sam dokument, który aplikacja
/// umie wydrukować do PDF i wyeksportować do CSV/XLSX.
///
/// Kolumny tego zestawienia nie są polami wymaganymi przez przepis (takie
/// kolumny biorą się ze słownika reguł, jak w trzech rejestrach) — to
/// nagłówki raportu, który aplikacja składa z własnych rachunków. Dlatego
/// stoją tutaj, a nie w danych; żadna z nich nie jest progiem ani terminem.
abstract final class WydrukWarunkowosci {
  static const List<PoleWymagane> kolumny = [
    PoleWymagane(id: 'norma', nazwa: 'norma'),
    PoleWymagane(id: 'nazwa', nazwa: 'co mówi'),
    PoleWymagane(id: 'stan', nazwa: 'stan'),
    PoleWymagane(id: 'co_wiemy', nazwa: 'co wiemy'),
    PoleWymagane(id: 'co_zrobic', nazwa: 'co zrobić'),
  ];

  /// Zwraca `null`, gdy słownik reguł nie zna obowiązku „warunkowosc" —
  /// wtedy nie udajemy dokumentu z podstawą prawną, której nie mamy.
  static DokumentEwidencji? zbuduj({
    required List<StanNormy> stany,
    required SlownikRegul reguly,
    required String gospodarstwo,
    required int rok,
    String? numerProducenta,
    DateTime? sporzadzono,
  }) {
    final obowiazek = reguly.obowiazek('warunkowosc');
    if (obowiazek == null) {
      return null;
    }
    return DokumentEwidencji(
      tytul: obowiazek.nazwa,
      podstawa: obowiazek.podstawa,
      wersjaRegul: reguly.wersja,
      gospodarstwo: gospodarstwo,
      numerProducenta: numerProducenta,
      rok: rok,
      kolumny: kolumny,
      wiersze: [
        for (final stanNormy in stany)
          WierszDokumentu(
            wartosci: [
              stanNormy.norma.numer,
              stanNormy.norma.nazwa,
              stanNormy.stanDlaRolnika,
              stanNormy.coWiemy.join(' '),
              stanNormy.coZrobic,
            ],
            // Na wydruku „brak" oznacza normę, której aplikacja nie
            // policzyła — kontrola ma widzieć, czego tu nie ma.
            braki: [if (!stanNormy.liczona) 'stan policzony przez aplikację'],
          ),
      ],
      sporzadzono: sporzadzono ?? DateTime.now(),
    );
  }
}
